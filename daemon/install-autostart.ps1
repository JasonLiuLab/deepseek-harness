# Configure DeepSeek Harness Daemon to run at Windows startup
$daemonDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$vbsScript = Join-Path $daemonDir "start-daemon.vbs"
$startupDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = Join-Path $startupDir "DeepSeek-Harness-Daemon.lnk"

$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "wscript.exe"
$shortcut.Arguments = "`"$vbsScript`""
$shortcut.WorkingDirectory = $daemonDir
$shortcut.Description = "DeepSeek Harness Background Daemon"
$shortcut.Save()

if (Test-Path $shortcutPath) {
    Write-Host "Autostart configured successfully." -ForegroundColor Green
    Write-Host "Shortcut written to: $shortcutPath" -ForegroundColor Cyan
    Write-Host "The daemon will start silently after the next sign-in." -ForegroundColor White
} else {
    Write-Host "Failed to write the autostart shortcut. Check your permissions." -ForegroundColor Red
}
