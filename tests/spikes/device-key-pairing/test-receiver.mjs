// Disposable end-to-end experiment; synthetic payloads, non-fixture TV keys.
// No QR links, codes, private keys, device secrets or plaintext payloads logged.
import { spawn, spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import { createHash, createCipheriv, createPublicKey, diffieHellman, generateKeyPairSync, hkdfSync, randomBytes, randomUUID } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import assert from 'node:assert/strict';
import { handoffVectors } from '../../../scripts/setup-handoff-vectors.mjs';

const host = process.env.ROKU_HOST, password = process.env.ROKU_DEV_PASSWORD;
assert.ok(host && password, 'device environment required');
const restore = process.env.ROKU_RESTORE_ZIP ?? 'out/native-parity-normal.zip';
assert.ok(createHash('sha256').update(readFileSync(restore)).digest('hex') === 'eb09f4b9705262d11efba05a7b27281ff6272f2b22ff0f003805d9e20224a610', 'verified normal restore ZIP required');
const temporary = '/private/var/folders/qc/4lbpvxwj7pn5_675mjffljrr0000gn/T/opencode';
const expiryOnly = process.argv.includes('--expiry-only');
const productionEntropy = process.argv.includes('--production-entropy');
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
  assert.ok(/Install Success|Identical/.test(response), 'installer success');
  return /Identical/.test(response);
}
const events = [], results = [], seenKeys = new Set();
let consoleProcess, connected = false, armed = false, closing = false, pending = '', error, resetCounter = 0;
async function wait(kind, after = 0, timeout = 30000) {
  const start = performance.now();
  while (performance.now() - start < timeout) {
    if (error) throw Error(error);
    const row = events.slice(after).find(row => row.kind === kind);
    if (row) return row;
    await delay(25);
  }
  throw Error(`Native experiment timed out waiting for ${kind}`);
}
function pass(id, extra = {}) { results.push({ id, passed: true, ...extra }); console.log(`${id}: passed`); }
async function qr(ready) {
  await delay(1200);
  const image = `${temporary}/devicecrypto-experiment-${randomUUID()}.jpg`;
  try {
    curl(['--digest', '--config', '-', '--fail', '-F', 'mysubmit=Screenshot', `http://${host}/plugin_inspect`], true);
    curl(['--digest', '--config', '-', '--fail', '-o', image, `http://${host}/pkgs/dev.jpg`], true);
    const decode = spawnSync('swift', ['-module-cache-path', `${temporary}/setup-swift-cache`, 'scripts/read-setup-probe-qr.swift', image], { encoding: 'utf8', timeout: 60000 });
    assert.ok(decode.status === 0, 'QR decodes');
    const link = new URL(decode.stdout.trim());
    assert.ok(link.protocol === 'aeriotv:' && link.hostname === 'setup', 'wire-v1 QR');
    assert.ok(link.searchParams.get('ip') === host && Number(link.searchParams.get('port')) === ready.port, 'QR targets active listener');
    assert.ok(link.searchParams.get('v') === '1', 'QR version');
    const code = link.searchParams.get('code');
    const pk = Buffer.from(link.searchParams.get('pk'), 'base64url');
    assert.ok(/^\d{6}$/.test(code) && pk.length === 32, 'generated code/public-key shape');
    let fingerprintValue = parseInt(createHash('sha256').update(pk).digest('hex').slice(0, 5), 16);
    const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    let fingerprint = '';
    for (let i = 3; i >= 0; i--) fingerprint += alphabet[Math.floor(fingerprintValue / (32 ** i)) % 32];
    assert.ok(fingerprint === ready.fingerprint, 'captured QR matches current key fingerprint');
    const hex = pk.toString('hex');
    assert.ok(!seenKeys.has(hex), 'new session must not reuse the public key');
    seenKeys.add(hex);
    return { code, pk, port: ready.port };
  } finally {
    try { unlinkSync(image); } catch {}
  }
}
async function reset() {
  const after = events.length;
  ecp(`input?setupProbeReset=${++resetCounter}`);
  return qr(await wait('ready', after));
}
function seal(session, payload, wrongCode = false) {
  const phone = generateKeyPairSync('x25519');
  const phonePk = phone.publicKey.export({ type: 'spki', format: 'der' }).subarray(-32);
  const publicKey = createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b656e032100', 'hex'), session.pk]), type: 'spki', format: 'der' });
  const shared = diffieHellman({ privateKey: phone.privateKey, publicKey });
  const code = wrongCode ? String((Number(session.code) + 1) % 1000000).padStart(6, '0') : session.code;
  const info = Buffer.concat([Buffer.from('aeriotv-setup-v1'), phonePk, session.pk]);
  const key = Buffer.from(hkdfSync('sha256', shared, Buffer.from(code), info, 32));
  const nonce = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  const sealed = Buffer.concat([cipher.update(Buffer.isBuffer(payload) ? payload : Buffer.from(JSON.stringify(payload))), cipher.final(), cipher.getAuthTag()]);
  key.fill(0); shared.fill(0);
  return JSON.stringify({ v: 1, phonePk: phonePk.toString('base64'), nonce: nonce.toString('base64'), ciphertext: sealed.toString('base64') });
}
async function request(session, body, headers = []) {
  const start = performance.now();
  return await new Promise((resolve, reject) => {
    const child = spawn('curl', ['--noproxy', '*', '--silent', '--show-error', '--connect-timeout', '2', '--max-time', '20', '-H', 'Expect:', '-H', 'Content-Type: application/json', ...headers.flatMap(value => ['-H', value]), '--data-binary', '@-', '--write-out', '\n%{http_code}', `http://${host}:${session.port}/setup`], { stdio: ['pipe', 'pipe', 'pipe'] });
    const chunks = [];
    child.stdout.on('data', chunk => chunks.push(chunk));
    child.stderr.resume();
    child.on('error', () => reject(Error('Request client failed')));
    child.on('close', code => {
      const text = Buffer.concat(chunks).toString('utf8');
      const split = text.lastIndexOf('\n');
      const status = Number(text.slice(split + 1));
      if (code !== 0 && ![7, 52, 56].includes(code)) return reject(Error('Request transport failed'));
      resolve({ status: status || null, body: text.slice(0, split), elapsedMs: Math.round(performance.now() - start) });
    });
    child.stdin.on('error', () => {});
    child.stdin.end(body);
  });
}
async function check(session, body, status, errorName, headers = []) {
  const response = await request(session, body, headers);
  if (response.status !== status) console.log(JSON.stringify({ diagnostic: 'unexpected-status', expected: status, actual: response.status, elapsedMs: response.elapsedMs, error: (() => { try { return JSON.parse(response.body).error; } catch { return 'non-json'; } })() }));
  assert.ok(response.status === status, 'expected setup HTTP status');
  assert.ok(response.elapsedMs < 10000, 'ten-second response budget');
  const reply = JSON.parse(response.body);
  assert.ok(status === 200 ? reply.ok === true : reply.ok === false && reply.error === errorName, 'expected setup reply');
  return response;
}
try {
  ecp('keypress/Home');
  await delay(1000);
  consoleProcess = spawn('curl', ['--noproxy', '*', '--no-buffer', '--verbose', '--connect-timeout', '5', `telnet://${host}:8085`], { stdio: ['pipe', 'pipe', 'pipe'] });
  consoleProcess.stdin.end();
  consoleProcess.stderr.on('data', chunk => { if (chunk.toString().includes('Connected to')) connected = true; });
  consoleProcess.on('error', () => { error = 'Console connection failed'; });
  consoleProcess.on('exit', () => { if (!closing) error = 'Console connection ended'; });
  consoleProcess.stdout.on('data', chunk => {
    if (!armed) return;
    pending += chunk;
    const lines = pending.split('\n'); pending = lines.pop();
    for (const line of lines) {
      if (/ERROR:|error &h|Syntax Error|BrightScript Micro Debugger/i.test(line) && !/ERROR: ParseJSON:/i.test(line)) error = 'Native compiler/runtime failure';
      const prefix = '[setup-receiver] ';
      const index = line.indexOf(prefix);
      if (index >= 0) {
        try {
          const row = JSON.parse(line.slice(index + prefix.length).trim());
          events.push(row);
          if (row.kind === 'key_encoding') console.log(JSON.stringify({ diagnostic: 'private-key-encoding', lowercase: row.lowercase }));
        }
        catch { error = 'Malformed native experiment event'; }
      }
    }
  });
  const connecting = performance.now();
  while (!connected && performance.now() - connecting < 7000) { if (error) throw Error(error); await delay(25); }
  assert.ok(connected, 'console available before install');
  await delay(1000);
  armed = true;
  const probe = productionEntropy ? 'out/setup-receiver-production-entropy-probe.zip' : 'out/devicecrypto-receiver-experiment.zip';
  if (install(probe)) ecp('launch/dev');
  if (productionEntropy) {
    await wait('unavailable');
    await delay(1000);
    assert.ok(!events.some(row => ['ready', 'payload'].includes(row.kind)), 'production source must remain fail-closed');
    pass('production-source-still-fails-closed');
  } else if (expiryOnly) {
    const session = await qr(await wait('ready'));
    const started = performance.now();
    await wait('task_expired', 0, 615000);
    assert.ok(performance.now() - started >= 590000, 'real ten-minute lifetime');
    assert.ok((await request(session, '{}')).status === null, 'expiry closes listener');
    assert.ok(!events.some(row => row.kind === 'payload'), 'no expired payload');
    pass('device-key-source-real-ten-minute-expiry');
  } else {
    let session = await qr(await wait('ready'));
    for (const [index, fixture] of handoffVectors().entries()) {
      if (index > 0) session = await reset();
      const after = events.length;
      const body = seal(session, JSON.parse(fixture.plaintext));
      const response = await check(session, body, 200);
      await wait('payload', after);
      assert.ok((await request(session, body)).status === null, 'one success closes listener and refuses replay');
      pass(`device-key-live-${fixture.id.replace(/-(000123|483920)$/, '')}`, { replyMs: response.elapsedMs });
    }
    session = await reset();
    const basic = JSON.parse(handoffVectors()[0].plaintext);
    let after = events.length;
    await check(session, seal(session, basic), 403, 'forbidden', ['Origin: https://example.test']);
    await check(session, '{', 400, 'bad_request');
    await check(session, seal(session, Buffer.from([255])), 400, 'bad_request');
    assert.ok(!events.slice(after).some(row => row.kind === 'payload'), 'rejections never publish a payload');
    pass('device-key-live-origin-malformed-and-utf8-rejection');
    for (let attempt = 0; attempt < 3; attempt++) await check(session, seal(session, basic, true), 403, 'wrong_code');
    const rotatedReady = await wait('ready', after);
    const rotated = await qr(rotatedReady);
    assert.ok(rotated.port === session.port && !rotated.pk.equals(session.pk), 'rotation uses fresh material on same listener');
    await check(rotated, seal(session, basic), 403, 'wrong_code');
    after = events.length;
    const response = await check(rotated, seal(rotated, basic), 200);
    await wait('payload', after);
    pass('device-key-live-three-attempt-rotation-and-new-key-acceptance', { replyMs: response.elapsedMs });
    session = await reset();
    after = events.length;
    const pendingRequest = request(session, seal(session, basic));
    await delay(700);
    ecp('keypress/Back');
    await wait('cancelled', after);
    assert.ok((await pendingRequest).status === null, 'crypto cancellation never succeeds');
    assert.ok(!events.slice(after).some(row => row.kind === 'payload'), 'crypto cancellation publishes nothing');
    assert.ok((await request(session, '{}')).status === null, 'cancel closes listener');
    pass('device-key-live-cancel-during-x25519');
  }
  const mode = productionEntropy ? 'production-gate' : expiryOnly ? 'expiry' : 'transfer';
  writeFileSync(`out/devicecrypto-receiver-${mode}-results.json`, JSON.stringify({ passed: true, experimentalSource: !productionEntropy, shippingApproval: false, distinctPublicKeys: seenKeys.size, results }, null, 2) + '\n');
} finally {
  closing = true;
  consoleProcess?.kill('SIGTERM');
  install(restore);
  console.log('Verified normal app ZIP restored');
}
