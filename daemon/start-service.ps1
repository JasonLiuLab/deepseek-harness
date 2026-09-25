# Start DeepSeek Harness Daemon Service
$daemonDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $daemonDir "logs\daemon.pid"
$vbsScript = Join-Path $daemonDir "start-daemon.vbs"

if (Test-Path $pidFile) {
    $existingPid = [int](Get-Content $pidFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($existingPid -and (Get-Process -Id $existingPid -ErrorAction SilentlyContinue)) {
        Write-Host "DeepSeek Harness Daemon is already running (PID: $existingPid)." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Starting DeepSeek Harness daemon service..." -ForegroundColor Cyan
try {
    $null = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "wscript.exe `"$vbsScript`""
        CurrentDirectory = $daemonDir
    } -ErrorAction Stop
} catch {
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsScript`""
}

Start-Sleep -Seconds 2

if (Test-Path $pidFile) {
    $newPid = [int](Get-Content $pidFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($newPid -and (Get-Process -Id $newPid -ErrorAction SilentlyContinue)) {
        Write-Host "Daemon started successfully (PID: $newPid)." -ForegroundColor Green
        Write-Host "Web service is starting. Find the URL in logs\dsh-web.log (the 'dsh web:' line)." -ForegroundColor Green
        exit 0
    }
}

Write-Host "Service is still starting. Run .\status-service.ps1 later, or check logs\dsh-web.log." -ForegroundColor Yellow
