# Full guide cache sizing on the alternate Dispatcharr server

This is a read-only sizing investigation on 2026-10-10 against the owner's
authorized 1,354-channel alternate server, plus a disposable Roku 3820RW2 /
OS 15.3.4 `cachefs:` capacity probe. No guide records, provider text, account
identifiers, URLs or credentials were persisted by the samplers. Numeric-only
results and private screenshots remain ignored under `out/`.

## What "full" means

- The app's default selectable range is three days back and seven days ahead:
  **80 three-hour windows**. The largest selectable range is 30 days in each
  direction: approximately **480 windows**. The on-screen guide retains three
  windows in memory, independently of disk coverage.
- Dispatcharr generates dummy programmes on demand for unassigned/dummy
  channels. At 30 and even 90 days before and after now, the sampled three-hour
  windows still returned hundreds of programmes, all with dummy IDs. There is
  therefore no finite "entire server guide" to download. This is independent
  of how much *real*, stored EPG the provider offers.

## Default 10-day horizon, measured

Each of the 80 three-hour API windows was requested once with the tested
account. The **sum of response bodies was 60,262,468 bytes** (about 57.5 MiB)
and 138,318 window-level programme rows (an airing spanning two windows can
appear twice). Every sampled window was nonempty. The largest individual
response was 1,726,700 bytes. A bounded off-device mirror of the Roku's
allowlisted normalization, using the freshly authorized channel/EPG mappings,
estimated **73,718,512 bytes** (about 70.3 MiB) of per-window payloads; all
703 assigned EPG IDs resolved, and its largest estimated payload was 2,080,667
bytes, below Roku's existing 3-MiB per-entry cache guard. This is an estimate,
not byte-for-byte `FormatJson` output from 80 production Roku Tasks. Headers,
checksums and filesystem staging add overhead.

The current normal app allows **24 MiB / 64 cachefs files globally**, including
other accounts, the channel summary and the mapping. Eighty guide windows plus
those entries exceed both the byte and file limits. The five-minute fresh TTL
and ten-minute explicitly labelled stale grace still apply if limits change;
storing every window does not make it current or authorized offline.

## Device capacity probe

A Task-thread probe in a disposable, credential-free ZIP wrote **80 synthetic
files sized to the estimated payloads plus 600 bytes per window** into its own
`cachefs:` directory. This was **73,766,512 bytes (~70.4 MiB)** total. All 80
files were present immediately, after a Developer Mode reinstall, and again
after an authorized live tune reached ECP `play` with `error=false` for a
45-second resource sample. That sample peaked at 67,080,192 bytes of app
resident memory with zero swap; cachefs is shared storage and is not included
in that app-memory reading. The first ECP Select timed out; a later Select
returned 200 and reached play. Back stopped playback with ECP `close` /
`error=false`. Roku uptime continued increasing.

The cleanup probe removed every synthetic file with zero failures and reported
zero files remaining. The exact normal verified 0.3.100 ZIP was reinstalled,
and the original saved 36-channel guide populated again. This proves that a
guide-sized *working set* fit and survived a short playback/reinstall test on
this specific Roku at this moment. It does not guarantee future `cachefs:`
retention, long playback stability, other Roku models, or the performance of
preloading/refreshing 80 real windows. No production cache bounds or TTLs were
changed for this investigation.

## Maximum selectable horizon

The 30-back/30-forward setting spans about **480 three-hour windows**. Sampled
far-past and far-future windows are entirely on-demand dummy programmes,
respectively about 0.40 MB and 0.28 MB per response. Extrapolating those
sampled tails plus the measured default range yields roughly **200 MB of API
responses** and potentially around **240 MB of normalized payloads**. That is
an estimate, not a full 480-request crawl or a tested Roku cache allocation.
It would require hundreds of cache entries, compete for shared cache storage,
and rapidly run into the existing five-minute freshness policy.

Conclusion: the *default 80-window range* can physically be stored in one
short-lived test on this target, but the current app does not keep or preload
all of it. A guaranteed whole-guide cache is a separate design decision about
which windows are worth caching, TTL/refresh cost, dummy programmes, account
scope and OS eviction—not a removal of the existing byte cap alone.
