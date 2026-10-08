; =========================================================
; Compile-time metadata
; =========================================================
#AutoIt3Wrapper_Icon=assets\app.ico
#AutoIt3Wrapper_Res_Fileversion=1.1.0.0
#AutoIt3Wrapper_Res_ProductVersion=1.1.0.0
#AutoIt3Wrapper_Res_ProductName=GnirehtetTray
#AutoIt3Wrapper_Res_Description=Tray wrapper for gnirehtet

; =========================================================
; Runtime options
; =========================================================
#include <Misc.au3>

Opt("TrayMenuMode", 3)
Opt("TrayAutoPause", 0)

; =========================================================
; Globals / Configuration
; =========================================================
Global Const $APP_NAME = "Gnirehtet Tray"
Global Const $GNI_PACKAGE = "com.genymobile.gnirehtet"

Global Const $g_dir        = @ScriptDir
Global Const $g_gni        = $g_dir & "\gnirehtet.exe"
Global Const $g_adb        = $g_dir & "\adb.exe"
Global Const $g_logdir     = $g_dir & "\logs"
Global Const $g_relayLog   = $g_logdir & "\relay-latest.log"
Global Const $g_actionLog  = $g_logdir & "\tray-actions.log"
Global Const $CONTROL_FILE = $g_logdir & "\tray-command.txt"

Global Const $ICON_CONNECTED    = $g_dir & "\assets\tray_connected.ico"
Global Const $ICON_WAITING      = $g_dir & "\assets\tray_waiting.ico"
Global Const $ICON_DISCONNECTED = $g_dir & "\assets\tray_disconnected.ico"

Global $g_serial             = ""
Global $g_poll_ms            = 10000
Global $g_lastAction         = "Starting"
Global $g_state              = "Starting"
Global $g_stateDetail        = "Initializing"
Global $g_desiredRunning     = True
Global $g_operation         = ""
Global $g_operationDetail   = ""
Global $g_operationTimer    = 0
Global Const $g_adbGraceMs = 8000
Global $g_lastDeviceOk = False
Global $g_adbGraceReason = ""
Global $g_adbGraceTimer = 0
Global $g_lastStatusKey = ""
Global $g_lastAdbReason = ""
Global $g_lastAdbElapsed = 0
Global $g_postRefreshPending = False
Global $g_postRefreshTimer = 0
Global $g_transientCheckTimer = 0
Global $g_usbRepairHoldTimer = 0
Global Const $g_usbRepairHoldMs = 3000
Global Const $g_relayCheckMs = 500
Global Const $g_relayRepairFirstMs = 750
Global Const $g_relayRepairSecondMs = 2500
Global Const $g_relayRepairFinalMs = 5000
Global Const $g_relayRepairCooldownMs = 8000
Global Const $g_relayRepairHoldMs = 3000
Global $g_relayLogOffset = -1
Global $g_relayCheckTimer = 0
Global $g_relayDisconnectPending = False
Global $g_relayDisconnectTimer = 0
Global $g_relayRecoveryAttempt = 0
Global $g_relayRepairCooldownTimer = 0
Global $g_relayRepairHoldTimer = 0
Global $g_relayClientConnected = False
Global $g_relayClientStateKnown = False
Global $g_relayLastClientEvent = ""
Global $g_cleanupDone = False
Global $g_singletonName = "GnirehtetTray-" & StringRegExpReplace(StringLower($g_dir), "[^a-z0-9]", "_")
Global $g_singleton = 0

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

Func _RunCapture($command, ByRef $out, $timeoutMs = 5000)
    Local $pid = Run($command, @ScriptDir, @SW_HIDE, 6)
    If $pid = 0 Then
        $out = ""
        Return -1
    EndIf

    Local $t = TimerInit()
    $out = ""

    While ProcessExists($pid)
        $out &= StdoutRead($pid)
        If TimerDiff($t) > $timeoutMs Then
            ProcessClose($pid)
            $out &= StdoutRead($pid)
            Return -1
        EndIf
        Sleep(25)
    WEnd

    $out &= StdoutRead($pid)
    Return 0
EndFunc


Func _Clip($text, $max)
    If StringLen($text) <= $max Then Return $text
    Return StringLeft($text, $max - 3) & "..."
EndFunc

