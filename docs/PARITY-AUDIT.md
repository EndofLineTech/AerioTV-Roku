# AerioTV → Roku feature-parity audit

**Date:** 2026-09-18

**Roku baseline:** 0.2.6, the current source and installed development build

**Upstream baseline:** [`jonzey231/AerioTV` at `8d5818456e0f4421d93b8ff120ad878d63331091`][upstream]
— confirmed as `main` at review time and the same revision originally selected.

**Execution tracking:** this document is the frozen comparison baseline. Current
work lives in Beads (`parity-audit` label), with audit-row labels such as
`audit-t02` linking implementation, verification or scope-decision issues to
this inventory. Use `bd ready --json` and `bd list --type epic --json` for current
status and sequencing.

## Executive assessment

We have a working **Dispatcharr Live TV / EPG slice**, with real-device evidence
for a 1,335-channel guide, live MPEG-TS playback, channel switching, now/next
information, and the basic audio/caption controls. We do **not** yet have broad
AerioTV product parity or an identical Apple TV interface.

The largest absent areas are:

1. Live rewind, seekable timelines, catch-up and program restart.
2. Movies/series and their browsing, metadata, resume and watchlist systems.
3. Server DVR and recording management.
4. The mini-player, in-player channel browser, last-channel toggle and recents.
5. Rich guide organization, artwork/badges and program search.
6. The settings/appearance/remote-customization system.
7. Additional providers, multi-playlist management, sync and companion integration.
8. Multiview, subject to Roku hardware feasibility.

A feature-count percentage would be misleading: a caption toggle and the entire
VOD subsystem are not comparable units of effort. The matrices below identify
concrete behaviors instead.

### Scope and evidence

- Compared the entire upstream README feature inventory, current release-note
  highlights, tvOS settings/action entry points, and the relevant models,
  services, player and library implementations.
- Read all current Roku runtime `.brs`/`.xml` files, the manifest, all six test
  suites, and the recorded hardware verification results.
- This is a **feature-level source audit**, not a claim that the upstream Swift
  implementation has been executed or reviewed line-by-line for correctness.
- Source revision is authoritative here; a current App Store/TestFlight binary
  may differ. There is no running Apple TV available for direct visual comparison.
- Existing constraints remain: Streaming Stick 4K, Dispatcharr 0.31.0,
  800–1,400 channels, EPG first, three days back/seven forward, personal sideloading,
  and **no additional service/container**. The 60-minute rewind target remains a
  requirement to prove, not a capability inferred from the working Pause button.

### Status meanings

| Status | Meaning |
| --- | --- |
| **Present** | A corresponding behavior exists in Roku code. This does not mean every edge case or hardware combination has been verified. |
| **Partial** | The basic behavior exists, but important upstream functionality, choices or fidelity are absent. |
| **Missing** | No corresponding active Roku implementation was found. |
| **Adaptation** | Missing or different, and a platform-specific design/feasibility decision is needed. |
| **Excluded** | Not an active current-tvOS feature, or specifically a mobile/Apple-system capability rather than a direct Roku parity requirement. |

Hardware verification limits are listed separately in §9 and
[DEVICE-VALIDATION.md](DEVICE-VALIDATION.md).

## 1. Important corrections to the README-only feature picture

The code changes the interpretation of the published list:

1. **Apple TV is guide-only at this revision.** `TVListView.enabled = false`
   explicitly hides the standalone Live TV List and its settings. Its source is
   retained. A missing standalone List screen is therefore **not** a current-tvOS
   parity defect. The separate **in-player Channels overlay is active** and is
   missing on Roku. [TV list flag][u-tv-list], [player channel overlay][u-channel-overlay].
2. **Local live rewind exists in code.** Settings expose 15/30/60/90/120/180-minute
   depths and optional retention of 1–5 recently watched channels. The underlying
   implementation owns a rolling on-device TS buffer and readers. Roku's native
   pause request is not equivalent. [Rewind settings][u-player-settings],
   [buffer implementation][u-rewind].
3. **Catch-up is implemented beyond what the README describes.** There are
   native Dispatcharr catch-up sessions, XC fallback, seek re-minting, position
   reports and session revocation. However, the guide's `canReplay` gate requires
   a program to have **ended**. Your requested **restart of an in-progress
   program** needs its own validation; it is not established simply by an enum
   named `restartProgram`. [Catch-up implementation][u-catchup],
   [ended-program gate][u-replay-gate], [action dispatcher][u-player-dispatch].
4. **Compressed XMLTV is implemented.** The README still calls `.xml.gz` a future
   feature, while the parser detects gzip by extension/type/magic and stream
   decompresses it. Roku has no XMLTV parser at all. HTTP gzip decoding for JSON
   is not this feature. [XMLTV parser][u-xmltv].
5. **The current engine routing is not simply “MPV-powered.”** The source has
   direct-HLS and TS-remux AVPlayer routes, unified playback, and an mpv switch
   that defaults **off** in this snapshot. Engine names are not themselves Roku
   UI features; compare playable formats, recovery and user behavior instead.
   [Actual engine flags][u-engine].
6. **tvOS reminders are state-only in the inspected implementation.** The
   five-minute notification/banner path is iOS-specific. Missing reminder state
   is a real gap, but an Apple TV background notification must not be assumed.
   [Reminder manager][u-reminders].
7. **Do not count every remote-action enum case as a working feature.** For
   example, the inspected tvOS dispatcher falls through for `restartProgram`,
   `jumpToLive` and `openSearch`. A separate Go Live transport control does exist
   for live rewind, and the application has a real global Search screen.
   [Dispatcher][u-player-dispatch], [transport controls][u-transport],
   [search implementation][u-search].
