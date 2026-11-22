# Larger Roku guide and logo caches — 0.3.99 candidate

The owner supplied a different, account-authorized Dispatcharr server for a
controlled cache comparison. Its tested account returned 1,354 channels,
703 distinct EPG assignments, 1,251 distinct logo IDs, and about 1.3 MB of
JSON for one three-hour grid window. No server lineup, artwork, or profile
was changed. Login credentials were used only in disposable ignored probe
packages and were not stored in the Roku registry or this document.

The Roku 3820RW2 / OS 15.3.4 was temporarily booted into memory-only
connections to that server, leaving its normal saved connection untouched.
Probes used separate `cachefs:` directories for capacity measurements; a
normal developer ZIP was rebuilt with `npm run verify` before the final probe.

| Workload | Previous bound | Tested bound | Device observation |
| --- | --- | --- | --- |
| 44 guide rows down and back | 24 logos / 12 MiB `tmp:` | 48 logos / 20 MiB `tmp:` | Previous bound: 42 evictions, 66 logo requests; final-code probe: zero evictions, 45 requests. Counts include the first visible batch. |
| 35 timeline steps forward and back | 8 MiB / 64 files `cachefs:` | 16 MiB / 64 files `cachefs:` | With fresh isolated caches, previous bound re-fetched two already loaded guide windows; larger bound restored six from cache and re-fetched none. Its disk peak was 12,141,090 bytes in 11 files. |

The native final-code probe used the exact 48-logo/20-MiB and 16-MiB/64-file
limits, returned populated programs/logos, had zero sampled swap or runtime
errors, and remained below the target's reported 513,802,240-byte foreground
app limit. Peak measured texture instance usage was about 90 MB against that
device's reported 100-MB limit. Graphics instances can include Roku-managed
resources, so that reading is **not** exclusive application logo texture
allocation. Resource limits and original-image decoding vary by Roku model;
this result does not establish safe texture headroom on older devices.

Both caches remain discardable: the guide still retains only three *resident*
windows and preserves its five-minute freshness / ten-minute labelled-stale
policy. Logos still download only for visible rows and use the same
authenticated per-connection cleanup. More disk capacity speeds eligible
revisits; it does not lengthen EPG freshness or speed first-time logo decode.
Individual numeric-only probe results and private screenshots are ignored
under `out/`. A Task-thread cleanup probe removed 61 isolated test-cache
files with zero failures. The disposable credential-bearing ZIPs were removed
from `out/`, and the verified normal 0.3.99 ZIP was reinstalled on the Roku.
Its original saved 36-channel connection reopened with populated programs and
logos. Probe code never enters the normal application package.