Func _DrawTrayStatus()
    Local $tip = $APP_NAME & @CRLF & _
                 "Action: " & _Clip($g_lastAction, 32) & @CRLF & _
                 $g_state & ": " & _Clip($g_stateDetail, 48)

    TraySetToolTip($tip)

    Switch $g_state
        Case "Gnirehtet ready"
            TraySetIcon($ICON_CONNECTED)
        Case "Stopped"
            TraySetIcon($ICON_DISCONNECTED)
        Case Else
            TraySetIcon($ICON_WAITING)
    EndSwitch
EndFunc

Func _BeginOperation($state, $detail)
    $g_operation = $state
    $g_operationDetail = $detail
    $g_operationTimer = TimerInit()
    $g_state = $state
    $g_stateDetail = $detail
    $g_lastAction = $detail
    _DrawTrayStatus()
EndFunc

Func _EndOperation()
    $g_operation = ""
    $g_operationDetail = ""
    $g_operationTimer = 0
EndFunc

Func _ActionStamp()
    Return @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & "." & StringRight("00" & @MSEC, 3)
EndFunc

Func _LogAction($message)
    If Not FileExists($g_logdir) Then DirCreate($g_logdir)
    Local $fh = FileOpen($g_actionLog, 1)
    If $fh = -1 Then Return
    FileWrite($fh, _ActionStamp() & " " & $message & @CRLF)
    FileClose($fh)
EndFunc

Func _TimedGniWait($label, $args, $timeoutMs)
    Local $t = TimerInit()
    _LogAction($label & " begin: gnirehtet " & $args & " timeout=" & $timeoutMs & "ms")
    Local $exitCode = _RunGniWait($args, $timeoutMs)
    _LogAction($label & " end: exit=" & $exitCode & " elapsed=" & Int(TimerDiff($t)) & "ms")
    Return $exitCode
EndFunc

Func _TimedAdbWait($label, $args, $timeoutMs)
    Local $t = TimerInit()
    _LogAction($label & " begin: adb " & $args & " timeout=" & $timeoutMs & "ms")
    Local $exitCode = _RunAdbWait($args, $timeoutMs)
    _LogAction($label & " end: exit=" & $exitCode & " elapsed=" & Int(TimerDiff($t)) & "ms")
    Return $exitCode
EndFunc

Func _TimedGniLaunch($label, $args)
    Local $t = TimerInit()
    _LogAction($label & " begin: gnirehtet " & $args & " async")
    Local $pid = Run('"' & $g_gni & '" ' & $args, @ScriptDir, @SW_HIDE)
    _LogAction($label & " end: pid=" & $pid & " elapsed=" & Int(TimerDiff($t)) & "ms")
    Return $pid
EndFunc

Func _SchedulePostCommandRefresh()
    $g_postRefreshPending = True
    $g_postRefreshTimer = TimerInit()
EndFunc


Func _MaybeTransientRefresh()
    If $g_adbGraceReason = "" Then Return
    If TimerDiff($g_transientCheckTimer) < 1500 Then Return

    $g_transientCheckTimer = TimerInit()
    _RefreshStatus()
EndFunc
Func _PostCommandRefresh()
    If Not $g_postRefreshPending Then Return
    If TimerDiff($g_postRefreshTimer) < 1500 Then Return

    $g_postRefreshPending = False
    _LogAction("status: post-command lightweight refresh")
    _RefreshStatus()
EndFunc

Func _LogStatusIfChanged($state, $detail, $devCount)
    Local $key = $state & "|" & $detail & "|" & $devCount & "|" & $g_lastAdbReason
    If $key = $g_lastStatusKey Then Return

    $g_lastStatusKey = $key
    _LogAction("status: state=" & $state & " detail=" & $detail & " devices=" & $devCount & " adb=" & $g_lastAdbReason & " adb_elapsed=" & $g_lastAdbElapsed & "ms")
EndFunc
Func _RunGniWait($args, $timeoutMs = 10000)
    Local $out = ""
    Return _RunCapture('"' & $g_gni & '" ' & $args, $out, $timeoutMs)
EndFunc

Func _RunAdbCapture($args, ByRef $out, $timeoutMs = 5000)
    Return _RunCapture('"' & $g_adb & '" ' & $args, $out, $timeoutMs)
EndFunc

Func _RunAdbWait($args, $timeoutMs = 5000)
    Local $out = ""
    Return _RunAdbCapture($args, $out, $timeoutMs)