8. **Emby/Jellyfin helpers are not evidence of supported product connections.**
   `MediaServerAPIs.swift` contains helpers, but `ServerType` exposes only
   Dispatcharr, Xtream Codes and M3U, and no Emby/Jellyfin constructor call sites
   were found in the inspected application sources. They are not counted as
   missing supported providers. [Server types][u-server-model].
9. **Store methods are not necessarily exposed controls.** Favorites has saved
   ordering/sync logic, and collections has rename/reorder methods. Current TV
   call sites establish collection creation, membership, placement and deletion;
   a current TV rename/member-reorder UI was not established. Those latent methods
   are not treated as verified user-facing controls. [Stores][u-collections].

## 2. Connections, providers and account behavior

Roku evidence: [connection controller][r-scene], [connection Task][r-connect],
[HTTP helper][r-http], [provider model][r-provider].

| ID | Feature | Roku status and remaining gap | Upstream evidence |
| --- | --- | --- | --- |
| C01 | Dispatcharr API-key and dashboard login | **Present.** Dashboard login obtains the account API key; the password is discarded. The API-key path and saved-key reconnect are device-proven; dashboard-login failure cases still need acceptance. | [Direct Connect][u-auth] |
| C02 | Automatic credential/session recovery | **Missing.** No JWT refresh/re-login or silent re-bootstrap after API-key rotation. Roku switches to the durable key, so this is not a claim that its API calls expire after 30 minutes; a revoked key requires manual login. | [Direct Connect][u-auth] |
| C03 | Multiple named playlists/servers | **Missing.** One remembered connection and one last-account preference set; no saved server collection, switcher, names or reordering. Switching identities discards the old preference set rather than retaining each playlist's state. | [Server model][u-server-model], [home/stores][u-home] |
| C04 | Account channel visibility | **Present for the 0.31 contract.** Roku uses the server-scoped channel summary and guide. A restricted-role/profile acceptance matrix is still outstanding. | [Account model][u-server-model] |
| C05 | User-selected channel profile | **Missing.** No chooser for a narrower Dispatcharr profile beyond the server's account visibility rules. | [Selected-profile property][u-server-model] |
| C06 | Local/WAN connection selection | **Missing.** No optional local URL, LAN reachability probe, automatic local/WAN switching or local EPG URL. One entered base URL is used. | [Playlist editor][u-edit-server], [server details][u-server-detail] |
| C07 | Advanced HTTP configuration | **Missing.** No per-server User-Agent override or auth-header-mode detection/selection. Roku sends a fixed User-Agent and both API-key headers. | [Server model][u-server-model], [playlist editor][u-edit-server] |
| C08 | External XMLTV override | **Missing.** No independent guide URL, XMLTV parsing, gzip feed support or alternate guide-source management. | [XMLTV parser][u-xmltv], [playlist editor][u-edit-server] |
| C09 | Xtream Codes | **Missing.** No login/provider adapter, category/EPG/VOD ingestion, archive resolver or provider URL fallback. | [README][u-readme], [streaming APIs][u-catchup] |
| C10 | M3U + XMLTV | **Missing.** No playlist URL parser/import workflow or XMLTV source setup. File-import affordances would additionally need a Roku-appropriate design. | [Playlist import][u-import], [XMLTV parser][u-xmltv] |
| C11 | Capability-aware application surfaces | **Missing beyond delegated channel visibility.** No cached DVR/VOD/catch-up capability snapshot, version probe, capability refresh or conditional future-tab/action gating. | [Server capabilities model][u-server-model] |
| C12 | Credential storage and setup-once | **Partial / adaptation.** Optional local registry API key and Forget work; no Keychain/iCloud equivalent. The Remember toggle itself is initialized to On rather than persisted as a preference. | [Server/credential model][u-server-model], [sync categories][u-sync] |

## 3. Guide, channel organization and search

Roku evidence: [GuideView][r-guide], [guide models/cache][r-guide-model],
[normalized fields][r-provider], [guide Task][r-guide-task].

