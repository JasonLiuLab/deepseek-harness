# Status of DeepSeek Harness Daemon Service
$daemonDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logsDir = Join-Path $daemonDir "logs"
$pidFile = Join-Path $logsDir "daemon.pid"
$childPidFile = Join-Path $logsDir "child.pid"
$logFile = Join-Path $logsDir "dsh-web.log"
$startupLnk = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\DeepSeek-Harness-Daemon.lnk"

Write-Host "=========================================" -ForegroundColor DarkGray
Write-Host " DeepSeek Harness Daemon status" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor DarkGray

$daemonProc = $null
$childProc = $null

if (Test-Path $pidFile) {
    $daemonPid = [int](Get-Content $pidFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($daemonPid) {
        $daemonProc = Get-Process -Id $daemonPid -ErrorAction SilentlyContinue
    }
}

if (Test-Path $childPidFile) {
    $childPid = [int](Get-Content $childPidFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($childPid) {
        $childProc = Get-Process -Id $childPid -ErrorAction SilentlyContinue
    }
}

if ($daemonProc) {
    $memMB = [math]::Round($daemonProc.WorkingSet64 / 1MB, 2)
    Write-Host "* Supervisor : running (PID: $($daemonProc.Id), mem: ${memMB}MB)" -ForegroundColor Green
} else {
    Write-Host "* Supervisor : not running" -ForegroundColor Red
}

if ($childProc) {
    $memMB = [math]::Round($childProc.WorkingSet64 / 1MB, 2)
    Write-Host "* dsh web    : running (PID: $($childProc.Id), mem: ${memMB}MB)" -ForegroundColor Green
} else {
    Write-Host "* dsh web    : not running" -ForegroundColor Red
}

# Probe the HTTP port. Any response with a status code, including 401,
# proves the server is listening.
$httpOk = $false
try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:3080" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
    $httpOk = $true
} catch {
    if ($_.Exception.Response.StatusCode -ne $null) {
        $httpOk = $true
    }
}

if ($httpOk) {
    Write-Host "* port 3080 : responding" -ForegroundColor Green
} else {
    Write-Host "* port 3080 : NOT reachable" -ForegroundColor Yellow
}

if (Test-Path $startupLnk) {
    Write-Host "* autostart : enabled (Windows Startup)" -ForegroundColor Green
} else {
    Write-Host "* autostart : disabled" -ForegroundColor DarkGray
}

Write-Host "-----------------------------------------" -ForegroundColor DarkGray
Write-Host "Latest log lines (last 10):" -ForegroundColor White
if (Test-Path $logFile) {
    Get-Content $logFile -Tail 10
} else {
    Write-Host "No log file yet." -ForegroundColor DarkGray
}
Write-Host "=========================================" -ForegroundColor DarkGray
