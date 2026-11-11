// Screenshots contain only synthetic gallery data. This is a rendered capture
// runner, NOT a claim of visual approval: review the resulting images as well.
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const [probe, restore, ...requested] = process.argv.slice(2);
const screens = requested.length ? requested : ['welcome', 'setup-dispatcharr', 'setup-xtream', 'setup-m3u', 'phone-ready', 'phone-expired', 'phone-failed', 'guide-picker', 'player-options', 'program-details', 'vod-details', 'navigation', 'group-pills', 'group-sidebar', 'player-controls', 'recording-controls', 'tips', 'settings-connection', 'settings-live', 'settings-player', 'settings-movies', 'settings-dvr', 'settings-appearance', 'settings-general', 'settings-remote', 'settings-about', 'settings-whatsnew', 'settings-licenses', 'dialog-duplicate', 'dialog-delete', 'dialog-diagnostics', 'keyboard', 'large-phone', 'large-options', 'large-settings', 'light-dialog', 'light-settings', 'light-tips'];
const host = process.env.ROKU_HOST, password = process.env.ROKU_DEV_PASSWORD;
if (!requested.length) screens.push('guide-picker-scroll');
const hash = path => createHash('sha256').update(readFileSync(path)).digest('hex');
assert.ok(host && password && probe && restore, 'Supply developer environment, isolated gallery and verified restore ZIP');
assert.equal(hash(restore), '40bd99329ff0c33fb4be807690970ba7d2ddd3b4add64bee0f9f7b079739794c', 'Owner-ready auto-guide rollback required');
assert.ok(screens.every(name => /^[a-z0-9-]+$/.test(name)), 'Only named synthetic gallery cases');
mkdirSync('out/ui-audit', { recursive: true });
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function curl(args, auth = false) {
  const result = spawnSync('curl', ['--noproxy', '*', '--max-time', '40', '-sS', ...args], { encoding: 'utf8', input: auth ? `user = ${JSON.stringify(`rokudev:${password}`)}\n` : undefined });
  assert.equal(result.status, 0, 'Device HTTP transport');
  return result.stdout;
}
function ecp(path) { curl(['--fail', '-X', 'POST', `http://${host}:8060/${path}`]); }
function install(path) {
  const response = curl(['--digest', '--config', '-', '-H', 'Expect: 100-continue', '-F', 'mysubmit=Install', '-F', `archive=@${path}`, `http://${host}/plugin_install`], true);
  assert.ok(/Install Success|Identical/.test(response), 'Native ZIP installed');
  if (/Identical/.test(response)) ecp('launch/dev');
}
let consoleProcess, connected = false, closing = false, armed = false, pending = '', runtimeError = false;
const events = [], captures = [];
try {
  ecp('keypress/Home');
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
      if (/ERROR:|error &h|Syntax Error|BrightScript Micro Debugger/i.test(line)) {
        runtimeError = true;
        const reason = /(?:Type mismatch|Member function not found|Invalid value|does not have a field|Unknown component)/i.exec(line)?.[0];
        if (reason) console.log(`Native diagnostic: ${reason}`);
        const compile = /(?:Syntax Error|Compile Error|Function .*? is not defined|Duplicate function)[^\r\n]*/i.exec(line)?.[0];
        if (compile) console.log(`Gallery compiler: ${compile}`);
      }
      const location = /pkg:\/(?:components|source)\/[A-Za-z0-9_-]+\.brs\(\d+\)/.exec(line)?.[0];
      if (runtimeError && location) console.log(`Native location: ${location}`);
      const marker = '[ui-audit] ';
      const at = line.indexOf(marker);
      if (at >= 0) { try { events.push(JSON.parse(line.slice(at + marker.length))); } catch { runtimeError = true; } }
    }
  });
  const start = performance.now();
  while (!connected && !runtimeError && performance.now() - start < 7000) await delay(25);
  assert.ok(connected && !runtimeError, 'Read-only console attached before install');
  await delay(1000); armed = true;
  install(probe);
  const boot = performance.now();
  while (!runtimeError && !events.some(row => row.ready && row.screen === 'welcome') && performance.now() - boot < 20000) await delay(50);
  assert.ok(!runtimeError && events.some(row => row.ready && row.screen === 'welcome'), 'Gallery initialized before input');
  for (const screen of screens) {
    const after = events.length;
    ecp(`input?uiAuditScreen=${screen}`);
    const started = performance.now();
    while (!runtimeError && !events.slice(after).some(row => row.ready && row.screen === screen) && performance.now() - started < 15000) await delay(50);
    await delay(250);
    assert.ok(!runtimeError && events.slice(after).some(row => row.ready && row.screen === screen), `Gallery ready: ${screen}`);
    if (['guide-picker', 'guide-picker-scroll', 'player-options', 'vod-details', 'dialog-duplicate'].includes(screen)) {
      // Exercise real native focus navigation without selecting any action.
      const dialog = screen === 'dialog-duplicate';
      ecp(`keypress/${dialog ? 'Up' : 'Down'}`);
      if (screen === 'guide-picker-scroll') {
        for (let i = 1; i < 9; i++) { await delay(80); ecp('keypress/Down'); }
      }
      await delay(200);
      const checkAfter = events.length;
      ecp('input?uiAuditCheck=focus');
      const checking = performance.now();
      while (!runtimeError && !events.slice(checkAfter).some(row => row.check) && performance.now() - checking < 5000) await delay(25);
      assert.equal(events.slice(checkAfter).find(row => row.check)?.focused, screen === 'guide-picker-scroll' ? 9 : 1, `Native pill focus: ${screen}`);
      if (screen !== 'guide-picker-scroll') ecp(`keypress/${dialog ? 'Down' : 'Up'}`);
      await delay(200);
    }
    curl(['--digest', '--config', '-', '--fail', '-F', 'mysubmit=Screenshot', `http://${host}/plugin_inspect`], true);
    const file = `out/ui-audit/${screen}.jpg`;
    curl(['--digest', '--config', '-', '--fail', '-o', file, `http://${host}/pkgs/dev.jpg`], true);
    if (screen === 'keyboard') {
      // Roku may display its own mobile-keyboard QR banner. Retain only the
      // keyboard/action region, never that system-generated link.
      const crop = spawnSync('sips', ['--cropToHeightWidth', '820', '1920', '--cropOffset', '240', '0', file], { encoding: 'utf8' });
      assert.equal(crop.status, 0, 'Remove system keyboard QR banner');
    }
    captures.push({ screen, file });
    console.log(`${screen}: captured on Roku`);
  }
  writeFileSync('out/ui-audit/captures.json', JSON.stringify({ rendered: true, visualReviewPending: true, probeSha256: hash(probe), savedConnectionsChanged: false, captures }, null, 2) + '\n');
} finally {
  closing = true; consoleProcess?.kill('SIGTERM');
  install(restore);
  console.log('Verified auto-guide developer build restored');
}
