# AerioTV for Roku

Native BrightScript/SceneGraph port of AerioTV, targeting the **Roku Streaming
Stick 4K and Dispatcharr 0.31.0**. The product goal is Apple TV visual/behavioral
parity with deliberate Roku remote adaptations. Distribution starts with personal
sideloading. The deployment consists of the Roku and the existing Dispatcharr
instance; no additional service/container is required by this build.

For the current feature-by-feature comparison against upstream AerioTV, see the
[parity audit and remaining-work inventory](docs/PARITY-AUDIT.md).

## Work tracking

**Beads is the authoritative execution backlog.** Epics contain child stories,
bugs, investigations, decisions and verification work. User-facing stories use
the standard `feature` type with the `story` label. Audit references are searchable
labels such as `audit-p09`; platform investigations also carry `spike` or
`feasibility` labels. Priorities express ordering, not a committed sprint schedule.

```sh
bd ready --json
bd list --type epic --json
bd list --parent <epic-id> --json
bd show <issue-id> --json
bd list --label audit-p09 --json
```

The audit and port plan are reference snapshots, not parallel status boards.
Update acceptance evidence, dependencies and work status in Beads. This project
uses the installed Dolt-backed Beads workflow; remote synchronization setup is
tracked in the delivery epic.

The GitHub repository is `EndofLineTech/AerioTV-Roku`; development is on `dev`.
The tracked `.beads/backlog-snapshot.json` archives issues, dependencies, comments
and labels from the local Dolt database. Refresh it with
`node scripts/snapshot-beads.mjs` before committing backlog changes. It is a
reviewable backup, not automatic Beads synchronization; the live Dolt database
and runtime files are ignored by Git. A remote Dolt destination and restore drill
remain tracked under `AerioTV-Roku-rgs.11`.

## 0.3.0 — Live TV compatibility and Guide discovery

The implementation pass for the Live TV and Guide epics is ready for combined
acceptance. Use [FINAL-TEST-RESULTS-0.3.0.txt](docs/FINAL-TEST-RESULTS-0.3.0.txt)
for PASS/FAIL/SKIP results. Physical acceptance remains separate from automated
and scripted-device evidence; Beads records the outstanding acceptance gates.

### Live TV changes

- **Automatic audio compatibility:** if native playback reports no audio, retry
  this client once with an existing active FFmpeg copy-video/AAC output profile
  discovered from Dispatcharr. Successfully repaired channels are remembered per
  account. Direct and Always AAC choices are in player options. The app does not
  create profiles, change the shared upstream or introduce a new service. A retry
  is a client retune and waits while menus/controls are in use.
- **Held Up/Down:** previews repeat after 400 ms, then every 150 ms; release
  coalesces a single tune. Context changes cancel the hold; a 10-second guard
  prevents an indefinitely stuck key.
- **Browser logos:** eight poster nodes and their HTTP agent are reused across
  openings within the same connection. Failed images can retry on reopen.
- **Clock format:** System/12-hour/24-hour preferences apply to guide, player,
  details and search. Explicit UTC references remain 24-hour.
- **Channel search:** searches the full authorized lineup; Clear restores the
  selected group. A direct-number action remains scoped to the visible list.

### Guide controls

Open guide **`*`** and scroll to **Guide settings**, **Manage groups**,
**Collections**, **Favorite ordering**, or **Program reminders**.

- Show/hide groups; Default/alphabetical/manual order; startup group independent
  from the last browsed group. A fallback prevents an all-hidden navigation trap.
- Top group pills or a sidebar overlay with debounced preview. Up from the first
  channel enters navigation; Down/OK (pills) or Right/OK (sidebar) returns to the
  grid. The modal group-list fallback is always available.
- Number/name/ID channel sorting, stable decimal ordering, manual favorite order
  and a Recently Watched guide group. Player browser ordering follows these
  preferences while Recent remains chronological.
- Up to 20 named collections with add/remove selected channel, rename/delete,
  collection/member ordering and First/Last selector placement. Membership uses
  compact channel IDs and is account-scoped. Registry limits still apply; failed
  persistence is reported rather than silently claimed successful.
- Fast Forward/Rewind page through channels, Jump to Top, and a decimal-aware
  Go to channel number keyboard.
