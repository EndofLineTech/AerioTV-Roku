# Series next-episode target — AerioTV-Roku-17h

The Dispatcharr series detail screen now offers **Play / resume next episode**
alongside **Browse episodes**. The action verifies the current account's series
permission, reads up to four ordered episode pages (**80 episodes**) and opens
the selected episode's *detail screen*. It does not start playback by itself.
The episode is fetched and verified again before the user chooses Play or
Resume. Direct Xtream remains on its existing Browse episodes path.

Selection uses the most recently updated matching saved episode. A new bounded
`touch` sequence on each saved VOD row preserves update order even though
curated rows are stored ahead of disposable progress. Unfinished episodes
resume; a finished episode advances to the next unwatched, non-hidden,
non-denied and non-missing numbered episode. A fully watched series does not
wrap back to episode one. Season zero sorts before season one. Older rows
without reliable order, unavailable/mismatched metadata, and an incomplete
catalog with no provable target fall back to explicit episode browsing rather
than guessing. The existing VOD preference schema and 24,000-byte aggregate
registry limit remain in force.

Continue Watching now promotes a verified next episode from a completed series
without saving a fabricated resume position or auto-playing it. The shelf
rechecks account and episode authorization and excludes older unfinished
episodes when a more recently completed episode has advanced the series. It
inspects at most **three completed series** and four pages per series under the
Task's existing deadline. If more series cannot be inspected, the TV directs
the viewer to TV Shows for explicit selection. Back from a selected next
episode detail returns to the same series tile or Continue shelf position.

## Verification — 2026-09-26

- `npm run verify` includes model checks for season-zero ordering, unfinished
  resume, watched-to-next progression, end-of-series, hidden/missing targets,
  unverified legacy recency, incomplete pagination, account mismatch, denied
  episode and a stale older resume row. The Task tests use mocked HTTP; they
  are not a live-provider authorization proof.
- On Streaming Stick 4K `3820RW2`, Roku OS `15.3.4`, a changed development ZIP
  showed an authorized eight-episode series' **S1E1** detail through the series
  action. Back returned focus to the original series tile. A temporarily
  marked-watched S1E1 then advanced the series action to **S1E2**. Continue
  Watching exposed a single S1E2 tile and its detail showed **Play next S1 E2**.
  The marker was cleared through the episode detail action; Continue Watching
  returned to its prior empty state. The check performed no VOD playback or
  provider mutation. Screenshots are ignored under `out/series-next-*.jpg` and
  `out/series-target-*.jpg`.

Rollback: reinstall the previous v0.3.81 release ZIP. It ignores the new
per-row `touch` field but does not need a schema migration to read older VOD
choices. An older app may discard `touch` on subsequent VOD writes, so a later
upgrade may offer Browse episodes until new progress establishes reliable
recency. Do not infer playback picture/audio continuity from detail screens.
