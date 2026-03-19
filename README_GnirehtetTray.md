GnirehtetTray (Windows)

A lightweight Windows tray wrapper for gnirehtet.

It runs: - gnirehtet relay - gnirehtet autorun

in the background and provides a tray icon with status and controls.

------------------------------------------------------------------------

What This Does

-   Runs gnirehtet silently
-   Shows connection status in the system tray
-   Allows Start / Stop / Restart
-   Shows device and VPN state
-   Captures logs automatically

------------------------------------------------------------------------

Requirements

You must have:

1.  gnirehtet.exe
2.  ADB (Android Platform Tools) in your PATH OR edit $g_adb inside the
    script before building.

Download platform tools:
https://developer.android.com/studio/releases/platform-tools

------------------------------------------------------------------------

Installation (Recommended)

1.  Download the latest release from the Releases page.
2.  Place GnirehtetTray.exe in the same folder as gnirehtet.exe.
3.  Double-click GnirehtetTray.exe.

No AutoIt required.

------------------------------------------------------------------------

Example Folder Layout

GnirehtetTray.exe gnirehtet.exe assets/ (only if using non-embedded tray
icons) logs/ (created automatically)

------------------------------------------------------------------------

Tray Icon States

Connected - Relay running + device detected + tun0 up Waiting - Relay
running but no device or VPN Stopped - gnirehtet not running

Hover over the icon to see detailed status. Right-click for controls.

------------------------------------------------------------------------

First-Time Setup

On your Android device:

-   Enable USB debugging
-   Accept the RSA prompt (Allow USB debugging)
-   Accept VPN permission when prompted

------------------------------------------------------------------------

Autostart (Optional)

To start at login:

1.  Press Win+R and type: shell:startup
2.  Place a shortcut to GnirehtetTray.exe there

------------------------------------------------------------------------

Pinning to Taskbar

If Windows shows the default icon after pinning:

Unpin -> delete exe -> rebuild -> repin.

If still incorrect, clear icon cache in CMD:

taskkill /f /im explorer.exe
del %localappdata%\IconCache.db
del %localappdata%\Microsoft\Windows\Explorer\iconcache*
start explorer.exe

------------------------------------------------------------------------

Logs

Logs are written to:

logs-latest.log logs-latest.log

Use these for troubleshooting.

------------------------------------------------------------------------

Building From Source (Developers Only)

Requires compiling with AutoIt.

Run build.bat or use CMD to make sure the app icon is used.

Example build command in CMD:

"C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe" /in "GnirehtetTray.au3" /out "GnirehtetTray.exe" /icon "assets\app.ico" /x64

------------------------------------------------------------------------

Licensing

This is an unofficial wrapper for gnirehtet licensed under the MIT License. It is not affiliated with
Genymobile.

gnirehtet is licensed under the Apache License 2.0.
Android platform-tools are licensed under the Apache License 2.0.

This project does not redistribute those binaries.