EndFunc

Func _OneLine($text)
    $text = StringReplace($text, @CRLF, " | ")
    $text = StringReplace($text, @LF, " | ")
    Return StringStripWS($text, 3)
EndFunc

Func _DiagnoseAdb($label, $args, $timeoutMs)
    Local $out = ""
    Local $t = TimerInit()
    Local $exitCode = _RunAdbCapture($args, $out, $timeoutMs)
    _LogAction("diagnose: " & $label & " exit=" & $exitCode & " elapsed=" & Int(TimerDiff($t)) & "ms output=" & _OneLine($out))
EndFunc

Func _RunDiagnostic()
    _LogAction("diagnose: begin")
    _DiagnoseAdb("devices", "devices", 3000)
    _DiagnoseAdb("shell echo", "shell echo ok", 3000)
    _DiagnoseAdb("reverse list", "reverse --list", 3000)
    _DiagnoseAdb("tun0", "shell ip addr show tun0", 3000)
    _LogAction("diagnose: end")
EndFunc

; =========================================================
; ADB Status
; =========================================================
Func _ADB_DeviceSummary(ByRef $deviceCount, ByRef $unauthorizedCount, ByRef $offlineCount, ByRef $otherCount)
    Local $out = ""
    Local $t = TimerInit()
    Local $exitCode = _RunAdbCapture("devices", $out, 3000)
    $g_lastAdbElapsed = Int(TimerDiff($t))

    $deviceCount = 0
    $unauthorizedCount = 0
    $offlineCount = 0
    $otherCount = 0
    $g_lastAdbReason = "ok"

    If $exitCode <> 0 Then
        $g_lastAdbReason = "adb failed"
        Return False
    EndIf

    Local $lines = StringSplit($out, @CRLF, 1)

    For $i = 1 To $lines[0]
        Local $L = StringStripWS($lines[$i], 3)
        Local $match = StringRegExp($L, "^(\S+)\s+(\S+)", 1)
        If @error Then ContinueLoop

        Switch $match[1]
            Case "device"
                $deviceCount += 1
            Case "unauthorized"
                $unauthorizedCount += 1
            Case "offline"
                $offlineCount += 1
            Case Else
                $otherCount += 1
        EndSwitch
    Next

    If $deviceCount > 0 Then
        $g_lastAdbReason = "ok"
    ElseIf $unauthorizedCount > 0 Then
        $g_lastAdbReason = "unauthorized"
    ElseIf $offlineCount > 0 Then
        $g_lastAdbReason = "offline"
    ElseIf $otherCount > 0 Then
        $g_lastAdbReason = "other"
    Else
        $g_lastAdbReason = "no device"
    EndIf

    Return True
EndFunc

Func _ADB_WaitingDetail($adbListed, $unauthorizedCount, $offlineCount, $otherCount)
    If Not $adbListed Then Return "ADB device list failed"
    If $unauthorizedCount > 0 Then Return "Phone connected, but USB debugging is not authorized"
    If $offlineCount > 0 Then Return "Phone connected, but ADB is offline"
    If $otherCount > 0 Then Return "Phone connected, but ADB is not ready"
    Return "No authorized Android device"
EndFunc

Func _ADB_TransientDetail($reason)
    Switch $reason
        Case "adb failed"
            Return "ADB is settling after a recent phone connection"
        Case "unauthorized"
            Return "Phone authorization is settling"
        Case "offline"
            Return "Phone ADB connection is settling"
        Case "other"
            Return "Phone ADB state is settling"
        Case Else
            Return "Waiting for phone to settle"
    EndSwitch
EndFunc

Func _ADB_DeviceCount()
    Local $devCount, $unauthorizedCount, $offlineCount, $otherCount
    If Not _ADB_DeviceSummary($devCount, $unauthorizedCount, $offlineCount, $otherCount) Then Return 0
    Return $devCount
EndFunc


; =========================================================
; Gnirehtet Control
; =========================================================
Func _WaitForGnirehtetProcess($timeoutMs)
    Local $t = TimerInit()
    While TimerDiff($t) < $timeoutMs
        If ProcessExists("gnirehtet.exe") Then Return True
        Sleep(100)
    WEnd
    Return ProcessExists("gnirehtet.exe") <> 0
EndFunc

