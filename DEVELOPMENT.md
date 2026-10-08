# Development

This repository is the development workbench for GnirehtetTray.

## Folder layout

- `src/` contains the AutoIt source.
- `assets/` contains icons tracked by Git.
- `helpers/` contains helper scripts shipped with releases.
- `scripts/` contains developer automation.
- `build/` contains the latest compiled executable. It is ignored by Git.
- `run/` is the local runnable gnirehtet installation. It is ignored by Git.
- `dist/` contains release ZIPs. It is ignored by Git.

## Why files are copied

There are two intentional copies during development:

- `build/GnirehtetTray.exe` is the compiler output.
- `run/GnirehtetTray.exe` is the local installed app used for testing beside `gnirehtet.exe`, `adb.exe`, `assets/`, `helpers/`, and `logs/`.

The files under `run/` mimic what a user has after installing the app. `assets/` and `helpers/` are copied there because the compiled AutoIt app and shortcut resolve those files relative to the running executable.

`package.ps1` may stage files temporarily, but it cleans that staging folder after creating `dist/GnirehtetTray.zip`.

## Daily development

Build and update `run/`, then launch the app:

```powershell
.\scripts\dev.ps1
```

Build and update `run/` without launching:

```powershell
.\scripts\dev.ps1 -NoLaunch
```

## Build only

```powershell
.\scripts\build.ps1
```

## Package release files

```powershell
.\scripts\package.ps1
```

The release ZIP is written to `dist/GnirehtetTray.zip`.

## Shortcut location

The project-created shortcut lives in `run/GnirehtetTray.lnk` because it belongs to the local runnable installation. Pin that shortcut to the taskbar if you want the no-UAC launch path.

Windows stores pinned taskbar items in its own shell-managed location. Do not track taskbar shortcuts in Git.

After moving the project folder or changing the runtime path, recreate the scheduled task and shortcut:

```powershell
.\scripts\setup-no-uac.ps1
```

The script asks for administrator permission, creates/updates the `GnirehtetTrayNoUAC` scheduled task, and refreshes `run/GnirehtetTray.lnk` to point at `run/helpers/NoUACHidden.vbs`.

## Second-launch command channel

The tray app is single-instance per runtime folder. Starting the same `run\GnirehtetTray.exe` again sends a command through `run\logs\tray-command.txt` and exits.

Default direct exe second launch command:

```powershell
.\run\GnirehtetTray.exe
```

The no-UAC shortcut writes `repair` to `run\logs\tray-command.txt`, waits briefly for the tray to consume it, and only calls Task Scheduler if no tray appears to be running. This reaches an already-running elevated tray even when Windows hides the process path from the helper without causing a double command. Directly launching `run\GnirehtetTray.exe` without arguments also sends `repair`. Explicit commands are also supported:

```powershell
.\run\GnirehtetTray.exe --repair
.\run\GnirehtetTray.exe --restart
.\run\GnirehtetTray.exe --start
.\run\GnirehtetTray.exe --stop
.\run\GnirehtetTray.exe --diagnose
```

Use `--repair` for the normal fast path: it starts if stopped, or sends one `gnirehtet restart` if the relay is already running. Use `--restart` when you explicitly want the slower full stop/start troubleshooting path.


## Tray menu model

The visible tray menu intentionally has only two connection controls:

- `Connect / repair`: starts the relay and sends one explicit `gnirehtet start` when stopped; otherwise sends one `gnirehtet restart` to the phone client.
- `Disconnect phone VPN`: sends one Android stop command, uses `adb shell am force-stop com.genymobile.gnirehtet` as a short fallback only if the stop command fails and the phone appears reachable, then closes the relay process. It does not wait for `tun0` proof.

The command channel still supports `--restart` for troubleshooting, but no-argument second launch now defaults to `repair` so the tray executable responds faster. Restart is not exposed as a normal tray item.

## Operation-state display

Start is bounded: it starts the relay if needed, then sends one explicit phone-client start without waiting for VPN proof. Stop is optimistic after the phone stop command is sent. Repair launches `gnirehtet restart` asynchronously and returns quickly. The source sets explicit `Starting`, `Repairing`, and `Stopping` states before running those commands, and stale operation text expires after about 15 seconds.

