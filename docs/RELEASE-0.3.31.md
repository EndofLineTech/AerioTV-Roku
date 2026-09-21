# AerioTV Roku v0.3.31 - Testing Preview

This is a Developer Mode testing prerelease built from the current `dev` guide
configuration. It supersedes v0.3.28 for testing; it is not a Roku Streaming Store
release or final Live TV acceptance.

## Why test this build

The current normal development build is intended to replace the earlier
guide-data testing candidate. Test the guide with your actual Dispatcharr account
and report the guide range, channel, time, and observed result without recording
credentials or media URLs. Server data, permissions, provider availability, and
Roku model differences can still affect results.

## New since v0.3.28

### Settings and playback preferences

- Select separate Replay actions for the Guide and live Player, with matching hints.
- Show or hide player logo, channel, title, time/progress, description, next item,
  and control hints.
- Choose Guide/no autoplay or last-channel mini-player startup behavior.
- Choose 10/20/30-second request ceilings and 2/5/10-minute active refresh cadence.
- Read installed version, What's New, GPL license, and Material attribution from
  Settings. Failed preference writes revert the visible value and show a sanitized
  notice.

### VOD enrichment and saved libraries

- Optional account-scoped TMDB enrichment provides supported artwork, cast/crew,
  people, and related-title discovery with required attribution.
- Saved Continue Watching, Watchlist, and Hidden shelves reconcile unavailable or
  removed catalog entries without exposing unavailable content.
- Guide search can route to permitted Movies or TV Shows scopes.

## Install and verify

Download **`aeriotv-roku-v0.3.31.zip`** from the release Assets and upload it
unchanged through the Roku Developer Mode installer. It replaces the single
development-slot application. Download `SHA256SUMS` alongside the ZIP and run:

```sh
shasum -a 256 -c SHA256SUMS
```

Use the [full installation guide](https://github.com/EndofLineTech/AerioTV-Roku/blob/v0.3.31/README.md)
and record settings results in `docs/PHYSICAL-SETTINGS-0.3.30.txt` from the source
tree or your supplied test worksheet.

## Verification

- 47 BrightScript model/controller suites, package-tool tests, compiler validation,
  ZIP inspection, and a clean dependency install pass.
- The exact release ZIP installed and launched remotely on the tested Streaming
  Stick 4K (3820RW2, Roku OS 15.3.4, 1080p). The active Developer Mode app reported
  version 0.3.31; uptime rose from 231966 to 231971 seconds during the check.
- Full physical guide, player, visual/focus, Audio Guide, resource-soak, and
  settings validation remains required for this prerelease.

ZIP SHA-256: `9066e36318c96d956c2978622d822141283b126cd9a3c3712df77325fd8e6386`

## Known limitations

- Guide data remains dependent on the authorized Dispatcharr lineup and available
  server EPG data; this release does not promise offline guide data.
- Roku physical remote input and Audio Guide behavior were not exercised remotely.
- Peak texture use and sustained 0.3.31 browsing/playback remain unmeasured.
- Some VOD provider renditions can fail. Choosing a working source version does not
  repair an upstream provider failure.
- No direct Xtream/M3U setup, DVR, multiview, or cross-device sync is included.
- Rewind is provider-backed, not a universal local buffer; it depends on eligible
  channel archives and whole-minute requests.
