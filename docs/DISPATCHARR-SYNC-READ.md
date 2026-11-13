# Own-account App Data reads (in progress)

`DispatcharrSyncKey.brs` implements the shared schema's UTF-8 byte key algorithm:
ASCII uppercase only is folded, unsafe bytes become `-xx`, nonalphanumeric
starts receive `u`, the encoded name is cut at 46 characters (even within an
escape), then `.aeriotv` is appended. Empty usernames wait. No trimming, Unicode
case folding or alternate key scheme is applied.

Read discovery validates the bounded server key list. The canonical key wins
over legacy keys. Legacy-only data yields a migration-required/read-only plan,
with all legacy sources retained for a future full category merge. It never
creates an empty canonical replacement or writes/deletes a legacy record.
Every plan explicitly has `allowWrite: false`.

`DispatcharrSyncReadTask` is an **internal, not UI-activated** read-only Task:

1. Verify `/api/accounts/users/me/` using its own supplied credential and match
   the expected account ID and case-insensitive stored username.
2. Read the same user's key list; never use an admin cross-user endpoint.
3. GET only the canonical key when listed. A missing canonical key or legacy
   migration requirement does not trigger any write or arbitrary legacy read.
4. Treat only a canonical GET's structured `404 key_not_found` after successful
   listing as missing. Forbidden/unsupported endpoints, proxy 404, transport
   failures, parks and malformed objects do not become absence/write permission.
5. Parse through native `ParseJson(text, "d")`, not shared `requestJson` or
   `copyJson`, preserving case, doubles, large integer stamps and unknown data.
   Future schema versions are reported read-only, not downgraded.

Transport admission, response bounds, cancellation and session retirement use
the existing request gate. The Task clears its credential before publishing a
result and does not log bodies or credentials. `DispatcharrSyncEnvelope` now
validates required v3 metadata and ISO timestamps using the existing validated
UTC parser. Each category is validated independently (timestamp/object data,
optional object extra and string deviceId). A malformed profiles category is
explicitly `profilesState: invalid`, never absent/empty; unknown category data
remains untouched. `ready` is not permission to display or switch profiles.

Host tests cover the shared key vectors, malformed discovery, own-identity
refusal, legacy/missing records and HTTP failure distinctions. Native primitive
tests also exercise actual UTF-8 accented/emoji usernames, with exact prior-app
restoration (`out/dispatcharr-sync-key-native.json`). The isolated request-gate
fixture's 14-group matrix now includes 13 real native HTTP discovery cases:
canonical/legacy/missing, structured versus proxy 404, forbidden/unsupported,
wrong user/username/string-typed identity, malformed/future/integral-float schema.
It checks exact allowed paths, no cross-user/legacy reads, no mutation methods,
and preservation of double settings and millisecond integers through the Task
result. The full matrix, including existing media fencing and slow recheck,
passed with exact prior-app restoration at the earlier key/discovery checkpoint.
Current requalification passes all read/gate operations but the native H.264
fixture now fails decoder admission, also in a fresh video-only Scene. This is
tracked as `AerioTV-Roku-a4n`; no renewed all-path media pass is claimed.
None of this is a claim
of measured production-server limits, sender interoperability, completed roster
import, sync writes or public profile switching.

## Roster decoder (internal)

`DispatcharrSyncRoster.brs` decodes a profiles-category **data object** without
modifying local state or the original wire value. It validates every row before
applying the 25-row wire cap (separate from the local four-profile cap). Required
user IDs must be literal signed 32-bit integers and usernames strings; any bad
required row rejects the category. Retained duplicate IDs select the newest row,
with first-insertion order and first-row tie behavior.

Sparse rows retain explicit missing-avatar/order/role semantics. Noninteger
stamps become zero; malformed numeric/direction PIN material yields a `keep`
marker rather than clearing an existing PIN. Unknown PIN types decode as none.
Valid v2 hashes/salts normalize to lowercase. A later merge must still enforce
newer-row/role-authority and any legacy-v1 preservation rules before acting on
these markers. Tombstones drop malformed entries individually, deduplicate by
lowercase username/newest stamp and retain only valid optional integer IDs.
Unknown row tails and the untouched original data remain available for future
strict re-emission; they never pass through `copyJson`.

The pure application gate denies both application and suggestions for Child or
unknown roles, Profiles-Off, malformed local authority and **any** address-held
slot profile, including keyless profiles. It does not clear pending changes or
holds. This is not yet a production handler enforcement claim: no roster pull
is applied or offered in the public UI.

The shared host/native decoder suite covers malformed trailing rows, sparse
metadata, malformed PIN preservation, tombstones, deduplication and gates.
Native fixture 16.4 also decodes the actual peer-shaped roster and verifies its
numeric and direction PINs using real SHA-256, and rejects floating user IDs
while treating floating stamps/order as absent. Reports are private under
`out/dispatcharr-sync-roster-native.json`; prior-app restoration is verified.

## Merge and atomic pull persistence

`DispatcharrSyncMerge` stages newer-row role/PIN/order/stamp updates against
verified local server authority, unclaimed name/avatar adoption, stripped-row
repair and rich-row recovery (including lowering a stripped local stamp).
Optional `displayNameClaimed` and `avatarClaimed` local fields default false for
existing records. Importing a remote stamp equal to the clock is not a local
edit; only an actual stripped-row repair marks the roster pending.

Paused adds settle to roster origin and the source stamp on the first applying
pull with a row; no row settles them to plain origin. Held/Child/Profiles-Off
pulls do not settle marks. Suggestions are returned without adding profiles.
Rows with ambiguous usernames/different known user IDs refuse application.
Tombstones expire after 90 days, preserve the default, remove eligible local
keys/blobs without new tombstones, and acknowledge local tombstones only when
superseded, expired or carried remotely.

`commitDispatcharrRosterPull` checks the captured immutable own-session scope
before a single registry transaction covering metadata, removed keys, PIN
backoff and preference cleanup. An active tombstone returns
`needsDefaultSwitch` **without writing anything**; the controller must first
authenticate/commit the default switch and re-plan. Failed writes/Flush restore
previous values; rollback failure requires recovery. Other slots and default
key/data are preserved. Native checks include actual private-registry cleanup,
fake-registry faults and stale A/B/A refusals.

Still required before import activation: controller scheduling and safe active
retirement, opt-in suggestion UI, PIN/Child enforcement and same-slot acceptance.
The read-before-write/60-second roster-add preservation rules still belong to
the later sync writer; no App Data writer is introduced. This does not close
`mrr.15` or `e3e.3`.
