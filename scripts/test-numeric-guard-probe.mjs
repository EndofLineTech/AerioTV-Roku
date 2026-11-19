import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { assertNumericGuardNativeVerdict, checkNumericGuardReport } from './numeric-guard-report.mjs';

const root = new URL('../', import.meta.url);
const nativeLog = process.argv[2];
const phase = process.argv[3];
assert(process.argv.length <= 4 && (!phase || ['pre-fix', 'post-fix'].includes(phase)),
  'Usage: node scripts/test-numeric-guard-probe.mjs [native-console.log [pre-fix|post-fix]]');

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

const result = checkNumericGuardReport(log, Boolean(nativeLog), { fixedHttp: phase === 'post-fix' });
const { summary, mismatches } = result;
if (nativeLog) {
  // An AA-only mismatch is evidence, not a product regression. Leave native
  // mismatch interpretation to the reader; never silently treat it as a pass.
  console.log(`Native evidence complete: ${summary.rows} rows, ${summary.observations} observations, ${summary.mismatches} mismatches (${summary.callermismatches} caller, ${summary.callershapemismatches} caller-shape).`);
  if (phase) {
    const { knownSynthetic, reproducedHttp } = assertNumericGuardNativeVerdict(result, phase);
    console.log(`Native ${phase} verdict matched: ${knownSynthetic} known synthetic cache/preference mismatches, ${reproducedHttp} HTTP bucket mismatches.`);
  }
} else {
  assert.deepEqual(mismatches, [], 'Host matrix regression');
  console.log(`Host gate passed: ${summary.rows} rows (${summary.observations} observations).`);
}
