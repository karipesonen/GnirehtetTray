# GnirehtetTray (Windows)

A lightweight Windows tray wrapper for **gnirehtet**.

Official project:  
https://github.com/Genymobile/gnirehtet

It runs:

- `gnirehtet relay`
- `gnirehtet autorun`

in the background and provides a system tray icon with status and controls.

> This project is an unofficial wrapper and is not affiliated with Genymobile.

---

## Quick Installation (Most Users)

### 1. Install gnirehtet normally

Follow the official instructions:  
https://github.com/Genymobile/gnirehtet

After installation you should have:

- `gnirehtet.exe`
- `adb.exe` (or adb available in PATH)

---

### 2. Copy GnirehtetTray into that same folder

Place the following into the same directory:

- `GnirehtetTray.exe`
- `assets/`

Example final folder:

- `gnirehtet.exe`
- `adb.exe`
- `GnirehtetTray.exe`
- `assets/`

---

### 3. Run GnirehtetTray.exe

Double-click `GnirehtetTray.exe`.

It will:

- Start gnirehtet in the background
- Launch relay and autorun automatically
- Show a tray icon with status

No AutoIt required.

---

## First-Time Android Setup

When connecting your phone for the first time:

- Enable **USB debugging**
- Tap **Allow** on the "Allow USB debugging" (RSA) prompt
- Accept the VPN permission request

If you press **Cancel**, the connection will not work.

---

## Tray Icon States

| State       | Meaning                                               |
|------------|--------------------------------------------------------|
| Connected  | Relay running + device detected + `tun0` up          |
| Waiting    | Relay running but no device or VPN                   |
| Stopped    | gnirehtet not running                                |

Hover the tray icon to see detailed status.  
Right-click for Start / Stop / Restart / Logs.

---

## Optional: Start at Login

1. Press `Win + R`
2. Type: `shell:startup`
3. Add a shortcut to `GnirehtetTray.exe`

---

## Log Files

Logs are written to:

logs\autorun-latest.log
logs\relay-latest.log


Use these if troubleshooting.

---

## Troubleshooting

### Device shows "unauthorized"

1. Disconnect USB
2. Reconnect
3. Accept the RSA prompt on the phone

---

### Taskbar icon appears incorrect after pinning

Run in **Command Prompt**:

```
taskkill /f /im explorer.exe
del %localappdata%\IconCache.db
del %localappdata%\Microsoft\Windows\Explorer\iconcache*
start explorer.exe
```

---

## Building From Source (Developers)

Requires AutoIt.

Compile using Command Prompt:

```
"C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe" /in "GnirehtetTray.au3" /out "GnirehtetTray.exe" /icon "assets\app.ico" /x64
```

Most users do not need this.

---

## Licensing

This project (GnirehtetTray) is licensed under the **MIT License**.

gnirehtet and Android platform-tools are licensed under the **Apache License 2.0**.

This repository does **not** redistribute those binaries.
