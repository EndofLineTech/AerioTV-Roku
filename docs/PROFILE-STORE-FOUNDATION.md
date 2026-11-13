# Profile storage and migration (`mrr.4`)

This is storage/migration delivery, **not** a delivered profile switcher. The
application checks saved protection before connecting and creates an unstamped
default after a successful, typed `/me/` verification. The
existing connection flow saves the verified `/me/` username alongside its
account ID, so later API-key migrations need not guess from a blank login field.
An old same-account caller may omit the username without erasing it; a different
account cannot inherit the old name.

## Model

`source/UserProfileModel.brs` contains pure identity, role and order rules:

- Canonical lowercase UUIDs and slot IDs are checked before creating
  `profKey_<slotId>_<uuid>` names. Identical imported UUIDs in two slots cannot
  share credentials. The UUID-only prototype was replaced before app activation;
  its native probes used disposable sections, not application storage.
- Server IDs are exact positive JSON integers through the portable safe-integer
  limit, without 32-bit `ToInt` coercion. Integer-looking floats are rejected.
- A default is constructed only from a verified account with a usable ID,
  username and typed server level. Staff/superuser flags fold into Admin;
  imported labels cannot grant server authority. Missing authority fails closed.
- Default creation has `updatedAt: 0`. Its stable ID and local protection survive
  repeated migration. Replacing a default identity is a separate gated action.
- Sorting is stable: explicit positions, then default/creation/insertion ties.
  Moves stamp only records whose stored order changes and do not mutate input.
- Display names stop at 40 UTF-8 bytes without cutting a code point.

Native Roku distinguishes boxed `roInteger` values in associative-array literals
from primitive `Integer` values. The model and strict JSON serializer accept both,
in addition to the existing interpreter alias `roInt`. This must not be confused
with permitting Float/Double IDs merely because their numeric value is integral.
Native case-sensitive parsed maps also require explicit canonical field access:
the store normalizes recognized spellings, rejects case-colliding keys and does
not create lowercased aliases when writing `userId` or roster timestamps.

## Store primitive

`source/UserProfileStore.brs` defines one `userProfilesV1_<slotId>` registry value
per Dispatcharr slot. Schema 1 carries `playlistId`, `active`, `askAtLaunch`,
`removed`, `pendingRoster` and one to four `profiles`. Profile records contain
local add origin/address-hold markers alongside identity/authority, role,
display/avatar/order, creation/roster stamps and imported PIN verification
metadata—never an API key or plaintext password. PIN metadata is sensitive;
"separate credentials" does not mean that the roster is safe to publish.

Only an **absent** registry key permits empty first-run migration. A present
empty value, malformed JSON, unexpected fields/schema/types, duplicate IDs/
usernames/user IDs, missing default, invalid active choice or corrupt PIN enters
read-only recovery. Unknown local fields are rejected rather than silently
dropping possible protection/hold state. The local schema must be extended
explicitly before subsequent lifecycle features persist their fields.

The candidate metadata ceiling is 8192 uncompressed bytes per slot. It is a
defensive bound for this four-record format, not a reserved/free registry budget
or a promise that four fully populated slots fit. Actual registry write/flush
failure still controls success, and full-app capacity must be remeasured.

`commitUserProfileStore` compares the saved metadata snapshot, validates a full
candidate, and stages metadata with non-default key writes/deletions in one
Flush. Failures restore previous values **and their presence/absence**, then
report whether recovery is required. Remember-off removes only owned non-default
keys. It never writes/deletes `connKey_<slotId>` or creates a default `profKey`
alias. Default Remember remains slot-owned.

`UserProfileLifecycle` supplies bounded tombstone union/90-day expiry, newer
re-add handling, default protection and removal/undo plans. Held removals,
pulled-tombstone cleanup and roster/paused-add undo create no new tombstone or
push. An active target must be retired/switched by the controller first.

`removeUserProfile` commits target-key deletion, roster/tombstone and only the
target's exact account preference scope together. Whole-slot
`forgetUserProfileConnection` commits connection removal, default/all
slot-namespaced profile keys, local profile metadata and every preference scope
ending in the slot identity in one Flush. It recovers an unreadable profile
roster without guessing identities or touching another slot. Corrupt unrelated
preferences are retained/refused, not silently replaced. Whole-slot Forget
creates no synced tombstones; the existing Forget controller uses this path.

`UserProfileAvatar` supplies shared icon/color catalogs, foreground ink,
normalization, complete-codepoint initials and UTF-16-unit default colors.
Native supplementary/accents pass. Actual avatar art is management UI work.

## Acceptance boundary

