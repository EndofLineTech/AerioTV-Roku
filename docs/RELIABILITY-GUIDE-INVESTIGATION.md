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
