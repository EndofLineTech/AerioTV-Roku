# Roku metadata cache strategy (mxz.1)

Selected under the PO's authorization to implement the mxz → 34y → l4j queue
using Roku plus the existing Dispatcharr server. This is a bounded, discardable
cache design, not a promise of a durable database or offline authorization.

## Native evidence — 3820RW2, OS 15.3.4, Dispatcharr 0.31.0

Measured 2026-09-20 with `tests/cache-probe` and a temporary production-app memory
probe. Requests were read-only and counters contained no credentials/media URLs.
The live lineup/catalog changed between runs; these are samples, not constants.

| Response | Rows / server total | JSON file bytes | Download / ParseJSON |
| --- | --- | --- | --- |
| Channel summary (`page_size=20`) | 1,934; **unpaginated** | 418,344 | 49ms / 29ms |
| Channel list page (`page_size=20`) | 20 / 1,934 | 15,067 | 59ms / <1ms |
| EPG mappings (`page_size=20`) | 49,019; **unpaginated** | 6,721,699 | 913ms / 1,830ms |
| Three-hour guide grid | 3,175; **unpaginated** | 1,460,226 | 435ms / 87ms |
| Movies page 1 (`page_size=20`) | 20 / 120,290 | 13,458 | 494ms / 1ms |
| Movies page 2 | 20 / 120,290 | 13,643 | 478ms / 1ms |
| Series page | 20 / 38,696 | 25,240 | 248ms / 1ms |
| Movies requested size 101 | **100** / 120,290 | 67,158 | 756ms / 5ms |

No ETag header was observed on these responses. v0.31 source confirms VOD
pagination defaults to 20 and caps at 100; summary/grid and EPG mapping endpoints
do not honor that pagination contract. Mapping ingestion is tracked in mxz.10.

Memory observations:
- Isolated Task/string/parse/normalization/cross-thread fixture: sampled peak **9%**,
  minimum reported available memory **290,156 KB**. Guide normalization/copy was
  deliberately limited to 2,500 rows in this fixture.
- Production app, including full startup, ESPN playback, logo browser, mini-guide
  and several guide-window jumps: sampled peak **30%**, minimum available
  **223,484 KB**, final **8%** after stopping. This was a 65-second scripted run,
  not an endurance proof or a guarantee for other hardware/lineups.
- Device memory-limit API returned raw values: foreground 501760, background
  401408, Roku-managed heap 363520. Preserve raw API values; available-memory
  readings above use the API's documented KB units.

## Storage result

- Eight 1-MiB files (8,388,608 bytes verified by stat) were successfully written
  to both `tmp:` and `cachefs:`. Cachefs took about 94–101ms; tmp about 34–35ms.
  This proves that tested amount, **not** a maximum quota.
- With files retained briefly, app-memory usage rose from 1% to 3% for tmp and
  remained 1% for cachefs. Cachefs still consumes shared device resources.
- After scripted app close and developer-package replacement/new process,
  cachefs and registry sentinel data survived; tmp data did not. Cachefs also
  survived an intervening normal-app playback/guide probe.
- A small isolated registry section was written/flushed/read and then deleted;
  the app's real preferences/credentials were not deleted by the storage probe.
- All probe files and the probe registry section were removed by the verify
  phase. Physical Home-only and reboot/OS-pressure behavior were not simulated
  as if directly measured. Roku documents eviction at any time and RAM-cache
  loss on reboot for devices without persistent expansion storage.
- `GetVolumeInfo` is documented for external volumes only; no internal capacity
  estimate is inferred from it. The registry's documented total is 32 KB.

An initial fixture used a large String() repeat and produced zero-byte test
blocks; a numeric-character replacement was rejected by native BrightScript.
The corrected fixture constructs an explicit 1-MiB string by doubling and checks
its byte-array length. Only the corrected storage-write measurements count.

## Selected policy

1. **Registry:** durable preferences/history and compact bounded user state only.
   Keep the existing 24-KB preference ceiling; coordinate additional VOD state
   with available registry space and byte limits. Never persist catalogs or
   media in the registry, and never evict explicit user settings to make cache room.