Func _LaunchRelay()
    Local $cmd = 'start "" /B "' & $g_gni & '" relay >> "' & $g_relayLog & '" 2>&1'
    _LogAction("start begin: launch relay")
    _RunCmdHidden($cmd)
    Local $ok = _WaitForGnirehtetProcess(1000)
    _LogAction("start end: launch relay=" & $ok)
    Return $ok
EndFunc
Func _StartConnection()
    Local $actionTimer = TimerInit()
    _LogAction("start action begin")
    $g_desiredRunning = True
    _ClearRelayClientState()

    If Not ProcessExists("gnirehtet.exe") Then _LaunchRelay()

    Local $startArgs = "start"
    If $g_serial <> "" Then $startArgs &= " -s " & $g_serial

    Local $pid = _TimedGniLaunch("start", $startArgs)
    If $pid = 0 Then
        $g_lastAction = "Start failed; see logs"
        _LogAction("start action end: launch failed elapsed=" & Int(TimerDiff($actionTimer)) & "ms")
        _SchedulePostCommandRefresh()
        Return False
    EndIf

    Sleep(250)
    If Not ProcessExists("gnirehtet.exe") Then
        _LaunchRelay()
    EndIf

    If ProcessExists("gnirehtet.exe") Then
        $g_lastAction = "Start sent"
        $g_state = "Waiting"
        $g_stateDetail = "Waiting for relay client"
        _LogAction("start action end: start sent gnirehtet=True elapsed=" & Int(TimerDiff($actionTimer)) & "ms")
        _SchedulePostCommandRefresh()
        Return True
    EndIf

    $g_lastAction = "Start sent; gnirehtet stopped"
    $g_state = "Waiting"
    $g_stateDetail = "gnirehtet is not running"
    _LogAction("start action end: start sent gnirehtet=False elapsed=" & Int(TimerDiff($actionTimer)) & "ms")
    _SchedulePostCommandRefresh()
    Return False
EndFunc

Func _ForceStopPhoneClient()
    $g_lastAction = "Force-stopping app"
    Return _TimedAdbWait("force-stop", "shell am force-stop " & $GNI_PACKAGE, 3000) = 0
EndFunc

Func _StopPhoneVpn()
    Local $args = "stop"
    If $g_serial <> "" Then $args &= " -s " & $g_serial

    $g_lastAction = "Stopping"
    Local $exitCode = _TimedGniWait("stop", $args, 4000)
    If $exitCode = 0 Then
        $g_lastAction = "Stop sent"
        Return True
    EndIf

    If _ADB_DeviceCount() > 0 Then
        If _ForceStopPhoneClient() Then
            $g_lastAction = "Force-stop sent"
            Return True
        EndIf
    EndIf

    $g_lastAction = "Stopped; VPN may remain"
    Return False
EndFunc

Func _CloseGnirehtetProcesses()
    Local $t = TimerInit()

    While ProcessExists("gnirehtet.exe")
        ProcessClose("gnirehtet.exe")
        Sleep(75)
        If TimerDiff($t) > 1500 Then Return False
    WEnd
    Return True
EndFunc

Func _StopConnection()
    Local $actionTimer = TimerInit()
    _LogAction("stop action begin")
    _BeginOperation("Stopping", "Stopping")
    $g_desiredRunning = False

    Local $stoppedVpn = _StopPhoneVpn()
    Local $closedRelay = _CloseGnirehtetProcesses()

    If $stoppedVpn And $closedRelay Then
        $g_lastAction = "Connection stop requested"
    ElseIf $closedRelay Then
        $g_lastAction = "Stopped; VPN may remain"
    Else
        $g_lastAction = "Stop sent; close failed"
    EndIf

    _SetRelayClientState(False)
    _EndOperation()
    $g_state = "Stopped"
    $g_stateDetail = "Stopped by user"
    _DrawTrayStatus()
    _LogAction("stop action end: vpn=" & $stoppedVpn & " relay=" & $closedRelay & " elapsed=" & Int(TimerDiff($actionTimer)) & "ms")
    _SchedulePostCommandRefresh()
    Return $stoppedVpn And $closedRelay
EndFunc