- History/future depth choices of 1/3/7/14/30 days. “All available” explicitly means
  bounded to 30 days each way. The three-window resident guide cache is independent
  of browsing depth. Date jumping groups Today/Upcoming/Previous and preserves UTC
  references for repeated DST hours.
- Scoped lineup refresh preserves selection/time and ongoing authorized playback.
  A channel removed from the authorized lineup is stopped explicitly. Guide/detail
  cache clear and refresh do not retune otherwise-valid playback.

### Program information, artwork and reminders

Guide data retains reported New/Live/Premiere/Finale and episode facts. Detail
enrichment is debounced, coalesced and cached in at most 32 entries for five minutes,
with bounded failure backoff. Selected programs and a limited visible set are
enriched progressively; the entire lineup is not fetched program-by-program.

Rich details include available rating/year/quality/language/country/cast and
artwork, with separate Watch LIVE and reminder actions. Per-badge controls and
category colors/rules are in Guide settings. Default precedence begins
Kids > Sports > News > Movies, followed by additional source-inspired buckets.
Focus overrides category tint; unavailable metadata remains neutral.

Artwork preserves aspect and bounded decode sizes. Dispatcharr headers are applied
only to same-origin artwork; external HTTPS artwork uses a separate plain agent.
Optional TMDB fallback is off by default. Its v3 API key can be tested/saved in the
device registry; fallback opt-in is per account. It searches program titles only
when indexed detail data lacks a poster and uses only a single exact-title match.
Ambiguous matches, missing keys and failures leave provider text usable. The
approved TMDB logo and non-endorsement attribution accompany TMDB artwork.

Up to 50 account-scoped reminders alert once in the foreground, about five minutes
before a program starts (or late if opened during an unnotified airing). Details
and the reminders menu support cancellation; guide cells show REM. Refreshed
windows reconcile schedule changes and suppress reminders whose saved program
disappeared; expired/unauthorized entries are cleaned up. No background delivery
is promised.

### Verification

Fourteen automated suites cover models, storage adapters, controller handlers and
the source Task flow. Native probes verified AAC decode on the affected ESPN
channel, healthy-channel direct audio, guide settings/pills/sidebar/details focus,
collection membership and reminder cancellation, held-key tune coalescing, and
poster-node reuse. The final package excludes test code and diagnostic autoplay.
See [device evidence](docs/DEVICE-VALIDATION.md) for limitations and remaining
physical checks, including a separately tracked unexplained device restart.

## 0.2.13 — Player-menu, transport-focus and mini-caption fixes

The Video now requests Options-key override and is non-focusable. Bare playback
uses a dedicated input Group whose keys bubble to the Scene. This corrects the
native focus handoff observed when trying to focus the Scene itself. The app menu
is branded **AerioTV player options**, with another entry in the mini-guide's
options menu. OK → Down → Options remains an alternate route.

Explicitly opened information stays visible until dismissed; the automatic
tune-in banner still expires after eight seconds. Entering transport reasserts
visibility and focus, and keys reaching the Scene while controls are active are
routed back to them. Native scripted Up/Left/Right transitions now return to the
input Group correctly and re-enter transport consistently.

The mini-player is 400×225 at [1424,16]. Its single-line caption ends at y=267,
above the guide timeline at y=270. A device screenshot confirms the separation.
Twelve suites and compiler/build checks pass. Installed 0.2.13 launches normally;
temporary native probe code is removed. Physical star-key interception and the
reported sequences need the [focused retest](docs/RETEST-0.2.13.txt).

## 0.2.12 — Source-switch continuity checks

Source changes now compare the original Dispatcharr client identities against
the confirmation snapshot. Messages distinguish clients still listed, clients
missing, and insufficient data. Equal client counts alone are not treated as
continuity evidence; client identifiers/IPs stay out of UI results and logs.
This is a point-in-time check, not proof of uninterrupted viewing.

Selecting the URL-confirmed active source sends no mutation. Invalid operations,
changed account identity, revoked admin permission and non-member sources are
rejected; mutation failures are not automatically retried. Confirmation polling
respects the overall Task deadline. Source transitions also cancel old server
metadata requests so late callbacks cannot repopulate obsolete Stream Info.

Twelve automated suites pass, including the actual source Task body with scripted
HTTP responses. A separate native read-only probe successfully fetched six member
sources and one active client on the target device. Real source mutation and
multi-viewer continuity remain part of final acceptance. The diagnostic autoplay
was removed; the installed 0.2.12 app launches normally into the guide.

