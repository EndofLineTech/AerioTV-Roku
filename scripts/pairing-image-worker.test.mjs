import assert from 'node:assert/strict';
import { execFile, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { test } from 'node:test';
import { readPairingImage, withPairingScreenshot } from './pairing-image-worker.mjs';

const privateMarker = 'synthetic text that must never reach diagnostics';

function fixture(t, body) {
  const directory = mkdtempSync(join(tmpdir(), 'pairing-worker-test-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const executable = join(directory, 'worker');
  writeFileSync(executable, `#!/bin/sh\n${body}\n`, { mode: 0o700 });
  return { directory, executable };
}

function safeError(operation, reason, extra = {}) {
  return error => {
    assert.equal(error.message, `Pairing image inspection failed: ${operation} (${reason})`);
    assert.deepEqual(error.diagnostic, { diagnostic: 'image-inspection', operation, reason, ...extra });
    assert.equal(JSON.stringify(error).includes(privateMarker), false);
    return true;
  };
}

function isRunning(pid) {
  const result = spawnSync('/bin/ps', ['-o', 'stat=', '-p', String(pid)], {
    encoding: 'utf8', timeout: 500, killSignal: 'SIGKILL',
  });
  assert.ifError(result.error);
  const state = result.stdout.trim();
  if (result.status === 1 && !state && !result.stderr) return false; // No matching PID.
  assert.equal(result.status, 0, 'ps must successfully report process state');
  assert.match(state, /^\S+$/);
  return !state.startsWith('Z'); // An exited, unreaped process may still have a PID.
}

async function waitForExit(pid) {
  const deadline = performance.now() + 1500;
  do {
    if (!isRunning(pid)) return;
    await delay(25);
  } while (performance.now() < deadline);
  assert.fail('the fixture process is still running after the bounded cleanup wait');
}

const timeoutRunner = `
import { strict as assert } from 'node:assert';
import { spawnSync } from 'node:child_process';
import { readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { PairingImageError, readPairingImage, withPairingScreenshot } from ${JSON.stringify(new URL('./pairing-image-worker.mjs', import.meta.url).href)};
const [directory, executable, marker, mode] = process.argv.slice(1);
const isRunning = ${isRunning.toString()};
const kill = process.kill;
let descendantWasRunning = false;
process.kill = (pid, signal) => {
  if (pid < 0 && signal === 'SIGKILL') {
    const descendant = Number(readFileSync(directory + '/descendant-ready', 'utf8'));
    descendantWasRunning = descendant > 1 && isRunning(descendant);
    if (mode === 'leader-only') return kill(-pid, signal);
    if (mode === 'signal-error') throw new Error(marker);
  }
  return kill(pid, signal);
};
const start = performance.now();
try {
  await withPairingScreenshot(directory, image => {
    writeFileSync(directory + '/screenshot-path', image);
    writeFileSync(image, marker);
    assert.equal(statSync(dirname(image)).mode & 0o777, 0o700);
    return readPairingImage('classify-ui', image, directory, { executable, timeoutMs: 2000 });
  });
  assert.fail('the stalled worker must not succeed');
} catch (error) {
  if (!(error instanceof PairingImageError)) throw error;
  const elapsed = performance.now() - start;
  assert.ok(descendantWasRunning, 'the handshake must identify a live descendant before the stop attempt');
  assert.ok(elapsed < 4500, 'the worker or cleanup must not extend the bounded wait');
  if (mode !== 'normal') assert.ok(elapsed >= 2900, 'unconfirmed cleanup must wait for the grace period');
  console.error(JSON.stringify(error.diagnostic));
  process.exitCode = 1;
}
`;

for (const mode of ['normal', 'leader-only', 'signal-error']) {
  test(`worker timeout (${mode}) is bounded, redacted, and runs only once`, async t => {
    const { directory, executable } = fixture(t, `
trap '' TERM
echo "$$" >> "$2/invocations"
echo '${privateMarker}'
echo '${privateMarker}' >&2
/bin/sh -c 'echo "$$" > "$1/descendant-ready"; exec /bin/sleep 60' sh "$2" &
wait`);
    const readPids = name => {
      const path = join(directory, name);
      return existsSync(path) ? readFileSync(path, 'utf8').trim().split(/\n/).map(Number) : [];
    };
    try {
      const result = await new Promise(resolve => {
        execFile(process.execPath, ['--input-type=module', '-e', timeoutRunner, directory, executable, privateMarker, mode],
          { timeout: 6000, killSignal: 'SIGKILL' },
          (error, stdout, stderr) => resolve({ code: error?.code, signal: error?.signal, stdout, stderr }));
      });
      const workers = readPids('invocations');
      const descendants = readPids('descendant-ready');
      assert.equal(workers.length, 1, 'exactly one worker invocation, without retries');
      assert.equal(descendants.length, 1, 'the descendant must write its own startup handshake');
      const [worker] = workers;
      const [descendant] = descendants;
      assert.ok(worker > 1 && descendant > 1 && worker !== descendant);
      assert.equal(result.signal, null);
      assert.equal(result.code, 1);
      assert.equal(result.stdout.length, 0, 'runner stdout must be empty');
      assert.ok(!result.stderr.includes(privateMarker), 'runner stderr must redact fixture contents');
      const { cleanup, ...diagnostic } = JSON.parse(result.stderr);
      assert.deepEqual(diagnostic, { diagnostic: 'image-inspection', operation: 'classify-ui', reason: 'timeout', timeoutMs: 2000 });
      assert.equal(existsSync(readFileSync(join(directory, 'screenshot-path'), 'utf8')), false);
      if (mode === 'normal') {
        assert.ok(cleanup === undefined || cleanup === 'unconfirmed', 'group absence may not yet be observable');
        await waitForExit(worker);
        await waitForExit(descendant);
      } else {
        assert.equal(cleanup, 'unconfirmed');
        if (mode === 'leader-only') await waitForExit(worker);
        else assert.ok(isRunning(worker), 'failed signaling leaves the worker running at the grace deadline');
        assert.ok(isRunning(descendant), 'the injected stop failure must leave a live descendant');
      }
    } finally {
      // A broken implementation or an injected failure must not leak fixture processes.
      const descendants = readPids('descendant-ready').filter(pid => pid > 1 && isRunning(pid));
      const workers = readPids('invocations').filter(pid => pid > 1);
      if (descendants.length || workers.some(isRunning)) {
        for (const worker of workers) {
          try { process.kill(-worker, 'SIGKILL'); } catch (error) { if (error.code !== 'ESRCH') throw error; }
        }
        for (const pid of [...workers, ...descendants]) await waitForExit(pid);
      }
    }
  });
}

test('nonzero exit, launch failure, and output overflow are terminal and redact worker output', async t => {
  const { directory, executable } = fixture(t, `echo '${privateMarker}'; echo '${privateMarker}' >&2; exit 7`);
  await assert.rejects(readPairingImage('classify-ui', 'unused', directory, { executable }),
    safeError('classify-ui', 'exit', { exitCode: 7 }));
  await assert.rejects(readPairingImage('classify-ui', 'unused', directory, { executable: join(directory, 'missing') }),
    safeError('classify-ui', 'launch'));
  writeFileSync(executable, '#!/bin/sh\nkill -9 "$$"\n');
  await assert.rejects(readPairingImage('classify-ui', 'unused', directory, { executable }),
    safeError('classify-ui', 'signal', { signal: 'SIGKILL' }));
  writeFileSync(executable, `#!/bin/sh\nwhile :; do echo '${privateMarker}'; done\n`);
  await assert.rejects(readPairingImage('decode-qr', 'unused', directory, { executable }),
    safeError('decode-qr', 'output-limit'));
});

test('classification and QR parsing reject malformed output without reproducing it', async t => {
  const { directory, executable } = fixture(t, `echo '${privateMarker}'`);
  const read = operation => readPairingImage(operation, 'unused', directory, { executable });
  await assert.rejects(read('classify-ui'), safeError('classify-ui', 'invalid-output'));
  await assert.rejects(read('decode-qr'), safeError('decode-qr', 'invalid-output'));
  writeFileSync(executable, `#!/bin/sh\necho '{"pairingReady":"${privateMarker}"}'\n`);
  await assert.rejects(read('classify-ui'), safeError('classify-ui', 'invalid-output'));
  writeFileSync(executable, `#!/bin/sh\necho '{"pairingReady":true,"connectionCount":2,"unknown":"${privateMarker}"}'\n`);
  assert.deepEqual(await read('classify-ui'), { pairingReady: true, connectionCount: 2 });
});
