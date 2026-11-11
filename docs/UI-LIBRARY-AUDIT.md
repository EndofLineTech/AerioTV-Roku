# Populated VOD/DVR rendered audit

Work item: `AerioTV-Roku-d85`, under `AerioTV-Roku-mrr`.
Date: November 11, 2026. This is fixture/audit delivery, **not** completion of
the VOD/DVR fixes or multi-user profiles.

## What was exercised

The isolated gallery now runs the production `VodView`, `DvrView`, navigation,
loading callbacks, detail/menu handlers, `VodDetails`, `AerioDialog`, native
`PosterGrid` and Settings controls against bounded synthetic data. It does not
draw a separate imitation library. Offline archive tests compare production
renderer/controller scripts byte-for-byte with the input ZIP.

The library suite has 40 starting cases, plus intermediate navigation/detail
captures. On-device key events are sent through Roku ECP into the real focus
engine; this is hardware remote-navigation testing, **not** a claim that a human
manually pressed a physical remote. Native state assertions accompany captures.
All 103 images from the preceding full run were inspected across 18 contact
sheets; important findings were also opened at full resolution. The final full
rerun corrected Settings fixture routing, and its theme, remote-player,
remote-guide and reset captures were reinspected at full resolution. Contact
sheets retained locally describe the preceding run. Capture success alone is
not a visual pass.

Final native result: **40 cases, 103 captures, 176 state observations**, completed
without a runtime error or automated navigation finding. Three visual defects
remain open below.

| Evidence | SHA256 |
| --- | --- |
| Tested isolated gallery ZIP | `a3a164d5037ef892587b849979aa0c1fbee54218067e951a262e459f970e313d` |
| Gallery marker's base ZIP | `7aca123759ba15dcbaa5cd1748f8ba4437974bb0d2dc49bf1d2d3f90c0672927` |
| Restored pill-UI developer ZIP | `91f8b8b1f3c2f45e625588e198b8f0a66af963ea285d49e1a27483461afb8734` |

Screenshots and manifests are local generated evidence under ignored `out/`;
fixtures, runner and this coverage/findings report are committed. The restored
developer ZIP is not a signed Beta/Store package.

## Source-to-surface coverage

All screenshot names below are relative to `out/ui-audit/libraries/` and have
the `.jpg` extension. Intermediate states use `--<step>` suffixes. The complete
capture/state inventory is `captures.json`; contact sheets are in `review/`.

| Production surface | Starting case(s) | Additional exercised states |
| --- | --- | --- |
| `VodView.drawVod` movie grid | `library-movies` | Index 17 / lower rows, page 2 and reverse pagination, details, synopsis, focused navigation tabs, common options, nested More actions |
| Series and episode grids | `library-series`, `library-episodes` | Series details → Browse episodes → Back to original series index; episode details → Back; season/episode tags |
| Saved library shelves | `library-favorite`, `library-watchlist`, `library-continue`, `library-recent`, `library-hidden` | Favorites/To Watch/hidden flags and resume position seeded in memory; detail labels verified, Back restores shelf; Recent grid inspected |
| Compact selectors | `library-categories`, `library-providers`, `library-versions`, `library-xtream` | Focus to fourth row, page 2, Back; Xtream uses its real provider-dependent navigation branch |
| VOD exceptional states | `library-empty`, `library-loading`, `library-error`, `library-denied` | Empty, held synthetic read, 503 and 403 responses through real load callback |
| VOD appearance | `large-library-movies`, `light-library-movies`, `large-library-categories`, `light-library-categories` | 120% text and light palette, long titles, focused/unfocused controls |
| `DvrView.drawDvr` / native sections | `dvr-populated` | 48 recordings across now/scheduled/recent plus two series rules; details, Back identity restoration, cross-section scrolling |
| Recording-state actions | `dvr-completed`, `dvr-recording`, `dvr-scheduled`, `dvr-failed` | Actual state-dependent detail buttons; delete/stop/cancel confirmation displayed, then **Back without confirming**; grid identity checked |
| Series-rule library | `dvr-rules` | Long title, details, Remove rule confirmation, Back, focus traversal |
| DVR view permission | `dvr-view` | Playback labels remain, management mutation labels absent; no playback selected |
| DVR exceptional states | `dvr-empty`, `dvr-loading`, `dvr-error`, `dvr-denied`, `dvr-rule-error` | Empty, held read, list 503/403, failed rules load retaining recordings |
| DVR appearance | `large-dvr-populated`, `light-dvr-populated` | 120% text and light appearance; native grid and hint rendering inspected |
| `DvrSeriesNavigation.showSeriesOptions` | `series-options`, `large-series-options` | Seven rule options, long title/description; title-matching toggle changes only the synthetic in-memory draft |
| `SettingsHub` choices/subcategories | `settings-choice`, `settings-remote-player`, `settings-remote-guide`, `settings-reset` | Theme choices, remote slot choices, nested Back, Reset appearance confirmation shown but not executed |

