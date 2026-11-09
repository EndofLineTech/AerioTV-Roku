// Authorized synthetic LAN acceptance only; always restores the normal ZIP.
import net from 'node:net';
import { spawnSync } from 'node:child_process';
import { existsSync, writeFileSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { handoffVectors } from './setup-handoff-vectors.mjs';
import { sealFixture, tvPublic, rotatedPublic, basicPayload, malformedEnvelopes, malformedPayloads, wrongCodeEnvelopes } from './setup-receiver-cases.mjs';

const host = process.env.ROKU_HOST;
const password = process.env.ROKU_DEV_PASSWORD;
const restore = process.argv[2];
const productionEntropy = process.argv.includes('--production-entropy');
const expiryOnly = process.argv.includes('--expiry-only');
if (!host || !password || !restore || !existsSync(restore)) throw Error('Supply developer environment and verified normal ZIP');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function curl(args, auth = false) {
  const result = spawnSync('curl', ['--noproxy', '*', '--max-time', '40', '-sS', ...args], {
    encoding: 'utf8', input: auth ? `user = ${JSON.stringify(`rokudev:${password}`)}\n` : undefined,
  });
  if (result.status !== 0) throw Error('Device HTTP failed');
  return result.stdout;
}
function install(path) {
  const body = curl(['--digest', '--config', '-', '-H', 'Expect: 100-continue', '-F', 'mysubmit=Install', '-F', `archive=@${path}`, `http://${host}/plugin_install`], true);
  if (!/Install Success|Identical/.test(body)) throw Error('Installer did not report success');
  return /Identical/.test(body);
}
function ecp(path) { curl(['--fail', '-X', 'POST', `http://${host}:8060/${path}`]); }
const events = [];
let consoleSocket, armed = false, pending = '', consoleError;
const results = [];
async function waitEvent(kind, after = 0, timeout = 30000) {
  const started = performance.now();
  while (performance.now() - started < timeout) {
    if (consoleError) throw Error(consoleError);
    const event = events.slice(after).find(row => row.kind === kind);
    if (event) return event;
    await delay(25);
  }
  throw Error(`Receiver did not report ${kind}`);
}
let port, resetCounter = 0;
async function reset() {
  const after = events.length;
  ecp(`input?setupProbeReset=${++resetCounter}`);
  const ready = await waitEvent('ready', after);
  assert.equal(ready.fingerprint, 'YFH7');
  port = ready.port;
}
async function checkQr() {
  await delay(1000); // Let the render thread finish the module rectangles.
  const capture = spawnSync('python3', ['scripts/capture-roku-screenshot.py', '--developer-mode', '--output', 'out/setup-receiver-native.jpg'], { encoding: 'utf8' });
  assert.equal(capture.status, 0, 'synthetic QR screenshot captured without policy changes');
  const decode = spawnSync('swift', ['-module-cache-path', join(process.env.OPENCODE_TMP_DIR ?? tmpdir(), 'setup-swift-cache'),
    'scripts/read-setup-probe-qr.swift', 'out/setup-receiver-native.jpg'], { encoding: 'utf8', timeout: 60000 });
  assert.equal(decode.status, 0, 'native QR screenshot decodes offline');
  const link = new URL(decode.stdout.trim());
  assert.equal(link.protocol, 'aeriotv:');
  assert.equal(link.hostname, 'setup');
  assert.equal(link.searchParams.get('v'), '1');
  assert.equal(link.searchParams.get('ip'), host);
  assert.equal(Number(link.searchParams.get('port')), port);
  assert.equal(link.searchParams.get('code'), '000123');
  assert.equal(Buffer.from(link.searchParams.get('pk'), 'base64url').toString('hex'), tvPublic);
  assert.ok([...link.searchParams.get('name')].length <= 60 && Buffer.byteLength(link.searchParams.get('name')) <= 63);
  results.push({ id: 'native-qr-scan', passed: true });
  console.log('Native on-screen QR decoded and matched the active session');
}
async function request({ method = 'POST', path = '/setup', body = '{}', headers = {}, omitLength = false, fragment = false, declaredLength, headOverride } = {}) {
  const encoded = Buffer.isBuffer(body) ? body : Buffer.from(body);
  const lines = [`${method} ${path} HTTP/1.1`, `Host: ${host}`, 'Content-Type: application/json'];
  for (const [name, value] of Object.entries(headers)) lines.push(`${name}: ${value}`);
  if (!omitLength) lines.push(`Content-Length: ${declaredLength ?? encoded.length}`);
  const head = headOverride ? Buffer.from(headOverride) : Buffer.from(lines.join('\r\n') + '\r\n\r\n');
  return await new Promise((resolve, reject) => {
    const socket = net.connect({ host, port });
    const chunks = [];
    let sentAt = performance.now();
    socket.setTimeout(18000, () => socket.destroy(Error('Setup response timed out')));
    socket.on('error', error => {
      if (error.code === 'ECONNREFUSED') resolve({ status: null, body: '', elapsedMs: 0 });
      else if (error.code === 'EPIPE' || error.code === 'ECONNRESET') return;
      else reject(error);
    });
    socket.on('data', chunk => chunks.push(chunk));
    socket.on('close', () => {
      try {
      const response = Buffer.concat(chunks).toString('utf8');
      if (!response) { resolve({ status: null, body: '', elapsedMs: performance.now() - sentAt }); return; }
      const split = response.indexOf('\r\n\r\n');
      assert.ok(split >= 0, 'complete response head');
      const head = response.slice(0, split);
      const body = response.slice(split + 4);
      const length = Number(/content-length:\s*(\d+)/i.exec(head)?.[1]);
      assert.equal(Buffer.byteLength(body), length, 'full declared response received before close');
      assert.match(head, /content-type: application\/json/i);
      assert.match(head, /connection: close/i);
      resolve({ status: Number(/^HTTP\/1.1 (\d+)/.exec(head)?.[1]), body, elapsedMs: performance.now() - sentAt });
      } catch (error) { reject(error); }
    });
    socket.on('connect', async () => {
      if (fragment) {
        socket.write(head.subarray(0, 9));
        await delay(50);
        socket.write(head.subarray(9));
        for (let i = 0; i < encoded.length; i += 4096) {
          if (socket.destroyed) break;
          socket.write(encoded.subarray(i, i + 4096));
          if (i + 4096 < encoded.length) await delay(10);
        }
      } else {
        socket.write(head);
        if (encoded.length) socket.write(encoded);
      }
      sentAt = performance.now();
    });
  });
}
async function check(id, requestOptions, status, error) {
  const response = await request(requestOptions);
  assert.equal(response.status, status, id);
  const expected = status === 200 ? { ok: true } : { ok: false, error };
  assert.deepEqual(JSON.parse(response.body), expected, id);
  assert.ok(response.elapsedMs < 10000, `${id}: ten-second response budget`);
  results.push({ id, status, elapsedMs: Math.round(response.elapsedMs) });
  console.log(`${id}: HTTP ${status}, ${Math.round(response.elapsedMs)} ms`);
}

async function incompleteRequest(id, bytes) {
  const started = performance.now();
  const after = events.length;
  await new Promise((resolve, reject) => {
    const socket = net.connect({ host, port });
    socket.setTimeout(18000, () => socket.destroy(Error('Idle connection was not closed')));
    socket.on('connect', () => socket.write(bytes));
    socket.on('data', () => reject(Error('Incomplete request must not be accepted')));
    socket.on('error', reject);
    socket.on('close', resolve);
  });
  assert.ok(performance.now() - started < 18000, id);
  assert.ok(!events.slice(after).some(row => row.kind === 'payload'), 'incomplete request never publishes payload');
  results.push({ id, passed: true });
  console.log(`${id}: closed without applying`);
}

try {
  ecp('keypress/Home');
  await delay(1000);
  consoleSocket = net.connect({ host, port: 8085 });
  consoleSocket.on('error', () => { consoleError = 'Console connection failed'; });
  consoleSocket.on('data', chunk => {
    if (!armed) return;
    pending += chunk;
    const lines = pending.split('\n'); pending = lines.pop();
    for (const line of lines) {
      if (/ERROR:|error &h|Syntax Error/.test(line) && !/ERROR: ParseJSON:/.test(line)) consoleError = 'Native compiler/runtime error';
      const marker = line.indexOf('[setup-receiver] ');
      if (marker >= 0) {
        try { events.push(JSON.parse(line.slice(marker + 17).trim())); }
        catch { consoleError = 'Malformed receiver event'; }
      }
    }
  });
  await delay(1500);
  armed = true;
  const probe = productionEntropy ? 'out/setup-receiver-production-entropy-probe.zip' : 'out/setup-receiver-probe.zip';
  if (install(probe)) ecp('launch/dev');
  if (productionEntropy) {
    await waitEvent('unavailable');
    await delay(1000);
    assert.ok(!events.some(row => row.kind === 'ready' || row.kind === 'payload'), 'production entropy cannot create a live setup session');
    results.push({ id: 'production-entropy-fail-closed', passed: true });
    console.log('Production entropy provider refused setup; no session advertised');
  } else {
  const ready = await waitEvent('ready');
  assert.equal(ready.fingerprint, 'YFH7');
  port = ready.port;
  await checkQr();
  if (!expiryOnly) {
  await check('wrong-path-precedes-origin', { path: '/Setup', headers: { ORIGIN: '' } }, 404, 'bad_request');
  await check('empty-origin', { headers: { origin: '' } }, 403, 'forbidden');
  await check('missing-length', { omitLength: true }, 400, 'bad_request');
  await check('oversized-before-body', { declaredLength: 262145, body: '' }, 413, 'too_large');
  await check('wrong-method', { method: 'GET', body: '' }, 404, 'bad_request');
  await check('transfer-encoding', { headers: { 'Transfer-Encoding': 'chunked' }, omitLength: true, body: '2\r\n{}\r\n0\r\n\r\n' }, 400, 'bad_request');
  await check('duplicate-length', { headers: { 'content-length': '2' } }, 400, 'bad_request');
  await check('invalid-length', { declaredLength: '-1', body: '' }, 400, 'bad_request');
  await check('unterminated-head-limit', { headOverride: 'x'.repeat(32769), body: '' }, 400, 'bad_request');
  for (const [id, body] of malformedEnvelopes()) await check(`envelope-${id}`, { body }, 400, 'bad_request');
  for (const [id, payload] of malformedPayloads()) await check(`payload-${id}`, { body: sealFixture(payload) }, 400, 'bad_request');
  const zero = JSON.parse(sealFixture()); zero.phonePk = Buffer.alloc(32).toString('base64');
  await check('all-zero-shared-secret', { body: JSON.stringify(zero) }, 400, 'bad_request');
  const positives = handoffVectors();
  for (let i = 0; i < positives.length; i++) {
    if (i) await reset();
    const after = events.length;
    const body = sealFixture(JSON.parse(positives[i].plaintext));
    await check(positives[i].id, { body, fragment: true }, 200);
    await waitEvent('payload', after);
    const replay = await request({ body });
    assert.ok(replay.status === null || replay.status === 403, 'one success per code');
  }
  await reset();
  await check('null-optionals', { body: sealFixture({ playlist: { ...basicPayload.playlist, xmltvUrl: null, guideDays: null }, sync: null }) }, 200);
  await reset();
  const urlEnvelope = JSON.parse(sealFixture());
  for (const field of ['phonePk', 'nonce', 'ciphertext']) urlEnvelope[field] = Buffer.from(urlEnvelope[field], 'base64').toString('base64url');
  await check('base64url-unpadded', { body: JSON.stringify(urlEnvelope) }, 200);
  await reset();
  const valid = sealFixture();
  await check('exact-body-limit-fragmented', { body: valid.padEnd(262144, ' '), fragment: true }, 200);
  for (const [id, body] of wrongCodeEnvelopes()) {
    await reset();
    await check(id, { body }, 403, 'wrong_code');
  }
  // 400 and forbidden replies must neither reset nor increment the failures.
  await reset();
  const wrong = sealFixture(basicPayload, { code: '000124' });
  await check('sequence-wrong-one', { body: wrong }, 403, 'wrong_code');
  await check('sequence-bad-between', { body: '{}' }, 400, 'bad_request');
  await check('sequence-wrong-two', { body: wrong }, 403, 'wrong_code');
  await check('sequence-origin-between', { headers: { ORIGIN: '' } }, 403, 'forbidden');
  const rotationStart = events.length;
  await check('sequence-wrong-three', { body: wrong }, 403, 'wrong_code');
  const rotated = await waitEvent('ready', rotationStart);
  assert.equal(rotated.port, port, 'rotation preserves listener port');
  assert.equal(rotated.fingerprint, 'YY3R', 'rotation installs the new key');
  await check('stale-key-after-rotation', { body: valid }, 403, 'wrong_code');
  await check('rotated-key-success', { body: sealFixture(basicPayload, { code: '483920', publicHex: rotatedPublic }) }, 200);
  await reset();
  await incompleteRequest('idle-partial-head', 'POST /setup HTTP/1.1\r\nContent-Len');
  await incompleteRequest('idle-partial-body', 'POST /setup HTTP/1.1\r\nContent-Length: 100\r\n\r\n{');
  // A valid request after both idle disconnects proves they did not consume it.
  await check('valid-after-idle-disconnects', { body: valid }, 200);
  await reset();
  const cancelStart = events.length;
  const cancelledResponse = request({ body: valid });
  await delay(700); // Native ladder is still running; cancellation is cooperative.
  ecp('keypress/Back');
  await waitEvent('cancelled', cancelStart);
  const cancelled = await cancelledResponse;
  assert.equal(cancelled.status, null, 'cancelled crypto never returns success');
  await delay(500);
  assert.ok(!events.slice(cancelStart).some(row => row.kind === 'payload'), 'cancel never publishes payload');
  assert.equal((await request({ body: valid })).status, null, 'cancel closes listener');
  results.push({ id: 'cancel-during-crypto', passed: true });
  console.log('Cancellation during crypto closed the listener without applying');
  }
  if (process.argv.includes('--expiry') || expiryOnly) {
    if (!expiryOnly) await reset();
    const expiryStart = events.length;
    const started = performance.now();
    await waitEvent('task_expired', expiryStart, 615000);
    assert.ok(performance.now() - started >= 590000, 'real ten-minute lifetime, not an accelerated fixture');
    assert.equal((await request({ body: sealFixture() })).status, null, 'expiry closes listener even if the render thread is paused');
    // Wake a public screensaver, if one is active, without accepting/retrying.
    // No screensaver settings are changed and no synthetic keepalive is sent.
    ecp('keypress/Right');
    await waitEvent('expired', expiryStart);
    assert.ok(!events.slice(expiryStart).some(row => row.kind === 'payload'));
    results.push({ id: 'ten-minute-expiry', passed: true });
    console.log('Ten-minute session expired and closed the listener');
  }
  }
  const evidence = productionEntropy ? 'out/setup-receiver-production-entropy-results.json'
    : expiryOnly ? 'out/setup-receiver-expiry-results.json' : 'out/setup-receiver-native-results.json';
  writeFileSync(evidence, JSON.stringify({ passed: true, results }, null, 2) + '\n');
} finally {
  consoleSocket?.destroy();
  install(restore);
  console.log('Normal app restored');
}
