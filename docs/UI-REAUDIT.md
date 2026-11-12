# Repeat whole-UI audit — guide, pop-ups and live-TV overlays

Work item: `AerioTV-Roku-iut`. Owner-requested repeat inspection, November 11,
2026. This report supersedes any implication in the earlier pill audit that
native alignment properties alone establish visually centered text.

**Outcome:** the owner was right. Guide, shared pop-up/live-overlay text and
some navigation/action surfaces still need correction. This is not a visual
approval and `iut` remains in progress.

## Completed repeat runs

| Run directory under `out/ui-reaudit/` | Starting-case executions | Captures | Native state observations |
| --- | ---: | ---: | ---: |
| `synthetic` | 129 | 341 | 392 |
| `supplement` | 19 | 55 | 49 |
| `corrections` | 21 | 92 | 100 |
| Total | 169, covering 146 unique starting cases | 488 | 541 |

All three runs completed without runtime/forbidden-operation errors or automated
navigation-expectation failures. **That does not mean the UI passed.** All 488
images were inspected across 84 contact sheets (12 shared, 18 library, 28
guide/live, 10 supplementary, 16 correction sheets); important findings were also
opened full-size. The fixture/recipe shortcomings discovered during inspection
and the corrected reruns are detailed below.

| Package | SHA256 |
| --- | --- |
| Full repeat probe | `96cf1ec4e313dd849a7f9cbc07dd63bcca7dd40866d2ccd1b440d119134293f0` |
| Supplement probe | `aaa2a92032f928d5f239eaedb6fb5a2ba123da713f9e6bb0c10fac134f85bd97` |
| Corrected probe | `df3d61a6ce6fc29a5075b764ee2188262f04fa1055322034786ad42b8e604ccd` |
| Input and restored owner-ready developer ZIP | `91f8b8b1f3c2f45e625588e198b8f0a66af963ea285d49e1a27483461afb8734` |

The current `--full` suite contains all 146 starting cases and the corrected
recipes. To repeat it, supply developer access in environment variables:

```sh
python3 scripts/build-ui-audit-probe.py --input out/pairing-tests/pill-ui/aeriotv-roku-v0.3.100-pairing-test.zip --output out/ui-reaudit/probe.zip
node scripts/test-ui-audit-native.mjs out/ui-reaudit/probe.zip out/pairing-tests/pill-ui/aeriotv-roku-v0.3.100-pairing-test.zip --full
```

Append defined starting-case names for a targeted repeat; `--run=<name>` keeps
its evidence separate. Generated manifests retain automated `findings` separately
from the visual findings in this report. Local review metadata is marked complete
only after actual inspection. Tests, compiler checks and package build passed;
fixtures are excluded from normal shipping packages.

## Scope and evidence rules

The installed owner-ready developer application was launched first. It showed
the saved Xtream connection's **session-only sign-in** screen. No credentials
were entered, extracted or changed. Actual provider-populated guide access and
overlays over decoded live video therefore remain **unverified in that app
session**. Do not call this end-to-end live playback acceptance.

For safe native rendering coverage, the isolated package is built from the exact
checksum-pinned owner-ready pill-UI ZIP, not a new application build containing
the owner's unrelated uncommitted cache/mapping work. The production guide is
configured with 24 synthetic channels and current/past/future programmes in its
real cache. Production rendering, navigation and menu construction remain intact.
The production Scene's `openPlayerOptions` builds actual main/submenu contents
from a synthetic snapshot record; no media node is given content or started.
`PlayerInfo` and `ChannelBrowser` are the real overlay components.
Navigation uses ECP key events through Roku's native focus engine, not a claim
of human-operated physical-remote or long-press integration acceptance.

Guide provider-load/detail timers are disconnected in the test hook; all Task
scripts remain replaced with the existing read-only fixture barrier. Artwork is
empty/local. Connection/record confirmations have their submit observer removed.
Directions and Back are exercised; settings values, recording confirmations,
channel-tune and media actions are not selected. The prior developer ZIP is
restored after each run. No gallery is handed off as an owner-testing app.

## Coverage inventory

Generated images/manifests live under ignored `out/ui-reaudit/`. The initial
installed-app image is private; do not commit it or publish its account context.
Synthetic captures may be inspected offline and regenerated from committed
fixtures. A completed capture run is **not** a visual pass.

