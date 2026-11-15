[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('create','upload','subscribe','inspect','publish')][string]$Action
)
$ErrorActionPreference='Stop'
$Addon='sandbox_mcp'
if([IntPtr]::Size -ne 4){throw 'Use 32-bit Windows PowerShell'}
$project=Split-Path -Parent $PSScriptRoot
$release=Join-Path $project 'release'
$manifest=Get-Content -LiteralPath (Join-Path $release 'release.json') -Raw | ConvertFrom-Json
if($manifest.appid -ne 4000 -or $manifest.addon -ne $Addon){throw 'Wrong release identity'}
$itemPath=Join-Path $release 'item.json'
$receiptPath=Join-Path $release ($Action+'.json')
$env:SteamAppId='4000'; $env:SteamGameId='4000'
. (Join-Path $PSScriptRoot 'steam-api.ps1')
function Await-Call([UInt64]$call,[int]$callback,[int]$size){
 if(!$call){throw 'Steam returned no call handle'}
 $receipt=[ordered]@{action=$Action;addon=$Addon;call="$call";status='pending';utc=[DateTime]::UtcNow.ToString('o')}
 $receipt | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding UTF8
 $deadline=[DateTime]::UtcNow.AddSeconds(55); $failed=$false; $done=$false
 do {
  [GModWorkshop]::SteamAPI_RunCallbacks()
  $done=[GModWorkshop]::SteamAPI_ISteamUtils_IsAPICallCompleted($utils,$call,[ref]$failed)
  if($done){break}; Start-Sleep -Milliseconds 100
 } while([DateTime]::UtcNow -lt $deadline)
 if(!$done -or $failed){throw 'Call pending or failed. Inspect receipt before retrying.'}
 $bytes=New-Object byte[] $size
 $received=[GModWorkshop]::SteamAPI_ISteamUtils_GetAPICallResult($utils,$call,$bytes,$size,$callback,[ref]$failed)
 $receipt.status='completed'; $receipt.received=$received; $receipt.failed=$failed
 $receipt.result=[BitConverter]::ToInt32($bytes,0); $receipt.item=[BitConverter]::ToUInt64($bytes,8).ToString()
 $offset=if($callback -eq 3403){16}else{4}; $receipt.needs_agreement=[bool]$bytes[$offset]
 $receipt | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding UTF8
 if(!$received -or $failed -or $receipt.result -ne 1){throw "Steam result $($receipt.result); see $receiptPath"}
 return $receipt
}
$errorText=New-Object Text.StringBuilder 1024
$init=[GModWorkshop]::SteamAPI_InitFlat($errorText)
if($init -ne 0){throw "Steam init failed ($init): $errorText"}
try {
 $ugc=[GModWorkshop]::SteamAPI_SteamUGC_v020(); $utils=[GModWorkshop]::SteamAPI_SteamUtils_v010()
 if($ugc -eq [IntPtr]::Zero -or $utils -eq [IntPtr]::Zero){throw 'Missing Steam interface'}
 if($Action -eq 'create'){
  if((Test-Path -LiteralPath $itemPath) -or (Test-Path -LiteralPath $receiptPath)){throw 'Creation already attempted; inspect receipts'}
  @{action='create';status='starting';utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding UTF8
  $call=[GModWorkshop]::SteamAPI_ISteamUGC_CreateItem($ugc,4000,0)
  $result=Await-Call $call 3403 24
  [ordered]@{appid=4000;addon=$Addon;id=$result.item;title=$manifest.title;download_verified=$false} | ConvertTo-Json | Set-Content -LiteralPath $itemPath -Encoding UTF8
  $result | ConvertTo-Json
  if($result.needs_agreement){throw 'Steam requires the owner to accept the Workshop agreement'}
  return
 }
 $item=Get-Content -LiteralPath $itemPath -Raw | ConvertFrom-Json
 [UInt64]$id=$item.id
 if(!$id -or $id -in @(3822268020,3826155980,3833655445,3833701277,3833701456,3833701577,3839646487) -or $item.appid -ne 4000 -or $item.addon -ne $Addon){throw 'Invalid GMod item identity'}
 if($Action -eq 'inspect'){
  $query=[GModWorkshop]::SteamAPI_ISteamUGC_CreateQueryUGCDetailsRequest($ugc,[UInt64[]]@($id),1)
  if($query -eq [UInt64]::MaxValue){throw 'Invalid query'}
  try {
   if(![GModWorkshop]::SteamAPI_ISteamUGC_SetReturnAdditionalPreviews($ugc,$query,$true)){throw 'Preview query failed'}
   $call=[GModWorkshop]::SteamAPI_ISteamUGC_SendQueryUGCRequest($ugc,$query)
   $deadline=[DateTime]::UtcNow.AddSeconds(30); $failed=$false; $done=$false
   do {
    [GModWorkshop]::SteamAPI_RunCallbacks()
    $done=[GModWorkshop]::SteamAPI_ISteamUtils_IsAPICallCompleted($utils,$call,[ref]$failed)
    if($done){break}; Start-Sleep -Milliseconds 100
   } while([DateTime]::UtcNow -lt $deadline)
   if(!$done -or $failed){throw 'Preview query failed'}
   $count=[GModWorkshop]::SteamAPI_ISteamUGC_GetQueryUGCNumAdditionalPreviews($ugc,$query,0)
   $previews=@()
   for([UInt32]$i=0;$i -lt $count;$i++){
    $url=New-Object Text.StringBuilder 4096; $name=New-Object Text.StringBuilder 1024; [int]$type=0
    if(![GModWorkshop]::SteamAPI_ISteamUGC_GetQueryUGCAdditionalPreview($ugc,$query,0,$i,$url,4096,$name,1024,[ref]$type)){throw 'Preview read failed'}
    $previews += [pscustomobject]@{index=$i;name=$name.ToString();type=$type;url=$url.ToString()}
   }
   $previews | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $release 'gallery.json') -Encoding UTF8
   if($count -ne ($manifest.gallery.Count + [int][bool]$manifest.youtube_id)){throw "Unexpected gallery size: $count"}
   Write-Output "Verified $count gallery media entries"
  } finally {[void][GModWorkshop]::SteamAPI_ISteamUGC_ReleaseQueryUGCRequest($ugc,$query)}
 }
 if($Action -in @('upload','publish')){
  if(Test-Path -LiteralPath $receiptPath){throw 'This mutation was already attempted; inspect receipts'}
  if($Action -eq 'publish' -and !$item.download_verified){throw 'Downloaded package verification is required'}
  $gma=Join-Path $project 'release/sandbox-mcp-0.1.0.gma'
  if((Get-FileHash -LiteralPath $gma -Algorithm SHA256).Hash -ine $manifest.sha256){throw 'GMA differs from tested release'}
  $text=[IO.File]::ReadAllText((Join-Path $project 'release/description.txt'))
  $update=[GModWorkshop]::SteamAPI_ISteamUGC_StartItemUpdate($ugc,4000,$id)
  if($update -eq [UInt64]::MaxValue){throw 'Invalid update handle'}
  $visibility=if($Action -eq 'publish'){0}else{2}
  if(![GModWorkshop]::SteamAPI_ISteamUGC_SetItemVisibility($ugc,$update,$visibility)){throw 'Visibility failed'}
  if(![GModWorkshop]::SteamAPI_ISteamUGC_SetItemTitle($ugc,$update,$manifest.title)){throw 'Title failed'}
  if(![GModWorkshop]::SteamAPI_ISteamUGC_SetItemDescription($ugc,$update,$text)){throw 'Description failed'}
  if(![GModTags]::Set($ugc,$update,[string[]]@('build','fun'))){throw 'Tags failed'}
  if($Action -eq 'upload'){
   # GMod uses a single GMA file as the UGC content path, as gmpublisher does.
   if(![GModWorkshop]::SteamAPI_ISteamUGC_SetItemContent($ugc,$update,$gma)){throw 'GMA content failed'}
   $icon=Join-Path $release 'workshop-preview.jpg'
   if(![GModWorkshop]::SteamAPI_ISteamUGC_SetItemPreview($ugc,$update,$icon)){throw 'Icon failed'}
   foreach($name in $manifest.gallery){
    $path=Join-Path $release $name
    if((Get-Item -LiteralPath $path).Length -ge 1000000){throw 'Gallery image exceeds preview limit'}
    if(![GModWorkshop]::SteamAPI_ISteamUGC_AddItemPreviewFile($ugc,$update,$path,0)){throw 'Gallery failed'}
   }
  }
  @{action=$Action;status='starting';item="$id";utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding UTF8
  $call=[GModWorkshop]::SteamAPI_ISteamUGC_SubmitItemUpdate($ugc,$update,'0.1.0 beta - Build scenes through MCP with optional Wiremod integration.')
  $result=Await-Call $call 3404 16
  $result | ConvertTo-Json
  if([UInt64]$result.item -ne $id){throw 'Wrong returned item'}
  if($result.needs_agreement){throw 'Steam requires the owner to accept the Workshop agreement'}
 }
 if($Action -eq 'subscribe'){
  $call=[GModWorkshop]::SteamAPI_ISteamUGC_SubscribeItem($ugc,$id)
  if(!$call){throw 'Subscribe failed'}
  $deadline=[DateTime]::UtcNow.AddSeconds(55); $requested=$false
  do {
   [GModWorkshop]::SteamAPI_RunCallbacks()
   $state=[GModWorkshop]::SteamAPI_ISteamUGC_GetItemState($ugc,$id)
   if(($state -band 1) -and !$requested){$requested=[GModWorkshop]::SteamAPI_ISteamUGC_DownloadItem($ugc,$id,$true)}
   if(($state -band 5) -eq 5 -and ($state -band 56) -eq 0){break}
   Start-Sleep -Milliseconds 100
  } while([DateTime]::UtcNow -lt $deadline)
 }
 [GModWorkshop]::SteamAPI_RunCallbacks()
 $state=[GModWorkshop]::SteamAPI_ISteamUGC_GetItemState($ugc,$id)
 [UInt64]$size=0; [UInt32]$timestamp=0; $folder=New-Object Text.StringBuilder 4096
 $installed=[GModWorkshop]::SteamAPI_ISteamUGC_GetItemInstallInfo($ugc,$id,[ref]$size,$folder,4096,[ref]$timestamp)
 $status=[ordered]@{id="$id";state=$state;installed=$installed;bytes=$size;folder=$folder.ToString();timestamp=$timestamp}
 $status | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $release 'status.json') -Encoding UTF8
 $status | ConvertTo-Json
} finally {[GModWorkshop]::SteamAPI_Shutdown()}
