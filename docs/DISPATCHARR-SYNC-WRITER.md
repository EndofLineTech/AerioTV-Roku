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

Fresh outgoing authority/binding refusal is distinct from a transient failed PUT.
It now stops source playback if present, fences native renderers and stays covered
with no active runtime scope/key; it cannot roll back to old permissions. Stored
credentials and pending metadata remain intact for proper own recovery. The
native source-B level change case required only B's `/me`, with no App Data/PUT
or A request (`out/mrr-sync-flush-authority-fenced-native.log`). Host tests assert
playback-stop/fence calls; this is not native video-plane acceptance. Full verify
and the native state/fault matrix passed
(`out/mrr-sync-flush-authority-final-verify.log`,
`out/mrr-sync-flush-authority-primitives-native.log`). Immediate role reload and
own-login recovery UX remain separate work, not implied by this fail-closed fix.

## Fresh read publication and retained protection

The private writer now returns a typed own-read receipt when local metadata must
settle before PUT. `commitDispatcharrSyncRosterRead` checks the exact roots,
current own scope/key digest and authorization signature, then imports metadata
without clearing pending intent or writing acknowledgement highwater. The
controller bounds settlement to two attempts and requires a fresh source read
after publication. A changed target PIN invalidates the old ticket and prompts
again; it cannot reuse a checked body from before the local transaction.

Native imported-PIN qualification passed with stricter integer/wire assertions
and distinct first/second flush nonces
(`out/mrr-sync-read-import-pin-resumed-native.log`): original target PIN, B-own
read importing a new PIN, old PIN refused, new PIN accepted, fresh B read/PUT/ack,
then A-own adoption. Full verification passed at
`out/mrr-sync-read-publication-resumed-verify.log`.

`AerioTV-Roku-ago9` exposed a separate retirement crash gap with a failing test:
phase one selected from old metadata, postponing retained protection until
cleanup. Selection now durably publishes merged retained metadata while keeping
removed records, keys, backoff and blobs unchanged until runtime teardown.
Cleanup reconstructs the same root at selection's original `plannedAt`, including
time-sensitive stripped-row repair; later seconds cannot change that snapshot.
The durable journal remains credential/PIN-grant-free and cold recovery grants
no system-adoption receipt.

Host live/cold, delayed repair, stale/time/root and existing fault/re-add cases
passed. Native live imported PIN and Child cases passed, as did an actual
separate-process cold restart requiring the newly imported PIN and refusing the
old PIN with zero requests. Evidence:
`out/mrr-retirement-retained-{pin,child,cold}-native.log` and
`out/mrr-retirement-retained-primitives-native.log`. Every run cleaned disposable
state and restored the exact owner app. Full verification passed at
`out/mrr-retirement-retained-protection-pre-native-verify.log`.

Active-own tombstones now use distinct actual-own admission. A matching current
own read receipt selects the real default with a credential/PIN-free durable
intent. After actual runtime teardown, exact source/selected/journal roots and
the original own credential digest admit live cleanup. Only that live boundary
returns the explicit system transition receipt; cold recovery still returns no
adoption receipt or PIN bypass. The shared controller then independently
authenticates, reads and loads the default. Generic read publication continues
to refuse active removal rather than silently authorizing it.

Host own-selection/cleanup faults, stale scope/authority/key/root/nonce,
Profiles-Off, live/cold and controller-routing tests passed. Native
`--writer-mode flush-own-retirement` passed
(`out/mrr-sync-own-retirement-native.log`): B me/list/key GET, no PUT, removed B
key/backoff/account ownership, imported default PIN retained, then independent
A-own authentication/read/lineup. Pending roster intent remains and no write
acknowledgement lands. Expanded native primitives and the original staged-C
system retirement regression passed
(`out/mrr-sync-own-retirement-primitives-native.log`,
`out/mrr-sync-own-retirement-staged-regression-native.log`), with exact owner
restoration and disposable cleanup. Full verification passed at
`out/mrr-sync-own-retirement-pre-native-verify.log`.

General category sync/scheduling and public recovery/Child/admin/onboarding and
acceptance are not established; shipping readiness flags remain false.

## Absent canonical creation

The private writer can now create its own canonical key only after a successful
same-session list with no legacy keys and an immediately preceding canonical GET
returning typed Dispatcharr `404 {"code":"key_not_found"}`. A generic/proxy 404,
failed GET/list, or legacy-only discovery cannot authorize an empty replacement.
A canonical that disappears while stranded legacy keys remain also refuses;
legacy keys are never written or deleted. If a peer creates the canonical between
list and GET, the returned value is merged rather than replaced with an empty base.
The fresh schema-3 envelope contains only explicitly owned profiles metadata and
passes the same checked-body/native precision gate before PUT.

Host creation/race/listed-missing/proxy/legacy tests passed. Actual native create
and acknowledgement passed (`out/mrr-sync-create-canonical-native.log`); legacy-only
and proxy-404 refusals retained exact pending roots and sent no PUT
(`out/mrr-sync-create-legacy-refusal-native.log`,
`out/mrr-sync-create-proxy404-refusal-native.log`). Every run cleaned and restored
the owner app. Full verification passed at
`out/mrr-sync-create-canonical-final-verify.log`. Legacy migration remains read-only,
not implicitly approved by canonical creation support.

## Private scheduled sessions