The model/store suites cover identity/authority, ordering, corruption, cap,
repeated migration and fake-registry write/flush/rollback/stale-snapshot behavior.
Native execution additionally qualifies boxed integer types and Unicode byte
boundaries. The isolated real-registry probe uses only a new UUID-named section,
synthetic identities/keys and explicit section cleanup; it does not load owner
profile or connection sections.

The optional native command is:

```sh
python3 scripts/test-profile-primitives-native.py --model-store \
  --restore /path/to/checksum-matched-prior.zip \
  --report out/profile-model-store-native.json
```

Supply device credentials through the environment. A failed probe report is
investigation evidence, not acceptance. All native runs must restore and verify
the exact prior developer ZIP, including on assertion failure.

On the authorized 3820RW2 / OS 16.0.4 build 853, the final combined run passed
143 assertions, including the prior HTTP/JSON/PIN matrix, shared model/store
tests, native Unicode checks and production-store operations in a disposable
real-registry section. Its section cleanup and checksum-matched prior app restore
both passed. Report: `out/profile-model-store-native.json`, SHA256
`c3be1005081d562c734323500d99293d234302b0d6f9890fe7d08c0e3b0c5965`;
probe archive SHA256
`219dbd45bd97d928b566e2606067bf334740831874cea348b4c597bc6f4a6162`.
Earlier failures identified boxed-integer, strict native type-comparison and
parsed-map field-casing differences; they are not passing acceptance reports.
Broader existing-model integer-guard auditing is tracked separately as `9sq`.

## Application integration

`DispatcharrTask` passes a minimal verified identity/authority object, not the
whole `/me/` object or its credential fields. `ensureConnectedUserProfile`
checks its ID against the Task account ID before default migration. Existing
defaults retain stable ID/PIN/metadata. A different identity is refused until
the separate staged replacement lifecycle in `mrr.6` is implemented.

Connection and Channel Profile entry points check saved state before creating
a network Task. Phone setup is checked before opening and again before
verification, including retry/direct handlers. Corruption is recovery, not
first run. Protected defaults, Child, non-default and pending-picker states
cannot silently connect using the slot key while their controller is absent.
This intermediate fence is not a PIN bypass or public profile UI delivery.

The real-app recovery probe substitutes a unique registry section, synthetic
remembered credential and corrupt roster. Its HTTP trap receives **zero
requests** and the connection creates no Task. Its section is then cleaned
and the checksum-matched previous app restored. Evidence:
`out/profile-recovery-native.json`; extended lifecycle/real-registry coverage:
`out/profile-migration-final-native.json`; receiver/direct-handler recovery:
`out/setup-apply-http-native-results.json`. The earlier 143-assertion hashes
above are historical foundation evidence, not hashes of these newer reports.

The extended migration/lifecycle matrix passes 246 native assertions, including
isolated real-registry per-profile removal and whole-slot Forget, with rollback
faults covered by the same shared fake-registry tests on native Roku. The
normal-app recovery screen was inspected after splash/first paint: the recovery
message is readable and the fake credential remains masked. The real HTTP setup
matrix passes 16 cases, including both ordinary and direct-handler recovery
refusals with zero provider requests. The full repository verification gate
passes; these are implementation/synthetic integration checks, not real-owner
profile switching or public certification acceptance.

The current slot-namespaced format was also remeasured with the four-slot/full
24KB preference fixtures: every 1/2/4/6/8-profile capacity candidate saved and
cleaned successfully; the four-profile candidate left 13,312 registry bytes.
Report: `out/profile-storage-final-native.json`. Counts above four are capacity
probes only, not allowed local rosters. Compression and populated-profile-budget
limitations from the original qualification still apply.

The address-trust metadata extension was remeasured on the authorized Roku with
the same four-slot/full-24KB fixtures, now including recorded default identity,
frozen snapshot and held non-default tags. The supported 1/2/4-profile candidates
all saved; four profiles per slot left 12,501 registry bytes. Each disposable
section was verified empty/deleted and the exact prior app was restored. Report:
`out/profile-address-capacity-native.json`. The probe now fails if any supported
candidate cannot save. Exploratory 6/8 candidates also saved, but **the local cap
remains four including default**. These representative 54-character synthetic
keys/names are not a promise that every maximum-sized profile/setting fits;
compression, byte ceilings and atomic write/Flush refusal still govern success.

Scoped state, shared request safety, read-only roster and PIN/Child controllers
must land before public switching. Actual active-session retirement, verified
role refresh/default replacement and management UI remain the corresponding
`mrr.6/.7/.8/.9/.10` work. The controlling scope remains
[PROFILES-CONTRACT.md](PROFILES-CONTRACT.md).
