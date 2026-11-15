# Dispatcharr sync writer status

The general writer (`AerioTV-Roku-e3e.6`) is **not active**. Profile switching
still lacks outgoing sync flush/session settlement; do not enable public profile
readiness based on the structural validation below.

## Private checked-body boundary

`source/DispatcharrSyncWriteBody.brs` checks a proposed profiles-only rebuild
against the freshly read canonical value. It refuses malformed/newer originals,
changed unknown envelope/category/data members, changed unsupported categories,
noncanonical new timestamps, missing rebuilt device identity, malformed profile
rows, floating stamps/order/tombstone IDs, invalid tombstones, encoding/size
failures and an independently reparsed body that differs in
typed JSON value. Object-member order is immaterial; key case, array order and
integer versus floating number kinds are not. No shared `copyJson` or default
precision parser handles the wire value.

The result contains the exact checked string and UTF-8 byte count, but deliberately
returns `allowWrite: false`. It does **not** prove session ownership, a correct
profiles row/tombstone merge, fresh GET/list evidence, legacy migration safety,
request-gate admission or current credentials. No production caller enables this
path. Creation of an absent canonical key is not supported by this gate.

Host tests cannot establish wire-case/number correctness because the interpreter
lowercases keys. The native private probe removes the host parser seam and runs
the successful body/roundtrip checks using the actual double-preserving parser.
Native assertions cover binary64/integral doubles, millisecond integers, null,
emoji and case-distinct future keys. Evidence:
`out/mrr-sync-write-integer-green-native.log`; zero failures and exact owner-app
restoration. Earlier native runs rejected a serialization-order comparison and
an incorrectly placed test snapshot assertion; those failures remain in their
logs rather than being counted as passes.
Native tests also exposed that the read decoder deliberately tolerates bad
stamps/order and drops malformed tombstones. A separate write-side validator now
refuses those inputs rather than emitting malformed rebuilt rows; the four-case
red run is retained in `out/mrr-sync-write-integer-red-native.log`.

The required subsequent writer must re-read before each PUT, merge supported
data without dropping remote rows/tails, bind the actual outgoing own session,
preserve dirty state on failure/hold/cancellation, and send the checked string
unchanged through the existing checked-JSON transport. Legacy/absent-key rules,
queue settlement, category mappings and peer interoperability remain unfinished.

## Remote roster write base

`source/DispatcharrSyncRosterWrite.brs` now provides the first pure roster-writing
stage. It preserves server users absent locally and future row tails/avatar
members, selects newest duplicate user IDs, supplies typed legacy row defaults,
unions local/remote username tombstones while retaining known server IDs, expires
ninety-day removals and lets newer remote re-adds clear old tombstones. Malformed
local removal intent or an unpreservable remote PIN refuses rebuilding rather
than silently clearing protection. Remote display names are UTF-8 bounded.

This stage does not merge local profile edits, apply stale-device acknowledgement
rules or authorize HTTP; `allowWrite` remains false. Host and native shared matrix
pass (`out/mrr-sync-roster-write-base-native.log`, exact owner restore). Full
verification: `out/mrr-sync-roster-write-base-full-verify.log`.

The subsequent private `dispatcharrSyncProfilesWritePlan` now plans local edits
through the existing read-side merge, preserves stored row stamps and same-ID
future tails, retains unclaimed future server avatar descriptors, and writes the
actual sorted visible index. It suppresses acknowledged stale local rows missing
from a nonempty newer server roster without deleting those local profiles. Newer
intentional local re-adds clear older tombstones. A covered default stays local
but is not blindly emitted as a new unstamped re-add. Local removals return
`cleanup-required`; a newly imported active Child role returns
`protection-changed`. Both require controller settlement, not an HTTP write.

The plan returns `allowWrite: false` and its local merge plan separately. There is
still no production caller, persisted acknowledgement/session integration,
legacy/absent-key creation or outgoing flush. Full host verification
and the expanded native matrix pass after the imported-Child regression:
`out/mrr-sync-profiles-write-plan-final-verify.log` and
`out/mrr-sync-profiles-write-plan-final-native.log` (exact owner app restored).

`dispatcharrSyncPrepareProfilesWrite` now connects the existing-canonical envelope,
roster merge and checked-body stages. It precision-clones rather than mutating the
fresh value, updates only writer metadata and the rebuilt profiles data, and
returns `needsLocalCommit` with the local plan. It still returns `allowWrite:
false`; fresh own-session GET/list/credential admission, local protection/cleanup
commit and acknowledgement/flush integration must precede any actual PUT.
Native tests-first assembly passed with unknown extras/categories, binary64,
case-distinct keys and no original mutation:
`out/mrr-sync-profiles-assembly-green-native.log`; full verification passed at
`out/mrr-sync-profiles-assembly-full-verify.log`. Exact owner restore succeeded.

## Private actual HTTP writer