| Surface family | Native fixture routes | What is inspected |
| --- | --- | --- |
| Welcome, connection setup and phone setup | Original `welcome`, `setup-*`, `phone-*`, large-phone routes | Action labels, hint pills, ready/expired/error states |
| Connection pop-ups | `connection-picker`, `connection-manager`, `connection-advanced`, `connection-auth`, `connection-forget` | Actual production dialog titles/choices; alternate focus, dismissal; no selection |
| Populated guide | `guide-populated`, `guide-sidebar`, `guide-basic` | Grid context, primary navigation, group navigation, overflow, scroll and Back; empty and gap variants |
| Guide pop-ups | `guide-options-real`, `guide-more-real`, `guide-layout-choices`, `guide-settings-real`, `guide-groups-real`, `guide-details-real`, `guide-gap` | Actual production menus/details, scrolling, focused/unfocused choices and Back |
| Live-TV options pop-up | `live-main` | Production main menu, lower choices reached by scrolling, dismissal |
| Live options submenus | `live-audio`, `live-subtitle`, `live-captions`, `live-audiomode`, `live-livetransport`, `live-scale`, `live-aspect`, `live-sleep`, `live-direction`, `live-clock`, `live-streaminfo` | Actual production choice construction; focus changes and return to parent through isolated routing; no value applied |
| Live information pop-up | `live-banner-playing`, `live-banner-paused`, `live-banner-buffering`, `live-banner-preview` | Now/next, descriptions, progress and remote hints; synthetic playback states only |
| Live channel/recent pop-up | `live-browser`, `live-recent` | Real production browser, group choices, scroll, watching marker, hints, Back/close |
| Playback error/history/diagnostic pop-ups | `popup-live-failure`, `popup-live-retry`, `popup-aac-failure`, `popup-diagnostics`, `popup-recent-history` | Production error and management dialogs, no retry/export/history deletion selected |
| Search | `search-populated` | Production result cards and non-result actions reached below results |
| Player controls | `player-controls`, `recording-controls` | Circular icon controls, alternate focused captions; no control activated |
| Record-once and series configuration | `record-flow`, `record-confirm`, `series-options`, `large-series-options` | Padding/recording/series choices and confirmations; no server writes |
| VOD/DVR | Full `ui-library-audit-cases.mjs` inventory | Repeats the populated catalog/personal-shelf/DVR-state, detail, confirmation and Back audit from `UI-LIBRARY-AUDIT.md` |
| Settings | All original Settings categories plus theme choice, remote subcategories and reset confirmation | Rail and detail focus, nested choices, long text; no setting/reset applied |
| Shared pop-ups and hints | Original duplicate/delete/diagnostic dialogs, native keyboard, hints | Pill alignment, alternate focus/dismissal; native keyboard styling remains accepted |
| Appearance variants | Large/light guide, sidebar, guide options/details, live options/banner/browser, plus prior library and Settings variants | Scale/contrast interaction and bounds, not just default appearance |

Additional guide-menu fixtures cover Manage groups, Startup group, Collections,
Favorite order, Reminders, Badges, optional TMDB settings and Jump to date. These
display production menus without selecting a setting. Populated collections,
saved reminder entries and deeper date/time choices are not separately claimed.

## Centering findings

The populated guide reproduces the owner's report. Explicitly bounded RGB ink
measurements supplement full-size image inspection; they are not OCR, universal
font metrics, or an automatic pass. Measurements use the visible pill fill's
center, not a guessed font baseline. `scripts/ui-audit-ink-bounds.swift` takes
explicit regions and emits ink bounds and center offsets.

- Guide group labels `All Channels` and `Favorites` sit about 2.5 pixels high
  at default size. **Measurement correction during the fix:** the original
  horizontal region counted the 3px fill inset twice. Correct fill x positions
  are 355.5 and 600.5; actual horizontal offsets are approximately -0.5 and 0px,
  not -3px. Do not apply a spurious horizontal shift to these labels. The
  primary-tab text-only horizontal displacement below is a separate real issue.
- Primary `Live TV` **text alone** is about 16.5 pixels right of the pill center;
  the combined icon/text run is approximately centered. This is the current
  `uiPillContent` composition policy, not proof that the requested text-centered
  result is delivered. Keep text centering distinct from whole-run centering.
