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
| Authorized guide, channel focus and logo cache | PASS (visual) | `gh-release-guide.jpg`, `gh-guide-logo-cache.jpg`; available lineup has no guide mappings. |
| Guide first/last channel wrap and shorter Options/More menus | PASS (navigation/visual) | `gh-guide-wrap-first.jpg`, `gh-guide-wrap-last.jpg`, `gh-guide-common-menu.jpg`, `gh-guide-more-menu.jpg`. |
| Program details, long description paging | PASS (fixture) | `gh-fixture-epg-page1.jpg`, `gh-fixture-epg-page5.jpg`; synthetic five-page text, not real EPG. |
| Live player startup, Options, transport, audio and subtitle menus | PASS (menu visibility) | `gh-release-player-startup.jpg`, `gh-release-player-options.jpg`, `gh-release-player-transport.jpg`, `gh-release-player-audio-mode.jpg`, `gh-release-player-captions.jpg`, `gh-release-player-subtitle-tracks.jpg`; transport description shortened after these captures. |
| Live video and audio continuity | SKIP (physical A/V) | A native MPEG-TS tune briefly reached `playing` then stopped; another tune failed. Developer screenshots cannot establish decoded picture or audible sound. HLS probe returning 410 did not prove playable HLS; Automatic remains MPEG-TS. |
| VOD empty library, Options, More, Back | PASS (visual/navigation) | `gh-release-vod.jpg`, `gh-release-vod-options-fixed.jpg`, `gh-release-vod-more.jpg`. |
| VOD populated poster row | PASS (fixture layout only) | `gh-fixture-vod.jpg` shows five fictional titles. A subsequent fallback-poster adjustment has not been recaptured; provider catalog, details and actual playback remain SKIP. |
| DVR real completed item and details | PASS (visual) | `gh-fixture-dvr-second.jpg` and earlier real-item captures; active/scheduled/rule provider data not available. |
| DVR four sections and focused first-row clipping | PASS (fixture visual) | `gh-fixture-dvr-border-fixed.jpg` shows all section counts and the entire first focused border; subsequent section scroll and Back/dialog need recapture. |
| Settings Live TV, Player, Remote (guide/player), Appearance, General, About, licenses, What's New and Connection | PASS (screen/menu entry) | `gh-release-ui-*.jpg` under private `out/`; Connection returned to setup without a carried-through OK after the fix. Updated What's New text and other last-pass labels still need a final ZIP retest. |
| Connection edit/forget/reconnect and first-run setup | SKIP (destructive/unauthorized provider changes) | Setup and connection surfaces were viewed only. Saved account and server lineup were not intentionally changed. |
| Provider-backed scheduled/active DVR, series rules, populated VOD, mapped EPG, catch-up and recording playback | SKIP (account data) | Synthetic fixtures establish layout only. No new shared-server recordings or mappings were created. |
| Exact final ZIP, signed package identity and post-install guide return | SKIP (not built/installed yet) | A previous `.pkg` predates later fixes and cannot be used. |

Release gate: repeat focus, scroll, dialogs and Back on the final exact ZIP,
especially DVR Scheduled/Recent/Series Rules, VOD poster fallback, What's New
and the shortened player transport label; inspect the final capture for clipping.
Restore the normal ZIP after every disposable probe. Record physical picture
and sound independently if witnessed; otherwise retain SKIP. Do not close the
UI-audit bead or publish on the strength of these intermediate screenshots.
