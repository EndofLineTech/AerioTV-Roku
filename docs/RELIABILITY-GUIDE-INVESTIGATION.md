# Reliability and guide investigation — November 18, 2026

Scope: `d43d`, `667m`, `o7b`, `cs6`, `njh`; discovered defect `9k6n`.
Released v0.3.102 ZIP/package and the GitHub prerelease are immutable.
New application changes use development version **0.3.103**, not a replacement
v0.3.102 build.

## Proven source defect: parsed PIN metadata

The network-free native policy run resolved all five checked function names as
`Function`; it did not reproduce the historical loader error. It instead exposed
three failing UUID import cases. Further native instrumentation established:

- A valid parsed row exposes `row.pinType`/`row.pinHash` and passes PIN validation.
- Its case-sensitive JSON map contains lowercase keys, so `row["pinType"]` is
  `invalid`, while `row["pintype"]` is a string.
- `phoneSetupProfileMetadata` validated named properties, then copied different
  dynamic aliases. This produced invalid PIN metadata and the final store check
  refused the entire import. It was **not a silent PIN-removal/access bypass**.

The fix copies the same three named values checked by the validator. Tests cover
parsed PIN retention, refusing to erase protection with malformed metadata, fresh
sender UUID preservation, existing-default UUID retention and invalid-ID fallback.

Native red: `out/reliability-native-pin-metadata-red.log/.json`.
Uninstrumented native green: `out/reliability-native-pin-metadata-green.log/.json`,
with exact v0.3.102 restoration. This fixes `9k6n`, not `d43d` or `667m`.

The native policy run with `--logo-checks` also passes the production logo status
callback tests, including new decode diagnostics:
`out/reliability-native-logo-policy-green.log/.json`.
Actual unchanged-controller/provider Apple→Child and Android→adult imports of
the 0.3.103 development build pass against live Dispatcharr, with exact v0.3.102
restoration after each. These whole-app regressions do not substitute for the
native lowercase-key red/green test of the specific defect.

Full `npm run verify` passes for v0.3.103 / 380 shipping files:
`out/reliability-guide-103-full-verify.log`. Targeted logo/tool tests and the
compiler also pass. Official Roku Static Analysis reports only the existing
French-`des` false positive at `DescriptionModel.brs:6`.
The final gate ZIP differs from the native-tested development ZIP only by one
GuideLogos explanatory comment, not executable code; the explicit comparison is
`out/reliability-103-final-source-comparison.json`. No v0.3.103 signed package or
public release was created, and v0.3.102's original checksums remain valid.

## Missing key delivery: narrowed, not resolved

`out/reliability-picker-no-capture-native.json` reproduces first Select timeout
(3,023 ms), no intent callback, despite omitting screenshot capture. Screenshots
are therefore **not necessary** for this reproduction.

Separate curl and phase-traced urllib runs both pass all eight HTTP-200 key
commands and six actual intent callbacks:

- `out/reliability-picker-curl-key-trace-native.json`
- `out/reliability-picker-urllib-transport-native.json`

The urllib pass records TCP connect/request-send and response-header phases;
native raw-key telemetry includes only enumerated navigation keys. Neither pass
establishes a Python transport bug, screenshot cause, firmware cause or app fix.
No failed key is retransmitted inside a run. No wake/reboot/network-policy change
is performed. Every completed run restores the exact v0.3.102 ZIP.

The picker runner now preserves unique probe/screenshot artifacts, supports
controlled screenshot/no-capture and transport comparisons, and requires the
exact eight-command sequence plus all six callbacks for acceptance. The policy
runner preserves unique artifacts and can capture function-binding types and
private refusal locations without contacting a provider or using owner storage.

A subsequent A/B/A comparison reuses **one unchanged saved ZIP**, checks its
SHA-256 before each run and verifies its installed MD5 after the key sequence:
`out/reliability-same-zip-comparison.json`. Both urllib-trace runs and the curl
run pass eight commands/six callbacks and exact restoration. This removes
rebuilding/package identity as a difference between these three passing cases;
it still does **not** explain the earlier failed key delivery. The new
`--reuse-probe` option requires an expected SHA-256 and rejects non-picker
archives. Its tests and these native runs pass separately after the full
application verification above; no production source changed afterward.

Fresh read-only device context verifies exact released v0.3.102 installed and
active, no screensaver, 3820RW2 / OS 16.0.4 build 853:
`out/reliability-current-device-context.json`. This clears `yuuv`'s stale
unexpected-installed-fixture blocker; it does not explain its historical
missing-launch event. `36eu`'s separate no-launch report, `5fif`'s post-PIN
authentication stall and `kz60`'s lost original key assertion remain distinct.
The older `a4n` decoder incident had already recovered after an explicitly
authorized restart and a passing 14-group matrix; it is not described as a
current playback outage or a permanent fix.

