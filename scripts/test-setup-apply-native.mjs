// Isolated native controller acceptance. All providers/registry operations in
// this ZIP are synthetic; always restore the explicitly supplied normal app.
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const host = process.env.ROKU_HOST;
const password = process.env.ROKU_DEV_PASSWORD;
const restore = process.argv[2];
if (!host || !password || !restore || !existsSync(restore)) throw Error('Supply developer environment and verified restore ZIP');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function curl(args, auth = false) {
  const result = spawnSync('curl', ['--noproxy', '*', '--max-time', '40', '-sS', ...args], {
    encoding: 'utf8', input: auth ? `user = ${JSON.stringify(`rokudev:${password}`)}\n` : undefined,
  });
  if (result.status !== 0) throw Error('Device HTTP failed');
  return result.stdout;
}
function ecp(path) { curl(['--fail', '-X', 'POST', `http://${host}:8060/${path}`]); }
function install(path) {
  const response = curl(['--digest', '--config', '-', '-H', 'Expect: 100-continue', '-F', 'mysubmit=Install', '-F', `archive=@${path}`, `http://${host}/plugin_install`], true);
  if (!/Install Success|Identical/.test(response)) throw Error('Installer did not report success');
  return /Identical/.test(response);
}
const events = [];
const results = [];
let consoleProcess, consoleConnected = false, closing = false, armed = false, pending = '', runtimeError = false, runtimeLocation = '', runtimeReason = '';
async function wait(kind, after = 0) {
  const started = Date.now();
  while (Date.now() - started < 20000) {
    if (runtimeError) throw Error(`Native apply probe compiler/runtime assertion failed ${runtimeLocation} ${runtimeReason}`);
    const row = events.slice(after).find(event => event.kind === kind);
    if (row) return row;
    await delay(25);
  }
  throw Error(`Native apply probe did not report ${kind}`);
}
async function begin(name) {
  const after = events.length;
  ecp(`input?setupApplyCase=${encodeURIComponent(name)}`);
  await wait('verifying', after);
  return after;
}
function passed(id) { results.push({ id, passed: true }); console.log(`${id}: passed`); }
try {
  ecp('keypress/Home');
  await delay(1000);
  // Use the same approved network client for console and ECP/installer access.
  // Some macOS hosts grant curl LAN access while Node's raw sockets are denied.
  consoleProcess = spawn('curl', ['--noproxy', '*', '--no-buffer', '--verbose', '--connect-timeout', '5', `telnet://${host}:8085`], { stdio: ['pipe', 'pipe', 'pipe'] });
  consoleProcess.stdin.end(); // Read-only, non-interactive console subscription.
  consoleProcess.on('error', () => { runtimeError = true; runtimeReason = 'console client failed'; });
  consoleProcess.on('exit', () => {
    if (!closing) { runtimeError = true; runtimeReason = 'console connection ended'; }
  });
  consoleProcess.stderr.on('data', chunk => {
    if (chunk.toString().includes('Connected to')) consoleConnected = true;
  });
  consoleProcess.stdout.on('data', chunk => {
    if (!armed) return;
    pending += chunk;
    const lines = pending.split('\n'); pending = lines.pop();
    for (const line of lines) {
      if (/ERROR:|error &h|Syntax Error|BrightScript Micro Debugger/i.test(line)) {
        runtimeError = true;
        if (!runtimeReason) runtimeReason = line.trim().replace(/["'][^"']*["']/g, '"..."').slice(0, 200);
      }
      if (runtimeError && !runtimeLocation) runtimeLocation = /pkg:\/[A-Za-z0-9_/.]+\(\d+\)/.exec(line)?.[0] ?? '';
      const prefix = '[setup-apply] ';
      const index = line.indexOf(prefix);
      if (index >= 0) {
        try { events.push(JSON.parse(line.slice(index + prefix.length).trim())); }
        catch { runtimeError = true; }
      }
    }
  });
  const connecting = Date.now();
  while (!consoleConnected && Date.now() - connecting < 7000) {
    if (runtimeError) throw Error('Console connection failed before installation');
    await delay(25);
  }
  if (!consoleConnected) throw Error('Console connection unavailable before installation');
  await delay(1000);
  armed = true;
  if (install('out/setup-apply-probe.zip')) ecp('launch/dev');
  await wait('ready');
  let after = await begin('reject');
  assert.equal((await wait('rejected', after)).unchanged, true);
  after = events.length;
  ecp('keypress/Select'); // Explicit verification retry; not a second receipt.
  assert.equal((await wait('rejected', after)).unchanged, true);
  after = events.length; ecp('keypress/Back');
  assert.equal((await wait('cancelled', after)).unchanged, true);
  passed('verification-failure-retry-and-cancel-preserve-old-state');

  after = await begin('cancel');
  await delay(300); ecp('keypress/Back');
  assert.equal((await wait('cancelled', after)).unchanged, true);
  await delay(700);
  assert.ok(!events.slice(after).some(row => row.kind === 'committed'));
  passed('cancel-during-provider-verification');

  after = await begin('duplicate-cancel');
  assert.equal((await wait('confirmation', after)).focus, 2, 'Replace initially focused');
  ecp('keypress/Up'); ecp('keypress/Up'); ecp('keypress/Select');
  assert.equal((await wait('cancelled', after)).unchanged, true);
  passed('duplicate-cancel');

  after = await begin('duplicate-replace-full');
  assert.equal((await wait('confirmation', after)).focus, 2);
  ecp('keypress/Select');
  let committed = await wait('committed', after);
  assert.equal(committed.count, 4); assert.equal(committed.replacement, true);
  passed('replace-retains-slot-at-capacity');

  after = await begin('duplicate-add');
  await wait('confirmation', after);
  ecp('keypress/Up'); ecp('keypress/Select');
  committed = await wait('committed', after);
  assert.equal(committed.count, 2); assert.equal(committed.replacement, false);
  passed('add-anyway-uses-distinct-slot');

  after = await begin('duplicate-full-add');
  await wait('confirmation', after);
  ecp('keypress/Up'); ecp('keypress/Select');
  assert.equal((await wait('capacity_refused', after)).unchanged, true);
  after = events.length; ecp('keypress/Back');
  assert.equal((await wait('cancelled', after)).unchanged, true);
  passed('add-anyway-refused-at-capacity');

  for (const name of ['m3u-query', 'xtream', 'default-profile']) {
    after = await begin(name);
    const confirmation = await wait('confirmation', after);
    if (name === 'default-profile' || name === 'm3u-query') assert.equal(confirmation.omissions, true);
    ecp('keypress/Select');
    assert.equal((await wait('committed', after)).count, 1);
    passed(name === 'default-profile' ? 'api-key-only-default-profile-and-omission-disclosure' : `${name}-session-credentials-and-clean-metadata`);
  }
  writeFileSync('out/setup-apply-native-results.json', JSON.stringify({ passed: true, results }, null, 2) + '\n');
} finally {
  closing = true;
  consoleProcess?.kill('SIGTERM');
  install(restore);
  console.log('Normal app restored');
}
