// Offline macOS Vision regression with synthetic fixtures only; no device.
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { generatePairingImageFixtures, PairingImageError, readPairingImage } from './pairing-image-worker.mjs';

const directory = mkdtempSync(join(process.env.OPENCODE_TMP_DIR ?? tmpdir(), 'pairing-ui-test-'));
try {
  const cache = join(directory, 'cache');
  await generatePairingImageFixtures(directory, cache);
  for (const [name, ready] of [
    ['live-qr-without-readable-fingerprint', true],
    ['fingerprint-without-qr-is-not-ready', false],
    ['unrelated-qr-is-not-ready', false],
    ['wrong-wire-version-is-not-ready', false],
  ]) {
    const image = join(directory, `${name}.png`);
    const result = await readPairingImage('classify-ui', image, cache);
    assert.equal(result.pairingReady, ready, `Pairing UI regression failed: ${name}`);
    if (ready) {
      const link = await readPairingImage('decode-qr', image, cache);
      assert.ok(link.protocol === 'aeriotv:' && link.hostname === 'setup' && link.searchParams.get('v') === '1',
        'The synthetic live QR decodes to a wire-v1 setup link');
    }
    console.log(`${name}: passed`);
  }
} catch (error) {
  if (!(error instanceof PairingImageError)) throw error;
  console.error(JSON.stringify(error.diagnostic));
  process.exitCode = 1;
} finally {
  rmSync(directory, { recursive: true, force: true });
}
