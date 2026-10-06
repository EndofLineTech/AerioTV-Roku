import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync, readdirSync } from 'node:fs';
import { assertPackageEntries } from './verify-package.mjs';

test('store manifest declares supported RSG level and an unbranded title', () => {
  const manifest = readFileSync(new URL('../manifest', import.meta.url), 'utf8');
  const fields = Object.fromEntries(manifest.trim().split('\n').map(line => line.split('=', 2)));
  assert.equal(fields.rsg_version, '1.3');
  assert.equal(fields.title, 'AerioTV');
  const version = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8')).version;
  assert.equal(fields.build_version, version.split('.')[2]);
});

test('no component creates a legacy keyboard dialog', () => {
  for (const file of readdirSync(new URL('../components/', import.meta.url)).filter(name => name.endsWith('.brs'))) {
    const source = readFileSync(new URL(`../components/${file}`, import.meta.url), 'utf8');
    assert.equal(/CreateObject\("roSGNode", "KeyboardDialog"\)/.test(source), false, file);
  }
});

test('accepts a normal Roku package layout', () => {
  assert.doesNotThrow(() => assertPackageEntries([
    'manifest',
    'source/main.brs',
    'components/AerioScene.xml',
    'images/channel-icon-fhd.png',
    'images/LICENSE.txt',
    'images/NOTICE.txt',
    'images/material-icons-LICENSE.txt',
  ]));
});

test('the packaged notices remain identical to the repository originals', () => {
  for (const name of ['LICENSE', 'NOTICE']) {
    assert.equal(
      readFileSync(new URL(`../images/${name}.txt`, import.meta.url), 'utf8'),
      readFileSync(new URL(`../${name}.md`, import.meta.url), 'utf8'),
      `${name} attribution stays in sync`,
    );
  }
});

test('rejects development files and a nested package root', () => {
  assert.throws(() => assertPackageEntries(['aeriotv/manifest']));
  assert.throws(() => assertPackageEntries(['manifest', 'tests/GuideModel.test.brs']));
  assert.throws(() => assertPackageEntries(['manifest', '.env.local']));
  const withRootNotice = ['manifest', 'source/main.brs', 'components/AerioScene.xml',
    'images/LICENSE.txt', 'images/NOTICE.txt', 'images/material-icons-LICENSE.txt', 'LICENSE.md'];
  assert.throws(() => assertPackageEntries(withRootNotice), /excluded development file/);
});
