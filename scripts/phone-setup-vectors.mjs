import { createCipheriv, createDecipheriv } from 'node:crypto';

// Independent host oracle: every negative case must fail authenticated final().
export function vectors() {
  const rows = [];
  for (const length of [0, 1, 16, 37]) {
    const key = Buffer.from(Array.from({ length: 32 }, (_, i) => i));
    const nonce = Buffer.from(Array.from({ length: 12 }, (_, i) => i + 32));
    const plain = Buffer.from(Array.from({ length }, (_, i) => i + 64));
    const c = createCipheriv('aes-256-gcm', key, nonce);
    const ciphertext = Buffer.concat([c.update(plain), c.final()]);
    const tag = c.getAuthTag();
    const base = { id: `length-${length}`, key: key.toString('hex'), nonce: nonce.toString('hex'), plain: plain.toString('hex'), ciphertext: ciphertext.toString('hex'), tag: tag.toString('hex'), valid: true };
    rows.push(base);
    for (const field of ['key', 'nonce', 'ciphertext', 'tag']) {
      if (!base[field]) continue;
      const altered = Buffer.from(base[field], 'hex');
      altered[0] ^= 1;
      rows.push({ ...base, id: `${base.id}-changed-${field}`, [field]: altered.toString('hex'), valid: false });
    }
    rows.push({ ...base, id: `${base.id}-missing-tag`, tag: '', valid: false });
    rows.push({ ...base, id: `${base.id}-truncated-tag`, tag: tag.subarray(0, 15).toString('hex'), valid: false });
  }
  for (const row of rows) {
    let accepted = false;
    try {
      const d = createDecipheriv('aes-256-gcm', Buffer.from(row.key, 'hex'), Buffer.from(row.nonce, 'hex'), { authTagLength: 16 });
      d.setAuthTag(Buffer.from(row.tag, 'hex'));
      const plain = Buffer.concat([d.update(Buffer.from(row.ciphertext, 'hex')), d.final()]);
      accepted = plain.toString('hex') === row.plain;
    } catch {}
    if (accepted !== row.valid) throw Error(`Host oracle mismatch: ${row.id}`);
  }
  return rows;
}
if (process.argv[1]?.endsWith('/phone-setup-vectors.mjs')) console.log(JSON.stringify(vectors()));
