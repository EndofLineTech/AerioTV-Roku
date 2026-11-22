# TV feature re-audit: tvOS, Android TV and Roku v0.3.81

**Date:** 2026-09-26. **Tracking:** `AerioTV-Roku-wno`.

| Source | Reviewed revision |
| --- | --- |
| [AerioTV tvOS](https://github.com/jonzey231/AerioTV/tree/8d5818456e0f4421d93b8ff120ad878d63331091) | `8d5818456e0f4421d93b8ff120ad878d63331091` (`main`) |
| [AerioTV Android](https://github.com/jonzey231/AerioTV-Android/tree/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b) | `7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b` (`main`) |
| Roku | v0.3.81, commit `32a0c8f80f17f4fe7c6cabb1e4cc0f1a07cfae49` |

Both upstream `main` revisions **still equal the earlier pinned snapshots**.
This updates the [Roku 0.2.6 parity baseline](PARITY-AUDIT.md) for current
Roku code; its old “Missing” rows must not be read as current status. This is
a source/entry-point audit, not a fresh tvOS/Android device run or full binary
comparison. Roku device proof is explicitly identified where available. The
Streaming Stick 4K `3820RW2`, Dispatcharr `0.31.0`, account-scoped API, bounded
on-device resources and no added runtime service remain the ordinary Roku
constraints. **Multiview is outside this re-audit and its backlog.**

## Bottom line

The original large gaps in guide organization, live player navigation,
server DVR, VOD and categorized settings have mostly been filled on Roku.
The strongest *current* feature opportunities are a unified EPG/VOD search,
series-aware next-episode entry, user-state retention beyond 20 VOD entries,
and measured display-rate matching. Schedule-time Comskip and user-accessible
log sharing are smaller gaps. Each has a Bead below; none is implied to be
approved implementation simply because another platform has it.

Two README claims need TV-specific correction before counting missing features:
the separate Live TV List is [disabled on tvOS][a-list] and
[disabled on Android TV][d-list] (their in-player Channels pickers still exist).
Android's “advance to next episode” is a [Continue Watching progression][d-upnext]
and a [series Play target][d-series], not proof of immediate auto-playing the
next episode. Touch PiP/gestures, mobile Cast sending, iOS Files access and
platform store services are not direct Roku-TV parity obligations.

**Status key:** Present = equivalent viewer behavior exists (not universal
hardware proof); Partial = a meaningful subset or limited source; Missing =
no corresponding user path; Adapted/deferred = prior PO decision or platform
boundary. tvOS/Android columns describe inspected TV paths unless marked mobile.

## Features now substantially present on Roku

| Area | tvOS / Android TV reference | Roku v0.3.81 evidence and qualification |
| --- | --- | --- |
| Dispatcharr authentication and scoped channels | Account/server capabilities, profile narrowing | API key/dashboard login, selected profile and capability-gated screens in [DispatcharrTask][r-connect] and [CapabilityModel][r-cap]. Direct M3U/XMLTV and session-only Xtream live/VOD/UTC completed archive are bounded variants, not every provider dialect ([direct-feed scope][r-direct]). |
| EPG and channel organization | [tvOS guide][a-guide], [Android TV guide][d-guide] | 7-row Preview/10-row Basic, now/next, art, badges, category tint, history/future choices, favorites, Recently Watched, named collections, group visibility/order and number/name sort in [guide settings][r-groups] and [GuideView][r-guide]. Earlier PO guide acceptance is recorded in Beads; source status is not a new device PASS. |
| Channel navigation while playing | In-player channels, recents, last channel, mini-player | Roku [ChannelBrowser][r-browser], [remote map][r-remote] and [Scene][r-scene] support the channel browser, previous channel, recent channels and same-session guide mini-player. This is an adaptation of each platform's Back/chrome gestures. |
| Program search and archive | Title/description search, program details, catch-up | Roku [ProgramSearchView][r-epg-search] pages title/description results back into the guide; provider-backed catch-up, conditional restart, bounded since-tune rewind and Go Live use [MediaNavigation][r-media]. The 60-minute history is provider-dependent, not a retained local Roku buffer. |
| Server DVR | [tvOS DVR][a-dvr], [Android DVR][d-dvr] | Roku [single-pane DVR][r-dvr] has Recording Now/Scheduled/Recent/Rules, external discovery, identity-checked stop/cancel/delete, series rules, completed-file playback/resume and growing HLS with native FF/REW. [Native development evidence][r-dvr-evidence] distinguishes decoder state from perceived picture/sound. Local recordings/downloads are deliberately [excluded][r-dvr-scope]. |
| VOD on Dispatcharr | Movies, series, episodes, category/provider browse, progress/curation | Roku [VodTask][r-vod-task], [VodView][r-vod-view], [VodState][r-vod-state] provide bounded paging, search/sort, resume/Continue, watchlist/hidden, watched markers, source choice and optional TMDB cast/person/related discovery. Xtream has a narrower category-scoped adapter ([media scope][r-xc]). |
| Player and personal settings | Audio/caption, sleep, scaling, remote customization, themes | Roku [settings model][r-settings], [remote map][r-remote] and [player options][r-scene] offer these; Stream Info includes native decoder and server facts in [AerioScene][r-info]. VOD speed and cross-app listening are intentional adaptations below. |

## Actionable differences to evaluate

| Priority / Bead | Upstream TV behavior | Roku evidence / gap | Decision or bounded next step |
| --- | --- | --- | --- |
| P2 [`ajr`](#tracking) — **unified search** | [tvOS All/Movies/TV Shows/EPG][a-search] and [Android TV mixed results][d-search] share one destination. Android's VOD half is Dispatcharr-only. | Roku guide [program search][r-epg-search] and catalog [title searches][r-vod-task] are separate screens. A guide query cannot return VOD titles in the same result set; Roku's EPG search *does* cover configured past results, unlike Android's now-forward local query. | Reuse authorized bounded operations and result navigation; avoid an unbounded local VOD/EPG scan or pretending XC VOD is globally indexed. |
| P2 [`17h`](#tracking) — **series next target** | tvOS [series Play target][a-series] and Android [SeriesTarget][d-series] choose the latest unfinished or next episode; Android [promotes the next episode into Continue][d-upnext]. | Roku [series menu][r-vod-state] offers “Browse episodes”; progress/Continue identify individual episodes but no series-aware Play Next target or next-item promotion. | Model seasons, watched progress, missing/denied episodes and Back focus; do not label this automatic autoplay. |
| P2 [`3ts`](#tracking) — **saved VOD state capacity** | tvOS SwiftData [episode progress rows][a-series] and Android [Room progress rows][d-upnext] persist independently. | Roku [VodState][r-vod-state] stores progress *and* watchlist/hidden/watched flags in one 20-entry account array. Updating a new title prepends it and drops the oldest, including a curated item; the [existing test][r-vod-test] confirms the cap. | Investigate durable bounded storage/migration before promising unlimited saved state; at minimum avoid silent loss of Watchlist/Hidden intent. |
| P2 [`5cq`](#tracking) — **display-rate matching** | tvOS sets [display criteria][a-rate]; Android TV measures rendered FPS and attaches [frame-rate matching][d-rate] to its player. | Roku [Stream Info][r-info] can report frame rate, but no explicit display-refresh-rate matching path was found. This is not proof Roku's native Video never matches autonomously. | Investigate supported Roku/player behavior with 50/60 fps inputs and HDMI output; keep user display settings and retune/A-V continuity in the decision. |
| P3 [`dwi`](#tracking) — **Comskip at schedule time** | tvOS [RecordProgramSheet][a-record] and Android [RecordProgramSheet][d-record] offer an optional server Comskip choice while creating a schedule. | Roku [record flow][r-record] offers padding and series rules; only a *finished* item exposes [Queue commercial processing][r-dvr]. | Verify Dispatcharr 0.31 schedule contract and safe capability gate before adding a write; current post-recording queue remains usable. |
| P3 [`kqg`](#tracking) — **diagnostic sharing** | tvOS has [log viewer and QR/LAN share][a-logs]; Android TV has [log viewer and QR share][d-logs]. | Roku keeps [session-only sanitized events][r-diagnostics]; Export writes to developer TCP 8085, which is inaccessible to many testers. | Find a supported opt-in, bounded, credential-safe Roku transfer/view method; no always-on listener or new runtime service is approved. |

## Known differences **not** automatically reopened

| Feature | Cross-platform interpretation and current Roku decision |
| --- | --- |
| Separate Live TV List | Both TV clients turn it off ([tvOS][a-list], [Android][d-list]); Roku's in-player channel browser is the relevant counterpart. Not a missing TV feature. |
| Local device DVR, offline downloads, Files, quota and keep-awake | Both upstream mobile/TV codebases have local options, but the Roku PO chose [server-owned DVR only][r-dvr-scope] on the Stick. No new local-media scope is inferred. |
| iCloud/Google Drive sharing, companion Cast handoff, system-home recommendations and deep links | tvOS [Top Shelf][a-top] and Android TV [Cast receiver][d-cast] have platform-specific integrations. Roku account data is device-local; the [cross-device decision][r-cross] explicitly defers sync, companion pairing and deep links, accepting in-app Recent/Continue as the home discovery adaptation. Mobile Cast/AirPlay sender is not a Roku TV sender requirement. |
| Local/WAN auto-switch | [tvOS playlist configuration][a-server] and Android TV [playlist screen][d-server] support local routes. Roku uses an explicit reachable base URL; the PO closed `AerioTV-Roku-ah5` with automatic LAN/WAN routing retired from current scope ([connections evidence][r-conn-scope]). |
| VOD playback speed, background Audio Only and spoken focus | Both upstream clients advertise speed/background behavior. Native Roku 1.5× transitions were unstable, and the PO accepted normal-speed VOD; foreground Hide picture is not TV-off playback. Custom Audio Guide speech on 3820RW2 is an [accepted platform limitation][r-release], not a verified spoken PASS. |
| Direct-source compatibility envelope | Roku [XtreamModel][r-xc-model] rejects HLS-only XC live accounts (requires MPEG-TS); its [Xtream VOD adapter][r-xc] caps a category at 600 and UTC-only completed archives. [M3uModel][r-m3u] caps 2 MiB/5,000 channels and rejects stream URLs containing userinfo; the connection editor also rejects credential-bearing playlist URLs. tvOS [XMLTV parser][a-xmltv] and Android [XMLTV parser][d-xmltv] decode raw gzip despite tvOS README's “coming” wording; Roku raw `.xml.gz` is unsupported. tvOS documents HLS→TS XC fallback; Android has broader media formats. These are intentional current [bounded provider adaptations][r-direct], not full provider parity. Reopen per actual affected provider with an approved transport/credential policy. |
| Guide timeline scale and manual category palettes | tvOS [Guide scale control][a-live-settings] and [category editor][a-colors] offer more fine-grained visual choices. Roku has Basic/Preview, text scale and an on/off category tint ([settings][r-settings]); no matching continuous timeline-width or arbitrary color editor. Android's preference for guide zoom exists, but a current TV setter call was not established in inspected code. This is optional TV polish, not a blocker. |
| DVR filters and watch-frequency Top Shelf | Android uses Scheduled/Recording/Completed chips ([DVR TV content][d-dvr]); Roku's one-list headings were a deliberate PO decision. tvOS system Top Shelf ranks most watched; Roku's recency ring is not a watch-frequency counter. |

Smaller UI/choice deltas that do not justify silently reopening accepted epics:

| Delta | Evidence / interpretation |
| --- | --- |
| DVR padding options | The [tvOS][a-record] and [Android][d-record] record sheets offer 60 minutes and a custom amount; Roku's [per-item picker][r-record] and saved defaults currently offer 0/5/10/15/30. This is a choice-range difference, not missing scheduling. |
| DVR library facets | Upstream [DVR TV views][a-dvr] offer additional hero/content-kind grouping and Android a bulk Clear All action ([DVR TV content][d-dvr]). Roku has status headings, title/channel search, date/title sort, per-item management and a PO-selected one-pane layout. Bulk destructive actions should require a distinct product decision. |
| Reminder delivery | Android advertises notifications and tvOS keeps [reminder state][a-reminders]; Roku [foreground reminders][r-reminders] require the app to be open. Do not infer Apple TV background notifications from the iOS path. |

## Tracking and verification

New discovered-from `AerioTV-Roku-wno` Beads: `AerioTV-Roku-ajr`, `17h`,
`3ts`, `5cq`, `dwi`, `kqg`. These are **candidates**, not a decision to ship all
six. The existing source-level [0.2.6 audit][r-old-audit] and closed guide,
player, DVR, VOD, connections and cross-device Beads were reconciled before
filing these distinct gaps. No duplicate multiview, sync, playback-speed or
local-DVR work was filed. `AerioTV-Roku-1ds` and `3ga` retain target-TV
picture/sound verification for the published v0.3.81 build; model tests,
developer captures and native `playing` do not fill that physical worksheet.
Future action should prioritize a specific viewer need and supported provider
before treating source parity as a promise on Roku hardware.

[a-list]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Design/Typography.swift#L500-L518
[d-list]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/livetv/LiveTVViewMode.kt#L43-L63
[a-guide]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/EPGGuideView.swift
[d-guide]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/livetv/grid/GuideScreen.kt#L175-L280
[a-dvr]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/DVR/DVRView.swift
[d-dvr]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/dvr/DvrTabContent.kt#L85-L154
[a-search]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Search/SearchView.swift#L4-L16
[d-search]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/search/SearchViewModel.kt#L25-L40
[a-series]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/VOD/VODDetailView.swift#L727-L769
[d-series]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/ondemand/SeriesTarget.kt#L20-L61
[d-upnext]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/watchprogress/WatchProgressViewModel.kt#L115-L223
[a-rate]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/App/TSHLSRemuxer.swift#L2450-L2482
[d-rate]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/player/DisplayFrameRateMatcher.kt#L12-L45
[a-record]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/LiveTV/RecordProgramSheet.swift#L724-L758
[d-record]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/livetv/RecordProgramSheet.kt#L711-L737
[a-logs]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/DeveloperSettingsView.swift#L770-L804
[d-logs]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/settings/DeveloperSettingsScreen.kt#L153-L170
[a-top]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/TopShelfExtension/ContentProvider.swift
[d-cast]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/core/cast/AerioCastReceiverController.kt#L56-L74
[a-server]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/EditServerPage.swift
[d-server]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/feature/settings/EditPlaylistScreen.kt
[a-live-settings]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/LiveTVSettingsView.swift#L600-L615
[a-colors]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Features/Settings/CategoryColorEditors.swift
[a-reminders]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Shared/ReminderManager.swift#L28-L155
[a-xmltv]: https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Networking/PlaylistParsers.swift#L320-L434
[d-xmltv]: https://github.com/jonzey231/AerioTV-Android/blob/7bf4a2ddad9dd6d58152eee5b4eee08873c1da3b/app/src/main/java/com/aeriotv/android/core/parser/XMLTVParser.kt#L22-L70
[r-old-audit]: PARITY-AUDIT.md
[r-connect]: ../components/DispatcharrTask.brs
[r-cap]: ../source/CapabilityModel.brs
[r-direct]: DIRECT-CONNECTIONS-0.3.76.md
[r-conn-scope]: CONNECTION-INTEGRATIONS-0.3.80.md
[r-guide]: ../components/GuideView.brs
[r-groups]: ../source/GuideSettingsModel.brs
[r-browser]: ../components/ChannelBrowser.brs
[r-remote]: ../source/RemoteMapModel.brs
[r-scene]: ../components/AerioScene.brs
[r-epg-search]: ../components/ProgramSearchView.brs
[r-media]: ../components/MediaNavigation.brs
[r-dvr]: ../components/DvrView.brs
[r-dvr-evidence]: DVR-ONE-PANE-0.3.80.md
[r-dvr-scope]: DVR-SERVER-ONLY-SCOPE.md
[r-record]: ../components/DvrNavigation.brs
[r-reminders]: ../source/ReminderModel.brs
[r-vod-task]: ../components/VodTask.brs
[r-vod-view]: ../components/VodView.brs
[r-vod-state]: ../source/VodState.brs
[r-vod-test]: ../tests/VodState.test.brs
[r-xc]: XTREAM-MEDIA-ADAPTER.md
[r-xc-model]: ../source/XtreamModel.brs
[r-m3u]: ../source/M3uModel.brs
[r-settings]: ../source/SettingsModel.brs
[r-info]: ../components/AerioScene.brs
[r-diagnostics]: ../components/Diagnostics.brs
[r-cross]: CROSS-DEVICE-SCOPE.md
[r-release]: RELEASE-0.3.81.md
