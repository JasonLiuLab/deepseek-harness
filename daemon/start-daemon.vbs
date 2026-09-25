Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

currentDir = fso.GetParentFolderName(WScript.ScriptFullName)
daemonScript = fso.BuildPath(currentDir, "daemon.mjs")

nodePath = "C:\Program Files\nodejs\node.exe"
If Not fso.FileExists(nodePath) Then
    nodePath = "node.exe"
End If

WshShell.Run """" & nodePath & """ """ & daemonScript & """", 0, False
