# Alternate-server cache headroom — 0.3.100 candidate

On the Roku 3820RW2 / OS 15.3.4, a memory-only, authorized test connection
to the owner's alternate Dispatcharr server returned 1,354 channels, 703
distinct assigned EPG IDs and 1,251 distinct logo IDs. The normal saved
connection and the server lineup were not changed. Credential-bearing probe
ZIPs and private screenshots were kept only under ignored `out/` for the test.

| Paired native run | 0.3.99 bounds | Disposable larger bounds | Result |
| --- | --- | --- | --- |
| 80 rows down and back | 48 logos / 20 MiB `tmp:` | 96 logos / 20 MiB `tmp:` | Previous bound held 48 files / 6,528,848 bytes, evicted 66 and requested 114 logos. Larger bound held 81 files / 10,022,554 bytes, evicted none and requested 81. The *file-count* cap, not the 20-MiB byte cap, caused the return downloads. |
| 60 timeline steps forward, then InstantReplay to Now | 16 MiB / 64 files `cachefs:` | 24 MiB / 64 files `cachefs:` | With fresh isolated caches and a settled first window, the previous bound re-fetched two previously loaded windows. The 24-MiB bound restored both, peaked at 17,571,452 bytes in 16 files, and made no repeated-window request. |

A 32-MiB guide probe also avoided refetches, but retained only 16,920,847
bytes in that run; the tested 24-MiB bound supplied the same observed benefit
with a smaller shared-cache ceiling. A 96-logo / 40-MiB probe retained only
10,022,554 bytes; keeping the 20-MiB byte limit gave the same 80-row result.

These are measured cache contents on this test server, **not** the amount
required to store its entire 1,251-logo lineup or all EPG history. The 24-MiB
metadata budget remains global across account scopes in the normal app;
probe-only directories isolated the paired capacity comparisons. The guide
still holds only three windows in SceneGraph memory and retains its existing
five-minute freshness / ten-minute labelled-stale policy.

Sampled app resident memory stayed below the target's reported foreground
limit (513,802,240 bytes), with zero sampled swap and no runtime errors in
the paired runs. Logo-browse texture readings were around 89–90 MB against
the target's reported 100-MB graphics-instance limit. Graphics counters can
include Roku-managed resources, and other Roku models have different limits;
this is not a claim of cross-model texture headroom. Larger file caches
reduce repeat downloads and do not resize oversized source artwork.

The exact 0.3.100 source ZIP passed `npm run verify`. Disposable native probes
built from that verified ZIP exercised both final limits on the alternate
server with no sampled swap or runtime errors. A Task-thread cleanup removed
90 isolated test-cache files with zero failures; credential-bearing ZIPs were
removed locally. The normal verified 0.3.100 ZIP was then installed on the
Roku, and its original saved 36-channel connection reopened with programs
and logos. No signing or Roku Dashboard submission was part of this test.
