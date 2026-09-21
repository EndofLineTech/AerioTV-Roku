# AerioTV Roku v0.3.33 - Testing Preview

This Developer Mode testing prerelease supersedes v0.3.31. It is not a Roku
Streaming Store release or final physical acceptance.

## Guide mapping fallback

Later previews could show an empty EPG when Dispatcharr's EPG-link request failed:
the client discarded a channel's direct guide ID while waiting for a mapped ID. This
build keeps the direct ID as a fallback and prefers a mapped ID when the request
succeeds. The guide may still display a mapping warning and retry on Refresh guide;
server authorization, EPG data, and provider availability still determine content.

If the guide is empty, use Guide `*` -> Diagnostics after one Refresh guide retry.
Record the sanitized guide stage, code, message, elapsed time, app version, Roku
model/OS, Dispatcharr version, and whether live TV tunes. Do not share credentials,
API keys, server/media URLs, or channel identifiers.

## Remote Control settings

Settings -> Remote control provides per-context Player and Guide assignments for
supported delivered buttons/actions. It includes default/custom persistence, reset,
explicit Do nothing choices, and hints derived from the effective map.

- Player: OK short/hold, Up, Down, Left, Right, Replay, Play/Pause, and Rewind.
- Guide: OK, Left, Hold Left, Right, Rewind, Fast Forward, Replay, and mini-player
  Play/Pause.
- Back remains the fixed recovery path. Home and fullscreen `*` remain Roku-owned.
  The app does not offer arbitrary system-button remapping or unsupported actions.

## Install and verify

Download **`aeriotv-roku-v0.3.33.zip`** from Assets and upload it unchanged through
the Roku Developer Mode installer. Download `SHA256SUMS` beside the ZIP and run:

```sh
shasum -a 256 -c SHA256SUMS
```

Use the [full installation guide](https://github.com/EndofLineTech/AerioTV-Roku/blob/v0.3.33/README.md).
For physical validation, use `docs/PHYSICAL-TESTING-CURRENT.txt` from the tagged
source tree.

## Verification and limits

- 49 BrightScript model/controller suites, package-tool tests, compiler validation,
  ZIP inspection, and a controlled Roku install/launch pass.
- The testing target is Streaming Stick 4K (3820RW2), Roku OS 15.3.4, 1080p.
- Physical testing of every remote-map assignment, affected-account guide fallback,
  visual/focus/Audio Guide behavior, and sustained resource/stability runs remains
  open. This prerelease does not claim those results.
- Provider-backed rewind, VOD rendition availability, and server-side EPG data
  remain dependent on the authorized Dispatcharr/provider configuration.

ZIP SHA-256: `350ef70e9b2e6eee9794468024afd8aae509fd339ea073c55bdf8e4177eb8a53`
