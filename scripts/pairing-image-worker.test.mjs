import assert from 'node:assert/strict';
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

test('a real worker that ignores SIGTERM times out, is killed, and the screenshot is removed', async t => {
  const { directory, executable } = fixture(t, `
trap '' TERM
echo "$$" > "$2/worker.pid"
echo '${privateMarker}'
echo '${privateMarker}' >&2
(sleep 2; touch "$2/descendant-survived") &
wait
sleep 8`);
  let screenshot;
  const started = performance.now();
  await assert.rejects(withPairingScreenshot(directory, image => {
    screenshot = image;
    writeFileSync(image, privateMarker);
    assert.equal(statSync(dirname(image)).mode & 0o777, 0o700);
    return readPairingImage('classify-ui', image, directory, { executable, timeoutMs: 1000 });
  }), safeError('classify-ui', 'timeout', { timeoutMs: 1000 }));
  assert.ok(performance.now() - started < 4000, 'the stalled worker must not extend the deadline');
  assert.equal(existsSync(screenshot), false);
  const pid = Number(readFileSync(join(directory, 'worker.pid'), 'utf8'));
  assert.throws(() => process.kill(pid, 0), { code: 'ESRCH' });
  await delay(Math.max(0, 2400 - (performance.now() - started)));
  assert.equal(existsSync(join(directory, 'descendant-survived')), false);
});

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
