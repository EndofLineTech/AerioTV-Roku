import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../', import.meta.url);
const prefix = '[numeric-guard]';
const completePrefix = `${prefix} COMPLETE`;
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

const lines = log.split(/\r?\n/).map(line => line.trim()).filter(line => line.startsWith(prefix));
assert(lines[0]?.startsWith(prefix), 'No probe evidence');
const complete = lines.filter(line => line.startsWith(completePrefix));
assert.equal(complete.length, 1, 'Expected one terminal marker');
assert.equal(lines.at(-1), complete[0], 'Terminal marker is not last');
const summary = JSON.parse(complete[0].slice(completePrefix.length));
const rows = lines.filter(line => /^\[numeric-guard\]\s+\{/.test(line))
  .map(line => JSON.parse(line.slice(prefix.length)));
assert.equal(summary.native, Boolean(nativeLog), 'Wrong runtime evidence');
assert.equal(summary.rows, nativeLog ? 226 : 205, 'Incomplete runtime matrix');
assert.equal(rows.length, summary.rows, 'Console rows lost or duplicated');
assert.equal(new Set(rows.map(row => `${row.target}/${row.name}`)).size, rows.length, 'Duplicate case');
const mismatches = rows.filter(row => row.expected !== 'observe' && row.actual !== row.expected);
assert.equal(rows.filter(row => row.expected === 'observe').length, summary.observations);
assert.equal(mismatches.length, summary.mismatches);
assert.equal(mismatches.filter(row => row.lane.startsWith('caller')).length, summary.callermismatches);
if (nativeLog) {
  assert(!rows.some(row => row.lane === 'host-only'), 'Host-only workaround in native log');
  assert(!rows.some(row => row.lane === 'fixture' || row.actual === 'runtime-exception'), 'Native fixture or runtime error; inspect rows');
  // An AA-only mismatch is evidence, not a product regression. Leave native
  // mismatch interpretation to the reader; never silently treat it as a pass.
  console.log(`Native evidence complete: ${summary.mismatches} mismatches (${summary.callermismatches} caller/caller-shape).`);
} else {
  assert.deepEqual(mismatches, [], 'Host matrix regression');
  console.log(`Host gate passed: ${summary.rows} rows (${summary.observations} observations).`);
}