Normal status polling is intentionally lightweight: it checks whether `gnirehtet.exe` is running, what `adb devices` reports, and the latest relay client connect/disconnect event from `logs/relay-latest.log`. Status uses `Gnirehtet ready` only after gnirehtet is running, ADB shows an authorized phone, and the relay log has seen a client connected event. Quick unplug/replug recovery watches appended `TunnelServer` client disconnect/connect events in `logs/relay-latest.log`, then sends bounded staged repairs at about 750ms, 2.5s, and 5s if the relay client is still disconnected. A new relay `connected` event cancels the remaining staged repairs. It does not poll `adb shell echo`, `adb reverse --list`, or `tun0` in the background, and it does not run recovery loops. Detailed VPN/tunnel truth belongs in `logs/relay-latest.log` and `logs/tray-actions.log`.

`tun0` is not checked during normal user actions anymore; that was accurate but made stop feel slow. Detailed VPN truth belongs in the gnirehtet log.

## Runtime dependencies

Keep `gnirehtet.exe`, `gnirehtet.apk`, `adb.exe`, and Android platform-tool DLLs inside `run/` for local testing. They are runtime dependencies, not project source.


## Timing diagnostics

The tray writes bounded action timings to `run/logs/tray-actions.log`. Use it with `run/logs/relay-latest.log` to separate tray-side waits from Android/ADB/gnirehtet connection delays.
## Debugging slowness checklist

Before changing app logic, check the environment first:

1. Check Windows performance: memory pressure, CPU spikes, disk activity, delayed tray/menu response, File Explorer lag, or slow process startup. If the PC is sluggish, free memory or wait until idle, then retest.
2. Check live processes: `GnirehtetTray.exe`, `gnirehtet.exe`, `adb.exe`, and `wscript.exe` when testing the shortcut helper.
3. Verify the scheduled task `GnirehtetTrayNoUAC` uses `MultipleInstances IgnoreNew`.
4. Verify the pinned/no-UAC shortcut points to `run\helpers\NoUACHidden.vbs` and that the runtime helper matches `helpers\NoUACHidden.vbs`.
5. Reproduce with `run\logs\tray-actions.log` open, then compare timings with `run\logs\relay-latest.log`.
6. Record whether the bad run happened under system load, after screen lock/unlock, during ADB authorization changes, or after moving/rebuilding files.

## Hidden external state

GnirehtetTray behavior is not only source code. Task Scheduler settings, `.lnk` shortcut contents, pinned taskbar state, copied files under `run\`, Android VPN state, and ADB authorization/offline state can all affect the observed result. Elevated scheduled-task tray processes can hide their `ExecutablePath` from unelevated helper scripts, so the no-UAC helper must not rely on process-path detection before sending a command. Recreate the no-UAC task and shortcut with `scripts\setup-no-uac.ps1` after moving the folder or changing the runtime path.

## Connection control model

Tray commands should stay bounded and non-overlapping. Start launches the relay, then start and repair send gnirehtet commands and return control to the tray quickly while status waits for a relay client connected event. Stop sends the phone stop command, uses the short force-stop fallback when appropriate, then closes the Windows relay. Exit tray runs the same cleanup, so closing the tray should also close the relay. The no-UAC taskbar shortcut and direct exe second launch both use the faster `repair` path. The tray status is relay-client/phone availability, not perfect proof of the Android VPN interface. `--restart` remains the stronger troubleshooting path, and `--diagnose` is the manual-only path for deeper ADB/VPN checks.

## Manual diagnostics

Use the hidden command when status/logs are not enough:

```powershell
.\run\GnirehtetTray.exe --diagnose
```

It writes one diagnostic section to `run\logs\tray-actions.log` using `adb devices`, `adb shell echo ok`, `adb reverse --list`, and `adb shell ip addr show tun0`. These deeper checks are never part of normal polling.
## Unplug/replug recovery

The no-UAC taskbar shortcut uses `repair`, not `restart`, because that matched the observed working unplug/replug recovery. Automatic USB replug recovery is handled by relay log disconnect detection first, with ADB transient repair as a fallback. The tray no longer relies on `gnirehtet autorun`, because it conflicted with the already-running relay port. Explicit `--restart` remains a plain stop/start troubleshooting path. Normal polling does not run loops or deep checks; it may send up to three async `gnirehtet restart` attempts after a relay client disconnect, or one repair when a previously authorized phone disappears and then returns.