- Live options `Audio track` sits about 2.5 pixels high. The first menu row's
  text has descenders and is approximately vertically centered; a single fixed
  offset for every string is not established as a correct fix.
- The `OK` hint in the live information overlay sits about 2.5 pixels high.
  Remote-hint line-box alignment needs the same rendered optical check.
- Shared confirmation `Cancel` sits about 2 pixels high; `Replace` (with a
  descender) is only about 0.5 pixels high. The programme-details recording
  action is about 1.5 pixels high and the Settings theme action about 2 pixels
  high. This is a shared font/ink-alignment issue, not just a guide-only case.
  The sampled Settings icon/text rail run is close to centered vertically.

Reproduce these samples with:

```sh
swift scripts/ui-audit-ink-bounds.swift scripts/ui-audit-ink-regions.json
```

The committed region definitions identify all twelve measurements. Positive
offsets mean right/down; negative means left/up. Pixel thresholds and glyph
side bearings make these approximate optical bounds, not a typography oracle.

These remain defects/follow-up under `iut`, not fixed production code. The
existing VOD selector geometry/heading collision and light-DVR hint-contrast
findings remain owned by `mrr.2` and `mrr.3` respectively.

## Other confirmed findings

| Finding | Native evidence | Tracking |
| --- | --- | --- |
| Live channel-browser **group choices** still use rectangular fills and left/high text; these are navigation, not content cards | `synthetic/live-browser--groups.jpg`, large/light variants; `ChannelBrowser.buildBrowserCanvas` group rows | `iut` |
| Search's Next page / Retry / Edit / Back **actions** remain rectangular, left/high labels; its footer is plain text rather than shared hint pills | `supplement/search-populated--action-rows.jpg`; `ProgramSearchView` uses content-card rendering for non-result actions too | `iut` |
| Small cap/join tabs remain visible on the bottom of the focused group-sidebar outline | `supplement/guide-sidebar-focus.jpg`, opened full-size; the prior seam claim is not accepted as complete | `iut` |
| Light guide title, unfocused primary navigation, date/ticks and hint descriptions lose contrast over the fixed dark Scene background; live browser header/hints have a similar contrast problem | `synthetic/light-guide-populated.jpg`, `light-guide-sidebar.jpg`, `light-live-browser--groups.jpg`, full-size inspection | `AerioTV-Roku-tm8` |
| Switching from populated programmes to an empty group leaves the old season/episode subtitle and lower description positioning visible | `synthetic/guide-populated--group-overflow.jpg`; `GuideView.drawGuide` returns before clearing subtitle/layout | `AerioTV-Roku-tk5` |

Do not turn channel rows, EPG cells, search results or poster cards into buttons
as part of fixing the navigation/action controls above.

## Fixture corrections, not product bugs

Image inspection caught weaknesses in the audit itself. Some original Up events
were clamped at the first dialog button; the revised recipe chooses a valid
direction and asserts focus actually moved. Group overflow could leave an empty
group before a supposed grid-scroll test; the revised recipe returns to All
Channels and asserts populated selection progress. Long options menus now move
in overlapping seven-row steps through the last choice, rather than stopping in
the middle of a list.

The subtitle snapshot initially used audio-track field names and rendered the
real "No subtitle tracks" state. The corrected fixture uses Roku subtitle
`trackName`/`description` fields. Banner cases initially inherited the previous
paused playhead, so some later "playing" images are actually delayed-state
renders; the fixture now clears playhead between cases, with default buffering/
preview rerun. Those earlier large/light banner images still demonstrate the
delayed layout, not fresh live timing. Settings What's New/license fixtures now
highlight their real About parent in the rail. None of these fixture corrections
is counted as a production UI fix.

## Limits — do not turn representative coverage into “everything passed”

The source inventory also contains provider/permission-specific messages,
archive/catch-up actions and skip-interval dialogs, optional metadata discovery,
support-code sharing, and system keyboard invocations with varying titles.
Shared-renderer coverage does not prove every message length or permission
combination. No live decoder, actual remote long-OK-to-options integration,
system caption setting change, media error recovery, or provider/DVR mutation
is performed by this isolated re-audit. Those paths are not declared passed.

No production centering fix or new signed Beta/Store package is delivered by
this inspection. `iut` remains open until defects are fixed and fresh native
images, including the owner's real-session guide/live context, are accepted.
