import { spawn } from 'node:child_process';
import { existsSync, writeFileSync, readFileSync, unlinkSync, openSync, closeSync, statSync, renameSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(__dirname, '..');
const cliBin = resolve(rootDir, 'apps', 'cli', 'lib', 'bin.js');
const logsDir = resolve(__dirname, 'logs');
const logFilePath = resolve(logsDir, 'dsh-web.log');
const oldLogFilePath = resolve(logsDir, 'dsh-web.old.log');
const pidFilePath = resolve(logsDir, 'daemon.pid');
const childPidFilePath = resolve(logsDir, 'child.pid');
const stopSignalPath = resolve(logsDir, 'stop.signal');

const MAX_LOG_SIZE = 20 * 1024 * 1024; // 20 MB
const RESTART_DELAY_MS = 3000;
const CRASH_WINDOW_MS = 30000;
const MAX_CRASHES_IN_WINDOW = 5;
const BACKOFF_DELAY_MS = 30000;

// Bind host for the dsh web child. Override with DSH_WEB_HOST; set it to
// '127.0.0.1' to serve loopback only again.
const BIND_HOST = process.env.DSH_WEB_HOST ?? '0.0.0.0';

function formatTimestamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

function log(message) {
  const line = `[${formatTimestamp()}] [DAEMON] ${message}\n`;
  try {
    rotateLogIfNeeded();
    writeFileSync(logFilePath, line, { flag: 'a' });
  } catch (err) {
    console.error('Failed to write to log:', err);
  }
}

function rotateLogIfNeeded() {
  try {
    if (existsSync(logFilePath)) {
      const stats = statSync(logFilePath);
      if (stats.size > MAX_LOG_SIZE) {
        if (existsSync(oldLogFilePath)) {
          unlinkSync(oldLogFilePath);
        }
        renameSync(logFilePath, oldLogFilePath);
      }
    }
  } catch {}
}

function isProcessAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

// Single-instance check
if (existsSync(pidFilePath)) {
  try {
    const existingPid = parseInt(statSync(pidFilePath).size > 0 ? String(readFileSync(pidFilePath, 'utf8')).trim() : '0', 10);
    if (existingPid && isProcessAlive(existingPid)) {
      console.log(`DeepSeek Harness Daemon is already running (PID: ${existingPid})`);
      process.exit(0);
    }
  } catch {}
}

if (existsSync(stopSignalPath)) {
  try { unlinkSync(stopSignalPath); } catch {}
}

writeFileSync(pidFilePath, String(process.pid));
log(`Supervisor started (PID: ${process.pid}). Root: ${rootDir}`);

let currentChild = null;
let isStopping = false;
const crashTimestamps = [];

function cleanupAndExit() {
  isStopping = true;
  log('Stopping daemon and child process...');
  if (currentChild && !currentChild.killed) {
    try {
      process.kill(currentChild.pid, 'SIGTERM');
    } catch {}
  }
  try { if (existsSync(pidFilePath)) unlinkSync(pidFilePath); } catch {}
  try { if (existsSync(childPidFilePath)) unlinkSync(childPidFilePath); } catch {}
  try { if (existsSync(stopSignalPath)) unlinkSync(stopSignalPath); } catch {}
  log('Daemon stopped cleanly.');
  process.exit(0);
}

process.on('SIGINT', cleanupAndExit);
process.on('SIGTERM', cleanupAndExit);

// Poll for stop signal file
const stopCheckTimer = setInterval(() => {
  if (existsSync(stopSignalPath)) {
    clearInterval(stopCheckTimer);
    cleanupAndExit();
  }
}, 1000);

function spawnChild() {
  if (isStopping) return;

  log(`Spawning dsh web child process: ${cliBin}`);
  rotateLogIfNeeded();

  const logFd = openSync(logFilePath, 'a');

  const env = { ...process.env, NPM_CONFIG_PM_ON_FAIL: 'ignore' };

  currentChild = spawn(process.execPath, [cliBin, 'web', '--no-open', '--host', BIND_HOST], {
    cwd: rootDir,
    env,
    stdio: ['ignore', logFd, logFd],
    windowsHide: true,
  });

  closeSync(logFd);

  if (!currentChild.pid) {
    log('Failed to spawn child process! Exiting.');
    cleanupAndExit();
    return;
  }

  writeFileSync(childPidFilePath, String(currentChild.pid));
  log(`Child process started (PID: ${currentChild.pid}). Bind host: ${BIND_HOST}`);

  currentChild.on('exit', (code, signal) => {
    try { if (existsSync(childPidFilePath)) unlinkSync(childPidFilePath); } catch {}

    if (isStopping) {
      log(`Child process exited during planned stop (code: ${code}, signal: ${signal}).`);
      return;
    }

    const now = Date.now();
    crashTimestamps.push(now);
    // Keep only crashes within window
    while (crashTimestamps.length > 0 && now - crashTimestamps[0] > CRASH_WINDOW_MS) {
      crashTimestamps.shift();
    }

    log(`Child process exited unexpectedly (code: ${code}, signal: ${signal}).`);

    if (crashTimestamps.length >= MAX_CRASHES_IN_WINDOW) {
      log(`Detected ${crashTimestamps.length} crashes in ${CRASH_WINDOW_MS / 1000}s. Applying backoff of ${BACKOFF_DELAY_MS / 1000}s...`);
      setTimeout(() => {
        if (!isStopping) spawnChild();
      }, BACKOFF_DELAY_MS);
    } else {
      log(`Restarting child process in ${RESTART_DELAY_MS / 1000}s...`);
      setTimeout(() => {
        if (!isStopping) spawnChild();
      }, RESTART_DELAY_MS);
    }
  });
}

spawnChild();
