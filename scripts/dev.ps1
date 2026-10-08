param(
    [switch] $NoLaunch
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$BuildScript = Join-Path $PSScriptRoot "build.ps1"
$BuildExe = Join-Path $RepoRoot "build\GnirehtetTray.exe"
$RunDir = Join-Path $RepoRoot "run"
$RunExe = Join-Path $RunDir "GnirehtetTray.exe"

& $BuildScript

if (!(Test-Path -LiteralPath (Join-Path $RunDir "gnirehtet.exe"))) {
    throw "Missing runtime gnirehtet.exe in $RunDir"
}
if (!(Test-Path -LiteralPath (Join-Path $RunDir "adb.exe"))) {
    throw "Missing runtime adb.exe in $RunDir"
}

Get-Process -Name "GnirehtetTray" -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $RunExe } |
    Stop-Process -Force

Copy-Item -LiteralPath $BuildExe -Destination $RunExe -Force
$RunAssets = Join-Path $RunDir "assets"
$RunHelpers = Join-Path $RunDir "helpers"
Remove-Item -LiteralPath $RunAssets -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $RunHelpers -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath (Join-Path $RepoRoot "assets") -Destination $RunAssets -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot "helpers") -Destination $RunHelpers -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $RunDir "logs") | Out-Null

Write-Host "Updated runtime: $RunDir"

if (!$NoLaunch) {
    Start-Process -FilePath $RunExe -WorkingDirectory $RunDir
}