`components/DispatcharrSyncWriteTask.brs` now implements existing-canonical own
`/me` → list → key GET → one checked-string PUT. Every request rechecks the
actual adopted request nonce, selected connection/profile and exact saved roots,
current own canonical/session key, full-access role, address holds and broker.
Fresh `/me` must match the expected identity and authorization signature.
Local protection/cleanup changes return a local plan instead of sending; missing
canonical/legacy migration stays read-only. Failure/cancel/late success never
retries immediately or clears durable dirty state. Task credentials are wiped.

The Task's `m.syncWriterReady` remains **false in shipping**. Only the private
fixture clone enables it and rewrites its registry section to the disposable
fixture. Host tests cover stale roots/keys/session, Child/Profiles-Off, held keys,
wrong identity/authority, local-commit needs, cancel, failed PUT and late success.

`--switch --switch-roster --switch-writer` passed on Roku under an actually
adopted B session (`out/mrr-sync-write-task-quiesced-native.log`): only B's
me/list/key/PUT calls occurred in the writer interval, with checked content type,
UTF-8 length, exact key case, integer/double/emoji/future-field preservation and
both local roster rows. The first strict ledger run failed because live Guide
EPG requests overlapped; the fixture now quiesces Guide rather than weakening
the ledger. Its earlier failure report is preserved. Exact owner restore and
disposable cleanup passed on both runs. Full verification passed at
`out/mrr-sync-write-task-final-verify.log` (338 files).

`source/DispatcharrSyncAckStore.brs` now commits matching successful receipts:
the exact original connection/roster roots, still-current actual scope and own
credential digest must match. Dirty clearing and a bounded, credential-free
per-slot highwater record are one registry transaction. Newer edits, changed
keys/holds/generations or stale receipts retain pending state; write/Flush faults
restore exact bytes. Opaque/future acknowledgement records are not overwritten.
Whole-slot Forget removes only the slot's acknowledgement metadata.

The private native writer fixture now also publishes this real acknowledgement,
proving pending clears only after its own successful PUT and the highwater lands.
`out/mrr-sync-write-ack-native.log` and the expanded fault/stale primitive matrix
`out/mrr-sync-ack-store-primitives-native.log` passed with exact owner restoration.
Local-plan publication, scheduling and outgoing flush/session settlement remain
required before the Task can be enabled by the real UI.

## Private outgoing roster flush

`ProfileSyncNavigation.brs` now connects a pending outgoing roster to a chosen
switch, behind shipping-off `m.profileSyncWriterReady`. The actual target PIN
must pass first. The writer keeps the original adopted outgoing scope/nonce/key;
its dedicated fresh flush nonce is only a memory-only request exception behind
the still-closed content fence. It cannot address content or another App Data
key. Ordinary old-user Tasks remain blocked. Acknowledgement refreshes the switch
snapshot; only then may incoming staging retire the outgoing nonce.

The initial native integration correctly refused to run behind the existing PIN
fence. It was not fixed by reopening that fence globally. The explicit writer
subtype/nonce/actual-source-session exception was added and separately tested.
The private real-PIN → B-own me/list/key/PUT/ack → A-own auth/read/lineup path passed
(`out/mrr-sync-flush-gated-native.log`), including zero pre-PIN requests, unchanged
source scope during flush and fresh incoming adoption afterward. The expanded
native state/fault matrix also passed (`out/mrr-sync-flush-primitives-native.log`).
Both cleaned disposable state and restored the exact owner app.

Sync device identity is a per-install UUID persisted once in
`dispatcharrSyncDeviceV1`, not a PIN salt or cryptographic entropy approval.
Invalid existing identity is not overwritten; failed writes restore absence.
Native failed/submitted-cancelled flush now also pass. A synthetic failed PUT
keeps B selected, dirty and credential-owned without any A request or retry.
Real ECP Back during a submitted delayed PUT was observed by Scene; B returns
with a fresh scope, the writer key is wiped, no acknowledgement lands and no A
request follows (`out/mrr-sync-flush-cancel-timed-native.log`). The fixture requires
the key event, not merely eventual rollback. Initial no-key-event failures and
their reports remain retained; one later run measured a 77 ms ECP send, which is
not a root-cause finding for the intermittent delivery issue `667m`.

Actual Scene routing initially recognized only the incoming Task, so Back during
a flush could fall through to protected-launch app exit. A tests-first Scene
regression fixed this independent routing gap (`AerioTV-Roku-cfzm`); do not conflate
it with missing key delivery. Final success and failed PUT native regressions
passed (`out/mrr-sync-flush-success-final-native.log`,
`out/mrr-sync-flush-failed-final-native.log`), as did full verification
`out/mrr-sync-flush-failure-cancel-final-verify.log`. Every run cleaned and restored
the exact owner app. Broader local-plan publication/category/schedule and public
qualification remain unfinished, so all shipping readiness flags stay false.
