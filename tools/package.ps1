param([string]$GameRoot = 'D:\Steam\steamapps\common\GarrysMod')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$release=Join-Path $project 'release'
$version='0.3.0'
$bundle=Join-Path $release "sandbox-mcp-$version-windows-x64"
New-Item -ItemType Directory -Force -Path $bundle | Out-Null
& cargo build --release --locked --manifest-path (Join-Path $project 'Cargo.toml')
if ($LASTEXITCODE -ne 0) { throw 'Companion build failed' }
Copy-Item -LiteralPath (Join-Path $project 'target\release\sandbox-mcp.exe') -Destination $bundle -Force
Copy-Item -LiteralPath (Join-Path $project 'LICENSE') -Destination $bundle -Force
Copy-Item -LiteralPath (Join-Path $project 'docs\INSTALL.md') -Destination (Join-Path $bundle 'START-HERE.md') -Force
$launcher=@'
Set files = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
exe = files.BuildPath(files.GetParentFolderName(WScript.ScriptFullName), "sandbox-mcp.exe")
shell.Run Chr(34) & exe & Chr(34) & " setup", 0, False
'@
Set-Content -LiteralPath (Join-Path $bundle 'Setup.vbs') -Value $launcher -Encoding ascii
$gma=Join-Path $release "sandbox-mcp-$version.gma"
& (Join-Path $GameRoot 'bin\gmad.exe') create -folder (Join-Path $project 'addon') -out $gma
if ($LASTEXITCODE -ne 0) { throw 'Workshop packaging validation failed' }
& python (Join-Path $project 'tools\third_party_notices.py')
if ($LASTEXITCODE -ne 0) { throw 'Dependency license collection failed' }
Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath (Join-Path $release "sandbox-mcp-$version-windows-x64.zip") -Force
Get-FileHash -LiteralPath $gma,(Join-Path $release "sandbox-mcp-$version-windows-x64.zip"),(Join-Path $bundle 'sandbox-mcp.exe') | ForEach-Object { @{file=(Split-Path $_.Path -Leaf);sha256=$_.Hash.ToLowerInvariant()} } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $release 'checksums.json')
Write-Output "Release prepared locally at $release. No Workshop upload was performed."
