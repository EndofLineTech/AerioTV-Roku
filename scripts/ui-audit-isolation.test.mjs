import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { assertPackageEntries } from './verify-package.mjs';
import { sharedAuditScreens, guideLiveAuditScreens, exerciseFullCase } from './ui-full-audit-cases.mjs';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('all confirmed control and contrast regressions use the shared production fixes', () => {
  const guide = read('components/GuideView.brs');
  const empty = guide.indexOf('m.title.text = "No matching channels"');
  assert.ok(guide.lastIndexOf('clearGuideProgramSummary()', empty) > guide.indexOf('sub drawGuide()'));
  assert.match(read('components/AerioScene.brs'), /uiSetColor\(m.top, "0x0A1628FF", "backgroundColor"\)/);
  assert.match(read('components/ChannelBrowser.brs'), /uiButton\(group,/);
  assert.match(read('components/ProgramSearchView.brs'), /uiCenterLabel\(row.title/);
  assert.match(read('components/ProgramSearchView.brs'), /uiRemoteHints\(/);
  assert.match(read('components/DvrView.brs'), /uiSetColor\(m.list, "0xE8F3FAFF", "caption1Color"\)/);
  assert.match(read('components/DvrView.brs'), /captionBackgroundBitmapUri = "pkg:\/images\/ui-list-inset.png"/);
  assert.match(read('components/VodView.brs'), /tile.border.radius = 58/);
});

test('live-options audit reaches every menu row without selecting an action', async () => {
  let focused = 0, visible = true;
  const observations = [0];
  await exerciseFullCase('live-main', {
    key: async (key, count = 1) => {
      assert.ok(['Down', 'Back'].includes(key));
      if (key === 'Down') focused = Math.min(22, focused + count);
      if (key === 'Back') visible = false;
    },
    check: async () => visible ? {player: {kind: 'main', focused, menu: {items: Array(23).fill({})}}} : {},
    capture: async () => { if (visible) observations.push(focused); },
  });
  assert.equal(focused, 22);
  assert.equal(visible, false);
  for (let i = 1; i < observations.length; i++) assert.ok(observations[i] - observations[i - 1] <= 7, 'No unseen gap between eight-row captures');
});

test('repeat audit covers populated guide and live pop-ups without submitting actions', () => {
  const screens = [...sharedAuditScreens, ...guideLiveAuditScreens];
  assert.equal(new Set(screens).size, screens.length);
  for (const screen of ['guide-populated', 'guide-sidebar', 'guide-options-real', 'guide-details-real', 'live-main', 'live-banner-playing', 'live-browser', 'live-captions', 'live-streaminfo', 'connection-forget', 'record-confirm']) {
    assert.ok(screens.includes(screen), screen);
  }
  const cases = read('scripts/ui-full-audit-cases.mjs');
  assert.doesNotMatch(cases, /key\(['"](?:Select|Play|Lit_|Enter)/);
  const probe = read('tests/native/UiAuditProbe.brs');
  assert.match(probe, /connectionDialog\.unobserveField\("buttonSelected"\)/);
  assert.match(probe, /recordDialog\.unobserveField\("buttonSelected"\)/);
  assert.match(probe, /m\.video = \{/); // synthetic snapshot, not a media node
  assert.match(probe, /availableSubtitleTracks: \[\{trackName: "1"/);
});

test('gallery replaces startup and disconnects real account navigation', () => {
  const builder = read('scripts/build-ui-audit-probe.py');
  assert.match(builder, /sub init\(\)\\n    initUiAudit\(\)\\nend sub/);
  assert.match(builder, /unusedApplicationKeyEvent/);
  assert.match(builder, /UiAuditMain\.brs/);
  assert.match(builder, /onSetupActive.*auditPhoneActive/);
  const main = read('tests/native/UiAuditMain.brs');
  assert.doesNotMatch(main, /launchRequest|roRegistry|roUrlTransfer/);
  const probe = read('tests/native/UiAuditProbe.brs');
  assert.doesNotMatch(probe, /\.observeField\("(?:buttonSelected|received|committed)"|roRegistry|roUrlTransfer|connectServer\(/);
  assert.match(probe, /observeField\("selection", "uiAuditPlayerSelection"\)/);
  assert.doesNotMatch(probe, /observeField\("selection", "onPlayerOption"\)/);
  const phone = read('tests/native/UiAuditPhone.brs');
  assert.match(phone, /sub auditPhoneActive\(\)\s*end sub/);
  assert.match(phone, /code: "123456"/);
  assert.doesNotMatch(phone, /startReceiver|control = "run"/);
});

test('shipping package guard rejects every gallery hook', () => {
  const base = ['manifest', 'source/Main.brs', 'components/AerioScene.xml', 'images/LICENSE.txt', 'images/NOTICE.txt', 'images/material-icons-LICENSE.txt'];
  assert.doesNotThrow(() => assertPackageEntries(base));
  for (const name of ['UiAuditMain.brs', 'UiAuditPhone.brs', 'UiAuditSettings.brs', 'UiAuditVod.brs', 'UiAuditDvr.brs', 'UiAuditFixtureTask.brs', 'UiAuditLibraryData.brs', 'UiAuditGuide.brs', 'UiAuditGuideData.brs', 'SetupReceiverProbeUiAudit.brs']) {
    assert.throws(() => assertPackageEntries([...base, `components/${name}`]), /probe/);
  }
  assert.throws(() => assertPackageEntries([...base, 'ui-audit-build.json']), /probe/);
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
