# v0.3.82 — Roku testing prerelease

This Developer Mode sideload ZIP targets the Streaming Stick 4K `3820RW2` on
Roku OS `15.3.4` with Dispatcharr `0.31.0`. It is a testing prerelease, not a
Roku Streaming Store submission or proof of full upstream feature parity.
Download **`aeriotv-roku-v0.3.82.zip`** from the GitHub release Assets, not
GitHub's generated Source code ZIP. Check the accompanying `SHA256SUMS`.

## Since v0.3.81

- [VOD curation](VOD-STATE-RETENTION-0.3.81.md) retains up to 40 explicit
  Watchlist/Hidden/Watched choices ahead of 20 recent uncurated rows. Capacity
  is visible rather than silently discarding an older choice; the aggregate
  registry preference ceiling is still 24,000 UTF-8 bytes. A synthetic 60-row
  Roku fixture survived a process/package replacement. Reverting to an old
  build and editing VOD may truncate rows beyond that build's 20-row limit.
- [Series episode targeting](VOD-SERIES-TARGET-0.3.81.md) offers an explicit
  Play/Resume/Next selection from series detail and promotes a verified next
  episode into Continue Watching after a completed one. It rechecks the
  selected episode before playback, never auto-plays, and falls back to Browse
  when the bounded catalog or legacy progress order is inconclusive.
- [Growing DVR playback controls](DVR-CONTROLS-0.3.81.md) use the same Aerio
  action-pill component as Live TV, with bounded 30-second Rew/FF seeking and
  a focusable information/timeline panel. Completed files retain Roku's native
  timeline. A disposable authorized recording resumed native `playing` after
  a Rewind seek; a later Forward attempt near the scheduled end coincided with
  Roku error **-3**, `reader pick stream error:bad:mpr playlist file is too
  large`. Causality and physical picture/audio continuity are unverified.
  `AerioTV-Roku-4vb` and `AerioTV-Roku-0i3` remain open/blocked accordingly.
- [EPG secondary titles](GUIDE-SECONDARY-TITLE-0.3.81.md) now show provider
  `sub_title` below generic titles such as “College Football” on wide Preview
  tiles and in the selected header. **Program subtitles / taller Preview** is
  On by default with six 112-pixel rows; Off restores the original seven-row
  96-pixel compact Preview. Basic remains ten rows. The pills stay inside tile
  and channel bounds; “Ole Miss at Florida” was visible in the native guide.

## Verification boundary

- `npm ci`, `npm run release:prepare` and
  `npm audit --omit=dev --audit-level=high` passed. The 189-file package passed model/controller,
  Python tooling, compiler, ZIP-root and exclusion checks; npm reported zero
  production vulnerabilities. `package.json`, `package-lock.json` and ZIP
  `manifest` agree on **0.3.82**. The versioned ZIP and `SHA256SUMS` were made
  from that same verified build, and `shasum -a 256 -c SHA256SUMS` passed.
- The matched VOD, series, guide and synthetic recording cases were observed
  on the target Roku in their source-pinned development builds; details and
  evidence limits are linked above. The **versioned v0.3.82 ZIP** installed
  and launched on the target; read-only ECP reported developer-slot app
  version `0.3.82`, and the six-row subtitle-rich guide appeared with the
  previously restored On account choice. This is an install/UI check, not a
  full physical A/V sign-off for this exact artifact.
- Developer Mode screenshots omit decoded video pixels; `playing` is not a
  physical picture/audio test. Use the
  [v0.3.82 physical worksheet](PHYSICAL-RELEASE-0.3.82.txt) for TV-side
  verification. The known near-end growing-HLS reader failure is not waived by
  this prerelease's automated checks.

The accepted custom Audio Guide speech limitation, source-specific VOD/codec
limits, unverified frame-rate matching and lack of multiview remain. No new
server service, shared Dispatcharr profile or local recorder is included.
No credentials, private media URLs or raw screenshots are shipped.

ZIP SHA-256: `e49d771a1b4c83729cfee9be490dd85574b8da12ae7f4c26c626168975e764cd`
