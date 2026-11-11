import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { assertShippingArchive } from './verify-package.mjs';

test('synthetic logo probe cannot ship or use the application scene/cache', () => {
  const directory = mkdtempSync(join(tmpdir(), 'aerio-logo-isolation-'));
  try {
    const base = join(directory, 'base.zip'), probe = join(directory, 'probe.zip');
    execFileSync('python3', ['-c', `import sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'w') as z:
 for name in ['manifest', 'images/LICENSE.txt', 'images/NOTICE.txt', 'images/material-icons-LICENSE.txt', 'source/Main.brs', 'components/Stub.xml']:
  z.writestr(name, 'fixture')
 z.writestr('source/MetadataCacheStore.brs', '"cachefs:/aeriotv-metadata-v1"')`, base]);
    execFileSync('python3', ['scripts/build-channel-logo-probe.py', '--base', base, '--output', probe]);
    assert.throws(() => assertShippingArchive(probe), /synthetic setup probe/);
    const read = name => execFileSync('unzip', ['-p', probe, name], { encoding: 'utf8' });
    assert.match(read('source/Main.brs'), /createScene\("ChannelLogoProbe"\)/);
    assert.doesNotMatch(read('source/Main.brs'), /AerioScene|roRegistry/);
    assert.match(read('source/MetadataCacheStore.brs'), /tmp:\/channel-logo-probe-cache/);
    assert.doesNotMatch(read('source/MetadataCacheStore.brs'), /cachefs:\/aeriotv-metadata/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