Func _RestartConnection()
    Local $actionTimer = TimerInit()
    _LogAction("restart action begin")
    $g_desiredRunning = True
    _StopConnection()
    $g_desiredRunning = True
    Sleep(250)
    Local $result = _StartConnection()
    _LogAction("restart action end: result=" & $result & " elapsed=" & Int(TimerDiff($actionTimer)) & "ms")
    Return $result
EndFunc

Func _RepairConnection()
    Local $actionTimer = TimerInit()
    _LogAction("repair action begin")
    If Not ProcessExists("gnirehtet.exe") Then
        Local $startResult = _StartConnection()
        _LogAction("repair action end: delegated-start result=" & $startResult & " elapsed=" & Int(TimerDiff($actionTimer)) & "ms")
        Return $startResult
    EndIf

    Local $args = "restart"
    If $g_serial <> "" Then $args &= " -s " & $g_serial

    Local $pid = _TimedGniLaunch("repair", $args)
    If $pid = 0 Then
        $g_lastAction = "Repair failed; see logs"
        _LogAction("repair action end: launch failed elapsed=" & Int(TimerDiff($actionTimer)) & "ms")
        _SchedulePostCommandRefresh()
        Return False
    EndIf

    $g_lastAction = "Repair sent"
    _LogAction("repair action end: restart sent elapsed=" & Int(TimerDiff($actionTimer)) & "ms")
    _SchedulePostCommandRefresh()
    Return True
EndFunc
Func _RepairAfterAdbReturn($reason)
    If Not ProcessExists("gnirehtet.exe") Then Return False

    Local $args = "restart"
    If $g_serial <> "" Then $args &= " -s " & $g_serial

    _LogAction("usb recovery repair begin reason=" & $reason)
    Local $pid = _TimedGniLaunch("usb recovery repair", $args)
    If $pid = 0 Then
        $g_lastAction = "USB repair failed"
        _LogAction("usb recovery repair end: launch failed")
        Return False
    EndIf

    $g_lastAction = "USB repair"
    $g_usbRepairHoldTimer = TimerInit()
    _LogAction("usb recovery repair end: restart sent")
    _SchedulePostCommandRefresh()
    Return True
EndFunc
Func _ConnectOrRepair()
    $g_desiredRunning = True

    Local $result = False
    If ProcessExists("gnirehtet.exe") Then
        _BeginOperation("Repairing", "Restarting phone client")
        $result = _RepairConnection()
    Else
        _BeginOperation("Starting", "Starting connection")
        $result = _StartConnection()
    EndIf

    _EndOperation()
    _DrawTrayStatus()
    Return $result
EndFunc

Func _RelayRecoveryRecentlySent()
    Return $g_relayRepairCooldownTimer <> 0 And TimerDiff($g_relayRepairCooldownTimer) < $g_relayRepairCooldownMs
EndFunc

Func _Cleanup()
    If $g_cleanupDone Then Return
    $g_cleanupDone = True
    _StopConnection()
EndFunc


Func _ClearRelayClientState()
    $g_relayClientConnected = False
    $g_relayClientStateKnown = False
    $g_relayLastClientEvent = ""
EndFunc

Func _SetRelayClientState($connected)
    $g_relayClientConnected = $connected
    $g_relayClientStateKnown = True
    If $connected Then
        $g_relayLastClientEvent = "connected"
    Else
        $g_relayLastClientEvent = "disconnected"
    EndIf
EndFunc

Func _AdoptRelayClientStateFromText($text)
    If $text = "" Then Return

    Local $lines = StringSplit(StringReplace($text, @CRLF, @LF), @LF, 1)
    For $i = 1 To $lines[0]
        Local $line = $lines[$i]
        If StringInStr($line, "TunnelServer: Client #") = 0 Then ContinueLoop

        If StringInStr($line, "disconnected") > 0 Then
            _SetRelayClientState(False)
        ElseIf StringInStr($line, "connected") > 0 Then
            _SetRelayClientState(True)
        EndIf
    Next
EndFunc

Func _AdoptRelayClientStateFromLog()
    If Not FileExists($g_relayLog) Then Return

    Local $text = FileRead($g_relayLog)
    _AdoptRelayClientStateFromText($text)
    If $g_relayClientStateKnown Then _LogAction("relay state adopted: " & $g_relayLastClientEvent)
EndFunc

