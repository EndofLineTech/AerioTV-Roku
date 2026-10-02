# Roku UI audit — v0.3.88 testing candidate (in progress)

Target: Streaming Stick 4K 3820RW2, Roku OS 15.3.4. Captures named below
are private, ignored files in this release worktree's `out/` or the main
checkout's `out/` (guide and earlier real-DVR captures); they were made
from successive development-slot ZIPs and disposable visual probes, **not**
from a signed final release artifact. PASS means the named visual or navigation
behavior was observed, not that every interaction on that screen passed.
Probes use fictional, credential-free metadata and do not verify a provider.

| Route / state | Result | Evidence and scope |
| --- | --- | --- |
| Authorized guide, channel focus and logo cache | PASS (native provider data) | After the owner's guide fix, `*` → More guide actions → Refresh guide loaded mapped current/next titles, times, subtitles, category colours and logos for the 36-channel lineup. `gh-guide-after-explicit-refresh.jpg`, `gh-guide-refresh-scrolled.jpg`, `gh-guide-refresh-revisited.jpg` and `gh-guide-refresh-revisit-immediate.jpg` show different/revisited rows populated. |
| Guide first/last channel wrap and shorter Options/More menus | PASS (navigation/visual) | `gh-guide-wrap-first.jpg`, `gh-guide-wrap-last.jpg`, `gh-guide-common-menu.jpg`, `gh-guide-more-menu.jpg`. |
| Guide follows now after playback, preserves deliberate time travel | PASS (native control path / fixture) | Normal ZIP played a real channel for two minutes then returned to the current-time guide without Replay; disposable one-hour-stale guide re-entry selected current vs historical fictional programmes correctly. A real one-hour soak stopped after ~15 minutes with a source demux error. See [guide return comparison](GUIDE-RETURN-0.3.88.md). |
| Program details, long description paging | PASS (real detail + fixture paging) | `gh-guide-refresh-real-details.jpg` shows a mapped provider title, description and artwork opened directly from the guide. `gh-fixture-epg-page1.jpg`, `gh-fixture-epg-page5.jpg` exercise a synthetic five-page description, not a real five-page provider description. |
| Live player startup, Options, transport, audio and subtitle menus | PASS (menu visibility) | `gh-release-player-startup.jpg`, `gh-release-player-options.jpg`, `gh-release-player-transport.jpg`, `gh-release-player-audio-mode.jpg`, `gh-release-player-captions.jpg`, `gh-release-player-subtitle-tracks.jpg`; transport description shortened after these captures. |
| Live video and audio continuity | SKIP (physical A/V) | A native MPEG-TS tune briefly reached `playing` then stopped; another tune failed. Developer screenshots cannot establish decoded picture or audible sound. HLS probe returning 410 did not prove playable HLS; Automatic remains MPEG-TS. |
| VOD empty library, Options, More, Back | PASS (visual/navigation) | `gh-release-vod.jpg`, `gh-release-vod-options-fixed.jpg`, `gh-release-vod-more.jpg`. |
| VOD populated poster row and missing-artwork fallback | PASS (fixture layout only) | `gh-fixture-vod-fallback-valid.jpg` shows five fictional titles with local placeholder art. The first fixture had numeric IDs, which incorrectly chose a server image route and did not test the fallback. Provider catalog, details and actual playback remain SKIP. |
| DVR real completed item and details | PASS (visual) | `gh-fixture-dvr-second.jpg` and earlier real-item captures; active/scheduled/rule provider data not available. |
| DVR four sections, focused cards, rule facts and Back | PASS (fixture visual/navigation) | `gh-fixture-dvr-focus-scheduled.jpg`, `gh-fixture-dvr-focus-recent.jpg`, `gh-fixture-dvr-focus-series.jpg`, `gh-fixture-dvr-series-dialog.jpg`, `gh-fixture-dvr-back-guide.jpg`. All four sections scroll with intact first-row border; rule removal was not selected. |
| Settings Live TV, Player, Remote (guide/player), Appearance, General, About, licenses, What's New and Connection | PASS (screen/menu entry) | `gh-release-ui-*.jpg` under private `out/`; Connection returned to setup without a carried-through OK. On the later normal ZIP, `gh-release-final-settings-rail-mask.jpg` has no square joins, `gh-release-final-whats-new-retake.jpg` has current text, and `gh-release-final-transport-retake.jpg` labels Automatic as MPEG-TS. |
| Connection edit/forget/reconnect and first-run setup | SKIP (destructive/unauthorized provider changes) | Setup and connection surfaces were viewed only. Saved account and server lineup were not intentionally changed. |
| Provider-backed scheduled/active DVR, series rules, populated VOD, catch-up and recording playback | SKIP (account data) | Synthetic fixtures establish layout only. No new shared-server recordings or mappings were created. |
| Exact versioned ZIP install and authorized guide return | PASS (native UI) | `aeriotv-roku-v0.3.88.zip` (SHA-256 `62f35262f1c5cfe24c60201924382eb07af8fdc453e2799e0b0e5c9e6dd49b40`) was installed from committed app source; read-only ECP reported developer-slot `0.3.88`, and `gh-release-exact-asset-guide-settled.jpg` shows the authorized 36-channel guide. |
| Signed package identity and final ZIP parity | SKIP (not packaged yet) | A previous `.pkg` predates later fixes and cannot be used. |

Release gate: generate and inspect a signed package from the exact committed
ZIP using the existing identity; confirm final asset parity and release scope.
Signed package testing cannot be inferred from an unsigned ZIP or a disposable
fixture.
Restore the normal ZIP after every disposable probe. Record physical picture
and sound independently if witnessed; otherwise retain SKIP. Do not close the
UI-audit bead or publish on the strength of these intermediate screenshots.
