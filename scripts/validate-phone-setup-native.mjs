// Installs the synthetic probe, captures a fresh run, and always restores the app.
import net from 'node:net';
import { spawnSync } from 'node:child_process';
import { existsSync, writeFileSync } from 'node:fs';
import { vectors } from './phone-setup-vectors.mjs';
import { x25519Vectors } from './setup-x25519-vectors.mjs';
import { handoffVectors } from './setup-handoff-vectors.mjs';

const host = process.env.ROKU_HOST;
const password = process.env.ROKU_DEV_PASSWORD;
const x25519 = process.argv.includes('--x25519');
const handoff = process.argv.includes('--handoff');
if (x25519 && handoff) throw Error('Choose --x25519 or --handoff, not both');
const restore = process.argv.slice(2).find(argument => !argument.startsWith('--'));
if (!host || !password || !restore || !existsSync(restore)) throw Error('Supply ROKU_HOST, ROKU_DEV_PASSWORD and normal-app ZIP argument');
const expected = handoff ? handoffVectors() : x25519 ? x25519Vectors() : vectors();
const mode = handoff ? 'setup-handoff' : x25519 ? 'setup-x25519' : 'phone-setup';
const prefix = handoff ? '[setup-handoff] ' : x25519 ? '[setup-x25519] ' : '[setup-matrix] ';
const probe = `out/${mode}-probe.zip`;
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function curl(args, auth = false) {
  const result = spawnSync('curl', ['--noproxy', '*', '--max-time', '40', '-sS', ...args], {
    encoding: 'utf8', input: auth ? `user = ${JSON.stringify(`rokudev:${password}`)}\n` : undefined,
  });
  if (result.status !== 0) throw Error('Roku HTTP request failed');
  return result.stdout;
}
function install(path) {
  const body = curl(['--digest', '--config', '-', '-H', 'Expect: 100-continue', '-F', 'mysubmit=Install', '-F', `archive=@${path}`, `http://${host}/plugin_install`], true);
  if (!/Install Success|Identical/.test(body)) throw Error('Installer did not report success');
  return /Identical/.test(body);
}
function post(path) { curl(['--fail', '-X', 'POST', `http://${host}:8060/${path}`]); }
let socket;
try {
  post('keypress/Home');
  await delay(1000);
  socket = net.connect({ host, port: Number(process.env.ROKU_CONSOLE_PORT ?? 8085) });
  let armed = false, pending = '';
  const rows = [];
  let complete, fail;
  const finished = new Promise((resolve, reject) => { complete = resolve; fail = reject; });
  // Errors can arrive while waiting for backlog to drain. Observe immediately;
  // the awaited promise below still propagates the failure to finally/restore.
  finished.catch(() => {});
  // Attach immediately to avoid unhandled connection errors.
  socket.on('error', () => fail(Error('Native console connection failed')));
  socket.on('data', chunk => {
    if (!armed) return;
    pending += chunk;
    const lines = pending.split('\n'); pending = lines.pop();
    for (const line of lines) {
      if (/ERROR:|error &h|Syntax Error/.test(line)) { fail(Error('Native probe compiler/runtime error')); continue; }
      const marker = line.indexOf(prefix);
      if (marker < 0) continue;
      const value = line.slice(marker + prefix.length).trim();
      if (value === 'complete-v1') { complete(); continue; }
      try { rows.push(JSON.parse(value)); } catch { fail(Error('Malformed matrix result')); }
    }
  });
  const timer = setTimeout(() => fail(Error('Native matrix timed out')), x25519 || handoff ? 180000 : 30000);
  try {
    await delay(1500); // Discard console backlog before launching a fresh instance.
    armed = true;
    // Installation auto-launches the new app. Capture that run rather than
    // losing it, pressing Home, and relying on an immediate relaunch to rerun.
    const identical = install(probe);
    if (identical) post('launch/dev');
    await finished;
  } finally { clearTimeout(timer); }
  if (x25519 || handoff) {
    const results = rows.filter(row => row.id);
    const summary = rows.find(row => row.complete === true);
    if (results.length !== expected.length || new Set(results.map(row => row.id)).size !== expected.length || !summary) throw Error('Incomplete setup crypto matrix');
    for (const fixture of expected) {
      const result = results.find(row => row.id === fixture.id);
      if (!result || typeof result.passed !== 'boolean' || !Number.isInteger(result.elapsedms) || result.elapsedms < 0) throw Error('Invalid setup crypto verdict');
    }
    const passed = results.every(row => row.passed);
    const maximumMs = Math.max(...results.map(row => row.elapsedms));
    if (summary.passed !== passed || summary.maximumms !== maximumMs) throw Error('Setup crypto summary mismatch');
    const budgetMs = handoff ? 10000 : 8000;
    const report = { rows, passed, maximumMs, budgetMs, withinBudget: maximumMs <= budgetMs };
    writeFileSync(`out/${mode}-native-results.json`, JSON.stringify(report, null, 2) + '\n');
    console.log(JSON.stringify({ passed, cases: results.length, maximumMs, budgetMs, withinBudget: report.withinBudget }, null, 2));
    if (!passed || !report.withinBudget) process.exitCode = 2;
  } else {
    const report = { rows, paths: {} };
    for (const mode of ['process', 'stream', 'settag-stream']) {
      const results = rows.filter(row => row.mode === mode);
      if (results.length !== expected.length || new Set(results.map(row => row.id)).size !== expected.length) throw Error('Incomplete or duplicate native matrix');
      for (const fixture of expected) {
        const result = results.find(row => row.id === fixture.id);
        if (!result || result.valid !== fixture.valid || result.setup !== 0) throw Error('Native fixture/setup mismatch');
        if (typeof result.accepted !== 'boolean' || typeof result.finalvalid !== 'boolean') throw Error('Missing native verdict fields');
      }
      const valid = results.filter(row => row.valid);
      const invalid = results.filter(row => !row.valid);
      report.paths[mode] = {
        validAccepted: valid.filter(row => row.accepted).length, validTotal: valid.length,
        invalidNativeFinalRejected: invalid.filter(row => !row.finalvalid && !row.taglengthrejected).length,
        invalidTagLengthRejected: invalid.filter(row => row.taglengthrejected).length, invalidTotal: invalid.length,
        compatible: valid.every(row => row.accepted && row.finalvalid) && invalid.every(row => !row.finalvalid),
        nonemptyCompatible: valid.filter(row => row.id !== 'length-0').every(row => row.accepted && row.finalvalid) && invalid.every(row => !row.finalvalid),
      };
    }
    const encryption = rows.filter(row => row.mode === 'encrypt');
    if (encryption.length !== 4) throw Error('Incomplete encryption controls');
    if (encryption.some(row => typeof row.ciphertextmatches !== 'boolean' || typeof row.taggedmatches !== 'boolean' || typeof row.tagmatches !== 'boolean')) throw Error('Missing encryption verdict fields');
    report.encryption = { ciphertextMatches: encryption.filter(row => row.ciphertextmatches).length, taggedMatches: encryption.filter(row => row.taggedmatches).length, explicitTagMatches: encryption.filter(row => row.tagmatches).length, total: encryption.length };
    writeFileSync('out/phone-setup-native-results.json', JSON.stringify(report, null, 2) + '\n');
    console.log(JSON.stringify({ paths: report.paths, encryption: report.encryption }, null, 2));
    if (!Object.values(report.paths).some(path => path.compatible)) process.exitCode = 2;
  }
} finally {
  socket?.destroy();
  install(restore);
  console.log('Normal app restored');
}