Func _RelayRecoveryRepair($reason, $ignoreCooldown = False)
    If Not $g_desiredRunning Then Return False
    If Not ProcessExists("gnirehtet.exe") Then Return False

    If Not $ignoreCooldown And $g_relayRepairCooldownTimer <> 0 And TimerDiff($g_relayRepairCooldownTimer) < $g_relayRepairCooldownMs Then
        _LogAction("relay recovery repair skipped cooldown reason=" & $reason)
        Return False
    EndIf

    Local $args = "restart"
    If $g_serial <> "" Then $args &= " -s " & $g_serial

    _LogAction("relay recovery repair begin reason=" & $reason)
    Local $pid = _TimedGniLaunch("relay recovery repair", $args)
    If $pid = 0 Then
        $g_lastAction = "Relay repair failed"
        _LogAction("relay recovery repair launch failed")
        Return False
    EndIf

    $g_lastAction = "Relay repair"
    $g_relayRepairCooldownTimer = TimerInit()
    $g_relayRepairHoldTimer = TimerInit()
    _LogAction("relay recovery repair sent")
    _SchedulePostCommandRefresh()
    Return True
EndFunc

Func _RelayLogSize()
    If Not FileExists($g_relayLog) Then Return -1
    Return FileGetSize($g_relayLog)
EndFunc

Func _InitRelayLogMonitor()
    _AdoptRelayClientStateFromLog()
    Local $size = _RelayLogSize()
    If $size < 0 Then
        $g_relayLogOffset = -1
    Else
        $g_relayLogOffset = $size
    EndIf
    $g_relayCheckTimer = TimerInit()
EndFunc

Func _ReadRelayLogAppend()
    Local $size = _RelayLogSize()
    If $size < 0 Then
        $g_relayLogOffset = -1
        Return ""
    EndIf

    If $g_relayLogOffset < 0 Or $size < $g_relayLogOffset Then
        $g_relayLogOffset = $size
        Return ""
    EndIf

    If $size = $g_relayLogOffset Then Return ""

    Local $fh = FileOpen($g_relayLog, 16)
    If $fh = -1 Then Return ""

    FileSetPos($fh, $g_relayLogOffset, 0)
    Local $bytes = FileRead($fh, $size - $g_relayLogOffset)
    FileClose($fh)

    $g_relayLogOffset = $size
    Return BinaryToString($bytes)
EndFunc

Func _HandleRelayLogText($text)
    If $text = "" Then Return

    Local $lines = StringSplit(StringReplace($text, @CRLF, @LF), @LF, 1)
    For $i = 1 To $lines[0]
        Local $line = $lines[$i]
        If StringInStr($line, "TunnelServer: Client #") = 0 Then ContinueLoop

        If StringInStr($line, "disconnected") > 0 Then
            _SetRelayClientState(False)
            _LogAction("relay event: client disconnected")
            If $g_desiredRunning And ProcessExists("gnirehtet.exe") Then
                $g_relayDisconnectPending = True
                $g_relayDisconnectTimer = TimerInit()
                $g_relayRecoveryAttempt = 0
                $g_lastAction = "Relay disconnected"
                $g_state = "Waiting"
                $g_stateDetail = "Relay disconnected; waiting"
                _DrawTrayStatus()
            EndIf
        ElseIf StringInStr($line, "connected") > 0 Then
            _SetRelayClientState(True)
            _LogAction("relay event: client connected")
            $g_relayDisconnectPending = False
            $g_relayRecoveryAttempt = 0
            $g_relayRepairHoldTimer = 0
            $g_usbRepairHoldTimer = 0
            $g_adbGraceReason = ""
            If $g_desiredRunning And ProcessExists("gnirehtet.exe") Then
                $g_lastAction = "Relay connected"
                _RefreshStatus()
            EndIf
            If $g_desiredRunning Then _SchedulePostCommandRefresh()
        EndIf
    Next
EndFunc

Func _RelayRecoveryDelayForAttempt($attempt)
    Switch $attempt
        Case 0
            Return $g_relayRepairFirstMs
        Case 1
            Return $g_relayRepairSecondMs
        Case 2
            Return $g_relayRepairFinalMs
    EndSwitch

    Return -1
EndFunc

