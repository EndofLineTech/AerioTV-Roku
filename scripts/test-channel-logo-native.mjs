// Synthetic loopback transport + real Guide/Channels/banner Poster's decode.
// The application scene/registry is never created. Restore the known test app.
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const [probe, restore] = process.argv.slice(2);
const host = process.env.ROKU_HOST, password = process.env.ROKU_DEV_PASSWORD;
assert.ok(host && password && probe && restore, 'Supply developer environment, probe and verified restore ZIP');
const hash = path => createHash('sha256').update(readFileSync(path)).digest('hex');
assert.ok(['28343bb7dbedd91c7c0ed353a8915cd1485a79f67b599ae193fcf2e78b149601', '16d9055585eefc12b2720e71188c0c5fc4d38dea00d9f7c60df2530883a88f66'].includes(hash(restore)), 'Previously verified developer test restore required');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function curl(args, auth = false) {
  const result = spawnSync('curl', ['--noproxy', '*', '--max-time', '40', '-sS', ...args], {
    encoding: 'utf8', input: auth ? `user = ${JSON.stringify(`rokudev:${password}`)}\n` : undefined,
  });
  assert.equal(result.status, 0, 'Device HTTP transport');
  return result.stdout;
}
function install(path) {
  const response = curl(['--digest', '--config', '-', '-H', 'Expect: 100-continue', '-F', 'mysubmit=Install', '-F', `archive=@${path}`, `http://${host}/plugin_install`], true);
  assert.ok(/Install Success|Identical/.test(response), 'Native ZIP installed');
  if (/Identical/.test(response)) curl(['--fail', '-X', 'POST', `http://${host}:8060/launch/dev`]);
}
let consoleProcess, connected = false, armed = false, closing = false, runtimeError = false, pending = '', result;
const stages = [];
try {
  curl(['--fail', '-X', 'POST', `http://${host}:8060/keypress/Home`]);
  consoleProcess = spawn('curl', ['--noproxy', '*', '--no-buffer', '--verbose', '--connect-timeout', '5', `telnet://${host}:8085`], { stdio: ['pipe', 'pipe', 'pipe'] });
  consoleProcess.stdin.end();
  consoleProcess.stderr.on('data', chunk => { if (chunk.toString().includes('Connected to')) connected = true; });
  consoleProcess.on('error', () => { runtimeError = true; });
  consoleProcess.on('exit', () => { if (!closing) runtimeError = true; });
  consoleProcess.stdout.on('data', chunk => {
    if (!armed) return;
    pending += chunk;
    const lines = pending.split('\n'); pending = lines.pop();
    for (const line of lines) {
      if (/ERROR:|error &h|Syntax Error|BrightScript Micro Debugger/i.test(line)) runtimeError = true;
      // Locations only, no raw console/source text or request data.
      const location = /pkg:\/(?:components|source)\/[A-Za-z0-9_-]+\.brs\(\d+\)/.exec(line)?.[0];
      if (runtimeError && location) console.log(`Native diagnostic: ${location}`);
      const marker = '[channel-logo-probe] ';
      const at = line.indexOf(marker);
      if (at < 0) continue;
      const value = line.slice(at + marker.length).trim();
      if (/^[a-z0-9-]+ passed$/.test(value)) { stages.push(value); console.log(value); }
      if (value.startsWith('{')) {
        const row = JSON.parse(value);
        if (row.diagnostic === true) { console.log(JSON.stringify(row)); continue; }
        result = { passed: row.passed === true, remoteRequests: row.remoterequests, proxyRequests: row.proxyrequests, authLeaks: row.authleaks };
      }
    }
  });
  const connectionStarted = performance.now();
  while (!connected && !runtimeError && performance.now() - connectionStarted < 7000) await delay(25);
  assert.ok(connected && !runtimeError, 'Read-only console attached before install');
  await delay(1000);
  armed = true;
  install(probe);
  const started = performance.now();
  while (!result && !runtimeError && performance.now() - started < 90000) await delay(50);
  await delay(150);
  assert.ok(!runtimeError && result?.passed && result.authLeaks === 0 && stages.length === 5, 'Native transport, bounds and all three logo surfaces passed');
  writeFileSync('out/channel-logo-native-results.json', JSON.stringify({ ...result, probeSha256: hash(probe), restoreSha256: hash(restore), savedConnectionsChanged: false, realProviderTested: false, stages }, null, 2) + '\n');
} finally {
  closing = true;
  consoleProcess?.kill('SIGTERM');
  install(restore);
  console.log('Verified developer test app restored');
}
