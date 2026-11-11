import assert from 'node:assert/strict';

export const libraryAuditScreens = [
  'library-movies', 'library-series', 'library-episodes', 'library-favorite', 'library-watchlist', 'library-continue', 'library-recent', 'library-hidden',
  'library-categories', 'library-providers', 'library-versions', 'library-xtream', 'library-empty', 'library-loading', 'library-error', 'library-denied',
  'large-library-movies', 'light-library-movies', 'large-library-categories', 'light-library-categories',
  'dvr-populated', 'dvr-completed', 'dvr-recording', 'dvr-scheduled', 'dvr-failed', 'dvr-rules', 'dvr-view', 'dvr-empty', 'dvr-loading', 'dvr-error', 'dvr-denied', 'dvr-rule-error',
  'large-dvr-populated', 'light-dvr-populated', 'series-options', 'large-series-options',
  'settings-choice', 'settings-remote-player', 'settings-remote-guide', 'settings-reset',
];

// Only safe detail/navigation choices. Never select Play, a mutation Confirm,
// a settings value, or a reset. The package independently blocks all Tasks
// except synthetic catalog/list reads, and observes unexpected play requests.
export async function exerciseLibraryCase(screen, { key, check, capture }) {
  let state = await check();
  async function select(label) {
    state = await check();
    const buttons = state.library?.buttons?.length ? state.library.buttons : state.buttons ?? [];
    const index = buttons.findIndex(value => value === label);
    assert.ok(index >= 0, `Expected safe action ${label}`);
    const focused = state.library?.dialog === 'VodDetails' ? state.library.focused : state.focused;
    assert.ok(focused >= 0, 'Native dialog has a focused action');
    await key(index >= focused ? 'Down' : 'Up', Math.abs(index - focused));
    await key('Select');
  }
  if (screen === 'library-movies') {
    await key('Right', 2); await key('Down', 3);
    state = await check(); assert.equal(state.library.index, 17);
    await capture('scroll');
    await key('Fwd'); state = await check(); assert.equal(state.library.page, 2);
    await capture('page2');
    await key('Rev'); state = await check(); assert.equal(state.library.page, 1);
    await key('Select'); state = await check(); assert.equal(state.library.dialog, 'VodDetails');
    await capture('details');
    await select('Full synopsis'); await capture('synopsis');
    await key('Back'); state = await check(); assert.equal(state.library.dialog, '');
    await key('Up'); state = await check(); assert.equal(state.library.tabs, true);
    await capture('tabs'); await key('Back');
    await key('Info'); await capture('options');
    await select('More library actions'); await capture('more-actions');
    await key('Back');
  } else if (screen === 'library-series') {
    await key('Select'); await capture('details');
    await select('Browse episodes'); state = await check(); assert.equal(state.library.kind, 'episode');
    await capture('episodes');
    await key('Back'); state = await check(); assert.equal(state.library.kind, 'series'); assert.equal(state.library.index, 0);
    await capture('back-to-series');
  } else if (['library-favorite', 'library-watchlist', 'library-continue', 'library-hidden', 'library-episodes'].includes(screen)) {
    await key('Select'); state = await check(); assert.equal(state.library.dialog, 'VodDetails');
    await capture('details');
    const expected = { 'library-favorite': 'Remove from Favorites', 'library-watchlist': 'Remove from To Watch', 'library-continue': 'Resume', 'library-hidden': 'Unhide title' }[screen];
    if (expected) assert.ok(state.library.buttons.includes(expected), `Shelf detail reflects saved state: ${expected}`);
    await key('Back'); state = await check(); assert.equal(state.library.dialog, '');
    await capture('back');
  } else if (['library-categories', 'library-providers', 'library-versions', 'library-xtream'].includes(screen)) {
    await key('Down', 3); state = await check(); assert.equal(state.library.index, 15);
    await capture('scroll');
    await key('Fwd'); state = await check(); assert.equal(state.library.page, 2);
    await capture('page2');
    await key('Back'); await capture('back');
  } else if (screen.startsWith('dvr-') && ['dvr-populated', 'dvr-completed', 'dvr-recording', 'dvr-scheduled', 'dvr-failed', 'dvr-rules', 'dvr-view'].includes(screen)) {
    const before = state.library.identity;
    await key('Select'); state = await check(); assert.equal(state.library.dialog, 'AerioDialog');
    await capture('details');
    if (screen === 'dvr-view') {
      assert.ok(!state.library.buttons.some(label => /Delete|Cancel future|Stop and|Remove rule/.test(label)), 'View-only omits mutations');
    }
    const confirmation = { 'dvr-completed': 'Delete permanently', 'dvr-failed': 'Delete permanently', 'dvr-recording': 'Stop and keep partial recording', 'dvr-scheduled': 'Cancel future schedule', 'dvr-rules': 'Remove rule and future schedules' }[screen];
    if (confirmation) {
      await select(confirmation); await capture('confirmation');
      // Deliberately Back out without selecting the destructive confirmation.
    }
    await key('Back'); state = await check(); assert.equal(state.library.dialog, ''); assert.equal(state.library.identity, before);
    await capture('back');
    await key('Down', screen === 'dvr-rules' ? 1 : 3); await capture('scroll');
    await key('Back'); state = await check(); assert.equal(state.library.closed, true);
  } else if (screen === 'settings-remote-player' || screen === 'settings-remote-guide') {
    await key('Select'); await capture('action-choices'); await key('Back'); await capture('back');
  } else if (screen === 'series-options') {
    const title = state.buttons.find(value => value.startsWith('Title matching:'));
    await select(title); await capture('title-mode');
    await key('Back');
  }
  state = await check();
  if (state.library) {
    assert.equal(typeof state.library.playrequested, 'boolean', 'Native play-request state is present');
    assert.equal(state.library.playrequested, false, 'No media request');
  }
}
