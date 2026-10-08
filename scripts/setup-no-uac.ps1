$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$TaskName = "GnirehtetTrayNoUAC"

$DevRunExe = Join-Path $RepoRoot "run\GnirehtetTray.exe"
$ReleaseExe = Join-Path $RepoRoot "GnirehtetTray.exe"
if (Test-Path -LiteralPath $DevRunExe) {
    $AppDir = Join-Path $RepoRoot "run"
} elseif (Test-Path -LiteralPath $ReleaseExe) {
    $AppDir = $RepoRoot
} else {
    throw "Could not find GnirehtetTray.exe in '$RepoRoot' or '$RepoRoot\run'. Build or extract the app first."
}

$RunExe = Join-Path $AppDir "GnirehtetTray.exe"
$RunHelper = Join-Path $AppDir "helpers\NoUACHidden.vbs"
$RunIcon = Join-Path $AppDir "assets\app.ico"
$ShortcutPath = Join-Path $AppDir "GnirehtetTray.lnk"

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Host "Requesting administrator permission to create/update the scheduled task..."
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`""
    ) -Verb RunAs
    exit
}

if (!(Test-Path -LiteralPath $RunExe)) { throw "Missing runtime executable: $RunExe" }
if (!(Test-Path -LiteralPath $RunHelper)) { throw "Missing helper script: $RunHelper" }
if (!(Test-Path -LiteralPath $RunIcon)) { throw "Missing icon: $RunIcon" }

$action = New-ScheduledTaskAction -Execute $RunExe -WorkingDirectory $AppDir
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 72) -MultipleInstances IgnoreNew
$task = New-ScheduledTask -Action $action -Principal $principal -Settings $settings
Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = "$env:WINDIR\System32\wscript.exe"
$shortcut.Arguments = "`"$RunHelper`""
$shortcut.WorkingDirectory = $AppDir
$shortcut.IconLocation = "$RunIcon,0"
$shortcut.Description = "Start GnirehtetTray through the no-UAC scheduled task; second launch repairs the connection"
$shortcut.Save()

Write-Host "Updated scheduled task: $TaskName"
Write-Host "Task target: $RunExe"
Write-Host "Updated shortcut: $ShortcutPath"
