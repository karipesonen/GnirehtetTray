GnirehtetTray (Windows)

A lightweight Windows tray wrapper for gnirehtet.
Official project: https://github.com/Genymobile/gnirehtet

It runs:
- gnirehtet relay
- gnirehtet autorun

in the background and provides a system tray icon with status and controls.

This project is an unofficial wrapper and is not affiliated with Genymobile.


QUICK INSTALLATION (MOST USERS)
--------------------------------

1) Install gnirehtet normally

Follow the official instructions at:
https://github.com/Genymobile/gnirehtet

After installation you should have:
- gnirehtet.exe
- adb.exe (or adb available in PATH)

2) Copy GnirehtetTray into that same folder

Place into the same directory:
- GnirehtetTray.exe
- assets/ (if included in the release)

Example final folder:

gnirehtet.exe
adb.exe
GnirehtetTray.exe
assets/

3) Run GnirehtetTray.exe

Double-click GnirehtetTray.exe.

It will:
- Start gnirehtet in the background
- Launch relay and autorun automatically
- Show a tray icon with status

No AutoIt required.


FIRST-TIME ANDROID SETUP
------------------------

When connecting your phone for the first time:

- Enable USB debugging
- Tap "Allow" on the "Allow USB debugging" (RSA) prompt
- Accept the VPN permission request

If you press Cancel, the connection will not work.


TRAY ICON STATES
----------------

Connected  - Relay running + device detected + tun0 up
Waiting    - Relay running but no device or VPN
Stopped    - gnirehtet not running

Hover the tray icon to see detailed status.
Right-click for Start / Stop / Restart / Logs.


OPTIONAL: START AT LOGIN
------------------------

1) Press Win + R
2) Type: shell:startup
3) Add a shortcut to GnirehtetTray.exe


LOG FILES
---------

logs\autorun-latest.log
logs\relay-latest.log


TROUBLESHOOTING
---------------

If device shows as "unauthorized":
- Disconnect USB
- Reconnect
- Accept the RSA prompt on the phone

If taskbar icon appears wrong after pinning, run in Command Prompt:

taskkill /f /im explorer.exe
del %localappdata%\IconCache.db
del %localappdata%\Microsoft\Windows\Explorer\iconcache*
start explorer.exe


BUILDING FROM SOURCE (DEVELOPERS)
---------------------------------

Requires AutoIt.

"C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe" /in "GnirehtetTray.au3" /out "GnirehtetTray.exe" /icon "assets\app.ico" /x64


LICENSING
---------

This project (GnirehtetTray) is licensed under the MIT License.

gnirehtet and Android platform-tools are licensed under the Apache License 2.0.

This repository does not redistribute those binaries.
