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
  cannot isolate this UI change's graphics cost. No provider/server write or
  display setting was made. The verified v0.3.81 release ZIP was reinstalled
  and its authorized guide launched after the check.

Rollback: reinstall the previous v0.3.81 ZIP. No persisted guide schema or
account setting was changed by the subtitle display work.
