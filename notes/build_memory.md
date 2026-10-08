# GnirehtetTray Build Memory

Last updated: 2026-10-07

## Canonical Paths

- Project root: `C:\Users\karip\Documents\Code\GnirehtetTray`
- Source: `src\GnirehtetTray.au3`
- Local runtime: `run\`
- Helper source: `helpers\NoUACHidden.vbs`
- Runtime helper copy: `run\helpers\NoUACHidden.vbs`
- No-UAC setup: `scripts\setup-no-uac.ps1`
- Main development guide: `DEVELOPMENT.md`

## Build Flow

- Use `scripts\dev.ps1` for normal development: compile, copy assets/helpers into `run\`, and launch.
- Use `scripts\dev.ps1 -NoLaunch` to compile and refresh `run\` without launching.
- Use `scripts\build.ps1` for compile-only output in `build\`.
- Use `scripts\package.ps1` for release ZIP output in `dist\`.

## Runtime Model

- `build\GnirehtetTray.exe` is compiler output.
- `run\GnirehtetTray.exe` is the local installed app used for testing beside `gnirehtet.exe`, `adb.exe`, Android platform-tool DLLs, `assets\`, `helpers\`, and `logs\`.
- Runtime copies in `run\assets\` and `run\helpers\` are intentional because the compiled app and shortcut resolve files relative to the running executable.
- The no-UAC scheduled task is named `GnirehtetTrayNoUAC`.
- The no-UAC taskbar shortcut uses `run\helpers\NoUACHidden.vbs`.

## Live Process Names

Check these before blaming source code:

- `GnirehtetTray.exe`
- `gnirehtet.exe`
- `adb.exe`
- `wscript.exe` when testing the helper path

## Shortcut And Command Behavior

- Direct second launch of `run\GnirehtetTray.exe` defaults to `repair`.
- The no-UAC helper writes `repair`, waits briefly for the tray to consume the command file, and only then calls Task Scheduler if needed. This avoids missed commands when elevated task processes hide `ExecutablePath`.
- The scheduled task should use `MultipleInstances IgnoreNew`, not `Parallel`.
- Windows pinned taskbar state, `.lnk` contents, Task Scheduler settings, and runtime helper copies are external state that can remain stale after source edits.

## Slowness Debugging Rule

Before changing connection logic, check whether Windows itself is slow: high memory use, CPU spikes, disk activity, delayed tray menu opening, File Explorer lag, or delayed process startup. If the PC is under pressure, free memory or wait until idle, then retest start/stop/restart timings.

Use `run\logs\tray-actions.log` and `run\logs\relay-latest.log` to separate tray-side command waits from Android/ADB/gnirehtet behavior.

Establish a measured baseline under comparable system load, change one recovery mechanism per experiment, and record command response, actual phone internet recovery, and icon update separately. A relay client connected event does not prove internet traffic works.

## Current Stability Pass

- Source-verified behavior: green status is `Gnirehtet ready` when a gnirehtet process exists, ADB sees an authorized phone, and the tracked relay client state is connected. This does not verify Android VPN state or working internet traffic.
- Lightweight status uses process state, `adb devices`, and relay client connect/disconnect events from `run\logs\relay-latest.log`, with an ADB grace period after a previously good device disappears or goes offline/unauthorized.
- `--diagnose` is manual-only and writes deeper ADB/VPN checks to `run\logs\tray-actions.log`; do not add those checks to background polling.

## Unplug/Replug Recovery

- Implemented: the no-UAC taskbar shortcut, direct no-argument second launch, and tray menu use `repair`; `--restart` remains a plain stop/start troubleshooting path.
- Implemented: appended relay log disconnect events schedule up to three asynchronous `gnirehtet restart` attempts at about 750ms, 2.5s, and 5s while running is desired and gnirehtet exists. A connected event cancels the remaining attempts. A new disconnect event resets the sequence; these are scheduled thresholds, not guaranteed completion times.
- Implemented: return of an authorized phone after a tracked ADB transient can send one repair, suppressed while a recent relay recovery is settling. Background behavior therefore includes recovery commands, not just passive polling.
- No `gnirehtet autorun`, background `adb reconnect`, or recurring deep Android checks are present in the source. Exit tray uses connection cleanup to stop the phone client and close gnirehtet processes.

## Phone-Test Evidence

- Historical user testing confirmed manual `repair`, including the taskbar shortcut, recovered after unplug/replug. This is an observed result, not a guarantee for every device state.
- Automatic recovery and icon timing had mixed results in this conversation, including connected-looking states without working internet. The current staged recovery has not been validated against a fresh phone test during this documentation update.
- Treat source implementation and successful compilation separately from phone-tested results; require a measured real-device reproduction before declaring connection problems fixed.
