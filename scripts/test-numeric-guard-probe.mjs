import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { checkNumericGuardReport } from './numeric-guard-report.mjs';

const root = new URL('../', import.meta.url);
const nativeLog = process.argv[2];
assert(process.argv.length <= 3, 'Usage: node scripts/test-numeric-guard-probe.mjs [native-console.log]');

let log;
if (nativeLog) {
  log = readFileSync(nativeLog, 'utf8');
} else {
  const config = JSON.parse(readFileSync(new URL('tests/native/numeric-guard-probe.bsconfig.json', root), 'utf8'));
  const sources = config.files.filter(file => typeof file === 'string');
  const result = spawnSync(process.execPath, [
    'node_modules/brs/bin/cli.js', '--root', 'tests/unit-root', ...sources,
    'tests/native/NumericGuardProbe.brs', 'tests/native/NumericGuardProbeHost.brs',
  ], { cwd: fileURLToPath(root), encoding: 'utf8', timeout: 15000 });
  if (result.error) throw result.error;
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, '', result.stderr);
  log = result.stdout;
}
process.stdout.write(log);

const { summary, mismatches } = checkNumericGuardReport(log, Boolean(nativeLog));
if (nativeLog) {
  // An AA-only mismatch is evidence, not a product regression. Leave native
  // mismatch interpretation to the reader; never silently treat it as a pass.
  console.log(`Native evidence complete: ${summary.rows} rows, ${summary.observations} observations, ${summary.mismatches} mismatches (${summary.callermismatches} caller, ${summary.callershapemismatches} caller-shape).`);
} else {
  assert.deepEqual(mismatches, [], 'Host matrix regression');
  console.log(`Host gate passed: ${summary.rows} rows (${summary.observations} observations).`);
}
