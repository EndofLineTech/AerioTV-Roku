# VOD state retention — AerioTV-Roku-3ts

The 0.3.81 account-local `settingsV1` registry value stores VOD rows together
with other preferences. Previously, normalization kept the first 20 rows; a
play or edit moved its row to the front, silently dropping older Watchlist,
Hidden and Watched choices.

## Retention and storage policy

- Keep the existing `settingsV1` schema and account scope. Existing VOD arrays
  migrate on read; no new registry key or cachefs dependency is required.
- Retain up to **40 explicit choices** (Watchlist, Hidden or Watched) and the
  **20 most recent uncurated rows** (progress/source metadata), in separate
  recency groups within the same VOD array. Playing more titles can evict only
  uncurated rows. A 41st new explicit choice is rejected with a TV notice;
  existing choices remain intact. Removing the last explicit flag frees a slot.
- The shared preference writer still enforces **24,000 UTF-8 bytes** for the
  entire store, not 24 KB per account or per VOD shelf. Reaching that budget or
  a failed registry write/flush displays the existing unsaved-change notice;
  VOD handlers restore the previous in-memory state and shelf. The effective
  explicit-choice limit can therefore be lower than 40 when other preferences
  or accounts consume the registry. No promise of unlimited titles is made.
- Cachefs is unsuitable for explicit choices: Roku can evict it, and it may
  disappear on reboot. Prior [device storage investigation][storage] measured
  eight 1-MiB cachefs writes and a small isolated registry sentinel, **not**
  this new 60-row VOD workload; the documented registry total is 32 KB.

`npm run verify` covers the 20-row legacy array, 30–40 subsequent distinct
movie/episode updates, capacity rejection and recovery, account-isolated
registry reload, and simulated quota/write/flush failures. The
`PlayerLifecycle.test.brs` Scene-handler test also checks the displayed
capacity notice and restores the shelf, account preferences and store after a
failed write. The previous final-build [resource baseline][mem] reported a
513,802,240-byte process limit and 231,260,160-byte live-playback peak;
that is a different workload, not the cost of these VOD rows.

## Isolated native measurement — 2026-09-26

Target: Streaming Stick 4K `3820RW2`, Roku OS `15.3.4`, 1080p. The
`tests/native/VodRetentionProbe` scene used the **separate**
`AerioTVVodRetentionProbeV1` registry section, no account credentials, and
synthetic movie/episode identities. It used the actual packaged `VodState` and
`PreferenceModel` source. A 40-choice + 20-recent-row fixture for account A,
plus one choice for account B, serialized to **16,107 UTF-8 bytes** including
the default device preferences. Native `savePreferenceStore` succeeded under
the shared 24,000-byte guard. The first run reported 60 rows and **2%** from
`roAppMemoryMonitor.getMemoryLimitPercent()`. A bounded six-second foreground
ECP sample (`out/vod-retention-seeded.json`, ignored) obtained three samples,
no failures, and **20,938,752 bytes** peak process memory against the
**513,802,240-byte** limit. The ECP figure is the whole isolated Scene process,
not memory attributable only to saved rows; normal-app before/after readings
would not isolate the VOD allocation either.

A second probe ZIP with a higher build number replaced the first and started a
new process. It read back all **60** account-A rows plus the account-B row,
verified all 40 original choices, rejected the 41st choice, found no tested
account-A choice in account B, and deleted/flushed its isolated registry value
(`reload ok=true`, `cleanup=true`). The probe's first attempt lacked a
`MediaSessionModel` script import and stopped before successful seeding; the
corrected seed/reload run is the evidence above. The normal verified v0.3.81
release ZIP was reinstalled and launched, loading its authorized guide.

The synthetic probe did not exercise actual remote/dialog or audible playback;
the capacity notice was checked in the Scene-handler test. No real VOD
preference value or Dispatcharr profile was changed by the isolated probe.

## Changed-app remote smoke check — 2026-09-26

The verified changed application ZIP (`out/aeriotv-roku.zip`) was installed
separately. ECP remote navigation reached the authorized Movies catalog,
Watchlist and Hidden shelves. Both saved shelves were empty before the check.
One catalog movie was temporarily added to Watchlist from its detail action;
the Watchlist displayed one item. After Home and an ECP launch of the same
development app (a fresh process), Watchlist still displayed that one item and
its detail action said **Remove from watchlist**. Removing it returned
Watchlist to its original empty state. UI screenshots are private and ignored
under `out/vod-retention-*.jpg`. No VOD media was played, and the account was
not populated with 20+ real titles: the isolated synthetic fixture is the
evidence for that bound. The previous verified v0.3.81 release ZIP was then
reinstalled and launched successfully.

Rollback: reinstall the previous application package. The on-disk VOD row
format remains unchanged, but the old app will again display only the first
20 rows. The new ordering puts explicit choices first, so rollback prioritizes
those choices. **Do not edit or play VOD in the old app** if preserving all
retained rows matters: an old-app VOD write can permanently truncate rows
beyond 20. Reinstall the updated app before making VOD changes, or restore a
previously backed-up `settingsV1` value if such a write has occurred.

[storage]: METADATA-CACHE-STRATEGY.md#storage-result
[mem]: RESOURCE-MEASUREMENTS-0.3.80.md