| ID | Feature | Roku status and remaining gap | Upstream evidence |
| --- | --- | --- | --- |
| G01 | Time-based guide, Now marker, logos, program title/time | **Present.** Seven reusable rows, clock-based selection, decimal numbers and effective EPG mapping. The populated real guide is verified. | [Guide implementation][u-guide] |
| G02 | Configurable guide depth | **Partial.** Three days back/seven forward is hard-coded to our agreed target. No per-playlist 1/3/7/14/All Available choice. | [Playlist editor][u-edit-server] |
| G03 | Cache-first launch and retained guide history | **Partial.** Three in-memory three-hour windows with refresh/prefetch; no persistent channel/EPG cache or per-day coverage restored on launch. Browsable ten-day scope is not ten days stored locally. Historical data must still be available from Dispatcharr. | [Guide cache][u-guide-cache], [home/stores][u-home] |
| G04 | Guide layout modes | **Partial.** A source-inspired Channel Preview layout only. No Basic/full-cell layout switch or configurable density. | [Live TV settings][u-live-settings] |
| G05 | Group navigation | **Partial.** Modal group picker works. No top group pills, docked sidebar, overlay/shift-guide layout, or focus-preview of groups while browsing the sidebar. | [Live TV settings][u-live-settings], [Manage Groups][u-groups] |
| G06 | Group management | **Missing.** No show/hide groups, Default/A–Z/Manual order, reordering All/Favorites, or explicit preferred startup group. Restoring the last group is a different behavior. | [Manage Groups][u-groups] |
| G07 | Favorites | **Partial.** Toggle/filter/persistence exist. No counterpart to upstream's persisted favorite-order model or cross-device membership/order sync. A current TV manual-editing UI was not established; the store supports ordering. | [FavoritesStore][u-favorites] |
| G08 | Named channel collections | **Missing.** No collection creation/deletion, member add/remove or beginning/end placement. Upstream also has rename/reorder store methods, but current TV UI exposure was not established. Collections are distinct from Favorites. | [ChannelCollectionsStore][u-collections], [guide actions][u-guide] |
| G09 | Channel sort choices | **Partial.** Server-requested number order only; no user selection of name/favorites ordering or stored per-playlist sort preferences. | [README][u-readme], [channel browser][u-channel-list] |
| G10 | Recently Watched group | **Missing.** No per-playlist ring of the last 25 channels or corresponding selectable/default group. Saving one last channel does not provide recents. | [RecentChannelsStore][u-recents], [Manage Groups][u-groups] |
| G11 | Channel search | **Present, narrower scope.** Name/number filtering inside the current group; not global EPG/content search. | [Channel browser][u-channel-list] |
| G12 | Program/global content search | **Missing.** No program-title/description query, current/upcoming/past results, jump to a result in the guide, or All/Movies/TV Shows/EPG scope. | [SearchView][u-search] |
| G13 | Jump to date/time and Now | **Present, adapted UI.** Local days/half-hour choices with UTC disambiguation and Replay-to-Now in the guide. Upstream's Today/Upcoming/Previous grouping and time-pill presentation are not reproduced. | [GuideJumpSheet][u-guide-jump] |
| G14 | Fast guide navigation | **Missing.** No page-up/down mappings, Jump to Top, hold-specific timeline behavior or numeric channel-entry overlay. Number search is not direct tune/jump entry. | [Remote map][u-remote], [number entry][u-number-entry] |
| G15 | Program details | **Partial.** Native text dialog with title/subtitle/description/times and Watch channel live. No rich program art, category pills, season/episode facts, ratings/extended enrichment or associated record/reminder/archive actions. | [ProgramInfoView][u-program-info], [guide actions][u-guide-actions] |
| G16 | Program badges | **Missing.** Normalization drops NEW/REPEAT/LIVE/PREMIERE/FINALE and season/episode fields. The player's LIVE stream-state label is not an EPG live-broadcast badge. | [Live TV settings][u-live-settings], [program model][u-program-info] |
| G17 | Category colors | **Missing.** No Sports/News/Movies/Kids tinting, palette/custom category rules or channel-card color preferences. | [Live TV settings][u-live-settings] |
| G18 | Program artwork/hero preview | **Missing.** Channel logos are present; program posters/backdrops and provider/TMDB art fallbacks are not. | [GuidePreviewBanner][u-guide-preview], [program details][u-program-info] |
| G19 | Reminders | **Missing.** No reminder state, scheduled-program action or sync. Five-minute iOS notifications are a separate platform capability, not verified tvOS behavior. | [ReminderManager][u-reminders] |
| G20 | Channels without guide data | **Present.** Gaps remain selectable for live tuning. Large/malformed schedules have bounded rendering and explicit states. | [Guide implementation][u-guide] |
| G21 | Refresh controls | **Partial.** Refresh Guide expires metadata windows; reconnect reloads channels/mappings. No separate Refresh Channels, cache statistics/clear actions, LAN detection refresh or full-refresh settings workflow. | [Server details][u-server-detail] |

## 4. Player experience and reliability

Roku evidence: [player lifecycle/keys/options][r-scene], [playback model][r-playback],
[information overlay][r-info], [now/next model][r-now], [options UI][r-options].

