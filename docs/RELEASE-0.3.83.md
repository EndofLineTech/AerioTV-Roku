# v0.3.83 — Roku testing prerelease

This Developer Mode sideload ZIP targets the Roku Streaming Stick 4K
`3820RW2` on Roku OS `15.3.4` and Dispatcharr `0.31.0`. It is a testing
prerelease, not a Roku Channel Store submission. Download the versioned
**`aeriotv-roku-v0.3.83.zip`** asset, not GitHub's generated source ZIP, and
check the adjacent `SHA256SUMS` before installing.

## Since v0.3.82

- **Unified TV search:** one guide search submission now returns interleaved,
  permitted server-indexed EPG airings, Movies and TV Shows. All, EPG title,
  EPG description, Movies and TV Shows scopes use bounded server pages. EPG
  selections return to the authorized channel/time; Movies and TV Shows open
  existing account-verified detail views, and Back returns to the selected
  search result. Direct Xtream/M3U accounts continue to use their narrower
  channel/category search paths. See [implementation and native evidence](UNIFIED-SEARCH-0.3.83.md).
- **Guide readability:** the focused group-pill fill no longer has a dark
  center/cap seam. Bold left/right arrows appear only when additional groups
  exist in that direction. An available S/E episode code now precedes its
  subtitle on the same secondary line rather than crowding the LIVE/NEW/time
  row. See [guide device evidence](GUIDE-PILLS-EPISODES-0.3.82.md).
- **DVR controls:** Rewind and Forward chevrons were optically centered in
  the recording control pills. The owner accepted the existing single-pane
  DVR and picture/sound after Rewind/Forward on the earlier v0.3.82 ZIP.

## Explicit release scope and limits

This release starts from the immutable v0.3.82 tag and selects only the
verified post-tag guide, DVR glyph and unified-search commits. The later
status-confirmed HLS recovery candidate on `dev` was **excluded** because
its one-shot status check can miss server finalization and its real-server
handoff remains unverified. The owner's previously accepted single near-end
`-3` HLS reader observation therefore remains a disclosed testing limitation,
not a claimed fix. The deferred candidate remains on the `dev` branch for
separate verification.

The accepted custom Audio Guide speech limitation, source-specific
VOD/codec boundaries, unverified display-rate matching and missing multiview
remain. No new runtime server, shared Dispatcharr profile change or local
recorder is included. No credentials, private server URLs or raw device
screenshots are distributed.

## Verification boundary

`npm ci`, `npm run release:prepare`, the production audit
(`npm audit --omit=dev --audit-level=high`) and
`shasum -a 256 -c SHA256SUMS` passed. The versioned
ZIP passed compiler, model/controller, Python tooling, package-root and
exclusion checks (190 package files); npm reported **zero production
vulnerabilities**. `package.json`, `package-lock.json` and ZIP `manifest`
agree on **0.3.83**. The versioned asset installed and launched on the target
Roku; ECP reported developer-slot version `0.3.83`. One native Dispatcharr
query returned interleaved EPG/Movie/TV Show results, FF and Rew moved between
result pages, Back returned to the guide, and the guide group arrow remained
visible. Earlier pre-release native checks exercised Movie/TV detail, Back
focus and EPG-to-guide selection. Private screenshots remain ignored locally.

These install/navigation checks do not establish physical picture or sound
for this exact ZIP. Use the [physical worksheet](PHYSICAL-RELEASE-0.3.83.txt)
for TV-side checks; no new server recording was created for this release.

ZIP SHA-256: `d4e9b5f0447c38fb40f4380e0aff5a0f93b580a52443a3c8be46bd0ad5f012cf`
