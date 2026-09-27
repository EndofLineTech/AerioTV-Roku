import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync, readdirSync } from 'node:fs';
import { assertPackageEntries } from './verify-package.mjs';

test('store manifest declares supported RSG level and an unbranded title', () => {
  const manifest = readFileSync(new URL('../manifest', import.meta.url), 'utf8');
  const fields = Object.fromEntries(manifest.trim().split('\n').map(line => line.split('=', 2)));
  assert.equal(fields.rsg_version, '1.3');
  assert.equal(fields.title, 'AerioTV');
  assert.equal(fields.build_version, '85');
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
    'LICENSE.md',
    'NOTICE.md',
  ]));
});

test('rejects development files and a nested package root', () => {
  assert.throws(() => assertPackageEntries(['aeriotv/manifest']));
  assert.throws(() => assertPackageEntries(['manifest', 'tests/GuideModel.test.brs']));
  assert.throws(() => assertPackageEntries(['manifest', '.env.local']));
});