## 0.2.11 — Scaling preview and server-reported stream details

Installed on the target Stick. **Player options → Video scale preference** offers
native Fit plus Fill/Stretch previews using a clipped video viewport. Fill and
Stretch ask for this channel's source aspect (4:3, 16:9 or 21:9) when unknown;
that override is account-scoped and saved per channel. Unconfigured channels fall
back to Fit. The preferred mode applies to fullscreen and mini-player without
replacing the Video/content session. Final visual crop/distortion acceptance is
still required; the native fixture verified transforms, clipping and playback.

Stream Info now requests existing Dispatcharr status metadata for admin accounts
and shows **Server resolution**, **Server source frame rate**, video/audio codec
and pixel format separately from native decoder facts. These values depend on
server metadata availability and may describe cached upstream data. Pixel
dimensions are not silently treated as display aspect, because SAR/DAR matters.
See [aspect/metadata research and native fixture procedure](docs/VIDEO-ASPECT-RESEARCH.md).

Eleven automated suites and compiler/package checks pass. Native installation,
launch and capability refresh succeeded. The normal app is installed after the
temporary test-pattern package; no fixture autoplay is present in it.

## 0.2.10 — Measured native diagnostics and player polish

Installed on the target Stick. Stream Info now includes the native rendered,
dropped, repeated-frame and stream-error counters measured on OS 15.3.4. Counter
snapshots are cleared on retune/Stop and repopulated by current playback events.
The tested continuous MPEG-TS stream reported no native resolution or source
frame rate, so those fields remain explicitly unavailable.

The mini-guide footer now describes Fullscreen/Stop correctly. Channel and recent
rows distinguish missing/loading/unavailable program data and label cached titles.
Channel surfing outside the guide's current filter explains how to resume browsing.
Source-change loading explains that closing its menu does not undo a submitted
shared-source request.

A temporary native playback probe verified `playing` through minimize/expand and
Hide picture with unchanged ContentNode identity and increasing render counters.
A shortened sleep deadline stopped playback once and cleared the cover. This
does not establish perceived audio/video quality or Dispatcharr client identities;
those remain in the deferred acceptance record. Probe autoplay/timers were removed
before the final package, which launches into the guide normally.

Ten automated suites, compiler checks and packaging pass. Fit/Fill/Stretch
(`ihp.10`) is blocked pending a supported, measured hardware-video mapping. The
epic remains open for that platform gap and final physical acceptance.

## 0.2.9 — Foreground listening and nested player menus

Installed on the target Stick, including the 0.2.8 program-search and sign-in
policy changes. Native compilation/launch and Dispatcharr capability refresh
succeeded. All ten automated suites pass; physical acceptance remains deferred.

**Player options → Hide picture (foreground listening)** covers the existing
video with black. The explanation fades after six seconds. Play/Pause and the
sleep timer remain active; a navigation key restores the picture and is consumed
through its release so a held wake key cannot immediately change channels.
Stop, errors, retuning and mini-player transitions remove the cover. This is a
foreground presentation mode: keep AerioTV open. The full video stream is still
received/decoded; background playback and TV power control are not provided.

**Back** now returns from player submenus to the parent menu, restoring the
parent option's focus. Back from source-switch confirmation returns to the source
list. **`*`** dismisses the menu to playback. Reopening a pending source operation
shows its loading state instead of appearing unresponsive.

## 0.2.8 — Program search and remembered sign-in policy

In the guide, open **`*` → Search programs → Title or Description**. Submit a
2–120-character query to search server-indexed airings from three days back to
seven days ahead. Dispatcharr's quoted phrases and AND/OR operators are supported.
Results show the effective channel name/number, local airing time, Past/Now/Upcoming
state and focused-program description. **OK** opens that channel/time in the guide;
it does not tune immediately. Channel filters are cleared only when needed to
show a selected result outside the current filter.

Results use explicit Next/Previous pages with 50 server programs per request and
a 200-airing display cap per page. Requests run only on submission/page actions;
Back, editing, leaving the guide or changing accounts cancels the current Task.
The existing channel-name/number search is separate. Returned channel IDs and EPG
mappings are checked against the connected lineup. Only programs indexed by
Dispatcharr's search endpoint can appear; dummy/unindexed schedules and effective
EPG overrides not represented by that endpoint may be absent.

