$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $RepoRoot "src\GnirehtetTray.au3"
$Icon = Join-Path $RepoRoot "assets\app.ico"
$BuildDir = Join-Path $RepoRoot "build"
$Output = Join-Path $BuildDir "GnirehtetTray.exe"
$AutoItDir = Join-Path ${env:ProgramFiles(x86)} "AutoIt3"
$Au3Check = Join-Path $AutoItDir "Au3Check.exe"
$Aut2Exe = Join-Path $AutoItDir "Aut2Exe\Aut2Exe.exe"

if (!(Test-Path -LiteralPath $Source)) { throw "Missing source: $Source" }
if (!(Test-Path -LiteralPath $Icon)) { throw "Missing icon: $Icon" }
if (!(Test-Path -LiteralPath $Au3Check)) { throw "Missing Au3Check: $Au3Check" }
if (!(Test-Path -LiteralPath $Aut2Exe)) { throw "Missing Aut2Exe: $Aut2Exe" }

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

Write-Host "Checking AutoIt syntax..."
& $Au3Check $Source
if ($LASTEXITCODE -ne 0) { throw "Au3Check failed with exit code $LASTEXITCODE" }

Write-Host "Compiling GnirehtetTray..."
Remove-Item -LiteralPath $Output -Force -ErrorAction SilentlyContinue
& $Aut2Exe /in $Source /out $Output /icon $Icon /x64
if ($LASTEXITCODE -ne 0) { throw "Aut2Exe failed with exit code $LASTEXITCODE" }

$deadline = (Get-Date).AddSeconds(30)
while (!(Test-Path -LiteralPath $Output) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
}
if (!(Test-Path -LiteralPath $Output)) { throw "Build did not create: $Output" }

Write-Host "Built: $Output"