Roku currently presents episodes in a flat grid with season/episode facts; there
is no separate season-picker renderer to test. The gallery includes multiple
season tags rather than pretending a missing screen exists. This audit does not
add a season feature.

## Confirmed visual findings

The fix work remains in the existing beads, with concrete reproduction notes.

| Finding | Evidence | Fix owner |
| --- | --- | --- |
| Compact category/provider/source actions remain rounded rectangles, not full pills; labels sit high within their 116px controls | `library-categories`, `library-providers`, `library-versions`, `library-xtream`, including light/large variants. `VodView.drawVod` uses radius 24 and manually offset title boxes. | `AerioTV-Roku-mrr.2` |
| Provider/source headings overlap the first Movies navigation pill | `library-providers`, `library-versions`; full-resolution inspection confirms the collision, not just truncated long catalog content. | `AerioTV-Roku-mrr.2` |
| Light-mode DVR leaves the panel/grid dark while hint descriptions use dark light-mode ink, making descriptions very difficult to read | `light-dvr-populated`; key pills are visible but Facts/play, Search/sort, Refresh and Guide descriptions lack contrast. | `AerioTV-Roku-mrr.3` |

The exercised pagination, series/episode Back path, DVR detail/confirmation Back,
native item identity restoration, and view-only mutation-label checks passed.
This does not waive the visual defects. Native wrapping between DVR sections is
the existing PosterGrid behavior, not a custom fixture navigation implementation.

## Isolation and safety

- Scene/Main application startup remains replaced; no real account/registry or
  application persistence observer is loaded by the gallery.
- **Every Task component** retains its interface but has its executable scripts
  replaced with `UiAuditFixtureTask` and pure synthetic data. Catalog/list reads
  return fixtures. Recording writes and unexpected Task kinds emit a forbidden
  event that fails the runner. Unit tests exercise the mutation rejection path.
- VOD artwork resolution returns a bundled placeholder. DVR uses bundled
  fallback art; fixture logos, TMDB paths and fallback URLs are empty. This also
  closes image-node networking paths outside Tasks. Detail artwork can show
  Unavailable; real provider artwork fetching is not claimed tested here.
- Unexpected `playRequested` events fail the runner; native state independently
  reports the boolean. No Video/Audio player is connected to fixture selections.
- No real recording was scheduled/stopped/deleted, no media played, and no saved
  setting/connection was changed. Reset and destructive confirmations were
  displayed only. The numeric/direction PIN/profile work is outside this task.
- Shipping and pairing-test builders reject `ui-audit-build.json` and all
  `UiAudit*` hooks. Normal package contents do not include the fixtures.
- The runner restores a checksum-pinned owner-ready ZIP in `finally`, including
  failure paths. The previous pill-UI developer build was restored after testing,
  not replaced with this synthetic gallery for owner use.

## Reproduce

With Roku developer access supplied only in environment variables:

```sh
npm run build
python3 scripts/build-ui-audit-probe.py
node scripts/test-ui-audit-native.mjs out/ui-audit-probe.zip out/pairing-tests/pill-ui/aeriotv-roku-v0.3.100-pairing-test.zip --libraries
swift scripts/ui-audit-contact-sheets.swift out/ui-audit/libraries/captures.json
```

Individual starting cases can follow `--libraries` to reproduce a finding. A
capture manifest starts with `visualReviewPending: true` and must not be treated
as reviewed until the actual images are inspected. `findings` in that manifest
contains automated navigation-expectation failures; the table above records
visual findings discovered by inspection, which automation cannot infer.

Tests: `npm test`, `npm run check`, `npm run build`, the archive isolation tests,
synthetic data tests, and mutation-barrier tests. The native suite validates
rendering/navigation with fixture reads, **not real-provider ingestion or DVR
mutation correctness**, and is not screen-reader certification or owner UAT.
