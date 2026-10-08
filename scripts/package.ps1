$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$BuildScript = Join-Path $PSScriptRoot "build.ps1"
$BuildExe = Join-Path $RepoRoot "build\GnirehtetTray.exe"
$DistDir = Join-Path $RepoRoot "dist"
$Zip = Join-Path $DistDir "GnirehtetTray.zip"
$StageDir = Join-Path ([System.IO.Path]::GetTempPath()) ("GnirehtetTray-package-" + [guid]::NewGuid().ToString("N"))

& $BuildScript

try {
    New-Item -ItemType Directory -Force -Path $StageDir, $DistDir | Out-Null
    Copy-Item -LiteralPath $BuildExe -Destination (Join-Path $StageDir "GnirehtetTray.exe") -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot "assets") -Destination (Join-Path $StageDir "assets") -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot "helpers") -Destination (Join-Path $StageDir "helpers") -Recurse -Force
    New-Item -ItemType Directory -Force -Path (Join-Path $StageDir "scripts") | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot "scripts\setup-no-uac.ps1") -Destination (Join-Path $StageDir "scripts\setup-no-uac.ps1") -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot "README.md") -Destination (Join-Path $StageDir "README.md") -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot "LICENSE") -Destination (Join-Path $StageDir "LICENSE") -Force

    Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $Zip -Force
    Write-Host "Packaged: $Zip"
} finally {
    Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction SilentlyContinue
}
