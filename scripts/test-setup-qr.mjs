import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const directory = mkdtempSync(join(process.env.OPENCODE_TMP_DIR ?? tmpdir(), 'setup-qr-'));
try {
  const fixtures = JSON.parse(readFileSync('tests/fixtures/phone-setup-qr.json', 'utf8')).cases;
  const fixture = join(directory, 'QrFixtures.brs');
  writeFileSync(fixture, `function phoneSetupQrFixtures() as object\nreturn parseJson(${JSON.stringify(JSON.stringify(fixtures)).replaceAll('\\"', '""')})\nend function\n`);
  const result = spawnSync(process.execPath, ['node_modules/brs/bin/cli.js', '--root', 'tests/unit-root',
    'source/PhoneSetupQr.brs', fixture, 'tests/PhoneSetupQr.test.brs'], { encoding: 'utf8', timeout: 120000 });
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  if (result.error) throw result.error;
  if (result.status !== 0 || !result.stdout.includes('ALL TESTS PASSED')) process.exitCode = 1;
} finally {
  rmSync(directory, { recursive: true });
}
