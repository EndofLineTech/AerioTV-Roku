# v0.3.88 — Roku testing candidate (not yet published)

This Developer Mode candidate targets the Streaming Stick 4K `3820RW2` on
Roku OS `15.3.4` with an authorized Dispatcharr `0.31.0` account. It is not a
Roku Channel Store submission. If approved for publication, install the
versioned **`aeriotv-roku-v0.3.88.zip`** asset, not GitHub's source ZIP;
verify `SHA256SUMS`. A same-identity signed `.pkg` must be generated from that
exact ZIP and checked separately before publication.

## Since v0.3.84

- **Guide and remote:** cached channel logos, quicker row revisits, channel
  wrap, repeated held FF/REW paging, a shorter common Options menu and direct
  full-program details with paginated long descriptions. The guide refreshes
  its time position when returning from playback without discarding deliberate
  time travel.
- **Live playback:** bounded startup retries, source failover and explicit stop
  controls. Audio recovery messages are less intrusive when the compatible
  stream subsequently plays. AC3 output and audible audio continuity on the
  reporter's device have not been established by a screenshot or model test.
- **DVR and presentation:** a sectioned Roku PosterGrid for Recording Now,
  Scheduled, Recent and Series Rules, with artwork/no-artwork presentation;
  simplified VOD options and a local missing-artwork fallback; corrected
  settings-rail focus styling and Settings-to-Connection handoff.
- **Account and release integration:** newly created Dispatcharr slots default
  to remembering a verified API key; existing choices stay intact. The
  certification-baseline voice-entry/launch integrations remain testing-only.

## Limits and device evidence

The verified version fields agree on `0.3.88`; `npm run release:prepare`
passed model/controller, package, Python-tool, compiler and ZIP checks. The
normal ZIP contains **195 files** and `npm audit --omit=dev --audit-level=high`
found zero production vulnerabilities. The exact versioned ZIP installed on
the target, reported developer-slot `0.3.88`, and returned to the authorized
36-channel guide. Private route-by-route visual, focus and fixture evidence
is in [UI audit](UI-AUDIT-0.3.88.md). Synthetic UI data never establishes a
real provider catalog or recording lifecycle.

The connected account lacks guide mappings, populated VOD and live/scheduled
DVR rows for provider-backed acceptance. A native MPEG-TS tune briefly reached
`playing` and then stopped; physical picture, sound and the requested AC3
output remain **unverified**. An unknown HLS token returning HTTP 410 did not
establish playable HLS: Automatic remains MPEG-TS, and explicit HLS is only a
controlled test option. The previously accepted intermittent growing-DVR
near-end reader limitation is not fixed; the later unverified HLS-to-file
recovery code is intentionally excluded. Roku Store certification tasks are
tracked separately. No new shared-server recordings or mappings were made.

ZIP SHA-256: `62f35262f1c5cfe24c60201924382eb07af8fdc453e2799e0b0e5c9e6dd49b40`

Publication requires a release-readiness decision on open acceptance gaps,
verification of the signed package made from this ZIP with the existing
channel identity, and final issue dispositions. An older `.pkg` was signed
before later fixes and is ineligible for this release.
