; =========================================================
; Compile-time metadata
; =========================================================
#AutoIt3Wrapper_Icon=assets\app.ico
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_ProductVersion=1.0.0.0
#AutoIt3Wrapper_Res_ProductName=GnirehtetTray
#AutoIt3Wrapper_Res_Description=Tray wrapper for gnirehtet

#RequireAdmin

; =========================================================
; Runtime options
; =========================================================
Opt("TrayMenuMode", 3)
Opt("TrayAutoPause", 0)

; =========================================================
; Globals / Configuration
; =========================================================
Global Const $APP_NAME = "Gnirehtet Tray"

Global Const $g_dir        = @ScriptDir
Global Const $g_gni        = $g_dir & "\gnirehtet.exe"
Global Const $g_adb        = "adb"
Global Const $g_logdir     = $g_dir & "\logs"
Global Const $g_autorunLog = $g_logdir & "\autorun-latest.log"
Global Const $g_relayLog   = $g_logdir & "\relay-latest.log"

Global Const $ICON_CONNECTED    = $g_dir & "\assets\tray_connected.ico"
Global Const $ICON_WAITING      = $g_dir & "\assets\tray_waiting.ico"
Global Const $ICON_DISCONNECTED = $g_dir & "\assets\tray_disconnected.ico"

Global $g_serial  = ""
Global $g_poll_ms = 4000

OnAutoItExitRegister("_Cleanup")

If Not FileExists($g_logdir) Then DirCreate($g_logdir)

; =========================================================
; Helpers
; =========================================================
Func _IsProc($name)
    Return ProcessExists($name) <> 0
EndFunc

Func _RunCmdHidden($cmd)
    Return Run(@ComSpec & ' /c ' & $cmd, @ScriptDir, @SW_HIDE)
EndFunc

; =========================================================
; ADB Status
; =========================================================
Func _ADB_DeviceCount()
    Local $pid = Run(@ComSpec & ' /c "' & $g_adb & ' devices"', "", @SW_HIDE, 6)
    Local $out = ""

    While 1
        $out &= StdoutRead($pid)
        If @error Then ExitLoop
        Sleep(20)
    WEnd

    Local $lines = StringSplit($out, @CRLF, 1)
    Local $cnt = 0

    For $i = 1 To $lines[0]
        Local $L = StringStripWS($lines[$i], 3)
        If StringRegExp($L, "^\S+\s+device$") Then $cnt += 1
    Next

    Return $cnt
EndFunc

Func _ADB_TunPresent()
    Local $pid = Run(@ComSpec & ' /c "' & $g_adb & ' shell ip addr show tun0"', "", @SW_HIDE, 6)
    Local $out = ""
    Local $t = TimerInit()

    While 1
        $out &= StdoutRead($pid)
        If @error Then ExitLoop
        If TimerDiff($t) > 2500 Then ExitLoop
        Sleep(20)
    WEnd

    If StringInStr($out, "error: no devices") Then Return False
    Return StringInStr($out, "tun0") > 0
EndFunc

; =========================================================
; Gnirehtet Control
; =========================================================
Func _RestartClient()
    Local $argsStop = "stop"
    Local $argsStart = "start"

    If $g_serial <> "" Then
        $argsStop  &= " -s " & $g_serial
        $argsStart &= " -s " & $g_serial
    EndIf

    RunWait('"' & $g_gni & '" ' & $argsStop,  @ScriptDir, @SW_HIDE)
    Sleep(300)
    RunWait('"' & $g_gni & '" ' & $argsStart, @ScriptDir, @SW_HIDE)
EndFunc

Func _StartRelay()
    Local $cmd = 'start "" /B "' & $g_gni & '" relay >> "' & $g_relayLog & '" 2>&1'
    _RunCmdHidden($cmd)
    Sleep(500)
    _RestartClient()
EndFunc

Func _StartAutorun()
    Local $args = "autorun"
    If $g_serial <> "" Then $args &= " -s " & $g_serial
    Local $cmd = 'start "" /B "' & $g_gni & '" ' & $args & ' >> "' & $g_autorunLog & '" 2>&1'
    _RunCmdHidden($cmd)
EndFunc

Func _StopClient()
    Local $args = "stop"
    If $g_serial <> "" Then $args &= " -s " & $g_serial
    RunWait('"' & $g_gni & '" ' & $args, @ScriptDir, @SW_HIDE)
EndFunc

Func _StopGnirehtet()
    _StopClient()

    While ProcessExists("gnirehtet.exe")
        ProcessClose("gnirehtet.exe")
        Sleep(150)
    WEnd
EndFunc

Func _Cleanup()
    _StopGnirehtet()
EndFunc

; =========================================================
; Tray Status
; =========================================================
Func _RefreshStatus()
    Local $devCount = _ADB_DeviceCount()
    Local $tunUp = False
    If $devCount > 0 Then $tunUp = _ADB_TunPresent()

    Local $hasGni = _IsProc("gnirehtet.exe")

    Local $tip = $APP_NAME & @CRLF & _
                 "Process: " & ($hasGni ? "running" : "stopped") & @CRLF & _
                 "Devices: " & $devCount & @CRLF & _
                 "VPN tun0: " & ($tunUp ? "UP" : "down")

    TraySetToolTip($tip)

    If $hasGni And $devCount > 0 And $tunUp Then
        TraySetIcon($ICON_CONNECTED)
    ElseIf $hasGni Then
        TraySetIcon($ICON_WAITING)
    Else
        TraySetIcon($ICON_DISCONNECTED)
    EndIf
EndFunc

; =========================================================
; Tray UI Setup
; =========================================================
TraySetIcon($ICON_WAITING)
TraySetToolTip($APP_NAME & " • initializing...")

Global $mStartRelay = TrayCreateItem("Start relay")
Global $mStopRelay  = TrayCreateItem("Stop relay")
TrayCreateItem("")
Global $mStartAuto  = TrayCreateItem("Start autorun")
Global $mStopAuto   = TrayCreateItem("Stop autorun")
TrayCreateItem("")
Global $mShowLogs   = TrayCreateItem("Open log folder")
Global $mRestartAll = TrayCreateItem("Restart (relay + autorun)")
TrayCreateItem("")
Global $mExit       = TrayCreateItem("Exit")

TraySetState(1)
AdlibRegister("_RefreshStatus", $g_poll_ms)

; =========================================================
; Initial Start
; =========================================================
_StartRelay()
_StartAutorun()

; =========================================================
; Main Loop
; =========================================================
While 1
    Switch TrayGetMsg()
        Case $mStartRelay
            _StartRelay()

        Case $mStopRelay, $mStopAuto
            _StopGnirehtet()

        Case $mStartAuto
            _StartAutorun()

        Case $mShowLogs
            ShellExecute($g_logdir)

        Case $mRestartAll
            _StopGnirehtet()
            Sleep(500)
            _StartRelay()
            Sleep(500)
            _StartAutorun()

        Case $mExit
            Exit
    EndSwitch

    Sleep(100)
WEnd