`DispatcharrSyncSchedule.brs` now models session-start pulls, one-second dirty
debounce, playlist-wide thirty-second picker throttling with one two-second
re-read, fifteen-minute cadence and explicit network-return requests. There is
one in-flight operation; network failures back off thirty seconds, two minutes,
then ten minutes, and broker parks
still gate every request. Old-scope queues/completions cannot affect a successor.
Queue state holds scope and a digest of roster bytes, never raw credentials or
roster/PIN material. Durable pending intent remains in the roster store.

`ProfileSyncSessionNavigation.brs` connects that model to actual own Tasks and
receipt publication/acknowledgement. Pull-only Tasks never PUT, even if dirty;
clean read publication does not invent pending intent. Authority/protection
refusals cover the source; active-own tombstones use explicit own retirement.
Scheduled work refuses closed PIN/Child/switch gates and cancels on reset.
Switch/flush admission refuses an already scheduled operation rather than racing
two writers. A separate shipping-off `m.profileSyncSchedulingReady` and explicit
device-wide opt-in are both required. Public startup/picker/opt-in controls and
native link-status event subscription are not connected by this private fixture.

Tests-first host timing/controller/race checks passed. Actual native Timer/HTTP
qualification passed at `out/mrr-sync-session-scheduler-final-native.log`: initial
B-own pull, debounced own PUT/ack, picker pull plus one re-read (duplicate picker
request suppressed), then explicit network-return pull, all under unchanged B's
scope and with unknown-category/wire preservation. The earlier native run measured
1.72 seconds from dirty marker to PUT. Fifteen-minute timing and thirty-second
expiry are native model arithmetic assertions, not claims of a real fifteen-minute
foreground soak or physical network-link transition.

Native model qualification exposed delayed observation of a normalized read root;
the controller now publishes its new digest to the debounce model immediately.
A separate fixture scope built from literal keys lost case on canonical clone;
the fixture now uses precise JSON session fields. Both earlier failing logs are
retained. Final expanded native matrix, outgoing-flush regression and full verify
passed (`out/mrr-sync-session-scheduler-qualified-primitives-native.log`,
`out/mrr-sync-session-scheduler-flush-regression-native.log`,
`out/mrr-sync-session-scheduler-final-verify.log`). All runs restored the exact owner
app and cleaned disposable state. Public integration, broader categories and
acceptance remain open; no shipping flags were enabled.

## Unchanged acknowledgement

After fresh own discovery/GET and any required local metadata settlement, exact
typed equality of intended and server `profiles.data` now suppresses a redundant
PUT. The Task returns `state=unchanged`, `submitted=false`, `readStatus=200`,
with the same scope/root/key-digest proof. That distinct receipt can atomically
clear only its exact pending snapshot and retain monotonic highwater; a missing
key, invalid GET, stale root or fake submitted flag cannot acknowledge unchanged.
Local-plan publication still precedes this check and requires another fresh read.

Host Task/store/outgoing-controller tests and native exact typed preparation tests
passed. Actual HTTP qualification (`out/mrr-sync-unchanged-settled-native.log`)
performed one original PUT/ack, published the next read's necessary local metadata,
then freshly re-read and acknowledged unchanged with no second PUT. The earlier
fixture expected immediate equality and correctly received `local-commit`; those
failed logs remain retained, not counted as unchanged success. Final native matrix,
scheduled-session regression and full verification passed
(`out/mrr-sync-unchanged-final-primitives-native.log`,
`out/mrr-sync-unchanged-schedule-regression-native.log`,
`out/mrr-sync-unchanged-final-verify.log`). All device runs cleaned disposable data
and restored the exact owner app.

## Endpoint failures and bounded pauses

`DispatcharrSyncPolicy.brs` returns sanitized phase/status classifications without
arbitrary response JSON, headers, credentials or URLs. Username 401/403 ends the
attempt quietly; list/PUT 401/403 records a memory-only sign-in pause until a good
later discovery. A key-GET failure is not that pause. The scheduler uses corrected
schema backoff of thirty seconds, two minutes, then ten minutes for network/server
failures. Authorization pauses wait for regular cadence; actual shared 429 parks
and specific rejected-key holds remain enforced below this policy on every call.

Typed `409 max_apps` blocks new canonical creation for this sync session, not
updates to a canonical that exists. Typed 413 stops repeated writes of the same
dirty snapshot; regular or explicitly requested pulls remain read-only, and
imported metadata does not count as a new local edit that unblocks writing.
The next real local mutation may prepare a fresh checked body. Safe category trim
steps and public error/status UI remain unfinished; no unknown data is discarded
to make a rejected body fit.

Host endpoint/capacity/backoff/blocked-root tests passed. Actual native 413 followed
by a read-only network-return pull sent exactly one PUT and retained dirty state;
generic list403 paused after me/list with no key GET or PUT
(`out/mrr-sync-error-too-large-native.log`,
`out/mrr-sync-error-signin-native.log`). Native model arithmetic covers backoff
and pause expiry; the short native refusal runs are not real fifteen-minute wait
claims. Final full verification and expanded native matrix passed
(`out/mrr-sync-error-policy-final-verify.log`,
`out/mrr-sync-error-policy-final-primitives-native.log`). All runs cleaned fixture
data and restored the exact owner app. Shipping flags remain false.
