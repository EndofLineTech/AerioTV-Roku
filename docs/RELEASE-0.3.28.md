# AerioTV Roku v0.3.28 — Testing Preview

A major update since v0.3.8 for the independent BrightScript/SceneGraph Roku port
of AerioTV. **Live TV, VOD and provider-backed time-shifting** use your existing
Dispatcharr deployment; no additional service/container is required.

## New since v0.3.8

### Movies and TV Shows
- Paged libraries with search, categories, sorting and episode browsing.
- Continue Watching, resume/from-beginning controls, watchlists, hidden titles and
  watched state, scoped to the connected account.
- Authorized provider filtering and remembered source-version selection.
- Improved DS9/unfetched episode loading and English-description preference when
  suitable provider metadata exists.

### Catch-up, Restart and rewind
- Replay eligible completed programs or **Restart Program** while a show is airing,
  subject to provider archive availability.
- **Provider-backed rewind up to 60 minutes since tuning** on catch-up channels.
- Configurable **1/2/5-minute skips**, held timestamp/marker preview, explicit
  seek commit/cancel and pause preservation.
- **Go Live** returns to the same channel. During provider rewind it preserves
  the original tune-history boundary.
- Playhead-relative program information, estimated broadcast time, delay and
  requestable history bounds. Missing/expired windows have explicit return paths.
- Material history icons beside channel numbers identify advertised catch-up.

### Navigation and reliability
- Guide header **Live TV / VOD / Settings**, with Movies/TV Shows library tabs.
- Categorized settings: Live TV, Player, Appearance, General and Connection.
- **Hold OK** for app player options; short OK still shows/hides live information.
- Faster useful guide startup, bounded metadata caching and independent mapping
  loading, cancellation and account isolation.
- Bounded startup/midstream recovery, contextual Retry/Return, sanitized diagnostics
  and the corrected native Roku `ts` reader hint.

Existing guide search, favorites, group layouts, collections, foreground reminders,
mini-player, channel/recent overlays, audio/caption options and sleep timer remain.

## Download and install

Download **aeriotv-roku-v0.3.28.zip** from Assets and keep it zipped. Do not use
GitHub's automatic **Source code (zip)** as the app package.

1. Enable Roku Developer Mode: from Home press **Home ×3, Up ×2, Right, Left,
   Right, Left, Right**, then follow Roku's setup prompts.
2. On a computer on the same network, open **`http://<your Roku IP>`**.
3. Sign in as **rokudev** with the developer password you chose.
4. Upload **aeriotv-roku-v0.3.28.zip** and select Install.
5. Connect using your Dispatcharr base URL and dashboard credentials or API key.

Only one development-slot app can be installed at a time. Updating replaces that
slot; no Node.js or compiler is needed for the provided ZIP.

[Full installation guide and controls](https://github.com/EndofLineTech/AerioTV-Roku/blob/v0.3.28/README.md)

## Controls to know

- **Hold OK:** app live-player options. **Fullscreen `*`:** Roku system options.
- **Back:** dismiss inner UI, then minimize live playback. Stop is explicit.
- **Live Rew:** provider history; available once the current tune has a requestable
  minute. Player options also offers **Rewind history (provider)**.
- **Archive/Restart/rewind:** tap Rew/FF to skip, hold to preview, OK/Play to commit,
  Back to cancel preview, Up for **Go Live** and skip settings.
- Open **Program details** for the separate archive/Restart and Watch LIVE choices.

## Scope and known limitations

- **Testing prerelease**, not a Roku Streaming Store app or full upstream parity.
- Tested baseline: **Streaming Stick 4K 3820RW2, Roku OS 15.3.4, 1080p, Dispatcharr
  0.31.0**. Other Roku models are not independently verified.
- Rewind is **provider-backed**, not a guaranteed local buffer or universal channel
  capability. Requests use whole minutes; archives can be delayed, missing or end
  early. Unavailability does not silently substitute live playback.
- Some VOD provider renditions still fail. Choosing a working source version does
  not repair the failing provider. Missing synopses remain a known limitation;
  complete VOD TMDB synopsis enrichment is not included.
- AAC compatibility requires an existing authorized copy-video/AAC output profile.
  Admin stream-source changes affect everyone watching that shared channel.
- No direct Xtream/M3U setup, DVR management, multiview or cross-device sync.
  Hide picture and reminders remain foreground-only. Inactive channels do not keep
  extra rewind readers open.

## Verification and integrity

44 automated suites and compiler/package checks accompany this version. Native
device checks exercised playback, session cleanup, history boundaries and failure
handling. The maintainer reported **50/50 consolidated physical checks PASS**;
this is not a guarantee for every provider or Roku model.

Download **SHA256SUMS** alongside the ZIP and verify with:

```sh
shasum -a 256 -c SHA256SUMS
```

ZIP SHA-256: `bebe4fdf8ebe19e0415574516d43f1de403de568fd09d966cccce9938706c91f`

Source and build instructions are available at tag **v0.3.28**. This independently
maintained port uses GPL-3.0-or-later, with bundled third-party attribution/licenses.
