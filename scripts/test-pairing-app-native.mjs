// Controlled full-app UI smoke: no Save/Replace/Forget, no real imported account.
// QR links/codes, screenshots, raw console and account text are never retained.
import { spawn, spawnSync } from 'node:child_process';
import { createHash, createCipheriv, createPublicKey, diffieHellman, generateKeyPairSync, hkdfSync, randomBytes, randomUUID } from 'node:crypto';
import { mkdirSync, readFileSync, realpathSync, unlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { performance } from 'node:perf_hooks';
import assert from 'node:assert/strict';

const [candidate, restore] = process.argv.slice(2);
const host = process.env.ROKU_HOST, password = process.env.ROKU_DEV_PASSWORD;
assert.ok(host && password && candidate && restore, 'Supply developer environment, test ZIP and verified restore ZIP');
assert.ok(createHash('sha256').update(readFileSync(restore)).digest('hex') === 'eb09f4b9705262d11efba05a7b27281ff6272f2b22ff0f003805d9e20224a610', 'Verified normal restore ZIP required');
const marker = spawnSync('unzip', ['-p', candidate, 'pairing-test-build.json'], { encoding: 'utf8' });
assert.ok(marker.status === 0 && JSON.parse(marker.stdout).kind === 'full-app-pairing-test', 'Explicit full-app test artifact required');
const testBuild = JSON.parse(marker.stdout);
const candidateSha256 = createHash('sha256').update(readFileSync(candidate)).digest('hex');
const temporaryBase = process.env.OPENCODE_TMP_DIR ?? join(tmpdir(), 'opencode');
mkdirSync(temporaryBase, { recursive: true });
const temporary = realpathSync(temporaryBase);
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const results = [];
let consoleProcess, connected = false, closing = false, armed = false, pending = '', runtimeError = false, entryRoute;
function curl(args, auth = false) {
  const result = spawnSync('curl', ['--noproxy', '*', '--max-time', '40', '-sS', ...args], {
    encoding: 'utf8', input: auth ? `user = ${JSON.stringify(`rokudev:${password}`)}\n` : undefined,
  });
  if (result.status !== 0) throw Error('Device HTTP failed');
  return result.stdout;
}
function ecp(path) { curl(['--fail', '-X', 'POST', `http://${host}:8060/${path}`]); }
async function key(name, count = 1) {
  for (let i = 0; i < count; i++) { ecp(`keypress/${name}`); await delay(100); }
  await delay(350);
}
function install(path) {
  const result = curl(['--digest', '--config', '-', '-H', 'Expect: 100-continue', '-F', 'mysubmit=Install', '-F', `archive=@${path}`, `http://${host}/plugin_install`], true);
  assert.ok(/Install Success|Identical/.test(result), 'Installer reported success');
  return /Identical/.test(result);
}
function swift(script, image) {
  const result = spawnSync('swift', ['-module-cache-path', join(temporary, 'pairing-swift-cache-canonical'), script, image], { encoding: 'utf8', timeout: 60000 });
  if (result.status !== 0) console.log(JSON.stringify({ diagnostic: 'image-inspection', script, exit: result.status, signal: result.signal, cacheConflict: /defined in both|cannot load underlying module/.test(result.stderr ?? ''), classificationFailed: /Pairing UI classification failed/.test(result.stderr ?? ''), imageBytes: readFileSync(image).length }));
  assert.ok(result.status === 0, 'Offline image inspection succeeded');
  return result.stdout.trim();
}
function snapshot(withQr = false) {
  if (runtimeError) throw Error('Native compiler/runtime failure');
  const image = join(temporary, `pairing-app-${randomUUID()}.jpg`);
  try {
    curl(['--digest', '--config', '-', '--fail', '-F', 'mysubmit=Screenshot', `http://${host}/plugin_inspect`], true);
    curl(['--digest', '--config', '-', '--fail', '-o', image, `http://${host}/pkgs/dev.jpg`], true);
    const state = JSON.parse(swift('scripts/read-pairing-ui.swift', image));
    if (withQr && state.pairingReady) state.link = swift('scripts/read-setup-probe-qr.swift', image);
    return state;
  } finally { try { unlinkSync(image); } catch {} }
}
async function waitUi(predicate, timeout = 25000) {
  const start = performance.now();
  while (performance.now() - start < timeout) {
    const state = snapshot();
    if (predicate(state)) return state;
    await delay(700);
  }
  throw Error('Expected full-app screen did not appear');
}
function readSession() {
  const state = snapshot(true);
  assert.ok(state.pairingReady && state.warning, 'Full-app pairing screen carries visible test warning');
  const link = new URL(state.link);
  assert.ok(link.protocol === 'aeriotv:' && link.hostname === 'setup' && link.searchParams.get('v') === '1', 'Wire-v1 QR');
  assert.ok(link.searchParams.get('ip') === host, 'QR targets selected Roku');
  const session = { pk: Buffer.from(link.searchParams.get('pk'), 'base64url'), code: link.searchParams.get('code'), port: Number(link.searchParams.get('port')) };
  assert.ok(session.pk.length === 32 && /^\d{6}$/.test(session.code) && session.port > 0, 'Fresh pairing material');
  return session;
}
async function openFromSetup() {
  const state = await waitUi(row => row.setup && Number.isInteger(row.connectionCount));
  await key('Up', 12); await key('Select');
  await waitUi(row => row.picker);
  await key('Down', state.connectionCount); await key('Select');
  await waitUi(row => row.manager);
  await key('Down', 3); await key('Select');
}
function pass(id, extra = {}) { results.push({ id, passed: true, ...extra }); console.log(`${id}: passed`); }
function seal(session) {
  const phone = generateKeyPairSync('x25519');
  const phonePk = phone.publicKey.export({ type: 'spki', format: 'der' }).subarray(-32);
  const publicKey = createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b656e032100', 'hex'), session.pk]), type: 'spki', format: 'der' });
  const shared = diffieHellman({ privateKey: phone.privateKey, publicKey });
  const info = Buffer.concat([Buffer.from('aeriotv-setup-v1'), phonePk, session.pk]);
  const secret = Buffer.from(hkdfSync('sha256', shared, Buffer.from(session.code), info, 32));
  const nonce = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', secret, nonce);
  // Closed Roku loopback port: exercises real M3uTask failure, no LAN provider.
  const payload = { playlist: { type: 'm3u', name: 'Pairing failure test', url: 'http://127.0.0.1:1/pairing-negative.m3u' } };
  const encrypted = Buffer.concat([cipher.update(Buffer.from(JSON.stringify(payload))), cipher.final(), cipher.getAuthTag()]);
  secret.fill(0); shared.fill(0);
  return JSON.stringify({ v: 1, phonePk: phonePk.toString('base64'), nonce: nonce.toString('base64'), ciphertext: encrypted.toString('base64') });
}
function request(session, body) {
  const start = performance.now();
  const result = spawnSync('curl', ['--noproxy', '*', '--silent', '--show-error', '--connect-timeout', '2', '--max-time', '20', '-H', 'Expect:', '-H', 'Content-Type: application/json', '--data-binary', '@-', '--write-out', '\n%{http_code}', `http://${host}:${session.port}/setup`], { encoding: 'utf8', input: body });
  const split = result.stdout.lastIndexOf('\n');
  return { status: Number(result.stdout.slice(split + 1)) || null, body: result.stdout.slice(0, split), elapsedMs: Math.round(performance.now() - start) };
}
try {
  await key('Home');
  consoleProcess = spawn('curl', ['--noproxy', '*', '--no-buffer', '--verbose', '--connect-timeout', '5', `telnet://${host}:8085`], { stdio: ['pipe', 'pipe', 'pipe'] });
  consoleProcess.stdin.end();
  consoleProcess.stderr.on('data', chunk => { if (chunk.toString().includes('Connected to')) connected = true; });
  consoleProcess.on('error', () => { runtimeError = true; });
  consoleProcess.on('exit', () => { if (!closing) runtimeError = true; });
  consoleProcess.stdout.on('data', chunk => {
    if (!armed) return;
    pending += chunk;
    const lines = pending.split('\n'); pending = lines.pop();
    if (lines.some(line => /ERROR:|error &h|Syntax Error|BrightScript Micro Debugger/i.test(line))) runtimeError = true;
  });
  const connecting = performance.now();
  while (!connected && performance.now() - connecting < 7000) { assert.ok(!runtimeError, 'Console connection'); await delay(25); }
  assert.ok(connected, 'Read-only console attached before installation');
  await delay(1000);
  armed = true;
  if (install(candidate)) ecp('launch/dev');
  await delay(5000);
  let state = snapshot();
  if (state.welcome) {
    entryRoute = 'welcome';
    await key('Down'); await key('Select');
  } else {
    entryRoute = 'manage-connections';
    if (!state.setup) {
      // Normal Guide -> Settings tab -> Connection pane; no preference edits.
      await key('Back'); await key('Right', 5); await key('Select');
      state = await waitUi(row => row.settingsHub || row.setup);
      if (state.settingsHub) { await key('Right'); await key('Select'); }
    }
    await openFromSetup();
  }
  await waitUi(row => row.pairingReady && row.warning);
  const firstSession = readSession();
  pass('full-app-entry-and-live-qr');
  await key('Select'); // New Code, through the normal production View handler.
  await waitUi(row => row.pairingReady && row.warning);
  const session = readSession();
  assert.ok(!session.pk.equals(firstSession.pk), 'New Code generated a different key');
  if (session.port !== firstSession.port) assert.ok(request(firstSession, '{}').status === null, 'Old New Code listener closed');
  pass('full-app-new-code-replaces-live-session');
  const response = request(session, seal(session));
  assert.ok(response.status === 200 && JSON.parse(response.body).ok === true && response.elapsedMs < 10000, 'Encrypted receipt completed within budget');
  await waitUi(row => row.verificationFailed && row.retry && row.warning);
  pass('full-app-receipt-to-real-provider-verification', { replyMs: response.elapsedMs });
  assert.ok(request(session, '{}').status === null, 'Successful receipt closed listener');
  await key('Select');
  await waitUi(row => row.verificationFailed && row.retry);
  pass('full-app-verification-retry-without-resending');
  await key('Back');
  state = await waitUi(row => (row.setup || row.welcome) && !row.pairing);
  pass('full-app-cancel-back-to-normal-setup');
  if (state.welcome) {
    await key('Back'); // Manual setup without selecting or creating a slot.
    await openFromSetup();
    await waitUi(row => row.pairingReady && row.warning);
    const managed = readSession();
    assert.ok(!managed.pk.equals(session.pk), 'Manage entry generated a fresh session');
    await key('Back');
    await waitUi(row => row.setup && !row.pairing);
    assert.ok(request(managed, '{}').status === null, 'Manage cancellation closed listener');
    pass('full-app-manage-entry-and-cancel');
  }
  assert.ok(!runtimeError, 'No native compiler/runtime errors');
  writeFileSync('out/pairing-app-native-results.json', JSON.stringify({ passed: true, version: testBuild.version, candidateSha256, baseZipSha256: testBuild.baseZipSha256, entryRoute, savedOrReplaced: false, realPhoneSenderTested: false, results }, null, 2) + '\n');
} finally {
  closing = true;
  consoleProcess?.kill('SIGTERM');
  install(restore);
  console.log('Verified normal app ZIP restored');
}