| ID | Feature | Roku status and remaining gap | Upstream evidence |
| --- | --- | --- | --- |
| P01 | Single-channel live playback | **Present on tested target.** Direct Dispatcharr MPEG-TS, authenticated requests and native Roku decoding; multiple channels were user-tested. | [README][u-readme], [engine routing][u-engine] |
| P02 | Broad media/codec/HDR/audio compatibility | **Adaptation + verification gap.** One proven transport path is not equivalent to upstream's engine/remux repertoire. Actual codec, surround, HDR, deinterlacing and device coverage are not cataloged. Do not port Apple engine switches literally. | [Engine routing][u-engine], [player diagnostics][u-player-options] |
| P03 | Previous/next channel switching | **Present with a behavior difference.** Filter-scoped, coalesced and non-wrapping; Roku Up=previous/Down=next is the reverse of the upstream default. See §8. | [Remote defaults][u-remote], [actual dispatcher][u-player-dispatch], [channel switcher][u-channel-switch] |
| P04 | Now/next channel information | **Present, basic content.** Logo, title/subtitle/synopsis, times, schedule progress, Up next, status and clock; OK recall and metadata refresh work. No configurable info-card fields or expanded in-player rich Program Info. | [Info-card settings][u-player-settings], [program info][u-program-info] |
| P05 | Full transport control surface | **Partial.** Remote actions plus an information panel, not upstream's focusable Pause/Record/Rewind/Forward/Multiview/Options controls and scrub timeline. | [Modern transport UI][u-transport] |
| P06 | In-player Channels browser | **Missing.** No Left-opened list over the picture, now-airing rows, Watching badge or local group-sidebar selection while the stream continues. | [ChannelListOverlay][u-channel-overlay] |
| P07 | Last-channel toggle | **Missing.** No quick zap between the current and previously watched channel. | [Actual dispatcher][u-player-dispatch], [channel switcher][u-channel-switch] |
| P08 | Recent-channel player overlay | **Missing.** No recently watched picker while viewing. | [RecentChannelsOverlay][u-recent-overlay] |
| P09 | Mini-player while browsing | **Missing.** Back stops the Video node and clears content. There is no corner-player state, guide browsing with continued video, minimize/expand, or settings-edge positioning. | [Back/minimize behavior][u-player-dispatch], [home/player host][u-home] |
| P10 | Layered Back/hold/double-Back behavior | **Partial.** Menus close before playback exits, but no Apple TV chrome → mini-player ladder, hold-stop, double-Back exit/top behavior or mini-player resume. Current Roku Back behavior is user-verified and should be changed deliberately. | [Player Back implementation][u-player-dispatch], [remote model][u-remote] |
| P11 | Audio/subtitle/caption selection | **Present at basic control level.** App-owned menus use native track fields. Real multi-language/codec coverage remains unverified; upstream's panel appearance is different. Roku caption mode is system-wide. | [TV options panel][u-player-options] |
| P12 | Stream Info overlay | **Missing.** No resolution/FPS/codec/bitrate/audio/cache/decode/drop diagnostics UI. Console error strings are not this feature; Roku may expose only a subset of mpv/AVPlayer statistics. | [Player/StreamInfo][u-player-info] |
| P13 | Sleep timer | **Missing.** No 30/60/90/120-minute timer, cancellation or countdown. | [TV options panel][u-player-options] |
| P14 | Video Scale | **Missing.** No Fit/Fill/Stretch selection. | [TV options panel][u-player-options] |
| P15 | Audio-only mode | **Missing for the broader Apple feature set.** Present in shared/mobile/companion paths; not an exposed row in the inspected tvOS options panel, so do not treat it as a proven default-tvOS menu item. | [README][u-readme], [companion controls][u-companion] |
| P16 | Automatic playback recovery | **Missing.** No app-level frozen-stream watchdog, bounded auto-reconnect, learned holdback, or busy-server Retry-After/connection-limit handling. Native buffering is not equivalent. Error/finished returns to the guide. | [Player settings][u-player-settings], [release highlights][u-whatsnew], [recent playback changes][u-changelog] |
| P17 | Loading/error UX | **Partial.** Buffering/paused labels, sanitized errors and connection-stage progress exist. Missing in-player Retry control, data-received/progress feedback and provider/account-specific connection-limit explanations. | [Transport Retry][u-transport], [release highlights][u-whatsnew] |
| P18 | Switch Stream/source picker | **Missing.** No Dispatcharr member-stream picker or active-source display. The UUID proxy can still perform its own server-side failover; that is distinct from a missing client picker/recovery system. | [SwitchStreamView][u-switch-stream], [TV options panel][u-player-options] |
| P19 | Source-identical controls/animations | **Partial.** Theme colors and an adapted overlay exist; circular transport buttons, compact floating options, focus animation and hide timing differ. The Roku panel hides after eight seconds. | [Modern transport UI][u-transport], [TV options panel][u-player-options] |

## 5. Live rewind, catch-up and restart

Roku evidence: [player commands][r-scene] issue `pause`/`resume`, but there is no
`seek` path, rolling media store, catch-up Task or session model. The caption mode
named **Instant replay** does not implement a replay button or rewind buffer.

| ID | Feature | Roku status and remaining gap | Upstream evidence |
| --- | --- | --- | --- |
| T01 | Short pause/resume | **Partial.** Native pause/resume was user-tested. Retained duration, overflow, resume accuracy and behavior across program boundaries are not established. | [Live rewind settings][u-player-settings] |
| T02 | Controlled rolling live buffer | **Missing / adaptation.** No owned buffer, retention policy, disk/resource budget or configured depth. Upstream's 15–180-minute buffer implementation cannot simply be copied into Roku's storage/player environment. Your 60-minute target is not fulfilled. | [LiveRewindBuffer][u-rewind], [settings][u-player-settings] |
| T03 | Keep recently watched channels buffering | **Missing / adaptation.** No retained concurrent ingest sessions or restored rewind timeline on return to a channel. This has additional connection/bandwidth/hardware costs. | [Channel retention settings][u-player-settings] |
| T04 | Seek controls and Go Live | **Missing.** No rewind/fast-forward, configurable skip intervals, accelerating hold-to-scrub, seek preview or live-edge return. Schedule progress is display-only. | [Transport/timelines][u-transport] |
| T05 | Completed-program catch-up | **Missing.** Past guide selection shows text details and Watch channel live. No archive playback, catch-up badges/retention gates, session create/revoke, position reporting or archive seek lifecycle. | [Catch-up sessions][u-catchup], [guide actions][u-guide-actions] |
| T06 | Restart currently airing program | **Missing; user requirement beyond demonstrated upstream guide behavior.** Upstream's inspected guide archive gate requires program end ≤ now. Validate ongoing-provider archive availability and transport semantics against the existing Dispatcharr; do not infer support from a wire enum. | [Replay gate][u-replay-gate], [dispatcher][u-player-dispatch] |
| T07 | Archive/VOD vs live position information | **Missing beyond live schedule display.** No pinned archived-program timeline or playhead-relative program metadata. While paused, Roku intentionally continues displaying what is on air now. | [Transport/timelines][u-transport], [catch-up model][u-catchup] |

**Deployment constraint:** solve or bound these using native Roku behavior and
the existing Dispatcharr/provider capabilities. An added media service is not
part of the agreed solution. Provider catch-up availability is confirmed by the
user; in-progress restart and the 60-minute retention behavior still need proof.

## 6. VOD, DVR and multiview