Func _CheckRelayLog()
    If TimerDiff($g_relayCheckTimer) < $g_relayCheckMs Then Return
    $g_relayCheckTimer = TimerInit()

    _HandleRelayLogText(_ReadRelayLogAppend())

    If $g_relayDisconnectPending Then
        Local $delayMs = _RelayRecoveryDelayForAttempt($g_relayRecoveryAttempt)
        If $delayMs < 0 Then
            $g_relayDisconnectPending = False
            Return
        EndIf

        If TimerDiff($g_relayDisconnectTimer) >= $delayMs Then
            If $g_relayClientConnected Then
                $g_relayDisconnectPending = False
                $g_relayRecoveryAttempt = 0
                _LogAction("relay recovery repair skipped reconnected")
                Return
            EndIf

            If Not $g_desiredRunning Or Not ProcessExists("gnirehtet.exe") Then
                $g_relayDisconnectPending = False
                _LogAction("relay recovery repair skipped not running")
                Return
            EndIf

            $g_relayRecoveryAttempt += 1
            If $g_relayRecoveryAttempt >= 3 Then $g_relayDisconnectPending = False

            If _RelayRecoveryRepair("disconnect-at-" & $delayMs & "ms", True) Then
                $g_state = "Waiting"
                $g_stateDetail = "Relay repair sent"
                _DrawTrayStatus()
            EndIf
        EndIf
    EndIf
EndFunc
; =========================================================
; Lightweight Status
; =========================================================
Func _ReadStatus(ByRef $hasGni, ByRef $devCount, ByRef $state, ByRef $detail)
    $hasGni = _IsProc("gnirehtet.exe")
    $devCount = 0

    If Not $g_desiredRunning Then
        $g_lastDeviceOk = False
        $g_adbGraceReason = ""
        $state = "Stopped"
        $detail = "Stopped by user"
        Return
    EndIf

    If Not $hasGni Then
        $g_lastDeviceOk = False
        $g_adbGraceReason = ""
        $state = "Stopped"
        $detail = "gnirehtet process is not running"
        Return
    EndIf

    Local $unauthorizedCount, $offlineCount, $otherCount
    Local $adbListed = _ADB_DeviceSummary($devCount, $unauthorizedCount, $offlineCount, $otherCount)

    If $devCount = 0 Then
        Local $reason = $g_lastAdbReason
        If $g_lastDeviceOk Then
            If $g_adbGraceReason <> $reason Then
                $g_adbGraceReason = $reason
                $g_adbGraceTimer = TimerInit()
                $g_transientCheckTimer = TimerInit()
                _LogAction("status: transient adb reason=" & $reason)
            EndIf

            If TimerDiff($g_adbGraceTimer) < $g_adbGraceMs Then
                $state = "Waiting"
                $detail = _ADB_TransientDetail($reason)
                Return
            EndIf
        EndIf

        $g_lastDeviceOk = False
        $state = "Waiting"
        $detail = _ADB_WaitingDetail($adbListed, $unauthorizedCount, $offlineCount, $otherCount)
        Return
    EndIf

    Local $recoveredReason = $g_adbGraceReason
    $g_lastDeviceOk = True
    $g_adbGraceReason = ""

    If $recoveredReason <> "" Then
        If _RelayRecoveryRecentlySent() Then
            $state = "Waiting"
            $detail = "Relay repair settling"
            Return
        EndIf

        If _RepairAfterAdbReturn($recoveredReason) Then
            $state = "Waiting"
            $detail = "USB repair sent"
            Return
        EndIf
    EndIf

    If $g_usbRepairHoldTimer <> 0 Then
        If TimerDiff($g_usbRepairHoldTimer) < $g_usbRepairHoldMs Then
            $state = "Waiting"
            $detail = "USB settling"
            Return
        EndIf
        $g_usbRepairHoldTimer = 0
    EndIf

    If $g_relayRepairHoldTimer <> 0 Then
        If TimerDiff($g_relayRepairHoldTimer) < $g_relayRepairHoldMs Then
            $state = "Waiting"
            $detail = "Relay repair settling"
            Return
        EndIf
        $g_relayRepairHoldTimer = 0
    EndIf

    If Not $g_relayClientStateKnown Then
        $state = "Waiting"
        $detail = "Waiting for relay client"
        Return
    EndIf

    If Not $g_relayClientConnected Then
        $state = "Waiting"
        $detail = "Relay client not connected"
        Return
    EndIf

    $state = "Gnirehtet ready"
    $detail = "Phone authorized; VPN not verified"
EndFunc

