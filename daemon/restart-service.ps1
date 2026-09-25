# Restart DeepSeek Harness Daemon Service
$daemonDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $daemonDir "stop-service.ps1")
Start-Sleep -Seconds 2
& (Join-Path $daemonDir "start-service.ps1")