There are no Roku movie/series/recording models, library screens or provider calls
for these domains. Its only playback descriptor constructs a live-channel TS URL.
These are absent subsystems, not disabled settings.

### Movies and TV shows

| ID | Feature | Roku status and remaining gap | Upstream evidence |
| --- | --- | --- | --- |
| V01 | Movies/TV Shows libraries and tabs | **Missing.** Catalog ingestion, category browsing, media pages and playback entry points. | [MoviesView][u-movies], [home/stores][u-home] |
| V02 | Detail pages and episodes | **Missing.** Movie/series detail pages, seasons, episodes, descriptions, cast/director/year/rating/runtime and per-episode facts/artwork. | [VODDetailView][u-vod-detail] |
| V03 | Library search/filter/sort/navigation | **Missing.** Provider/group/genre filters, title/year/rating/recent sorting, inline search, alphabet rail and poster focus restoration. | [MoviesView][u-movies] |
| V04 | Artwork/TMDB enrichment | **Missing.** Posters/backdrops, metadata/art fallback, user TMDB key/test/save, attribution UI. | [Movies/TV settings][u-vod-settings], [VOD details][u-vod-detail] |
| V05 | Resume and Continue Watching | **Missing.** Movie/episode progress, Resume vs Play from Beginning, resumable hero/shelf and removal from Continue Watching. | [VOD details][u-vod-detail], [MoviesView][u-movies] |
| V06 | Watchlist, hidden titles, watched state | **Missing.** Add/remove watchlist, hide/unhide titles, Hidden category and mark episodes watched/unwatched. | [VOD models/stores][u-vod-models], [VOD details][u-vod-detail] |
| V07 | Related titles and person discovery | **Missing.** Library-matched recommendations and cast/crew/person search/discovery. | [VOD details][u-vod-detail], [MoviesView][u-movies] |
| V08 | Provider-copy/version selection | **Missing.** Auto or explicit provider copy; selection remembered per item and switching during playback. | [VOD details][u-vod-detail], [TV options panel][u-player-options] |
| V09 | Trailer/TMDB links | **Missing / adapted interaction.** Upstream has external links, with QR presentation on TV; this is not assumed to mean inline trailer playback. | [VOD details][u-vod-detail] |
| V10 | VOD-specific transport | **Missing.** Seek/resume/duration timeline and speed choices. Native capability and format coverage must be verified on Roku. | [Player/options][u-player-options], [transport][u-transport] |
| V11 | Large-library persistence and refresh | **Missing / adaptation.** No persisted/windowed catalog, resumable ingestion, quiet background sweep, per-playlist VOD enable switch or refresh cadence. Reproduce bounded behavior, not SwiftData/SQLite implementation details blindly. | [Catalog store][u-vod-catalog], [Movies/TV settings][u-vod-settings], [home/stores][u-home] |

### DVR

| ID | Feature | Roku status and remaining gap | Upstream evidence |
| --- | --- | --- | --- |
| D01 | Record current/upcoming programs | **Missing.** Recording actions in guide/player, destination choice and scheduling UI. | [RecordProgramSheet][u-record] |
| D02 | Pre-roll/post-roll | **Missing.** Per-recording/default start-early/end-late settings and custom values. | [Recording sheet][u-record], [DVR settings][u-dvr-settings] |
| D03 | Series rules | **Missing.** Just this airing / every episode / new only, title/description matching and channel scope. | [Rule controls][u-record] |
| D04 | DVR library and metadata | **Missing.** Recording Now/Scheduled/Recent, resumable hero, content-kind filtering, title/channel search, sort, recording facts and artwork. | [DVRView][u-dvr] |
| D05 | Discover/manage server recordings | **Missing.** Discover recordings created elsewhere; stop/cancel/delete and capability-aware actions. | [RecordingActions][u-record-actions], [DVRView][u-dvr] |
| D06 | Recording playback/resume | **Missing.** Completed and eligible in-progress playback, resume and recording timeline. | [RecordingActions][u-record-actions] |
| D07 | Commercial removal | **Missing.** Request server-side Comskip at schedule time or for a completed recording. | [RecordingActions][u-record-actions], [recording sheet][u-record] |
| D08 | Device recording/downloads/storage | **Missing / adaptation.** No local capture, downloaded-copy management, quota/usage UI or keep-awake behavior. The Apple device-storage design is not a proven fit for the Stick; prefer existing Dispatcharr server DVR when this milestone is undertaken. iOS Files/custom-folder integration is mobile-only. | [DVR settings][u-dvr-settings], [recording engine][u-rewind] |

### Multiview

| ID | Feature | Roku status and remaining gap | Upstream evidence |
| --- | --- | --- | --- |
| M01 | Multiple simultaneous channels | **Missing / feasibility-gated.** Roku currently owns one Video node/session. Do not promise upstream's nine simultaneous streams on the Stick without decoder/resource tests. | [Multiview store][u-multiview], [README][u-readme] |
| M02 | Layout/audio/tile controls | **Missing.** Auto/even/spotlight/stacked/hero-corner layouts, audio focus, per-tile tracks, move/reorder, remove and fullscreen-in-grid. | [Layout model][u-multiview-layout], [multiview host][u-player-dispatch] |
| M03 | Resource and appearance policies | **Missing / adaptation.** No multistream resource guard, thermal-equivalent strategy, tile spacing/corners or audio-focus styling preferences. | [README][u-readme], [player settings][u-player-settings] |

## 7. Settings, presentation and integrations

### Application settings and visual parity

