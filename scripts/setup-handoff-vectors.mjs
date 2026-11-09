// Synthetic Appendix C payload shapes. Re-sealed independently with Node crypto;
// the minimal M3U envelope and both HKDF values are pinned to the supplied handoff.
import { createCipheriv, createHmac, hkdfSync } from 'node:crypto';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { x25519Vectors } from './setup-x25519-vectors.mjs';

function sorted(value) {
  if (Array.isArray(value)) return value.map(sorted);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, sorted(value[key])]));
  return value;
}

export function handoffVectors() {
  const rfc = x25519Vectors();
  const tv = rfc.find(row => row.id === 'rfc-bob-public');
  const phone = rfc.find(row => row.id === 'rfc-alice-public');
  const shared = Buffer.from(rfc.find(row => row.id === 'rfc-bob-shared').expected, 'hex');
  const tvPk = Buffer.from(tv.expected, 'hex');
  const phonePk = Buffer.from(phone.expected, 'hex');
  const info = Buffer.concat([Buffer.from('aeriotv-setup-v1'), phonePk, tvPk]);
  const dispatcharr = { type: 'dispatcharr', name: 'Home Server', url: 'https://dispatcharr.example.test',
    guideDays: 7, catchupOffsetMinutes: 0, vodEnabled: true, channelProfileIds: [2] };
  const sam = { username: 'sam', displayName: 'Sam', role: 'user', isDefault: true, order: 0, pinType: 'none', pinHash: '', pinSalt: '' };
  const inputs = [
    { id: 'm3u-basic-000123', code: '000123', nonceStart: 0,
      payload: { playlist: { type: 'm3u', name: 'Home', url: 'http://192.168.1.10/a.m3u' } } },
    { id: 'dispatcharr-full-000123', code: '000123', nonceStart: 16, payload: {
      playlist: { ...dispatcharr, localUrl: 'http://192.0.2.10:9191', credential: { apiKey: 'synthetic-api-key-alex-0001', username: 'alex' } },
      profiles: [
        { username: 'alex', displayName: 'Alex', role: 'admin', isDefault: true, order: 0, avatar: { icon: 'initial', color: '' },
          pinType: 'numbers', pinHash: 'bad0b4f7cae08eb7c1b5acc763a8ed25242e2c9173e81f3f624b1fa5303cf6ce', pinSalt: '000102030405060708090a0b0c0d0e0f' },
        { ...sam, isDefault: false, order: 1, credential: { apiKey: 'synthetic-api-key-sam-0002' } },
        { username: 'kid', displayName: 'Kid', role: 'child', isDefault: false, order: 2, avatar: { icon: 'star', color: 'blue' },
          credential: { password: 'synthetic-password-kid' }, pinType: 'directions',
          pinHash: '7c56fef64e9d71e9d37d4c5b03a6caf9ee114920bac24a1b9977d415c1fd387e', pinSalt: '101112131415161718191a1b1c1d1e1f' },
      ], sync: { provider: 'dispatcharr', enabled: true },
    } },
    { id: 'dispatcharr-user-only-483920', code: '483920', nonceStart: 32, payload: {
      playlist: { ...dispatcharr, credential: { apiKey: 'synthetic-api-key-sam-0002', username: 'sam' } }, profiles: [sam],
    } },
    { id: 'xtream-483920', code: '483920', nonceStart: 48, payload: { playlist: {
      type: 'xtream', name: 'Xtream Example', url: 'http://xtream.example.test:8080',
      xmltvUrl: 'http://xtream.example.test:8080/xmltv.php', guideDays: 3, catchupOffsetMinutes: -60,
      vodEnabled: true, channelProfileIds: [], credential: { username: 'synthetic-user', password: 'synthetic-pass' },
    }, profiles: [] } },
    { id: 'm3u-483920', code: '483920', nonceStart: 64, payload: { playlist: {
      type: 'm3u', name: 'M3U Example', url: 'https://m3u.example.test/playlist.m3u?token=synthetic',
      xmltvUrl: 'https://m3u.example.test/guide.xml', userAgent: 'AerioTV-Fixture/1.0',
      guideDays: 0, catchupOffsetMinutes: 0, vodEnabled: false, channelProfileIds: [],
    }, profiles: [] } },
    { id: 'dispatcharr-user-only-apikey-483920', code: '483920', nonceStart: 112, payload: {
      playlist: { ...dispatcharr, credential: { apiKey: 'synthetic-api-key-sam-0002' } }, profiles: [sam],
    } },
  ];
  return inputs.map((row, index) => {
    const plaintext = JSON.stringify(index ? sorted(row.payload) : row.payload);
    const nonce = Buffer.from(Array.from({ length: 12 }, (_, i) => row.nonceStart + i));
    const prk = createHmac('sha256', row.code).update(shared).digest('hex');
    const key = Buffer.from(hkdfSync('sha256', shared, Buffer.from(row.code), info, 32));
    assert.equal(prk, row.code === '000123' ? 'efd3b5160a8c29616f5707840b0890a8d886a4a1eb49102e2d9107fb6f8e3ffd' : 'af0a44f086e72cc659abe1aebb9842a4af0025ca8ab81bb2aac2a28c9ba5424c');
    assert.equal(key.toString('hex'), row.code === '000123' ? 'c67b44c2c172f055781e716e52be98878d7263f336282f8951ce15527cc768d9' : '2df5d76d03e91ce6bcd560758d6e236d7b31a5d392affcb03c12b3c37b64cea9');
    const cipher = createCipheriv('aes-256-gcm', key, nonce);
    const sealed = Buffer.concat([cipher.update(plaintext), cipher.final(), cipher.getAuthTag()]);
    if (!index) assert.equal(sealed.toString('base64'), '2aMyFJI7VyZn4Jnwrh3Aos9ub2bz6IoMX0s8drjVe8/0S0HKVbDAjTuoJoR1DgPym9RjbIon2CrVS/Io9kgpsh6jJhOF25i2U2mVW9brAj7K7s57TrrgFa9hWw==');
    return { id: row.id, secret: tv.secret, tvPublicHex: tv.expected, code: row.code, prkHex: prk,
      keyHex: key.toString('hex'), plaintext, envelopeJson: JSON.stringify({ v: 1, phonePk: phonePk.toString('base64'), nonce: nonce.toString('base64'), ciphertext: sealed.toString('base64') }) };
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) console.log(JSON.stringify(handoffVectors()));
