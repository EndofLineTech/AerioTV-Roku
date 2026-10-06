# Roku settings rail — 0.3.91 development candidate

The TV settings references are tvOS `dc1a9733d2251302796efa1b992d8b55812baf3b`
(`Features/Settings/TVSettingsSplitView.swift`) and Android
`47fa1c9629ce7cc9cb3291a29b66330277f754b5`
(`feature/settings/SettingsHost.kt`). Both browse a left rail by focus and
open the selected detail on Right/OK; Back returns to the rail. Roku follows
that interaction and uses its existing navy/cyan palette and available icons.
The categories are Connection, Live TV, Player, optional Movies & TV Shows,
optional DVR (management permission), Appearance, General, Remote control and
About. Movies/DVR preferences moved from General without changing their
persistence scope or choices. Unsupported upstream Sync, update, developer and
playlist-management controls were not fabricated in the Roku interface.

The candidate branches from v0.3.89 certification source and carries forward
the v0.3.90 first-run launch-beacon fix. The original v0.3.90 worktree is
untouched. The developer install replaced only the Roku dev-slot ZIP, not a
Store app. A preserved v0.3.90 ZIP is in
`out/first-run-launch-fix/out/release/aeriotv-roku-v0.3.90.zip`.

## Verification on 3820RW2, Roku OS 15.3.4

- `npm run verify` passed (unit/controller suites, package checks, tooling,
  BrightScript compiler and v0.3.91 package validation).
- Developer installation accepted v0.3.91 and the Roku launched a populated
  authorized guide. ECP keypresses returned HTTP 200. Developer Mode screenshots
  were reviewed locally and kept under ignored `out/settings-redesign/out/`.
- Rail browse switched the pane on Down; Right entered it; Back returned to the
  selected category. The remote-control submenu returned to its parent. About
  opened license notices and What's New from its top-level rail page.
- Live TV guide history changed 3 → 7, survived reinstall/relaunch, then was
  restored to 3. VOD libraries changed On → Off → On. General request timeout
  changed 20 → 30 → 20 seconds. Player audio compatibility changed Automatic →
  Direct → Automatic without tuning. Appearance changed AerioTV → Midnight →
  AerioTV theme and Dark → Light → Dark mode; screenshots showed immediate color
  changes and the restored values.
- The initial theme test exposed a legacy case-variant preference collision:
  `themePreset=midnight` reached the Scene handler but normalization read an
  older key. Device and account writes now remove all casings of the selected
  key before setting its canonical spelling. A regression test covers duplicate
  JSON keys; native theme and player edits passed with the corrected build.
- After the account became an admin, the DVR rail category was visible. Its
  account defaults were initially start early=0/end late=0. Changed both to
  5/10; cold Home/relaunch showed 5/10. Restored both to 0/0; another cold
  Home/relaunch showed 0/0. No recording or provider source was changed. Private
  device captures are under ignored `out/settings-redesign/out/admin-settings-*.jpg`.

These checks establish navigation, representative guide/account/device writes
and account-scoped DVR persistence. They do not establish every setting's
downstream effect, a completed recording with changed padding, Audio Guide,
network failure timing, all remote mappings or physical-remote audiovisual
behavior. The model suite enumerates the offered choices and verifies capability
gates; existing preference and remote-map suites cover normalization and
failed-write rollback. The settings source is isolated from uncommitted EPG
beacon experimentation in another worktree.
