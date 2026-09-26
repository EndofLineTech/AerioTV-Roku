# v0.3.81 — Roku testing prerelease

This Developer Mode sideload ZIP targets the Streaming Stick 4K `3820RW2` on
Roku OS `15.3.4` with Dispatcharr `0.31.0`. It is a testing prerelease, not a
Roku Streaming Store submission or proof of full upstream feature parity.
Download **`aeriotv-roku-v0.3.81.zip`** from the GitHub release Assets without
extracting it; GitHub's generated source ZIP is not the Roku application. Check
the accompanying `SHA256SUMS` before installation.

## Since v0.3.80

- Dispatcharr DVR now presents Recording Now, Scheduled, Recent and Series Rules
  in one scrolling list with bold section headings, indented recording rows,
  counts, account-safe refresh and focus-preserving navigation. Active recordings
  appear first.
- Growing Dispatcharr HLS recordings expose Roku's native FF/REW availability
  window. On the tested device, rewind reached the start of an approximately
  three-minute-old disposable recording; Play committed a seek and the reader
  returned to `playing`. FF moved back toward the live edge. Completed and
  stopped files retain the native FF/REW timeline. The Roku labels the growing
  recording's native overlay “Rewind live TV”; seek depth is provider/server
  dependent. See [DVR seek evidence](DVR-TRICKPLAY-0.3.80.md).
- Bounded AAC decoder fallback, unreadable saved-roster recovery, explicit VOD
  sort choices and guide-options focus-pill refinements are included. Earlier
  PO-confirmed Basic/Preview guide and visual/VOD checks are documented for their
  tested candidate builds; those observations are not silently transferred to
  this new release.

## Verification boundary

- `npm ci` and `npm run release:prepare` passed all model/controller and tooling
  suites, compiler checks, Roku package construction and ZIP inspection (187
  files). The versioned package and checksum match `manifest`, `package.json`
  and `package-lock.json`. `npm audit --omit=dev --audit-level=high` found zero
  production vulnerabilities.
- The versioned v0.3.81 ZIP installed and launched on the target Roku;
  read-only ECP reported active developer-slot app version `0.3.81`. This
  establishes install/launch, not physical picture, sound or remote feel.
- The local development build was installed on the target Roku for the
  [single-pane DVR check](DVR-ONE-PANE-0.3.80.md) and the
  [growing-recording seek check](DVR-TRICKPLAY-0.3.80.md). One owner-approved
  disposable recording was identity-checked and deleted after each bounded
  check; the pre-existing server item was not changed.
- Native decoder state and Developer Mode screenshots do **not** establish
  perceived video/audio after DVR seeking. Video pixels are omitted from the
  screenshots. Physical picture/sound, long-duration seek continuity and the
  active-HLS-to-completed-file handoff remain for TV-side validation. Use the
  [v0.3.81 physical worksheet](PHYSICAL-RELEASE-0.3.81.txt); no blank check is
  presented as PASS.

The accepted target-device custom Audio Guide speech limitation remains.
Direct-feed compatibility, VOD rendition availability and server-dependent
catch-up/rewind limitations from [v0.3.80](RELEASE-0.3.80.md) also remain.
No multiview player, new service, or local recording backend ships here.
No credentials, private media labels/URLs, or raw screenshots are included in
this release.

ZIP SHA-256: `a0eb0c2d8e0d32d42a494c43b6655b463d577c8b1aecb0d1c32c48890974b998`
