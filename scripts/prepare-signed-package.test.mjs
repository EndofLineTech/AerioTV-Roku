import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { prepareSignedPackage } from './prepare-signed-package.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const header = Buffer.from('Roku Channel PakV 2.0');

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'roku-signed-name-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const release = join(root, 'out/release');
  mkdirSync(release, { recursive: true });
  const manifest = 'title=AerioTV\nmajor_version=0\nminor_version=3\nbuild_version=97\n';
  writeFileSync(join(root, 'package.json'), JSON.stringify({ version: '0.3.97' }));
  writeFileSync(join(root, 'manifest'), manifest);
  const zipName = 'aeriotv-roku-v0.3.97.zip';
  execFileSync('zip', ['-q', join(release, zipName), 'manifest'], { cwd: root });
  const zipBytes = readFileSync(join(release, zipName));
  const pkgBytes = Buffer.concat([header, Buffer.alloc(1024, 3)]);
  const original = join(release, 'P0123456789abcdef0123456789abcdef.pkg');
  writeFileSync(original, pkgBytes);
  writeFileSync(join(release, 'SHA256SUMS'), `${hash(zipBytes)}  ${zipName}\n`);
  writeFileSync(join(release, 'SHA256SUMS-v0.3.97'), `${hash(pkgBytes)}  ${original.split('/').at(-1)}\n${hash(zipBytes)}  ${zipName}\n`);
  return { root, release, original, pkgBytes, zipBytes, zipName };
}

test('copies Roku package to a stable versioned name and writes usable checksums', t => {
  const { root, release, original, pkgBytes, zipBytes, zipName } = fixture(t);
  const first = prepareSignedPackage(original, root);
  const name = 'aeriotv-roku-v0.3.97.pkg';
  assert.equal(first.destination, join(release, name));
  assert.deepEqual(readFileSync(first.destination), pkgBytes);
  assert.deepEqual(readFileSync(original), pkgBytes);
  const checksums = `${hash(pkgBytes)}  ${name}\n${hash(zipBytes)}  ${zipName}\n`;
  assert.equal(readFileSync(join(release, 'SHA256SUMS-v0.3.97'), 'utf8'), checksums);
  assert.equal(readFileSync(join(release, 'SHA256SUMS'), 'utf8'), checksums);
  assert.equal(prepareSignedPackage(original, root).destination, first.destination);
});

test('rejects unsigned input and a different existing signed package under the same version', t => {
  const { root, release, original, pkgBytes, zipBytes } = fixture(t);
  const unsigned = join(release, 'unsigned.pkg');
  writeFileSync(unsigned, Buffer.alloc(1024, 5));
  assert.throws(() => prepareSignedPackage(unsigned, root), /Roku-signed/);
  writeFileSync(join(release, 'aeriotv-roku-v0.3.97.pkg'), Buffer.concat([header, Buffer.alloc(1024, 4)]));
  assert.throws(() => prepareSignedPackage(original, root), /different bytes/);
  copyFileSync(original, join(release, 'aeriotv-roku-v0.3.97.pkg'));
  writeFileSync(join(release, 'SHA256SUMS-v0.3.97'), `${'0'.repeat(64)}  aeriotv-roku-v0.3.97.pkg\n${hash(zipBytes)}  aeriotv-roku-v0.3.97.zip\n`);
  assert.throws(() => prepareSignedPackage(original, root), /conflicts/);
  assert.deepEqual(readFileSync(original), pkgBytes);
});

test('rejects a versioned ZIP built for a different app version', t => {
  const { root, original } = fixture(t);
  writeFileSync(join(root, 'manifest'), 'title=AerioTV\nmajor_version=0\nminor_version=3\nbuild_version=98\n');
  assert.throws(() => prepareSignedPackage(original, root), /versions differ/);
});
