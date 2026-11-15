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
request-gate admission or current credentials. There is no production caller or
PUT Task yet. Creation of an absent canonical key is not supported by this gate.

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
legacy/absent-key creation, outgoing flush or PUT Task. Full host verification
and the expanded native matrix pass after the imported-Child regression:
`out/mrr-sync-profiles-write-plan-final-verify.log` and
`out/mrr-sync-profiles-write-plan-final-native.log` (exact owner app restored).
