# Incremental guide startup and metadata restore — 0.3.13

Implements `mxz.2`, `mxz.3`, and `mxz.10` using the policy in
`METADATA-CACHE-STRATEGY.md`. This is development-device evidence, not a public
release or physical-remote acceptance.

## Runtime behavior

- Authenticate and fetch the current authorized channel summary before restoring
  anything. Cache presence never authorizes offline browsing. Channels and groups
  become usable before the separate mapping Task finishes.
- Cache normalized channels, only the EPG links needed by that lineup, and fetched
  three-hour guide windows. Channels without explicit EPG assignments need no
  mapping transfer. Unresolved explicit assignments cannot fall back to a different
  station's TVG ID.
- Namespace by SHA-256 of server/account identity. Fingerprint the fresh summary;
  guide generations additionally include resolved mapping contents. Lineup refresh
  cancels obsolete Tasks and rehydrates mappings while preserving playback.
- Use `cachefs:/aeriotv-metadata-v1`, at most **64 files / 8 MiB globally**. Evict
  oldest files before staging a replacement. Check UTF-8 byte size, actual written
  size, schema, scope, generation, age, and SHA-256 payload checksum. Interrupted
  staging files are swept under the per-session single-writer lock.
- Retain at most **three resident windows**, separately from disk coverage. The
  browsing horizon is a permitted request range, not downloaded coverage. A cached
  empty successful window remains distinct from a missing/failed request; it does
  not manufacture history the server does not supply.
- Freshness is five minutes. Guide data may be shown explicitly as cached while
  refreshing for ten additional minutes. Failed refreshes do not advance its
  timestamp; memory entries are also pruned after that grace or clock rollback.
- Persist allowlisted programme facts, excluding artwork/provider URL fields.
  Detailed artwork can be fetched on demand. No credentials, playback URLs, raw
  login responses or raw EPG mapping responses enter this cache.
- Guide `* > Refresh guide` and `* > Clear guide/detail cache` cancel old work,
  invalidate its write epoch, clear the current disk scope, then rebuild. Forget
  connection also clears that scope. None of these metadata operations stops a
  shared upstream channel.

Cache misses, OS eviction, corrupt files and oversized entries use the same
network rebuild path. Retention across reboot or OS pressure remains explicitly
unsupported as a guarantee; no actual OS-pressure eviction was induced.

## Native evidence — 2026-09-20 UTC

Streaming Stick 4K 3820RW2, OS 15.3.4, Dispatcharr 0.31.0, 1,934 authorized
channels and 553 relevant EPG links. Times are sampled, not performance promises.

| Run | Authorized lineup | Mapping completion after lineup configuration | Guide restore |
| --- | --- | --- | --- |
| Initial cold cache | 2,212 ms | Separate network Task | Network windows populated |
| Warm package/process restart | 1,932 ms | 979 ms, cache | First two windows at 2,128 / 3,339 ms after configuration |
| Cold rebuild after eviction fixture | 2,467 ms | 6,798 ms, network | First window at 10,621 ms after configuration |
| Final normal package | Not captured by this filtered log | 1,064 ms, cache | Three windows restored at 2,301 / 3,481 / 4,513 ms |

The warm app still authenticates and fetches its fresh authorized summary.
Its **25-second guide-only** memory sample peaked at **8%**, minimum available
**255,476 KB**, final 7%.

The corrected **45-second scripted native lifecycle** run selected an ESPN
channel, cleared metadata during initial buffering, refreshed the channel lineup,
and stopped locally. After clearing, Video reported `playing`, preserving the
same ContentNode. After lineup refresh, it again reported `playing` with the same
ContentNode. Peak memory was **29%**, minimum available **221,096 KB**, final 7%.
This does not establish perceived picture/audio continuity or physical key input.
An earlier fixture required the exact name `ESPN`, found no matching channel and
crashed its own unguarded media assertion. That attempt provides no playback
evidence; the corrected fixture matches ESPN within the name and guards missing
content. All temporary app hooks, autoplay and memory sampling were removed.

`tests/cache-probe`, phase `cache`, exercised the actual filesystem store:

- Write/read round trip, including distinct `ABC` / `abc` keys: PASS.
- Different account, different generation, unauthenticated reads: cache miss.
- 301-second age: stale; 901 seconds: miss.
- Deliberately malformed JSON: miss (its ParseJSON diagnostic is expected).
- Cancelled Task and old write epoch: writes rejected.
- 66 small writes: retained 64; oldest evicted; scope clear verified.
- Four roughly 2-MiB writes: oldest evicted; total retained **6,292,413 bytes**,
  below 8 MiB. Interrupted `.part` cleanup verified.
- Fixture sampled peak **2%**, minimum available **313,532 KB**. Its own records
  were cleared; eviction intentionally exercised the shared disposable cache.

The final normal 0.3.13 ZIP installed successfully and restored guide windows
without runtime errors in the captured 35-second run.

## Automated verification

`npm test`: **28 suites**. Actual GuideTask / MappingTask code is exercised with
cache/transport adapters: warm request avoidance, stale publication plus failed
refresh, explicit bypass, allowed EPG keys only, URL exclusion, cancellation,
credential release and no-assignment fast path. Native filesystem tests complement
these adapters; the off-device interpreter is not a Roku emulator.

`npm run check`, `npm run build`, and `git diff --check` pass.

## Remaining upstream limitation

Dispatcharr 0.31's `/api/epg/epgdata/` ignores pagination and returns roughly
49,000 mappings / 6.7 MB on this server. A cache miss still downloads that response
through the existing **8-MiB pre-parse cap** and memory guard. It is no longer on
the channel-startup path and warm loads avoid it entirely. Larger unsupported
responses produce a mapping-unavailable message while live tuning remains usable.
File staging is not a hard network byte quota. This implementation does not claim
that the upstream endpoint became paginated or arbitrarily scalable.

Physical acceptance is consolidated in `PHYSICAL-VALIDATION-CURRENT.txt`, including
the previously pending hold-OK shortcut checks.
