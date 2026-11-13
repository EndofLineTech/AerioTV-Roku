# Profile storage foundation (`mrr.4`, in progress)

This is internal groundwork, not a delivered profile switcher or an activated
migration. The application does not yet load or write this profile store. The
existing connection flow now saves the verified `/me/` username alongside its
account ID, so later API-key migrations need not guess from a blank login field.
An old same-account caller may omit the username without erasing it; a different
account cannot inherit the old name.

## Model

`source/UserProfileModel.brs` contains pure identity, role and order rules:

- Canonical lowercase UUIDs are checked before creating `profKey_<uuid>` names.
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
per Dispatcharr slot. Schema 1 carries `playlistId`, `active`, `askAtLaunch` and
one to four `profiles`. Profile records contain identity/authority, role,
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
alias. Default Remember, whole-slot Forget, scoped data cleanup and policy-safe
removal must be implemented in the later integrated lifecycle transaction.

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

`mrr.4` stays open: avatar catalog/UTF-16 color rules, tombstones/removal policy,
whole-slot cleanup, verified-result authority handoff, startup migration and
corrupt-store connection fences are not delivered by these primitives. Scoped
state, request safety, read-only roster and PIN/Child gates must land before any
public switching. The controlling scope remains
[PROFILES-CONTRACT.md](PROFILES-CONTRACT.md).
