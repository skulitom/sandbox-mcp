param([string]$GameDir = 'D:\Steam\steamapps\common\GarrysMod\garrysmod')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$target=Join-Path $GameDir 'addons\sandbox_mcp_dev'
if (Test-Path -LiteralPath $target) {
    if (-not (Test-Path -LiteralPath (Join-Path $target '.sandbox-mcp-development'))) { throw 'Refusing to overwrite an unmarked addon directory' }
} else { New-Item -ItemType Directory -Path $target | Out-Null }
Copy-Item -Path (Join-Path $project 'addon\*') -Destination $target -Recurse -Force
Set-Content -LiteralPath (Join-Path $target '.sandbox-mcp-development') -Value $project
Write-Output "Installed development addon at $target"