| ID | Feature | Roku status and remaining gap | Upstream evidence |
| --- | --- | --- | --- |
| A01 | Full navigation/settings hub | **Missing beyond connection setup.** No real Movies/TV Shows/DVR tabs or categorized settings panes. The Live TV heading is not a complete tab system. | [Settings routes][u-settings-routes], [home/tabs][u-home] |
| A02 | Themes and appearance modes | **Partial.** Default navy/cyan colors exist. No theme presets, dark/light/system choice, custom accent or glass-style settings. Native Apple materials need a Roku visual approximation. | [ThemeManager][u-theme], [Appearance settings][u-appearance] |
| A03 | Text/subtext size and contrast | **Missing.** Fixed font sizes/colors; no app-wide text scale, independent secondary-text scale or contrast control. | [Appearance settings][u-appearance] |
| A04 | Clock format | **Partial.** Local timezone is applied, but output is hard-coded HH:mm. No 12-hour/system preference, despite the test device reporting a 12-hour clock. | [Appearance settings][u-appearance], [Roku formatter][r-clock] |
| A05 | Channel/guide presentation preferences | **Missing.** No show/hide logos/numbers/names/program subtitles, logo-corner choices or guide scaling. Some guide badges aren't normalized at all. | [Live TV settings][u-live-settings] |
| A06 | Player info-card preferences | **Missing.** No independent logo/name/title/time/subtitle/description visibility choices or optional dynamic hint strip. | [Player settings][u-player-settings], [Remote settings][u-remote-settings] |
| A07 | Remote remapping | **Missing.** Keys are hard-coded; no separate guide/player assignments, short/hold choices, presets/reset or per-device map preferences. Only genuinely executable upstream actions should be offered. | [Remote map][u-remote], [settings][u-remote-settings] |
| A08 | Startup behavior preferences | **Missing.** No configurable landing tab, Skip Loading Screen or launch-time resume into a mini-player. Saved-key reconnect and last-row restoration are present but different. | [General settings][u-general] |
| A09 | Refresh/network preferences | **Partial.** Fixed timeout/deadline/backoff values and active-session metadata refresh exist. No configurable request timeout, retry count, cadence or equivalent cache-maintenance pages. iOS background scheduling isn't assumed available on Roku. | [General settings][u-general], [server detail][u-server-detail] |
| A10 | App branding/onboarding flow | **Partial.** Branded text/theme and setup form, but no source-matched welcome/splash/icon experience. The manifest has a splash color but no packaged app icon/splash artwork. | [SplashView][u-splash], [welcome][u-welcome], [Roku manifest][r-manifest] |
| A11 | About, version, What's New, licenses UI | **Missing.** License/notice files are packaged, but there are no corresponding in-app pages or release-note flow. | [Settings routes][u-settings-routes], [What's New][u-whatsnew] |
| A12 | Developer diagnostics UI/export | **Missing.** Console logging and sanitized playback errors exist; no log viewer/share/export, process/resource dashboard or stream-stat overlay. Apple-specific engine switches are not literal Roku requirements. | [Developer settings][u-developer] |
| A13 | Accessibility/focus semantics | **Incomplete / unverified.** Custom grid/setup use virtual selection on a container; no explicit selected-item Roku audio-guide descriptions were found. User-tested visible focus is not screen-reader acceptance. | [Transport accessibility labels][u-transport], [Roku UI helper][r-clock] |
| A14 | Visual fidelity as a whole | **Partial.** Source-inspired guide dimensions and palette, but different menus, typography, static rectangular surfaces, focus/motion, artwork and transport composition. No current running-tvOS side-by-side acceptance. Duplicate channel-number/name text remains a known cosmetic issue. | [Guide][u-guide], [TV options][u-player-options], [device record][r-device] |

### Cross-device and platform-specific features

| ID | Feature | Roku status and appropriate interpretation | Upstream evidence |
| --- | --- | --- | --- |
| I01 | iCloud sync and category controls | **Adaptation.** No server/config/preferences/watch-progress/reminder/remote-map/credential sync, per-category enable/delete, or push/pull workflow. Apple KVS/Keychain cannot be directly reused. Any replacement must respect the no-extra-service constraint. | [Sync categories][u-sync], [sync implementation][u-sync-manager] |
| I02 | Aerio phone-to-TV companion control | **Missing / adaptation.** No `_aeriotv._tcp` advertisement, pairing code, authenticated companion protocol, state feedback or native handoff receiver. Roku's OS remote/ECP capability is not an Aerio companion implementation. | [CompanionHost][u-companion] |
| I03 | Google Cast / AirPlay sender experience | **Excluded as a direct Roku-TV client requirement; broader integration absent.** Upstream's phone sender/proxy/cast card is primarily mobile. Roku's system AirPlay support does not make this app a port of that sender or its native Aerio handoff. | [README casting][u-readme], [cast/companion implementation][u-companion] |
| I04 | Apple TV Top Shelf | **Platform adaptation.** No equivalent system-home integration or watched-frequency/Continue Watching feed. An in-app recent/most-watched surface is a separate implementable feature; do not promise Apple's extension API on Roku. | [Top Shelf extension][u-topshelf] |
| I05 | Deep links / launch-to-content | **Missing.** Main has no launch-argument routing and input launch is disabled; there are no channel/movie/series deep-link resolvers. | [Top Shelf links][u-topshelf], [Roku Main][r-main], [manifest][r-manifest] |
| I06 | Mobile gestures/PiP/CarPlay/files | **Excluded from direct TV parity.** Touch gestures, orientation, brightness/volume edge slides, OS PiP across apps, CarPlay, Files integration and iOS notifications are not straightforward Roku-TV features. This does not excuse the missing in-app corner player. | [README][u-readme], [CarPlay][u-carplay], [reminders][u-reminders] |
| I07 | Standalone Apple TV channel list | **Excluded at this revision.** Explicitly disabled upstream. Keep it separate from missing in-player Channels/Recents overlays. | [TVListView flag][u-tv-list] |

