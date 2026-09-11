' patch-vencord.vbs -- hidden logon launcher for patch-vencord.ps1.
'
' Place this file ALONGSIDE patch-vencord.ps1 in the Windows Startup folder:
'   %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
'
' At every logon it re-applies the Vencord patch (Discord wipes it on each
' self-update). Runs fully hidden, does not wait, logs to
' %LOCALAPPDATA%\Vencord\patch-vencord.log. See README.md.
Option Explicit
Dim objShell, scriptDir, ps1
Set objShell = CreateObject("WScript.Shell")
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
ps1 = scriptDir & "patch-vencord.ps1"
objShell.Run "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & ps1 & """", 0, False
Set objShell = Nothing