## Guide/logos: current evidence and next affected-user capture

Read-only queries against both approved **live Dispatcharr** test accounts show
36 authorized channels, 36 EPG assignments and 36 usable logo IDs each:
`out/reliability-guide-live-account-readiness.json`.
Neither is the affected 91-channel account. Existing detail-first mapping and
bounded oversized-list fallback are not reimplemented or declared fixed by a
smaller-account pass.

Direct Roku validation then used the released 0.3.102 ZIP as the base for a
private driver with isolated storage and live Dispatcharr. Mapping resolved
36/36 links in 1,819 ms via per-ID details. After 20 seconds the initial viewport
had six programmes-bearing rows and six ready logos. The sweep covered all
36 channels; each sampled viewport had six populated rows and all six logo
files downloaded. Ready Poster counts were 6/6/6/3/5/5/6 at the sampled
positions, with no explicit `failed` status. Download completion is not the
same as immediate rendering after a scroll, and these snapshots do not
establish why every incomplete Poster was not ready. The exact release was
restored (`out/guide-live-scroll-102.log`).

Separately, the guide permanently suppressed repeat downloads after a logo
failure for the lifetime of the connection. The **Refresh guide** action
previously did not clear that suppression. The development fix resumes
bounded attempts on explicit Refresh, keeps successful cached artwork, and
does not allow an already-running batch to reinstate the pre-refresh
suppression. A failed retry is suppressed again until the next explicit
refresh. This is not an automatic retry loop or a claim about the original
91-channel incident.

The native refresh comparison seeded one previously failed logo locally,
then invoked the real Refresh guide handler against live Dispatcharr. On
0.3.102 the image remained suppressed; on development 0.3.103 the normal
download task fetched it again. No server-side failure was injected.
See `out/guide-live-refresh-102.log` and `out/guide-live-refresh-103-settled.log`.
`scripts/test-live-guide-scroll-native.py` supports repeating the sweep with
`--seed-logo-failure` and distinguishes an actual download from a cleared flag.

A follow-up sweep (`out/guide-live-poster-phases.log`) again recovered the
seeded failure, covered all 36 channels, and restored the exact release. At
every sampled viewport, all six files were downloaded and all six Posters
pointed to the correct cached URI. Non-ready Posters reported `loading`, not
`failed` or a stale assignment (one or two at four intermediate positions).
This isolates the observed scroll delay to after download and URI assignment;
it does not identify a decoder failure or reproduce the original report.

The held-viewport sweep (`out/guide-live-poster-held.log`) resampled each
of the three partially ready viewports ten seconds later without scrolling.
Each went from five ready Posters and one loading to six ready, with the same
correct cached assignments. Across this 36-channel run, no sampled logo stayed
missing after the extra wait.

The timed sweep (`out/guide-live-poster-timing.log`) sampled seven viewports,
including the initial one. After scrolling, files were all cached in roughly
0.4–0.7 seconds, while all six Posters were ready in roughly 0.4–4.4 seconds.
The slowest sampled page spent about 3.8 seconds more waiting for its Posters
after all files had been cached. These are viewport-level samples, not per-image
decode benchmarks; compressed file size alone does not identify the slowdown.
The native sweep can compare the default Poster mode with Roku's `limitSize`
mode in an isolated probe. It records the reported bitmap pixel count and leaves
the download logic and production package unchanged.

The two isolated scaling runs (`out/guide-poster-size-baseline.log` and
`out/guide-poster-size-limit.log`) both covered all 36 channels and restored
the release. In the six scrolled viewports, the maximum reported bitmap
pixel counts matched at each position, and time to all ready differed by
at most 24 ms per position in this pair. The initial viewport was not part
of that comparison. These runs do not support changing the shipping mode.

Page Down (`out/guide-poster-page-scroll.log`) also covered all 36 channels
and restored v0.3.102. Compared with repeated Down at the same six scrolled
positions, time to all ready varied in both directions, by at most 184 ms.
That does not support changing the scroll handler.

On a separate Page Down / Page Up round trip
(`out/guide-poster-revisit.log`), the six forward scrolled viewports reached
all-ready in 399–4,579 ms. Returning through six viewports in the same
session, all six logos were already ready at the first sample, 52–88 ms
after navigation. The return viewports overlap the forward viewports but
do not all have the same starting row. This distinguishes first-display
loading from rendering already-seen artwork; it does not separate the
local-file cache from Roku's decoded-image cache. The run restored exact
v0.3.102. No shipping performance change was made.