## 8. Existing behavior that differs from the Apple TV reference

These are review decisions, not instructions to silently undo tested Roku behavior:

- **Channel direction:** upstream's default Up dispatches +1/next and Down
  −1/previous; Roku does the reverse. Upstream's switcher uses the active server's
  channel list; Roku deliberately stays within the current filtered guide list.
  [Remote defaults][u-remote], [dispatch][u-player-dispatch],
  [actual channel index step][u-channel-switch], [Roku step][r-playback].
- **Back:** Roku exits playback to the guide immediately. Upstream has the
  chrome/mini-player ladder and additional hold/double-press behaviors.
- **OK:** Roku toggles a non-interactive information panel. Upstream reveals
  focusable player controls/timeline. Our physical Play/Pause button is separate.
- **`*`:** Roku opens an app-owned modal audio/caption menu. Upstream uses a
  compact options panel with substantially more actions. Native Roku system
  Options were replaced to make OK ownership reliable.
- **Info timing:** Roku uses eight seconds. The README describes five seconds,
  and newer upstream release notes describe a three-second modern control band;
  exact matching needs the selected source/binary's actual UI as reference.
- **Clock/date formatting:** Roku local time is correct but fixed to 24-hour
  HH:mm and ISO-like dates rather than a system/12-hour/24-hour choice.
- **Paused information:** Roku shows **on-air schedule** progress, not the
  paused frame's position. That is correctly labeled, but is not a DVR timeline.
- **Historical guide selection:** Roku opens details with Watch channel live;
  upstream can directly play an eligible completed archive program.
- **Reminders:** state tracking is a current-tvOS comparison; five-minute push
  notifications are an iOS comparison.

## 9. Verification and release-readiness gaps

Existing verification is useful but narrow. The six suites cover provider/model
parsing, times/DST, cell math, an in-memory 1,400-channel fixture, bounded caching,
now/next, track mapping, event-node identity and the shared font regression.
They do **not** execute native video, actual HTTP Tasks, screen focus, storage
quota failures, or all UI flows. See [test runner][r-tests] and [hardware record][r-device].

Still needed before treating the first-release experience as robust:

- Repeatable real-device tests for setup/login failures, cancellation and the
  120-second watchdog, credential rotation, account/profile restrictions and
  preference restoration.
- Real ten-day navigation, program-boundary rollover, guide outage/recovery and
  missing/duplicate EPG-source cases—not only synthetic model fixtures.
- Sustained playback and rapid tuning with server connection cleanup measured.
- A representative codec/resolution/HDR/audio/subtitle matrix. Several channels
  playing successfully is not evidence for every provider format.
- Pause duration/overflow/resume accuracy; explicit proof for any claimed rewind
  retention window. Caption mode “Instant replay” is not such proof.
- Peak application/texture memory and performance with the real large lineup.
  Responses are buffered fully before the current 16 MB JSON parsing limit;
  normalized guide windows have a 24,000-program cap. Larger inputs receive
  errors rather than having a streaming parser/resource strategy.
- Accessibility/audio-guide, clipping, long names and focus restoration review.
- Screenshot/motion comparison against a current tvOS build. The published
  screenshots examined so far mainly establish setup styling.
- CI/build/deploy automation and release packaging/branding appropriate to the
  eventual distribution target. Current delivery is a sideload ZIP.
- Development dependency follow-up: four moderate advisories are already
  documented. They are build-tool dependencies, not bundled channel libraries.

Some implementation limitations are already visible without a device test:

- No automatic stream recovery after error/finished; an error stops playback.
- Channel and EPG mapping loads precede entering the guide; no cache-first or
  incremental startup path.
- Only the last connected account's saved preferences are retained.
- The Remember toggle resets to On at initialization, even though choosing Off
  removes the saved key for that connection.
- Registry-save failures update setup status rather than producing a visible
  guide notification while browsing.
- Program normalization intentionally retains only a small field set, so rich
  badges/art/details require model and provider changes, not just new labels.

## 10. Recommended order of work

This is a proposed ordering based on the agreed Live TV-first scope, not a new
commitment to add every Apple/mobile feature.

### A. Complete the everyday Live TV experience

1. Player Channels overlay, last-channel toggle and Recently Watched.
2. Mini-player while browsing the guide; then agree on the Back/expand/stop ladder.
3. Group hide/reorder/defaults, favorite ordering, channel sort choices and faster
   guide paging/direct-number navigation.
4. Settings foundation: clock preference, text/contrast/density, information-card
   visibility, remote hints and deliberate key-map choices.
5. Program badges/artwork/category details and EPG title/description search.
6. Recovery and startup performance: actionable Retry, stalled-stream detection,
   connection-limit handling and a Roku-appropriate cache/startup strategy.

Smaller useful player additions include Video Scale, Sleep Timer and Stream Info.

### B. Prove and implement the requested time features

1. Capability/retention discovery and completed-program catch-up through existing
   Dispatcharr sessions.
2. Validate in-progress restart with the actual providers; implement only when the
   server/media path demonstrates it.
3. Establish a supported 60-minute rewind approach under the no-extra-service
   constraint. Then add real seek limits, skip/hold controls and Go Live.

This investigation should happen early even if the UI work above proceeds first;
it is the largest platform-dependent item in the requested initial roadmap.

### C. VOD

