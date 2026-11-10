// Disposable native measurement; never outputs encrypted bytes or identifiers.
import { spawn, spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
const host = process.env.ROKU_HOST;
const password = process.env.ROKU_DEV_PASSWORD;
const restore = process.env.ROKU_RESTORE_ZIP ?? 'out/native-parity-normal.zip';
assert.ok(host && password);
assert.equal(createHash('sha256').update(readFileSync(restore)).digest('hex'), 'eb09f4b9705262d11efba05a7b27281ff6272f2b22ff0f003805d9e20224a610');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function curl(args, auth = false) {
  const result = spawnSync('curl', ['--noproxy', '*', '--max-time', '40', '-sS', ...args], {
    encoding: 'utf8', input: auth ? `user = ${JSON.stringify(`rokudev:${password}`)}\n` : undefined,
  });
  if (result.status !== 0) throw Error('Device HTTP failed');
  return result.stdout;
}
function ecp(path) { return curl(['--fail', '-X', 'POST', `http://${host}:8060/${path}`]); }
function install(path) {
  const response = curl(['--digest', '--config', '-', '-H', 'Expect: 100-continue', '-F', 'mysubmit=Install', '-F', `archive=@${path}`, `http://${host}/plugin_install`], true);
  assert.match(response, /Install Success|Identical/);
  return /Identical/.test(response);
}
const rows = [];
let consoleProcess, connected = false, armed = false, closing = false, pending = '', error;
try {
  ecp('keypress/Home');
  await delay(1000);
  consoleProcess = spawn('curl', ['--noproxy', '*', '--no-buffer', '--verbose', '--connect-timeout', '5', `telnet://${host}:8085`], { stdio: ['pipe', 'pipe', 'pipe'] });
  consoleProcess.stdin.end();
  consoleProcess.stderr.on('data', chunk => { if (chunk.toString().includes('Connected to')) connected = true; });
  consoleProcess.on('error', () => { error = 'Console connection failed'; });
  consoleProcess.on('exit', () => { if (!closing) error = 'Console disconnected'; });
  consoleProcess.stdout.on('data', chunk => {
    if (!armed) return;
    pending += chunk;
    const lines = pending.split('\n'); pending = lines.pop();
    for (const line of lines) {
      // Do not dump diagnostics that could contain data, even on failure.
      if (/error &h|Syntax Error|BrightScript Micro Debugger/i.test(line)) error = 'Native compiler/runtime failure';
      const prefix = '[entropy-capability] ';
      const index = line.indexOf(prefix);
      if (index >= 0) {
        try { rows.push(JSON.parse(line.slice(index + prefix.length).trim())); }
        catch { error = 'Malformed diagnostic result'; }
      }
    }
  });
  const connecting = Date.now();
  while (!connected && Date.now() - connecting < 7000) { if (error) throw Error(error); await delay(25); }
  assert.equal(connected, true);
  await delay(1000);
  armed = true;
  if (install('out/entropy-capability-probe.zip')) ecp('launch/dev');
  const start = Date.now();
  while (!rows.some(row => row.kind === 'complete') && Date.now() - start < 60000) { if (error) throw Error(error); await delay(25); }
  assert.ok(rows.some(row => row.kind === 'complete'), 'complete native measurement');
  assert.equal(rows.filter(row => row.kind === 'encryption').length, rows.find(row => row.kind === 'component').available ? 12 : 0);
  writeFileSync('out/entropy-capability-native-results.json', JSON.stringify({ rows, securityApproval: false }, null, 2) + '\n');
  console.log(JSON.stringify(rows, null, 2));
} finally {
  closing = true;
  consoleProcess?.kill('SIGTERM');
  install(restore);
  console.log('Verified normal app ZIP restored');
}
