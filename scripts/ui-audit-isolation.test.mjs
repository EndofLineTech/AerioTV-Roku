import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { assertPackageEntries } from './verify-package.mjs';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('gallery replaces startup and disconnects real account navigation', () => {
  const builder = read('scripts/build-ui-audit-probe.py');
  assert.match(builder, /sub init\(\)\\n    initUiAudit\(\)\\nend sub/);
  assert.match(builder, /unusedApplicationKeyEvent/);
  assert.match(builder, /UiAuditMain\.brs/);
  assert.match(builder, /onSetupActive.*auditPhoneActive/);
  const main = read('tests/native/UiAuditMain.brs');
  assert.doesNotMatch(main, /launchRequest|roRegistry|roUrlTransfer/);
  const probe = read('tests/native/UiAuditProbe.brs');
  assert.doesNotMatch(probe, /observeField\("(?:selection|buttonSelected|received|committed)"|roRegistry|roUrlTransfer|connectServer\(/);
  const phone = read('tests/native/UiAuditPhone.brs');
  assert.match(phone, /sub auditPhoneActive\(\)\s*end sub/);
  assert.match(phone, /code: "123456"/);
  assert.doesNotMatch(phone, /startReceiver|control = "run"/);
});

test('shipping package guard rejects every gallery hook', () => {
  const base = ['manifest', 'source/Main.brs', 'components/AerioScene.xml', 'images/LICENSE.txt', 'images/NOTICE.txt', 'images/material-icons-LICENSE.txt'];
  assert.doesNotThrow(() => assertPackageEntries(base));
  for (const name of ['UiAuditMain.brs', 'UiAuditPhone.brs', 'UiAuditSettings.brs', 'SetupReceiverProbeUiAudit.brs']) {
    assert.throws(() => assertPackageEntries([...base, `components/${name}`]), /probe/);
  }
});

test('all application action lists/dialogs use shared pill renderers', () => {
  for (const name of readdirSync(new URL('../components/', import.meta.url)).filter(name => /\.(?:brs|xml)$/.test(name))) {
    const source = read(`components/${name}`);
    assert.doesNotMatch(source, /createChild\("LabelList"\)|<LabelList\b|CreateObject\("roSGNode", "Dialog"\)/, name);
  }
  const item = read('components/AerioPillListItem.brs');
  assert.match(item, /m\.fill\.radius = height \/ 2/);
  assert.match(item, /m\.label\.horizAlign = "center"/);
  assert.match(item, /m\.label\.vertAlign = "center"/);
  assert.match(item, /if not action then m\.label\.horizAlign = "left"/);
});
