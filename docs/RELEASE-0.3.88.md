# v0.3.88 — Roku testing prerelease

This Developer Mode sideload ZIP targets the Streaming Stick 4K `3820RW2` on
Roku OS `15.3.4` with an authorized Dispatcharr `0.31.0` account. It is a
testing prerelease, not a Roku Channel Store submission. Install the versioned
**`aeriotv-roku-v0.3.88.zip`** asset, not GitHub's source ZIP, and verify
`SHA256SUMS`. The accompanying same-identity `.pkg` is the signed Roku
distribution package, not the Developer Mode sideload ZIP.

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

The Product Owner confirmed validation of the reported top-pill animation and
AAC/AC3 behavior. The nine GitHub-linked break/fix reports in this testing
scope are closed with their verification boundaries recorded individually.

## Limits and device evidence

The verified version fields agree on `0.3.88`; `npm run release:prepare`
passed model/controller, package, Python-tool, compiler and ZIP checks. The
normal ZIP contains **195 files** and `npm audit --omit=dev --audit-level=high`
found zero production vulnerabilities. The exact versioned ZIP installed on
the target, reported developer-slot `0.3.88`, and returned to the authorized
36-channel guide. Private route-by-route visual, focus and fixture evidence
is in [UI audit](UI-AUDIT-0.3.88.md). Synthetic UI data never establishes a
real provider catalog or recording lifecycle.

The connected account initially lacked guide mappings. After the owner fixed
the guide, an explicit Roku refresh displayed mapped programme titles, timing,
subtitles, colours and real program details on the authorized lineup; revisited
rows kept their logos and colours. Populated VOD and live/scheduled DVR rows
remain unavailable for provider-backed acceptance. Native MPEG-TS tunes have
also stopped with source-specific Roku media errors; these tests cannot prove
continuous picture/sound for every stream. The Product Owner's AAC/AC3
acceptance is distinct from that broader playback check. An unknown HLS token
returning HTTP 410 did not establish playable HLS: Automatic remains MPEG-TS, and
explicit HLS is only a controlled test option. The previously accepted
intermittent growing-DVR near-end reader limitation is not fixed; the later
unverified HLS-to-file recovery code is intentionally excluded. Roku Store
certification tasks are tracked separately. No new shared-server recordings
or mappings were made.

The exact **195-file versioned ZIP** was installed and launched on the target;
Roku reported developer-slot `0.3.88` and returned to the authorized guide.
The Roku Packager reported success using the existing channel developer ID.
Its installed-source MD5 matched the exact versioned ZIP before signing;
the downloaded `.pkg` has the Roku package header and was checked against the
accompanying checksum. No signing credential is in these assets.

ZIP SHA-256: `62f35262f1c5cfe24c60201924382eb07af8fdc453e2799e0b0e5c9e6dd49b40`

Signed `.pkg` SHA-256: `84c5c919abef745b97b0095ed6c5519251e48628e3fba561c239dedd7f806629`
