// Installs the synthetic probe, captures a fresh run, and always restores the app.
import net from 'node:net';
import { spawnSync } from 'node:child_process';
import { existsSync, writeFileSync } from 'node:fs';
import { vectors } from './phone-setup-vectors.mjs';

const host = process.env.ROKU_HOST;
const password = process.env.ROKU_DEV_PASSWORD;
const restore = process.argv[2];
if (!host || !password || !restore || !existsSync(restore)) throw Error('Supply ROKU_HOST, ROKU_DEV_PASSWORD and normal-app ZIP argument');
const expected = vectors();
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
}
function post(path) { curl(['--fail', '-X', 'POST', `http://${host}:8060/${path}`]); }
let socket;
try {
  install('out/phone-setup-probe.zip');
  post('keypress/Home');
  await delay(1000);
  socket = net.connect({ host, port: 8085 });
  let armed = false, pending = '';
  const rows = [];
  let complete, fail;
  const finished = new Promise((resolve, reject) => { complete = resolve; fail = reject; });
  // Attach immediately to avoid unhandled connection errors.
  socket.on('error', () => fail(Error('Native console connection failed')));
  socket.on('data', chunk => {
    if (!armed) return;
    pending += chunk;
    const lines = pending.split('\n'); pending = lines.pop();
    for (const line of lines) {
      const marker = line.indexOf('[setup-matrix] ');
      if (marker < 0) continue;
      const value = line.slice(marker + 15).trim();
      if (value === 'complete-v1') { complete(); continue; }
      try { rows.push(JSON.parse(value)); } catch { fail(Error('Malformed matrix result')); }
    }
  });
  const timer = setTimeout(() => fail(Error('Native matrix timed out')), 30000);
  try {
    await delay(1500); // Discard console backlog before launching a fresh instance.
    armed = true;
    post('launch/dev');
    await finished;
  } finally { clearTimeout(timer); }
  const report = { rows, paths: {} };
  for (const mode of ['process', 'stream']) {
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
      invalidFinalRejected: invalid.filter(row => !row.finalvalid).length, invalidTotal: invalid.length,
      compatible: valid.every(row => row.accepted && row.finalvalid) && invalid.every(row => !row.finalvalid),
    };
  }
  const encryption = rows.filter(row => row.mode === 'encrypt');
  if (encryption.length !== 4) throw Error('Incomplete encryption controls');
  if (encryption.some(row => typeof row.ciphertextmatches !== 'boolean' || typeof row.taggedmatches !== 'boolean')) throw Error('Missing encryption verdict fields');
  report.encryption = { ciphertextMatches: encryption.filter(row => row.ciphertextmatches).length, taggedMatches: encryption.filter(row => row.taggedmatches).length, total: encryption.length };
  writeFileSync('out/phone-setup-native-results.json', JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({ paths: report.paths, encryption: report.encryption }, null, 2));
  if (!Object.values(report.paths).some(path => path.compatible)) process.exitCode = 2;
} finally {
  socket?.destroy();
  install(restore);
  console.log('Normal app restored');
}