**Remember API key** now persists independently of the key. Off immediately
removes the saved key, stays Off after relaunch, and prevents loading a residual
saved key. On stores a key only after a successful connection. Forget removes
connection/account data while retaining this device policy. Existing installations
without a policy retain the previous On default; malformed policy values use Off.
Storage failures are reported rather than silently claiming the choice was saved.

Nine model suites and compiler/build checks cover the local build. Native search,
keyboard/focus, paging, and registry-relaunch acceptance are deferred in Beads
(`AerioTV-Roku-5tg.11`, `AerioTV-Roku-b17.3`) until device testing is available.
These additions are included in the installed 0.2.9 package.

## 0.2.7 — Live TV navigation preview

This development build adds account-scoped recent/previous channels, an in-player
Channels/Recently Watched browser, a corner mini-player using the existing Video
session, focusable transport actions, and a 30/60/90/120-minute sleep timer.

During playback, **Up = next / Down = previous** by default (configurable in
player options). **Left** opens Channels, **Right** returns to the previous
watched channel, and **Replay** opens Recently Watched. **OK**, then **Down**, enters
transport controls. **Back** dismisses explicit info/overlays, then minimizes to
the guide; Back from the guide expands the mini-player. Stop is an explicit menu
action. See the [remote contract](docs/PLAYER-CONTRACT.md).

Player options also include **Stream Info** and, for verified Dispatcharr admins,
**Switch stream source**. Source switching rechecks account permission and channel
membership, explains its shared-viewer effect, and confirms the server's source
URL without reloading the Roku player. Provider URLs are excluded from menu data.
Stream Info displays native facts or `Unavailable`; decoded resolution/frame
rate mapping and Fit/Fill/Stretch remain under investigation.

All eight off-device suites and the compiler/build pass. The developer installer
accepted 0.2.7, native launch succeeded, and the capability Task reported an admin
account on Dispatcharr 0.31.0. Physical-remote, playback-continuity, source-switch,
and persistence acceptance for these additions is still pending. Evidence and
platform constraints are recorded in [device validation](docs/DEVICE-VALIDATION.md).

## 0.2.6 — Live information overlay (verified baseline)

The player now displays the channel/logo, current on-air program, synopsis,
start/end times, schedule progress, remaining broadcast minutes, and **Up next**.
It appears when tuning and can be shown/hidden with **OK**, without pausing.
During normal playback it hides after eight seconds. Metadata refreshes do not
reopen a dismissed panel or steal focus.

The guide cache continues updating during playback. Now/next and program rollover
are selected from UTC schedule times; the visible clock/progress update every
second. Missing, loading, stale, and unavailable metadata have explicit states.
The progress bar follows the broadcast schedule, including when paused; it does
not represent a seekable buffer or the paused frame's position.

The Scene now owns playback keys because Roku's focused Video node consumes OK
as pause even when its transport UI is disabled. **`*` opens an in-app audio,
subtitle-track and caption-mode menu**, replacing the native Roku Options panel.
Play/Pause, Up/Down and Back are handled separately. Caption-mode changes use
Roku's system-wide setting, as stated in the menu. Short pause/resume is not a
guarantee of the planned 60-minute rewind window.

Verified on the target Stick: the user confirmed the overlay and all controls
work; a device screenshot confirmed populated now/next information, logo,
schedule progress and paused-state indicator. Exact-boundary rollover, overlap,
gap, stale-data, long-program lookahead and track mapping have regression tests.

### Earlier playback and guide improvements

In 0.2.4–0.2.6, fullscreen playback handled **Up = previous channel** and **Down = next
channel** within the guide's current group/favorites/search results. Endpoints
do not wrap or retune the same channel; the banner identifies the boundary.
Rapid key presses are coalesced for 250 ms before tuning. Back cancels a pending
switch and returns to the currently tuned channel in the guide.

This was tested with the physical remote on the target Stick. Native logs showed
404 → 405 → 404 and additional successful switches; the user confirmed Up/Down,
Roku `*` Options and Back worked in 0.2.4. That version retained Video focus;
0.2.6 uses the app-owned player controls described above.

