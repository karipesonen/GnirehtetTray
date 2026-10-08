# GnirehtetTray (Windows)

A lightweight Windows tray wrapper for **gnirehtet**.

Official project:  
https://github.com/Genymobile/gnirehtet

It runs `gnirehtet relay` in the background and sends `gnirehtet start` to start the phone client. Repairs use `gnirehtet restart`; this version does not run `gnirehtet autorun`.

> This project is an unofficial wrapper and is not affiliated with Genymobile.

---

## Quick Installation (Most Users)

### 1. Install gnirehtet normally

Follow the official instructions:  
https://github.com/Genymobile/gnirehtet

### 2. Copy GnirehtetTray into that same folder

Extract the [GnirehtetTray release ZIP](https://github.com/karipesonen/GnirehtetTray/releases/latest) into the folder containing `gnirehtet.exe` and `adb.exe`.

Example final folder:

- `gnirehtet.exe`
- `adb.exe`
- `AdbWinApi.dll`
- `AdbWinUsbApi.dll`
- `GnirehtetTray.exe`
- `assets\`
- `helpers\`
- `scripts\setup-no-uac.ps1`

### 3. Run GnirehtetTray.exe

Double-click `GnirehtetTray.exe`.

It will:

- Start the relay and phone client in the background
- Show a tray icon with status and controls

No AutoIt required to run the release.

---

## Optional No-UAC Shortcut

If you want a shortcut that starts GnirehtetTray through an elevated scheduled task, run:

```powershell
.\scripts\setup-no-uac.ps1
```

The script asks for administrator permission, creates or updates the `GnirehtetTrayNoUAC` scheduled task, and creates `GnirehtetTray.lnk` beside the executable.

It also allows repeated shortcut launches, so clicking the shortcut while the tray app is already running sends the second-launch repair command.

If you move the folder later, run the setup script again so the task points to the new path.

---

## Second Launch Behavior

GnirehtetTray runs one tray instance per install folder. If it is already running, launching `GnirehtetTray.exe` directly with no arguments sends the faster `repair` command to the existing tray instance and exits. The no-UAC taskbar shortcut also sends `repair`.

Command modes:

```powershell
.\GnirehtetTray.exe --restart
.\GnirehtetTray.exe --repair
.\GnirehtetTray.exe --start
.\GnirehtetTray.exe --stop
.\GnirehtetTray.exe --diagnose
```

The no-UAC taskbar shortcut sends `repair` when the tray is already running. Use explicit `--restart` only when you want the stronger, slower stop/start troubleshooting path.

---

## First-Time Android Setup

When connecting your phone for the first time:

- Enable **Developer options**.
- Enable **USB debugging**.
- Tap **Allow** on the USB debugging authorization prompt.
- Accept the VPN permission prompt from gnirehtet.

For a trusted personal PC, enabling **Disable ADB authorization timeout** can reduce repeated authorization prompts.

---

## Tray Icon States

The tray status is intentionally lightweight. It shows gnirehtet process, authorized phone availability, and relay client connect/disconnect events from `logs\relay-latest.log`; it is still not a perfect live proof of internet traffic.

| State | Meaning |
|---|---|
| Gnirehtet ready | gnirehtet is running, ADB shows an authorized phone, and the relay log has seen a client connected event; internet traffic is not deeply verified |
| Waiting | gnirehtet is starting, no authorized phone is available, or the relay client is not connected yet |
| Starting / Repairing / Stopping | A user command is still in progress |
| Stopped | gnirehtet is not running, or the user disconnected it |

Hover the tray icon to see status details. Right-click for Connect / repair, Disconnect phone VPN, and Logs. Use `logs\relay-latest.log` for relay client disconnect/connect events and `logs\tray-actions.log` to see start/stop/repair timings and recovery attempts.

---


## Tray Controls

- `Connect / repair` starts gnirehtet and sends one explicit `gnirehtet start` if it is stopped. If it is already running, it sends one `gnirehtet restart` to the phone client.
- `Disconnect phone VPN` sends one stop command to the phone, uses a short `adb shell am force-stop com.genymobile.gnirehtet` fallback only if that command fails and the phone appears reachable, then closes the Windows relay process. `Exit tray` runs the same cleanup before closing. It does not wait to prove `tun0` disappeared.
- Reopening the no-UAC pinned shortcut performs the same fast repair path as `Connect / repair`. After a relay client disconnect or ADB transient, the tray sends bounded staged repairs at about 750ms, 2.5s, and 5s if the relay client is still disconnected.

Startup and disconnect are intentionally bounded so the tray stays responsive; Android and gnirehtet may still need a few seconds to settle afterward. During that window the tray holds an explicit `Starting`, `Repairing`, or `Stopping` state instead of treating each intermediate check as a final failure.

---

## Optional: Start at Login

1. Press `Win + R`
2. Type: `shell:startup`
3. Add a shortcut to `GnirehtetTray.exe`

---

## Log Files

Logs are written to:

- `logs\relay-latest.log`
- `logs\tray-actions.log`

Use these if troubleshooting. This version does not create `autorun-latest.log`.

---

## Troubleshooting

### Device shows "unauthorized"

1. Disconnect USB
2. Reconnect
3. Accept the RSA prompt on the phone

### Connection does not return after unplug/replug

Use `Connect / repair` in the tray menu or click the no-UAC taskbar shortcut. Automatic recovery may take time; a green icon does not prove internet traffic works.

### Taskbar icon appears incorrect after pinning

Unpin the old shortcut, run `scripts\setup-no-uac.ps1` again, and pin the updated `GnirehtetTray.lnk`. If the icon remains stale, restart Windows Explorer from Task Manager.

---

## Building From Source (Developers)

Requires AutoIt 3. Run these commands from the repository folder; it can live anywhere.

Build the executable into `build\` without launching it:

```powershell
.\scripts\build.ps1
```

Build, copy into `run\`, and launch the local runtime:

```powershell
.\scripts\dev.ps1
```

Create a release ZIP:

```powershell
.\scripts\package.ps1
```

See `DEVELOPMENT.md` for the folder layout.

The scripts use AutoIt's `Aut2Exe` compiler; `build.ps1` also runs `Au3Check` first. Direct compilation still works if you prefer it.

Create the output folder and compile directly from Command Prompt:

```cmd
if not exist build mkdir build
"C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2Exe.exe" /in "src\GnirehtetTray.au3" /out "build\GnirehtetTray.exe" /icon "assets\app.ico" /x64
```

---

## Licensing

This project (GnirehtetTray) is licensed under the **MIT License**.

gnirehtet and Android platform-tools are licensed under the **Apache License 2.0**.

This repository does **not** redistribute those binaries.

---

## Support

If this project saves you time, you can support it here:

https://buymeacoffee.com/karipesonen
