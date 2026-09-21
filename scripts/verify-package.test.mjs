import assert from 'node:assert/strict';
import test from 'node:test';
import { assertPackageEntries } from './verify-package.mjs';

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