This is consistent with the earlier small-image comparison in `dv1`:
the supported avenue to investigate is smaller authorized artwork, rather
than changing scaling mode, adding scroll redraws, or enlarging the disk
cache to address first-display latency.

### Programme artwork versus channel-logo speed

Development programme details prefer usable artwork from the matching
Dispatcharr detail response, then the guide-feed icon, then optional TMDB
artwork. A dummy programme can supply `custom_properties.icon` as an object
or bounded JSON object string. A detail result with the same programme ID
but a different station or time range cannot replace the selected airing.
If the selected programme ID returns 404 (for example, after a Teamarr feed
refresh), Program Details makes one bounded grid request near the airing
start. It accepts only a unique replacement with the same station, time
range and title, then tries that ID once. Background prefetch does not run
this recovery. Ambiguous matches leave the existing feed art alone.
Artwork URLs are not written into the persistent guide cache. Same-origin
artwork still uses the existing account request gate; public HTTPS artwork
does not get provider headers. A syntactically valid URL may still fail to
load; this change does not retry through other sources after a Poster error.

An isolated native run (`scripts/test-guide-overlays-live-native.py`,
`out/guide-artwork-live-overlays-retry.log`) used the v0.3.102 release ZIP
with only the artwork patch and private probe changes. On the authorized
live Dispatcharr test account, the selected programme's Poster reached
`ready`, Player Info appeared over a playing Video node, the channel browser
took focus without stopping playback, and minimizing returned to the Guide
with the mini-player still playing. The probe used controller calls, not a
physical remote, and did not verify picture/audio externally or exercise
every programme-art fallback on the provider. It cleaned its disposable
state and restored exact v0.3.102. This is partial evidence for `dgt`, not
owner-account, light appearance, empty-group, or VOD/DVR acceptance.

For channel logos, the inspected Dispatcharr source (`f1a0bb2c`,
`apps/channels/api_views.py`, `LogoViewSet.cache`) still streams original
bytes and exposes no size option in that action. Roku cannot assume a
thumbnail route. A compatible design would ask for a bounded size only on a
provider that advertises support, serve a derivative of an existing
account-authorized logo ID (never an arbitrary URL), and fall back to the
original route for unsupported providers. Validate first-display and warm
revisit timings, visible image quality and texture headroom before enabling
it. Persistent retention and TimeGrid address different questions; neither
is a substitute for smaller source artwork.

A later paired Roku sweep kept the live Dispatcharr download path and local
Poster URIs unchanged. In the small-image run, the private probe replaced
each downloaded file with a small packaged PNG just before assigning it.
Both runs covered all 36 rows and restored exact v0.3.102. Across six scrolled
viewports, median time to all six Posters ready fell from **4.64 s to 0.75 s**;
the median time to all files cached was essentially unchanged (**631 ms vs
636 ms**). Five viewports improved materially; one was already fast. This
isolates the cost after download in this comparison. It does not measure
real resized-logo quality, a thumbnail endpoint, or a shipping improvement.
See `out/guide-live-decode-original.log` and `out/guide-live-decode-small.log`.

The expanded live overlay probe passed light appearance and the empty
Favorites round-trip with no stale subtitle. The first feed reached a
terminal Video state before overlay checks; that run did not reach the
library checks. The probe now tries at most three authorized channels and
can check VOD/DVR independently if none starts.

The existing guide reports missing logo IDs and download failures. Development
v0.3.103 additionally reports **successful downloads that fail Poster decoding**,
using aggregate counts only. It ignores uncached/hidden failures, deduplicates
repeat notifications, stops reporting for an inactive guide and resets with
the connection. This closes a diagnostic blind spot, not the unknown cause of
the affected account's missing logos. No automatic retries or request/PIN gates
are changed.

### Capture on the affected account

1. Record the AerioTV version and Roku model/OS.
2. Open the affected guide and wait at least 20 seconds.
3. Scroll past the first six channels; note whether later programmes and logos
   appear, and whether the problem affects every later row or only some.
4. Open **Diagnostics**, then **Show support code**, and supply that sanitized
   code with the observations. Relevant events distinguish `mapping details`,
   `mapping network response-too-large`, `logos lineup`, `logos network`, and
   (v0.3.103 onward) `logos poster`.
5. Do not send passwords, API keys, full authenticated image URLs or unredacted
   account/server screenshots. Do not change server permissions or lineups just
   to make the test pass.

If v0.3.102 is installed, its existing download/mapping diagnostics are useful;
the new Poster-decoder diagnostic requires v0.3.103 or later. Provider integration
must target the live service: the Roku cannot reach a laptop HTTP fixture over
the current VPN.
