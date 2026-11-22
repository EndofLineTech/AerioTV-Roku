# EPG detail-first candidate — 0.3.98

Dispatcharr 0.31's `/api/epg/epgdata/` list ignores `page` and `page_size`.
After a fresh authorized channel summary, the Roku now resolves at most 100
**distinct** assigned EPG IDs through its existing eight-at-a-time, file-backed
detail lookup instead of downloading that server-wide list. Larger lineups
retain the list-first path and its oversized-response detail fallback. Mapping
cache scope, cancellation, 404 handling, and failure behavior remain bounded.

## Local Roku verification

The verified 199-file 0.3.98 Developer Mode ZIP was installed on the owner's
3820RW2, Roku OS 15.3.4 (1080p), with the existing saved, authorized
36-channel Dispatcharr connection. The previously installed 0.3.97 build
provided a same-device list-path comparison. Private screenshots and
credential-free numerical runs remain ignored under `out/`.

| Run | Mapping completion after lineup | Source | First program label after guide configuration |
| --- | ---: | --- | ---: |
| Installed 0.3.97, cache-expired list path | 1,264 ms | network | 1,781 ms |
| Installed 0.3.98, first cache-expired detail path | 963 ms | details | 1,312 ms |
| Installed 0.3.98, second cache-expired detail path | 893 ms | details | 1,230 ms |
| Installed 0.3.98, warm cache | 195–209 ms | cache | 860–914 ms |
| Disposable list-route probe, cache bypassed | 1,166 ms | network | 1,517 ms |

These are individual native runs, not a controlled statistical benchmark.
Guide-window cache state and provider/network timing varied between them, so
the first-program differences cannot be attributed solely to mapping. Both
detail runs returned real program titles, times, and channel logos; the
second fetched a neighboring guide window from the network. ECP Down navigated
to later guide rows, whose programs and logos also appeared. On the candidate,
Select reached native media-player `play` with `error=false`; Back minimized to
the guide without ending the stream, and a second Back reached `close` with
`error=false`.
Developer screenshots do not prove physical picture or sound.

The disposable 0.3.99 probe was built from the verified 0.3.98 ZIP under
ignored `out/`. It forced the retained list route for the same authorized
36-channel account, skipped mapping-cache reads and writes, and changed no
server data. It loaded real guide programs with no recorded runtime error.
The exact normal verified 0.3.98 ZIP was reinstalled afterward; the probe is
not the candidate or a release artifact.

A 60-second guide resource sample returned 20 good samples, zero failures,
zero swap, 35,393,536-byte peak app resident against a 513,802,240-byte
foreground limit, and 69,681,152-byte peak single-instance texture usage
against a reported 100,000,000-byte maximum. A continuous 91-channel-account
native timing/permission check is still needed: the connected local account
exposes only 36 channels. Off-device regressions exercise 91 and 100 distinct
assignments taking details without a full-list request, 101 taking the list,
and oversized-list fallback, cancellation, timeout, no-assignment, and
authorized-ID filtering. `npm run verify` and `git diff --check` pass.
