# Stop DeepSeek Harness Daemon Service
$daemonDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logsDir = Join-Path $daemonDir "logs"
$pidFile = Join-Path $logsDir "daemon.pid"
$childPidFile = Join-Path $logsDir "child.pid"
$stopSignal = Join-Path $logsDir "stop.signal"

$stopped = $false

if (Test-Path $pidFile) {
    $daemonPid = [int](Get-Content $pidFile -Raw -ErrorAction SilentlyContinue).Trim()

    # Ask the supervisor to shut its child down cleanly.
    Set-Content -Path $stopSignal -Value "stop" -Force
    Write-Host "Stop signal sent to the supervisor (PID: $daemonPid)..." -ForegroundColor Cyan

    for ($i = 0; $i -lt 5; $i++) {
        Start-Sleep -Seconds 1
        if (-not (Get-Process -Id $daemonPid -ErrorAction SilentlyContinue)) {
            $stopped = $true
            break
        }
    }

    # The supervisor ignored the signal; force it.
    if (Get-Process -Id $daemonPid -ErrorAction SilentlyContinue) {
        Write-Host "Force-stopping the supervisor (PID: $daemonPid)..." -ForegroundColor Yellow
        Stop-Process -Id $daemonPid -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path $childPidFile) {
    $childPid = [int](Get-Content $childPidFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($childPid -and (Get-Process -Id $childPid -ErrorAction SilentlyContinue)) {
        Write-Host "Stopping the web worker (PID: $childPid)..." -ForegroundColor Yellow
        Stop-Process -Id $childPid -Force -ErrorAction SilentlyContinue
    }
}

# Clean up transient state.
Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path $childPidFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path $stopSignal -Force -ErrorAction SilentlyContinue

# A force-killed dsh leaves an orphan lock behind; every later start would
# then fail with "timed out waiting for the writer lock".
$lockFile = Join-Path $env:USERPROFILE ".dsh\.credentials.yaml.lock"
if (Test-Path $lockFile) {
    Write-Host "Removing the orphan credential lock left by the stopped process..." -ForegroundColor Yellow
    Remove-Item -Path $lockFile -Force -ErrorAction SilentlyContinue
}

Write-Host "DeepSeek Harness daemon and web process stopped." -ForegroundColor Green
