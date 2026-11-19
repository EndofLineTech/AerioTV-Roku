import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';

const timeoutMsDefault = 60_000;
const cleanupGraceMs = 1_000;
const cleanupPollMs = 25;
const outputLimit = 16 * 1024;
const scripts = new Map([
  ['classify-ui', 'scripts/read-pairing-ui.swift'],
  ['decode-qr', 'scripts/read-setup-probe-qr.swift'],
  ['generate-fixtures', 'scripts/generate-pairing-ui-fixtures.swift'],
]);
const stateFlags = [
  'welcome', 'setup', 'guide', 'settingsHub', 'picker', 'manager', 'pairing',
  'pairingReady', 'preparing', 'unavailable', 'warning', 'verificationFailed', 'retry',
];

export class PairingImageError extends Error {
  constructor(operation, reason, extra = {}) {
    super(`Pairing image inspection failed: ${operation} (${reason})`);
    this.diagnostic = { diagnostic: 'image-inspection', operation, reason, ...extra };
  }
}

function runWorker(operation, input, cache, { executable = 'swift', timeoutMs = timeoutMsDefault } = {}) {
  const script = scripts.get(operation);
  return new Promise((resolve, reject) => {
    const child = spawn(executable, ['-module-cache-path', cache, script, input], {
      // macOS/Unix: isolate the group for best-effort termination on failure.
      // Never collect or print Swift/Vision stderr.
      detached: true, stdio: ['ignore', 'pipe', 'ignore'],
    });
    let deadline, cleanupDeadline, cleanupPoll, failure, settled = false, chunks = [], bytes = 0;
    function finish(error, output) {
      if (settled) return;
      settled = true;
      clearTimeout(deadline);
      clearTimeout(cleanupDeadline);
      clearInterval(cleanupPoll);
      chunks = [];
      if (error) reject(error);
      else resolve(output);
    }
    function checkGroupGone() {
      if (!child.pid) return;
      try { process.kill(-child.pid, 0); }
      catch (error) {
        // A successful signal or the direct child's close does not prove
        // group absence. Only ESRCH makes that observation at this instant.
        if (error.code === 'ESRCH') finish(failure);
      }
    }
    function stop(error) {
      if (failure || settled) return;
      failure = error;
      clearTimeout(deadline);
      chunks = [];
      try { if (child.pid) process.kill(-child.pid, 'SIGKILL'); } catch {}
      child.stdout.destroy();
      // Bound the wait for both the direct child and observable group
      // absence. This cannot establish cleanup of descendants that left the
      // group, and an unreaped zombie can keep the group observable.
      cleanupDeadline = setTimeout(() => {
        child.unref();
        failure.diagnostic.cleanup = 'unconfirmed';
        finish(failure);
      }, cleanupGraceMs);
    }
    deadline = setTimeout(() => stop(new PairingImageError(operation, 'timeout', { timeoutMs })), timeoutMs);
    child.on('error', () => {
      if (!failure) finish(new PairingImageError(operation, 'launch'));
    });
    child.stdout.on('error', () => stop(new PairingImageError(operation, 'output-read')));
    child.stdout.on('data', chunk => {
      if (failure) return;
      bytes += chunk.length;
      if (bytes > outputLimit) stop(new PairingImageError(operation, 'output-limit'));
      else chunks.push(chunk);
    });
    child.on('close', (exitCode, signal) => {
      if (settled) return;
      if (failure) {
        checkGroupGone();
        if (!settled) cleanupPoll = setInterval(checkGroupGone, cleanupPollMs);
      } else if (signal) finish(new PairingImageError(operation, 'signal', { signal }));
      else if (exitCode !== 0) finish(new PairingImageError(operation, 'exit', { exitCode }));
      else finish(null, Buffer.concat(chunks).toString('utf8').trim());
    });
  });
}

export async function readPairingImage(operation, image, cache, options) {
  if (operation !== 'classify-ui' && operation !== 'decode-qr') throw new TypeError('Unknown pairing image operation');
  const output = await runWorker(operation, image, cache, options);
  try {
    if (operation === 'decode-qr') {
      return new URL(output);
    }
    const raw = JSON.parse(output);
    if (!raw || typeof raw.pairingReady !== 'boolean') throw new Error();
    const state = {};
    for (const key of stateFlags) {
      if (!Object.hasOwn(raw, key)) continue;
      if (typeof raw[key] !== 'boolean') throw new Error();
      state[key] = raw[key];
    }
    if (Object.hasOwn(raw, 'connectionCount')) {
      if (![0, 1, 2, 3, 4].includes(raw.connectionCount)) throw new Error();
      state.connectionCount = raw.connectionCount;
    }
    return state;
  } catch {
    // JSON.parse and URL exceptions can include the rejected contents.
    throw new PairingImageError(operation, 'invalid-output');
  }
}

export async function generatePairingImageFixtures(directory, cache) {
  await runWorker('generate-fixtures', directory, cache);
}

export async function withPairingScreenshot(base, inspect) {
  let directory, inspectionError;
  try {
    // The downloaded screenshot is only accessible within this 0700 directory.
    directory = mkdtempSync(join(base, 'pairing-app-'));
  } catch {
    throw new PairingImageError('screenshot', 'create-temp');
  }
  try {
    return await inspect(join(directory, 'screen.jpg'));
  } catch (error) {
    inspectionError = error;
    throw error;
  } finally {
    try { rmSync(directory, { recursive: true, force: true }); }
    catch {
      if (inspectionError instanceof PairingImageError) inspectionError.diagnostic.screenshotCleanupFailed = true;
      else throw new PairingImageError('screenshot', 'cleanup');
    }
  }
}
