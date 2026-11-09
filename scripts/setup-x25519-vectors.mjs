// Synthetic public RFC inputs and deterministic test labels only. Not key generation.
import { createHash, createPrivateKey, createPublicKey, diffieHellman } from 'node:crypto';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';

const privatePrefix = Buffer.from('302e020100300506032b656e04220420', 'hex');
const publicPrefix = Buffer.from('302a300506032b656e032100', 'hex');
const alice = '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a';
const bob = '5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb';
const alicePk = '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a';
const bobPk = 'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f';
const shared = '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742';
const base = '09' + '00'.repeat(31);

export function x25519Vectors() {
  const vectors = [];
  function add(id, secret, peer, expected) {
    const privateKey = createPrivateKey({ key: Buffer.concat([privatePrefix, Buffer.from(secret, 'hex')]), format: 'der', type: 'pkcs8' });
    const publicKey = createPublicKey({ key: Buffer.concat([publicPrefix, Buffer.from(peer, 'hex')]), format: 'der', type: 'spki' });
    const actual = diffieHellman({ privateKey, publicKey }).toString('hex');
    if (expected) assert.equal(actual, expected, id);
    vectors.push({ id, secret, peer, expected: actual });
  }
  add('rfc-alice-public', alice, base, alicePk);
  add('rfc-bob-public', bob, base, bobPk);
  add('rfc-bob-shared', bob, alicePk, shared);
  add('rfc-alice-shared', alice, bobPk, shared);
  // RFC 7748 section 5.2 scalar/u pair, not just base-point multiplication.
  add('rfc-scalar-u', 'a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4',
    'e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c',
    'c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552');
  add('rfc-masked-peer-high-bit', bob, alicePk.slice(0, 62) + 'ea', shared);
  add('rfc-noncanonical-base-p-plus-9', alice, 'f6' + 'ff'.repeat(30) + '7f', alicePk);
  for (let i = 0; i < 3; i++) {
    const secret = createHash('sha256').update(`aeriotv-synthetic-scalar-${i}`).digest('hex');
    const peer = createHash('sha256').update(`aeriotv-synthetic-peer-${i}`).digest('hex');
    add(`host-oracle-${i}`, secret, peer);
  }
  for (const [id, peer] of [['zero', '00'.repeat(32)], ['one', '01' + '00'.repeat(31)], ['p', 'ed' + 'ff'.repeat(30) + '7f']]) {
    vectors.push({ id: `low-order-${id}`, secret: bob, peer, expected: '00'.repeat(32) });
  }
  return vectors;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) console.log(JSON.stringify(x25519Vectors()));
