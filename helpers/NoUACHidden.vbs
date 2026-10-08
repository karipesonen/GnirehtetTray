Option Explicit

Dim shell, fso, helperDir, appDir, runExe, logDir, controlFile, result
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

helperDir = fso.GetParentFolderName(WScript.ScriptFullName)
appDir = fso.GetParentFolderName(helperDir)
runExe = appDir & "\GnirehtetTray.exe"
logDir = appDir & "\logs"
controlFile = logDir & "\tray-command.txt"

' Send the command first. Elevated scheduled-task tray processes can hide
' ExecutablePath from this unelevated helper, so process detection is not
' reliable enough to decide whether a command should be sent.
SendRepairCommand logDir, controlFile

If WaitForCommandConsumed(controlFile, 1200) Then
    WScript.Quit 0
End If

result = shell.Run("schtasks /run /tn ""GnirehtetTrayNoUAC""", 0, True)
If result <> 0 Then
    MsgBox "Could not start the GnirehtetTrayNoUAC scheduled task." & vbCrLf & vbCrLf & _
           "Run scripts\setup-no-uac.ps1 from the GnirehtetTray project folder to recreate the task after moving the folder.", _
           vbExclamation, "GnirehtetTray"
End If

Sub SendRepairCommand(targetLogDir, targetControlFile)
    Dim file
    If Not fso.FolderExists(targetLogDir) Then fso.CreateFolder(targetLogDir)
    Set file = fso.OpenTextFile(targetControlFile, 2, True)
    file.WriteLine "repair"
    file.Close
End Sub

Function WaitForCommandConsumed(targetControlFile, timeoutMs)
    Dim elapsed
    elapsed = 0
    WaitForCommandConsumed = False

    Do While elapsed < timeoutMs
        WScript.Sleep 100
        elapsed = elapsed + 100
        If Not fso.FileExists(targetControlFile) Then
            WaitForCommandConsumed = True
            Exit Function
        End If
    Loop
End Function