; =========================================================
; Tray Status
; =========================================================
Func _RefreshStatus()
    If $g_operation <> "" Then
        If TimerDiff($g_operationTimer) < 15000 Then
            $g_state = $g_operation
            $g_stateDetail = $g_operationDetail
            _DrawTrayStatus()
            Return
        EndIf

        _EndOperation()
    EndIf

    Local $hasGni, $devCount, $state, $detail
    _ReadStatus($hasGni, $devCount, $state, $detail)
    $g_state = $state
    $g_stateDetail = $detail
    _LogStatusIfChanged($state, $detail, $devCount)
    _DrawTrayStatus()
EndFunc
Func _CommandFromArgs()
    If $CmdLine[0] = 0 Then Return ""

    For $i = 1 To $CmdLine[0]
        Local $arg = StringLower(StringStripWS($CmdLine[$i], 3))

        Switch $arg
            Case "--restart", "/restart", "restart"
                Return "restart"
            Case "--repair", "/repair", "repair"
                Return "repair"
            Case "--start", "/start", "start"
                Return "start"
            Case "--stop", "/stop", "stop"
                Return "stop"
            Case "--diagnose", "/diagnose", "diagnose"
                Return "diagnose"
        EndSwitch
    Next

    Return ""
EndFunc

Func _WriteControlCommand($command)
    If $command = "" Then $command = "repair"
    If Not FileExists($g_logdir) Then DirCreate($g_logdir)

    Local $fh = FileOpen($CONTROL_FILE, 2)
    If $fh = -1 Then Return False

    FileWrite($fh, $command & @CRLF)
    FileClose($fh)
    Return True
EndFunc

Func _HandleControlCommand($command)
    $command = StringLower(StringStripWS($command, 3))
    If $command = "" Then Return

    If $g_operation <> "" Then
        If TimerDiff($g_operationTimer) < 15000 Then
            $g_lastAction = "Busy: ignored " & $command
            _LogAction("command ignored while " & $g_operation & ": " & $command)
            _DrawTrayStatus()
            Return
        EndIf

        _EndOperation()
    EndIf

    Switch $command
        Case "restart"
            _RestartConnection()
        Case "repair", "start"
            _ConnectOrRepair()
        Case "stop"
            _StopConnection()
        Case "diagnose"
            _RunDiagnostic()
        Case Else
            $g_lastAction = "Ignored unknown command: " & $command
    EndSwitch

    _DrawTrayStatus()
EndFunc

Func _CheckControlCommand()
    If Not FileExists($CONTROL_FILE) Then Return

    Local $command = FileRead($CONTROL_FILE)
    FileDelete($CONTROL_FILE)
    _HandleControlCommand($command)
EndFunc

Global $g_launchCommand = _CommandFromArgs()
FileDelete($CONTROL_FILE)
$g_singleton = _Singleton($g_singletonName, 1)
If $g_singleton = 0 Then
    If $g_launchCommand = "" Then $g_launchCommand = "repair"
    _WriteControlCommand($g_launchCommand)
    Exit
EndIf

If $g_launchCommand = "diagnose" Then
    _RunDiagnostic()
    Exit
EndIf

OnAutoItExitRegister("_Cleanup")

TraySetIcon($ICON_WAITING)
TraySetToolTip($APP_NAME & " - initializing...")

Global $mConnectRepair = TrayCreateItem("Connect / repair")
Global $mStopConnection = TrayCreateItem("Disconnect phone VPN")
TrayCreateItem("")
Global $mShowLogs = TrayCreateItem("Open log folder")
TrayCreateItem("")
Global $mExit = TrayCreateItem("Exit tray")

TraySetState(1)
AdlibRegister("_RefreshStatus", $g_poll_ms)
AdlibRegister("_CheckControlCommand", 250)

_InitRelayLogMonitor()
_BeginOperation("Starting", "Starting connection")
_StartConnection()
_EndOperation()
_DrawTrayStatus()
While 1
    Switch TrayGetMsg()
        Case $mConnectRepair
            _ConnectOrRepair()

        Case $mStopConnection
            _StopConnection()

        Case $mShowLogs
            ShellExecute($g_logdir)

        Case $mExit
            _Cleanup()
            Exit
    EndSwitch

    _CheckRelayLog()
    _MaybeTransientRefresh()
    _PostCommandRefresh()
    Sleep(100)
WEnd

