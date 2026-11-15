[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateSet(220,4000)][int]$AppId,
      [Parameter(Mandatory=$true)][string]$Name)
$ErrorActionPreference='Stop'
if([IntPtr]::Size -ne 4){throw 'Use 32-bit Windows PowerShell'}
$project=Split-Path -Parent $PSScriptRoot
$publishing=Join-Path $project 'release'
$entries=Get-Content -LiteralPath (Join-Path $publishing 'youtube.json') -Raw | ConvertFrom-Json
$entry=@($entries | Where-Object {$_.name -eq $Name -and $_.appid -eq $AppId})
if($entry.Count -ne 1){throw 'Unknown or ambiguous video identity'}
$entry=$entry[0]
[UInt64]$item=$entry.workshop_id
$video=$entry.youtube_id
if($video -notmatch '^[A-Za-z0-9_-]{11}$'){throw 'Invalid YouTube ID'}
$env:SteamAppId="$AppId"
$env:SteamGameId="$AppId"
. (Join-Path $PSScriptRoot 'steam-api.ps1')
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WorkshopVideo {
 [DllImport(@"D:\Steam\steamapps\common\Half-Life 2\bin\steam_api.dll", CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Ansi)]
 [return: MarshalAs(UnmanagedType.I1)]
 public static extern bool SteamAPI_ISteamUGC_AddItemPreviewVideo(IntPtr self, ulong update, string videoId);
}
'@
function Wait-SteamCall([UInt64]$call){
 if(!$call){throw 'Steam returned no call handle'}
 $deadline=[DateTime]::UtcNow.AddSeconds(45)
 $failed=$false
 do {
  [GModWorkshop]::SteamAPI_RunCallbacks()
  $done=[GModWorkshop]::SteamAPI_ISteamUtils_IsAPICallCompleted($utils,$call,[ref]$failed)
  if($done){if($failed){throw 'Steam API call failed'}; return}
  Start-Sleep -Milliseconds 100
 } while([DateTime]::UtcNow -lt $deadline)
 throw 'Steam call still pending; inspect receipt before retrying'
}
function Get-Previews {
 $query=[GModWorkshop]::SteamAPI_ISteamUGC_CreateQueryUGCDetailsRequest($ugc,[UInt64[]]@($item),1)
 if($query -eq [UInt64]::MaxValue){throw 'Invalid query'}
 try {
  if(![GModWorkshop]::SteamAPI_ISteamUGC_SetReturnAdditionalPreviews($ugc,$query,$true)){throw 'Preview query setup failed'}
  Wait-SteamCall ([GModWorkshop]::SteamAPI_ISteamUGC_SendQueryUGCRequest($ugc,$query))
  $count=[GModWorkshop]::SteamAPI_ISteamUGC_GetQueryUGCNumAdditionalPreviews($ugc,$query,0)
  for([UInt32]$i=0;$i -lt $count;$i++){
   $url=New-Object Text.StringBuilder 4096
   $file=New-Object Text.StringBuilder 1024
   [int]$type=0
   if(![GModWorkshop]::SteamAPI_ISteamUGC_GetQueryUGCAdditionalPreview($ugc,$query,0,$i,$url,4096,$file,1024,[ref]$type)){throw 'Preview read failed'}
   [pscustomobject]@{index=$i;type=$type;url=$url.ToString();name=$file.ToString()}
  }
 } finally {[void][GModWorkshop]::SteamAPI_ISteamUGC_ReleaseQueryUGCRequest($ugc,$query)}
}
$receiptPath=Join-Path $publishing ($Name+'-steam.json')
$errorText=New-Object Text.StringBuilder 1024
$init=[GModWorkshop]::SteamAPI_InitFlat($errorText)
if($init -ne 0){throw "Steam init failed ($init): $errorText"}
try {
 $ugc=[GModWorkshop]::SteamAPI_SteamUGC_v020()
 $utils=[GModWorkshop]::SteamAPI_SteamUtils_v010()
 if($ugc -eq [IntPtr]::Zero -or $utils -eq [IntPtr]::Zero){throw 'Missing Steam interface'}
 $before=@(Get-Previews)
 $present=@($before | Where-Object {$_.type -eq 1 -and $_.url.Contains($video)})
 if($present.Count){Write-Output "Already attached: $Name ($video)"; return}
 if(Test-Path -LiteralPath $receiptPath){throw 'A previous mutation receipt exists; inspect it before retrying'}
 if(!$before.Count){throw 'Expected existing screenshots; refusing to modify an unexpectedly empty gallery'}
 $receipt=[ordered]@{name=$Name;appid=$AppId;workshop_id="$item";youtube_id=$video;utc=[DateTime]::UtcNow.ToString('o');status='prepared';before=$before}
 $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
 $update=[GModWorkshop]::SteamAPI_ISteamUGC_StartItemUpdate($ugc,$AppId,$item)
 if(!$update -or $update -eq [UInt64]::MaxValue){throw 'Invalid update'}
 if(![WorkshopVideo]::SteamAPI_ISteamUGC_AddItemPreviewVideo($ugc,$update,$video)){throw 'Add preview video failed'}
 # Metadata-only update. Existing mod files, descriptions, images and visibility are untouched.
 $call=[GModWorkshop]::SteamAPI_ISteamUGC_SubmitItemUpdate($ugc,$update,'')
 $receipt.status='submitted'; $receipt.call="$call"
 $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
 Wait-SteamCall $call
 $bytes=New-Object byte[] 16
 $failed=$false
 $received=[GModWorkshop]::SteamAPI_ISteamUtils_GetAPICallResult($utils,$call,$bytes,16,3404,[ref]$failed)
 $receipt.result=[BitConverter]::ToInt32($bytes,0)
 $receipt.returned_item=[BitConverter]::ToUInt64($bytes,8).ToString()
 $receipt.needs_agreement=[bool]$bytes[4]
 $receipt.status='completed'
 $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
 if(!$received -or $failed -or $receipt.result -ne 1 -or $receipt.returned_item -ne "$item" -or $receipt.needs_agreement){throw 'Steam update did not complete successfully; inspect receipt'}
 $after=@(Get-Previews)
 $receipt.after=$after
 if(!@($after | Where-Object {$_.type -eq 1 -and $_.url.Contains($video)}).Count){throw 'Video missing from updated gallery'}
 foreach($old in $before){if(!@($after | Where-Object {$_.type -eq $old.type -and $_.url -eq $old.url}).Count){throw 'An existing preview is missing'}}
 $receipt.status='verified'
 $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
 Write-Output "Verified $Name ($item): added $video; retained $($before.Count) existing previews"
} finally {[GModWorkshop]::SteamAPI_Shutdown()}
