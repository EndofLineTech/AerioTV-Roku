# v0.3.84 — Roku testing prerelease

This Developer Mode sideload ZIP targets the Roku Streaming Stick 4K
`3820RW2` on Roku OS `15.3.4` with Dispatcharr `0.31.0`. It is a testing
prerelease, not a Roku Channel Store submission. Download the versioned
**`aeriotv-roku-v0.3.84.zip`** asset rather than GitHub's generated source ZIP,
and check the accompanying `SHA256SUMS` before installing.

## Since v0.3.83

- **Private, on-TV support code:** Diagnostics now offers an explicit
  **Show support code** action. A current-account-scoped, allowlisted snapshot
  of at most eight session events becomes a grouped code with a transcription
  checksum. The guide/player is covered while the code is displayed; Back,
  account change or 90 seconds clears it from the TV. The code can be
  photographed or dictated and decoded offline with
  `scripts/decode-roku-support-code.py`. It never encodes event message text,
  media names, account identity, server URLs or credentials. A previously
  photographed code remains decodable; it is not an authentication token.
  The existing local event viewer and explicit developer-console export remain.
  See [design, risk and native evidence](ROKU-DIAGNOSTICS-SUPPORT-CODE.md).
- **Reconnect repair:** unified-search Movie/TV detail selection is reattached
  when the Guide is recreated after a connection change.
- **Comskip contract review:** Dispatcharr 0.31's finalizer follows the global
  DVR Comskip setting, not a per-recording schedule flag. A schedule-time
  On/Off choice would mislead users, so the existing guarded post-completion
  Queue action remains the accurate per-item control. No shared server
  setting was changed. See [pinned source evidence](DVR-COMSKIP-SCHEDULE-0.3.83.md).

## Release scope and known limits

This tag starts from the immutable v0.3.83 release and selects only the
Comskip contract documentation, support code and reconnect observer repair.
The later unverified DVR HLS status-recovery candidate on `dev` remains
**excluded**. The owner's accepted single near-end `-3` reader observation
remains a disclosed testing limitation, not a claimed fix. The custom Audio
Guide speech limitation, source-specific codec/VOD limits, unverified
display-rate matching and absent multiview also remain. No always-on listener,
new runtime service, local recorder or server write is introduced by this
release. No credentials, private media URLs or raw screenshots are distributed.

## Verification boundary

`npm ci`, `npm run release:prepare`, the production audit
(`npm audit --omit=dev --audit-level=high`) and
`shasum -a 256 -c SHA256SUMS` passed. The 190-file package passed model,
controller, Python decoder, compiler, ZIP-root and exclusion checks; npm
reported **zero production vulnerabilities**. `package.json`, the lockfile
and ZIP `manifest` agree on **0.3.84**. The exact versioned ZIP installed and
launched on the target Roku; ECP reported developer-slot `0.3.84`. Its
Diagnostics support code was visible over an opaque guide cover, and Back
cleared the code screen while leaving the guide operational. The earlier
development candidate also demonstrated automatic 90-second expiry. The
offline decoder accepted the fixed artificial sample code; it transmits
nothing to a server. Private device captures stay ignored locally.

The Roku checks do not establish physical picture/sound for this exact ZIP,
and an alternate-account/120% text-size TV check was not performed. Use the
[physical worksheet](PHYSICAL-RELEASE-0.3.84.txt) for those observations.
No new Dispatcharr recording or server mutation was made.

ZIP SHA-256: `64e2501c1cde94a9651f7dc223e0aba17c006ff9cea61b7e4dfbc3daba23abe1`