Live playback now uses Dispatcharr's **MPEG-TS output** with Roku's `mpegts`
reader. The previous MP4 reader failed with “Full-content response on a range
request”: it expected byte-range responses from a continuous stream. On the
target Streaming Stick 4K, the MPEG-TS test reached `playing` in about 1.6 seconds,
and the user confirmed **both picture and audio**. No server configuration or
additional service was needed. This validates the tested channel/device, not
every provider codec or the future rewind window.

The temporary autoplay smoke test has been removed. Normal launch opens the
guide; select a current program to watch. Playback failures now retain and report
sanitized native diagnostics instead of the old generic experimental-format message.

Fixes a device-confirmed crash after a successful channel load: SceneGraph task
nodes must be compared with `isSameNode()`, not `<>`. The connection and guide
completion handlers now use that API. The corrected build was installed on a
Streaming Stick 4K (3820RW2, OS 15.3.4 build 2402), and a captured device screen
confirmed a populated **1,335-channel guide** with program data and logos.

Connect is now a filled teal action button; Forget Connection is a separate
rose-outlined action. Loading shows the current stage/page and elapsed time,
with Back to cancel and a 120-second connection watchdog. Native timeout and
retry scenarios still need device acceptance; they are not implied by the
successful connection test.

Fixes the missing text reported on the initial setup screen: the shared label
helper now retains Roku's resolved default font instead of assigning a Font with
an empty URI. A regression test covers font-face preservation at the sizes used
for captions, fields, program titles and headings. The user confirmed that text
now renders correctly on the device.

Implemented (device acceptance is partial; see the checklist):

- Dispatcharr API-key or dashboard username/password setup.
- Optional saved API key and automatic reconnect; dashboard passwords are never saved.
- Account-scoped favorites, selected channel, and channel group.
- EPG landing screen: seven reusable rows, channel logos, time-scaled programs,
  focused-program details, current-time line, and missing-guide states.
- Three days back / seven days forward navigation, subject to server data.
- Three-hour guide requests, neighboring-window prefetch, a three-window LRU cache,
  five-minute freshness, request cancellation, and retry backoff.
- Groups, channel name/number search, date/time picker, Jump to Now, and program details.
- Dispatcharr 0.31 summary/effective channel values and explicit EPG-ID → TVG-ID mapping.
- Live playback using Dispatcharr's existing MPEG-TS output, with the live info
  overlay and app-owned remote controls/audio-caption options.

**This is not a completed or pixel-identical port.** Unit tests and compilation
do not establish device rendering, playback, remote behavior, or memory performance.
See [device validation](docs/DEVICE-VALIDATION.md).

Further player controls and visual polish, VOD,
catch-up/restart, and a verified 60-minute pause/rewind window remain on the
[port plan](docs/PORT-PLAN.md). Past-program details currently offer **Watch channel
live**, explicitly; selecting past guide data does not play its archive.

## Build

Use Node.js 22 or newer and npm:

```sh
npm ci
npm test
npm run check
npm run build
```

Sideload archive: **`out/aeriotv-roku.zip`**. The package contains the manifest,
application scripts/components, and license/attribution notices. Build tools,
tests, and credentials are excluded.

## Install

1. Enable Roku developer mode: from Home press **Home three times, Up twice,
   Right, Left, Right, Left, Right**. Follow the setup and record the Roku IP.
2. From the same network, open `http://<roku-ip>`; log in as `rokudev` with the
   developer password.
3. Upload the ZIP and choose **Install**. This replaces any existing sideloaded
   development channel on that Roku.
4. Enter the final Dispatcharr base URL and choose **API key** or **Dashboard
   username and password**. These are dashboard credentials, not XC credentials.
5. Select **Connect**. The guide opens around Now after channels and EPG mappings load.

### Connection storage

**Remember API key** is on by default and can be turned off before connecting.
The key is stored in the Roku app registry, not Apple Keychain or an encrypted
credential vault. Login exchanges the dashboard password for the account's API
key; only that key is eligible for saving. Relaunch uses the saved key. Rotated
or revoked keys require signing in again.

Turning Remember off removes the saved key. **Forget connection** removes the
saved URL, key, favorites and selected group/channel. Only the most recently
connected account's preferences are retained. Changing the URL clears the entered
credentials, preventing accidental reuse at a different server.

## Remote controls

