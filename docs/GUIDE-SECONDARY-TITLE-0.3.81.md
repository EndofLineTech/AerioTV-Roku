# Guide secondary titles — AerioTV-Roku-31z

The PO requested the matchup beneath a generic program title such as
“College Football.” On the authorized target Roku, Program Details already
showed **“Ole Miss at Florida”** as a separate `sub_title` field. The EPG
normalizer preserved it as `program.subtitle`, but the guide grid and selected
program header did not display it. This change uses that field; it does not
derive a matchup from the description.

When **Show program subtitles** is enabled, the selected-program header shows
the subtitle on a separate line. Preview-density program tiles show it below
the title when they are at least 260 pixels wide. Duplicate titles and empty
subtitles are suppressed. Narrow tiles and Basic density retain their existing
compact title/time presentation; Program Details still contains the complete
description. The selected title's Audio Guide announcement includes the
subtitle when the setting permits it.

Preview uses **six 112-pixel rows** in the existing 672-pixel guide viewport
instead of seven 96-pixel rows. Each tile is 111 pixels high, with separate
vertical positions for title, secondary title, flags and time. Badge pills
leave a 10-pixel bottom gutter, and per-tile clipping prevents text or pills
from painting into a neighboring program or channel. Secondary labels are
created only when needed; Basic's ten 64-pixel rows are unchanged. Normal
Up/Down focus keeps the selected channel visible as the six-row window scrolls.

## Verification — 2026-09-26

- `npm run verify` passed model, controller, package and compiler checks. Tests
  cover source-field normalization, preference gating, duplicate/empty fields,
  Preview width and Basic fallback, bounded subtitle geometry and Audio Guide
  text.
- A changed application ZIP installed on Streaming Stick 4K `3820RW2`, Roku
  OS `15.3.4`. The selected “College Football” program showed “Ole Miss at
  Florida” on its own line in both header and wide tile; other channels showed
  their distinct matchup subtitles. The first Preview arrangement put the
  LIVE/NEW pills too close to row boundaries. After the PO flagged this, the
  rows were expanded and the final device capture showed the pills inset.
  Remote scrolling to a focused bottom-row matchup kept that tile and its
  pills within the grid, above the footer. Private screenshots are ignored
  under `out/guide-subtitle-*.jpg`.
- A six-second resource sample of the earlier compact candidate peaked at
  92,553,216 process bytes. Subsequent Roku graphics counters were also high
  under the previous release ZIP (~87 MB single-instance texture), so they
  cannot isolate this UI change's graphics cost. The initial 31z check made no
  provider/server write or display-setting change. The verified v0.3.81 release
  ZIP was reinstalled and its authorized guide launched after the check.

## Default and compact option — AerioTV-Roku-80l

The account-local setting **Settings → Live TV → Program subtitles / taller
Preview** defaults to **On**. On keeps six 112-pixel Preview rows with source
subtitles. Off hides the secondary line and restores the original seven
96-pixel Preview rows, using the same 672-pixel viewport. Basic density stays
at ten rows regardless of this choice. No additional setting or registry
schema was introduced.

The changed build showed the On setting and six-row matchup view on the target
Roku. Selecting Off through the TV settings rendered seven compact rows without
the matchup and retained Off after Home/relaunch. Selecting On restored six
rows and the matchup. The original On setting was restored before the verified
release ZIP was reinstalled. Private device captures remain ignored under
`out/guide-subtitle-*.jpg`; model and Settings Hub tests exercise the defaults,
saved setting and both geometry branches. No provider/server configuration was
changed.

Rollback: reinstall the previous v0.3.81 ZIP. There is no guide-schema
migration; the account's original On selection was restored after verification.
