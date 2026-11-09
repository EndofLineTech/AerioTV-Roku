import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { x25519Vectors } from './setup-x25519-vectors.mjs';
import { createRequire } from 'node:module';
import { Writable } from 'node:stream';

// brs 0.39 rejects Double arguments to Int instead of coercing them as Roku
// does. This test-only adapter models the measured native Float narrowing.
// It changes no installed files and is NOT included in either Roku package.
const require = createRequire(import.meta.url);
const math = require('brs/lib/stdlib/Math');
const types = require('brs/lib/brsTypes');
math.Int = new types.Callable('Int', ...[types.ValueKind.Float, types.ValueKind.Double].map(kind => ({
  signature: { args: [new types.StdlibArgument('x', kind)], returns: types.ValueKind.Int32 },
  impl: (_interpreter, x) => new types.Int32(Math.floor(Math.fround(x.getValue()))),
})));
const brs = require('brs');

// Generated test input is temporary and synthetic, never included in the app.
const directory = mkdtempSync(join(process.env.OPENCODE_TMP_DIR ?? tmpdir(), 'setup-x25519-'));
try {
  const fixture = join(directory, 'Vectors.brs');
  writeFileSync(fixture, `function setupX25519TestVectors() as object\nreturn parseJson(${JSON.stringify(JSON.stringify(x25519Vectors())).replaceAll('\\"', '""')})\nend function\n`);
  let output = '';
  const stdout = new Writable({ write(chunk, _encoding, done) { output += chunk; done(); } });
  await brs.execute(['source/PhoneSetupX25519.brs', fixture, 'tests/SetupX25519.test.brs'], {
    root: 'tests/unit-root', stdout, stderr: process.stderr,
  });
  process.stdout.write(output);
  if (!output.includes('ALL TESTS PASSED')) process.exitCode = 1;
} finally {
  rmSync(directory, { recursive: true });
}
