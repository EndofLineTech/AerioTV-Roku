import assert from 'node:assert/strict';

export const sharedAuditScreens = ['welcome', 'setup-dispatcharr', 'setup-xtream', 'setup-m3u', 'phone-ready', 'phone-expired', 'phone-failed', 'guide-picker', 'guide-picker-scroll', 'player-options', 'program-details', 'vod-details', 'navigation', 'group-pills', 'group-sidebar', 'player-controls', 'recording-controls', 'tips', 'settings-connection', 'settings-live', 'settings-player', 'settings-movies', 'settings-dvr', 'settings-appearance', 'settings-general', 'settings-remote', 'settings-about', 'settings-whatsnew', 'settings-licenses', 'dialog-duplicate', 'dialog-delete', 'dialog-diagnostics', 'keyboard', 'large-phone', 'large-options', 'large-settings', 'light-dialog', 'light-settings', 'light-tips'];
export const guideLiveAuditScreens = [
  'popup-live-failure', 'popup-live-retry', 'popup-aac-failure', 'popup-diagnostics', 'popup-recent-history', 'search-populated', 'guide-sidebar-focus', 'large-guide-sidebar-focus', 'light-guide-sidebar-focus',
  'guide-manage-groups', 'guide-startup', 'guide-collections', 'guide-favorites', 'guide-reminders', 'guide-badges', 'guide-tmdb', 'guide-date',
  'connection-picker', 'connection-manager', 'connection-advanced', 'connection-auth', 'connection-forget', 'record-flow', 'record-confirm',
  'guide-populated', 'guide-sidebar', 'guide-basic', 'guide-empty', 'guide-gap', 'guide-options-real', 'guide-more-real', 'guide-layout-choices', 'guide-settings-real', 'guide-groups-real', 'guide-details-real',
  'live-main', 'live-audio', 'live-subtitle', 'live-captions', 'live-audiomode', 'live-livetransport', 'live-scale', 'live-aspect', 'live-sleep', 'live-direction', 'live-clock', 'live-streaminfo',
  'live-banner-playing', 'live-banner-paused', 'live-banner-buffering', 'live-banner-preview', 'live-browser', 'live-recent',
  ...['large-', 'light-'].flatMap(prefix => ['guide-populated', 'guide-sidebar', 'guide-options-real', 'guide-details-real', 'live-main', 'live-banner-playing', 'live-browser'].map(screen => prefix + screen)),
];

// Move native focus and Back only; selections are restricted to read-only
// submenu opening. No settings value, player action or mutation is selected.
export async function exerciseFullCase(screen, { key, check, capture }) {
  const base = screen.replace(/^(large|light)-/, '');
  async function inspectAllMenuRows() {
    let state = await check();
    let menu = state.player ? {count: state.player.menu.items.length, focused: state.player.focused} : {count: state.guide.titles.length, focused: state.guide.focused};
    let page = 1;
    while (menu.focused < menu.count - 1) {
      const before = menu.focused;
      await key('Down', Math.min(7, menu.count - 1 - menu.focused));
      state = await check();
      menu.focused = state.player?.focused ?? state.guide.focused;
      assert.ok(menu.focused > before, 'Menu scroll makes native focus progress');
      await capture(`all-rows-${page++}`);
    }
  }
  if (['guide-populated', 'guide-sidebar', 'guide-basic'].includes(base)) {
    await key('Back'); let state = await check(); assert.equal(state.guide.primary, true);
    await key('Right', 2); await capture('primary-focus');
    await key('Down'); await capture('group-focus');
    if (base !== 'guide-sidebar') {
      await key('Right', 5); await capture('group-overflow');
      const empty = await check();
      if (empty.guide.count === 0) {
        assert.equal(empty.guide.subtitle, '', 'Empty group clears prior programme subtitle');
        assert.equal(empty.guide.subtitlevisible, false);
        assert.equal(empty.guide.descriptiony, 205, 'Empty group restores normal summary layout');
      }
      await key('Left', 5); // Restore populated All Channels before testing scroll.
    }
    await key('Back'); await key('Down', 7);
    let scrolled = await check(); assert.ok(scrolled.guide.count > 0 && scrolled.guide.selected >= 4, 'Populated guide actually scrolled');
    await capture('grid-scroll');
    await key('Info'); await capture('options');
    await key('Back'); state = await check(); assert.equal(state.guide.picker, '');
    await capture('back');
  } else if (base === 'guide-sidebar-focus') {
    await key('Down', 6); await capture('scroll-focus'); await key('Back');
    const state = await check(); assert.equal(state.guide.groups, false); await capture('back');
  } else if (base.startsWith('guide-') && !['guide-picker', 'guide-picker-scroll', 'guide-empty', 'guide-gap', 'guide-details-real', 'guide-groups-real'].includes(base)) {
    if (base === 'guide-more-real' || base === 'guide-settings-real') await inspectAllMenuRows();
    else await key('Down', 2);
    await capture('scroll-focus'); await key('Back');
    const state = await check(); assert.equal(state.guide.picker, ''); await capture('back');
  } else if (['guide-gap', 'guide-details-real'].includes(base)) {
    await key('Down'); await capture('action-focus'); await key('Back'); await capture('back');
  } else if (base === 'guide-groups-real') {
    await key('Right', 5); await capture('overflow'); await key('Back'); await capture('back');
  } else if (base === 'live-main') {
    await inspectAllMenuRows(); let state = await check(); assert.equal(state.player.focused, state.player.menu.items.length - 1);
    await capture('scroll'); await key('Back'); await capture('dismissed');
  } else if (base.startsWith('live-') && !base.startsWith('live-banner-') && !['live-browser', 'live-recent'].includes(base)) {
    await key('Down'); await capture('focus');
    if (base === 'live-streaminfo') await inspectAllMenuRows();
    await key('Back');
    const state = await check(); assert.equal(state.player.kind, 'main'); await capture('parent');
  } else if (base === 'live-browser' || base === 'live-recent') {
    await key('Down', base === 'live-recent' ? 1 : 9); await capture('scroll');
    if (base === 'live-browser') { await key('Left'); await key('Down'); await capture('groups'); await key('Back'); await capture('groups-back'); }
    await key('Back'); const state = await check(); assert.equal(state.browser, false); await capture('closed');
  } else if (['navigation', 'group-pills', 'group-sidebar', 'player-controls', 'recording-controls'].includes(base)) {
    await key(base === 'group-sidebar' ? 'Down' : 'Right', 2); await capture('alternate-focus');
  } else if (['guide-picker', 'guide-picker-scroll', 'player-options', 'program-details', 'vod-details'].includes(base) || base.startsWith('settings-') || ['large-options', 'large-settings', 'light-settings'].includes(screen)) {
    await key('Down', base.includes('scroll') ? 9 : 2); await capture('alternate-focus');
  } else if (base === 'search-populated') {
    await key('Down', 7); await capture('action-rows'); await key('Back'); await capture('back');
  } else if (base.startsWith('popup-')) {
    await key('Down', 2); await capture('alternate-focus'); await key('Back'); await capture('dismissed');
  } else if (base.startsWith('dialog-') || base.startsWith('connection-') || base.startsWith('record-') || screen === 'light-dialog') {
    const before = await check();
    await key(before.focused > 0 ? 'Up' : 'Down');
    const after = await check();
    if (before.buttons?.length > 1) assert.notEqual(after.focused, before.focused, 'Native dialog focus actually moved');
    await capture('alternate-focus'); await key('Back'); await capture('dismissed');
  }
  await check();
}
