# Remove DeepSeek Harness Daemon from Windows startup
$startupDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = Join-Path $startupDir "DeepSeek-Harness-Daemon.lnk"

if (Test-Path $shortcutPath) {
    Remove-Item -Path $shortcutPath -Force
    Write-Host "Autostart disabled." -ForegroundColor Green
} else {
    Write-Host "No autostart shortcut found; nothing to remove." -ForegroundColor Yellow
}