| Screen | Control | Action |
| --- | --- | --- |
| Connection | Up/Down, OK | Edit fields, switch sign-in method, connect |
| Connecting | Back | Cancel |
| Guide | Up/Down | Change channel while retaining selected time |
| Guide | Left/Right | Move to previous/next program or missing-data interval |
| Guide | OK on current program or no-data cell | Watch channel live |
| Guide | OK on past/future program | Program details; explicit Watch channel live action |
| Guide | `*` | Details, favorites, groups, search, date/time, Now, refresh, settings |
| Guide | Instant Replay | Jump to Now |
| Guide | Back | Connection settings |
| Menu | Back | Close and restore guide focus |
| Player | OK | Show/hide now/next information without pausing |
| Player | Play/Pause | Request native pause/resume; retained duration depends on stream/device |
| Player | `*` | Audio track, subtitle track, and caption mode menu |
| Player | Up / Down | Previous / next channel in the current guide filter |
| Player options | Back or `*` | Close menu and return to playback |
| Player | Back | Stop and return to the same guide selection |

The date picker displays local calendar days and half-hour times with a UTC
reference to distinguish repeated daylight-saving hours. A missing spring-forward
hour is not offered. The guide follows the current time until you navigate
horizontally or jump to a historical/future time.

## Live playback transport

The live route is:

```text
/proxy/ts/stream/<channel-uuid>?output_format=mpegts
```

Dispatcharr 0.31.0 emits `video/mp2t`; the Roku Video node uses `mpegts`. This
combination was exercised on model 3820RW2 / OS 15.3.4 build 2402 with working
picture and audio. The fMP4/`mp4` combination was tested and rejected by Roku's
HTTP range reader. It is not used as a fallback.

Additional codecs, long-duration playback, repeated tuning, and seek/pause behavior
still require testing. Successful live viewing is not proof of a 60-minute buffer.

The old 0.1 `/proxy/hls/...` candidate was removed because that route is not wired
into 0.31.0's proxy URLs. This build does not add a proxy, transcoder, recording
service, HLS endpoint, or claimed DVR window. A failed compatibility test is a
decision point about existing server configuration/stream support.

## Development layout

```text
components/AerioScene.*       Setup, account persistence, player lifecycle
components/GuideView.*        Guide rendering, focus, menus, window orchestration
components/DispatcharrTask.*  Login, identity, channels, groups, EPG mapping
components/GuideTask.*        Three-hour EPG fetch and normalization
components/PlayerInfo.*       Now/next overlay, clock, schedule progress and logo
components/PlayerOptions.*    App-owned audio/caption track menus
source/DispatcharrHttp.brs    Task-thread HTTP helpers
source/DispatcharrModel.brs   Provider normalization and channel filters
source/GuideModel.brs         UTC times, guide cells, navigation, bounded cache
source/SceneUi.brs            SceneGraph creation and local-time formatting
source/PlaybackModel.brs      Verified live transport and sanitized failure messages
source/NowNextModel.brs       Schedule selection, progress and bounded lookahead
tests/                       Off-device model tests, including 1,400 channels
docs/                        Architecture, UI specification, device checklist
```

Guide limits: three cached windows, 24,000 normalized programs per window, 128
rendered cells per row, and a 16 MB JSON parsing limit per HTTP response. Excessive
input produces an explicit error/state. HTTP transfers still buffer complete
responses before the parsing limit is checked. Channel and EPG mapping catalogs
are loaded at connection time; their peak memory also needs device measurement.

`brs@0.39.0` runs only pure-model tests. Its newer release adds an archive-extraction
dependency with a critical advisory. It is not a Roku emulator. The initial audit
has four moderate development-tool findings in the `uuid`/`brs` and
`decode-uri-component`/`source-map-resolve` chains. These tools are excluded from
the ZIP; dependency replacement remains build-tool follow-up work.

## References and licensing

- [AerioTV](https://github.com/jonzey231/AerioTV), reference commit
  `8d5818456e0f4421d93b8ff120ad878d63331091`.
- [Dispatcharr v0.31.0](https://github.com/Dispatcharr/Dispatcharr/tree/v0.31.0),
  commit `bcbb68c4f054ee56383a41604cfcd7302b85da66`.
- [License notice](LICENSE.md) and [attribution](NOTICE.md).

AerioTV is Copyright (C) 2026 Logan Jones and contributors, GPL-3.0-or-later.
This port uses the same license and is an independent development preview.