2. **cachefs:** account-scoped, normalized metadata, initially **8 MiB total**,
   bounded file count. It is a performance optimization; every read can miss.
   No guaranteed retention across reboot, OS eviction or app replacement.
3. **tmp:** transient authenticated download/parse staging and the existing bounded
   logo cache. Remove staging on success/error/cancel. It counts against app
   resources and must not be mistaken for a durable store.
4. Keep resident render-thread working sets small: current guide's three-window
   cap, 32 detail entries / five minutes, and a few VOD pages rather than the
   120,000-title catalog. VOD browse uses server paging/search/categories.

Initial metadata entry limits (enforced by the shared model):

| Kind | Max serialized entry | Fresh TTL | Explicit stale display grace |
| --- | --- | --- | --- |
| Channels / scoped EPG mapping | 1 MiB | 5 min | None |
| Guide window | 3 MiB | 5 min | 10 additional min |
| VOD page/detail bundle | 1 MiB | 5 min | 10 additional min |

Evict before writing so committed plus staging cache bytes remain bounded.
Oversized records are cache misses/rejected writes, never silently truncated
catalogs. Global byte/file caps apply across account scopes, not independently
per account. Cache failures must leave network loading usable.

## Scope, invalidation and recovery semantics

- Use SHA-256 namespaces derived from canonical server/account identity. Do not
  include credentials or raw server URLs in filenames. Validate expected schema,
  scope, resource kind/key and data generation on every read.
- Authenticate normally before restoring account data. Cache presence is not
  permission. Load a fresh authorized lineup (or an authoritative conditional
  response, if supported) before using cached channel/guide data. No ETag was
  observed, so do not assume conditional requests are available on this server.
- A lineup/EPG-assignment fingerprint supplies the guide generation. Cached guide
  rows are restricted to the newly authorized lineage; account changes cannot
  reuse another scope. Refresh/Forget clears or invalidates the appropriate scope.
- VOD pages include query/filter/sort/page identity and complete-versus-partial
  status. Never combine an old query's pages with new results. Server library
  changes mean offset paging is not a transactional catalog snapshot.
- Persist normalized allowlisted metadata, never API keys, login responses,
  playable/provider URLs, or raw VOD objects containing stream credentials.
- Write a staging file, validate its size/schema, then rename into place. Roku
  rename does **not** overwrite a destination; a replace gap/crash must produce a
  cache miss, not corrupt data. An optional metadata cache does not require a
  full database transaction system. Sweep only the app-owned namespace.
- Missing/expired/corrupt/future-schema entries rebuild from the server. Stale
  guide/VOD content is labeled as refreshing, and cannot bypass current account
  permissions. Clock rollback/future timestamps invalidate a cache entry.
- Cancellation/request-generation guards prevent obsolete Tasks publishing data
  or recreating a cache after an explicit clear/account change.

## Consequences for subsequent work

Implemented for channels/mappings/guide in development **0.3.13**. See
`METADATA-CACHE-IMPLEMENTATION.md` for filesystem, restore, eviction, cold/warm
timing and native-media evidence. VOD integration remains separate work.

mxz.2 can expose the authorized lineup before expensive mappings/EPG hydration.
mxz.3 implements discardable disk coverage and truthful warm restoration.
mxz.8 must distinguish post-download parse caps from transfer-memory bounds and
handle the unpaged mapping endpoint explicitly. Existing fixtures test entry
validation; filesystem integration and low-memory reactions belong to those
implementation stories. No SQLite/SwiftData or extra service/container is needed.

Sources:
- https://developer.roku.com/dev/docs/file-system.md
- https://developer.roku.com/dev/docs/iffilesystem.md
- https://developer.roku.com/dev/docs/ifregistry.md
- https://developer.roku.com/dev/docs/ifappmemorymonitor.md
- https://github.com/Dispatcharr/Dispatcharr/tree/v0.31.0/apps/vod
- https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/api_views.py
- https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/epg/api_views.py