Movie/series catalogs → details/episodes → playback/resume → Continue Watching →
watchlist/filter/search/artwork → provider versions and richer discovery.
Design for bounded large libraries from the first VOD iteration.

### D. Later parity

Existing Dispatcharr server DVR, additional providers/multi-playlist management,
companion integration and appropriate sync alternatives. Multiview requires a
separate hardware-capacity decision. Apple/mobile-only integrations should not
block the Roku Live TV release.

## Source references

Local links refer to the reviewed 0.2.6 tree. Upstream links are commit-pinned.

[upstream]: https://github.com/jonzey231/AerioTV/tree/8d5818456e0f4421d93b8ff120ad878d63331091
[u-readme]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/README.md#L52
[u-whatsnew]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/App/WhatsNew.swift#L58
[u-changelog]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/CHANGELOG.md#L131
[u-tv-list]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Design/Typography.swift#L500-L518
[u-engine]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Shared/PlayerSession.swift#L900-L1023
[u-auth]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Networking/DispatcharrDirectConnect.swift
[u-server-model]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Models/Models.swift#L57-L327
[u-edit-server]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/EditServerPage.swift
[u-server-detail]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/ServerDetailView.swift
[u-xmltv]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Networking/PlaylistParsers.swift#L320-L434
[u-import]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Onboarding/PlaylistImportViews.swift
[u-home]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Home/HomeView.swift
[u-guide]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/EPGGuideView.swift
[u-guide-cache]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/EPGGuideView.swift#L186
[u-guide-actions]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/EPGGuideView.swift#L7811-L7899
[u-channel-list]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/ChannelListView.swift
[u-replay-gate]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/ChannelListView.swift#L2735-L2771
[u-live-settings]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/LiveTVSettingsView.swift#L464-L633
[u-groups]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Design/Components/ManageGroupsSheet.swift#L20-L170
[u-favorites]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Home/FavoritesStore.swift#L10-L119
[u-collections]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Home/FavoritesStore.swift#L143-L323
[u-recents]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Shared/RecentChannelsStore.swift
[u-search]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Search/SearchView.swift#L424-L529
[u-guide-jump]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/GuideJumpSheet.swift
[u-program-info]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/ProgramInfoView.swift#L98-L175
[u-guide-preview]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/GuidePreviewBanner.swift
[u-reminders]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Shared/ReminderManager.swift#L28-L155
[u-remote]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Shared/RemoteControlMap.swift#L190-L225
[u-remote-settings]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/RemoteControlSettingsView.swift
[u-number-entry]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Shared/ChannelNumberEntry.swift#L7-L189
[u-player-options]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/App/PlayerView.swift#L4195-L4512
[u-player-info]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/App/PlayerView.swift#L62-L172
[u-player-settings]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/PlayerSettingsView.swift#L473-L618
[u-player-dispatch]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Multiview/MultiviewContainerView.swift#L1565-L1785
[u-channel-switch]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Home/HomeView.swift#L3967-L4064
[u-channel-overlay]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Player/ChannelListOverlay.swift
[u-recent-overlay]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Player/RecentChannelsOverlay.swift
[u-transport]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Multiview/PlaybackChromeOverlay.swift#L1120-L1420
[u-switch-stream]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/SwitchStreamView.swift
[u-rewind]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Shared/LocalRecordingSession.swift#L214-L262
[u-catchup]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Networking/StreamingAPIs.swift#L6021-L6370
[u-movies]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/VOD/MoviesView.swift
[u-vod-detail]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/VOD/VODDetailView.swift
[u-vod-models]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Models/VODModels.swift
[u-vod-settings]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/MoviesTVSettingsView.swift
[u-vod-catalog]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Shared/VODCatalogStore.swift
[u-record]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/RecordProgramSheet.swift
[u-dvr]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/DVR/DVRView.swift
[u-record-actions]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/DVR/RecordingActions.swift
[u-dvr-settings]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/DVRSettingsView.swift
[u-multiview]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Multiview/MultiviewStore.swift
[u-multiview-layout]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Multiview/MultiviewGridMath.swift#L3-L109
[u-settings-routes]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/SettingsDestination.swift
[u-theme]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Design/ThemeManager.swift
[u-appearance]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/AppearanceSettingsView.swift
[u-general]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/GeneralSettingsView.swift
[u-splash]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/App/SplashView.swift
[u-welcome]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Onboarding/WelcomeView.swift
[u-developer]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/DeveloperSettingsView.swift
[u-sync]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Shared/SyncFlags.swift#L26-L95
[u-sync-manager]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Shared/SyncManager.swift
[u-companion]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/App/AerioCastController.swift#L3320-L3603
[u-topshelf]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/TopShelfExtension/ContentProvider.swift
[u-carplay]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/App/CarPlaySceneDelegate.swift
[r-scene]: ../components/AerioScene.brs
[r-connect]: ../components/DispatcharrTask.brs
[r-guide]: ../components/GuideView.brs
[r-guide-model]: ../source/GuideModel.brs
[r-guide-task]: ../components/GuideTask.brs
[r-provider]: ../source/DispatcharrModel.brs
[r-http]: ../source/DispatcharrHttp.brs
[r-playback]: ../source/PlaybackModel.brs
[r-info]: ../components/PlayerInfo.brs
[r-now]: ../source/NowNextModel.brs
[r-options]: ../components/PlayerOptions.brs
[r-clock]: ../source/SceneUi.brs
[r-main]: ../source/Main.brs
[r-manifest]: ../manifest
[r-tests]: ../scripts/test.mjs
[r-device]: DEVICE-VALIDATION.md
