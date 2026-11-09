// All inputs are synthetic. No production credential or entropy generation.
import { createPrivateKey, createPublicKey, diffieHellman, hkdfSync, createCipheriv } from 'node:crypto';
import { x25519Vectors } from './setup-x25519-vectors.mjs';

const rfc = x25519Vectors();
export const tvPublic = rfc.find(row => row.id === 'rfc-bob-public').expected;
export const rotatedPublic = '130388590da57cdc0c70608a494e46cd8154abe7d731a6a224e49fa05f9d1206';
const phone = rfc.find(row => row.id === 'rfc-alice-public');
export const basicPayload = { playlist: { type: 'm3u', name: 'Synthetic', url: 'https://m3u.example.test/a.m3u' } };

export function sealFixture(payload = basicPayload, { code = '000123', publicHex = tvPublic } = {}) {
  const privateKey = createPrivateKey({ key: Buffer.from('302e020100300506032b656e04220420' + phone.secret, 'hex'), format: 'der', type: 'pkcs8' });
  const publicKey = createPublicKey({ key: Buffer.from('302a300506032b656e032100' + publicHex, 'hex'), format: 'der', type: 'spki' });
  const shared = diffieHellman({ privateKey, publicKey });
  const phonePk = Buffer.from(phone.expected, 'hex');
  const info = Buffer.concat([Buffer.from('aeriotv-setup-v1'), phonePk, Buffer.from(publicHex, 'hex')]);
  const key = Buffer.from(hkdfSync('sha256', shared, Buffer.from(code), info, 32));
  const nonce = Buffer.from(Array.from({ length: 12 }, (_, i) => i + 128));
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  const plaintext = Buffer.isBuffer(payload) ? payload : Buffer.from(JSON.stringify(payload));
  const sealed = Buffer.concat([cipher.update(plaintext), cipher.final(), cipher.getAuthTag()]);
  return JSON.stringify({ v: 1, phonePk: phonePk.toString('base64'), nonce: nonce.toString('base64'), ciphertext: sealed.toString('base64') });
}

export function malformedEnvelopes() {
  const valid = JSON.parse(sealFixture());
  return [
    ['not-json', 'not json'], ['top-level-array', '[]'], ['empty-object', '{}'],
    ['version-string', JSON.stringify({ ...valid, v: '1' })],
    ['version-two', JSON.stringify({ ...valid, v: 2 })],
    ['missing-version', JSON.stringify({ ...valid, v: undefined })],
    ['missing-nonce', JSON.stringify({ ...valid, nonce: undefined })],
    ['short-nonce', JSON.stringify({ ...valid, nonce: 'AA==' })],
    ['short-key', JSON.stringify({ ...valid, phonePk: 'AA==' })],
    ['bad-base64', JSON.stringify({ ...valid, ciphertext: '!!!not base64!!!' })],
    ['tag-only', JSON.stringify({ ...valid, ciphertext: Buffer.alloc(16).toString('base64') })],
  ];
}

export function malformedPayloads() {
  const playlist = basicPayload.playlist;
  return [
    ['not-json', Buffer.from('not json')], ['top-level-array', []], ['missing-playlist', {}],
    ['missing-url', { playlist: { type: 'm3u', name: 'Synthetic' } }],
    ['unknown-type', { playlist: { ...playlist, type: 'plex' } }],
    ['empty-url', { playlist: { ...playlist, url: '' } }],
    ['guide-string', { playlist: { ...playlist, guideDays: '7' } }],
    ['guide-out-of-range', { playlist: { ...playlist, guideDays: 99 } }],
    ['profiles-object', { playlist, profiles: {} }],
    ['not-utf8', Buffer.concat([Buffer.from('{"playlist":{"type":"m3u","name":"'), Buffer.from([255]), Buffer.from('","url":"https://m3u.example.test/a"}}')])],
    ['raw-nul-after-json', Buffer.concat([Buffer.from(JSON.stringify(basicPayload)), Buffer.from([0])])],
  ];
}

export function wrongCodeEnvelopes() {
  const valid = JSON.parse(sealFixture());
  const sealed = Buffer.from(valid.ciphertext, 'base64');
  const changedTag = Buffer.from(sealed); changedTag[changedTag.length - 1] ^= 1;
  const changedCiphertext = Buffer.from(sealed); changedCiphertext[0] ^= 1;
  const nonce = Buffer.from(valid.nonce, 'base64'); nonce[0] ^= 1;
  return [
    ['wrong-code', sealFixture(basicPayload, { code: '000124' })],
    ['changed-tag', JSON.stringify({ ...valid, ciphertext: changedTag.toString('base64') })],
    ['changed-ciphertext', JSON.stringify({ ...valid, ciphertext: changedCiphertext.toString('base64') })],
    ['changed-nonce', JSON.stringify({ ...valid, nonce: nonce.toString('base64') })],
    ['missing-tag', JSON.stringify({ ...valid, ciphertext: sealed.subarray(0, -16).toString('base64') })],
    ['truncated-tag', JSON.stringify({ ...valid, ciphertext: sealed.subarray(0, -1).toString('base64') })],
  ];
}
