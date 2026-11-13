# Import-only PIN verification policy (in progress)

`UserProfilePinPolicy` implements per-holder import-only verification/backoff.
`ProfilePinNavigation` connects numeric records to the native launch PIN pad.
Neither generates salt or creates/changes a PIN.

Five wrong valid-length submissions lock a holder for 30 seconds. Each further
five-entry round doubles the lock, capped at 30 × 2^10 seconds. A lock resets
the count; a correct entry after expiry resets all history. Entries during a
lock do not invoke the digest or count. Invalid length/type is not a submission.
Persisted arithmetic remains integer-typed on native Roku.

`userProfilePinAttemptStored` loads `pinHold_<slot>_<holder>` and grants success
only after its state transaction Flush succeeds. A corrupt present record is
recovery, never a silent reset. Failed persistence cannot unlock the app. Slots
and holders remain independent; the ledger contains only count, round and
deadline, never PIN material. Removal, roster tombstone cleanup and slot Forget
clear relevant ledgers atomically.

Exit-authority checks count numeric and direction PINs on full-access profiles,
plus an existing device-local admin PIN. Child PINs do not count. Certification
does not make a Directions-only household appear to have no PINs or authorize
a fallback into unprotected setup.

The profile's locally learned `pinLength` starts at zero (unknown). Correct
verification saves its 4–6-entry length in the same transaction as the backoff
reset, without stamping a roster edit. A changed imported PIN clears the length;
unchanged or malformed-preserve PIN rows keep it. Roku's explicit native-pad
exception in 7.7 keeps `maxTextLength` at six; the learned length remains local
metadata, never a sync field. Stored verification rechecks the live holder/material
before digesting, so a dialog cannot verify a removed or changed profile record.

The entire app checks `GetOSVersion()` before opening its application registry
or creating the network broker. Unknown versions and versions below 14.6 stay
on a readable update-required cover; Back exits. The isolated native fixture
can inject 14.5 on the current OS16 device to exercise this branch (it is not
physical OS14.5 qualification). The actual Developer Dashboard floor remains
an external release check and has not been changed by this implementation.

## Numeric launch integration

The scene starts with an opaque cover. A saved numeric PIN opens a real
`StandardPinPadDialog` before connecting. Submissions clear transient text;
wrong entries and storage failures stay covered. Lock feedback ticks down.
Only successfully persisted verification creates a grant tied to the exact
slot, profile and PIN material. Native `wasClosed` is treated as a void signal:
it requests whole-screen exit, never dismissal into setup/guide. Main observes
that exit after `screen.show()`: registering the field observer earlier returns
false on this Roku, and reading the field before show deadlocks initialization.
Both failures were exposed by the real launch/cancellation fixture rather than
host emulation.

After authentication-only `/me/`, `ProfileRosterNavigation` reads and atomically
applies own-user protection before any channel/cache/settings activation.
Imported numeric protection uses the same gate. The early-read authorization is
single-use and bound to the captured immutable scope and credential; PIN wait
does not invalidate its authenticated continuation. Changed material retires
old grants. Directions is usable only under the developer manifest opt-in below;
without it, and for the still-unfinished Child controller, startup remains safely
covered rather than falling into an unlocked setup page.

The isolated normal-app fixture `scripts/test-profile-pin-native.py` exercises
both a saved numeric PIN and a PIN discovered from App Data, using a private
registry/cache and synthetic loopback server. Five wrong entries, correct input
during the lock, expiry and successful guide continuation pass natively. Protected
HTTP observations permit only `/me/` and own App Data discovery for the imported
case; saved-PIN startup sends no provider request before unlock. Screenshots show
the real pad over the opaque cover. Every test cleans its private section and
checksum-restores the prior app. This is not complete profile acceptance.

Real ECP Back and Options→Back runs also verify the whole-screen exit signal.
The Main field observer is attached only after the render thread starts; a
successful `wasClosed` callback alone is not sufficient evidence of app exit.

## Developer-only Directions entry

`DirectionsPinPad` uses the D-pad itself, explicit Select submission, masked dot
shapes, Back-to-clear and empty-Back/Options exit. Known local length controls
the dot count; imported length starts unknown. Real ECP Up/Down/Left/Right/Select
entry passes the saved and imported roster gate after a full lockout interval.
The same persisted verifier and exact-material grant apply; no PIN is created.
Native screenshots were inspected: unsupported circle glyphs in the first
render were replaced with the existing native rounded shape component.

This surface is enabled only when `aeriotv_profile_directions_test=1` exists in
the developer manifest. The shipping archive verifier rejects **any** occurrence
of that opt-in, even value zero, so renaming a developer package cannot promote
it to a Beta/Store package. With no opt-in, a saved Directions profile remains
covered and Back exits with zero provider requests. This implements the approved
developer phase, not Roku certification or an approved public fallback; `mrr.19`
continues to block public profile delivery.

The selected-connection key loader now goes through `userProfileCredential`:
default migration owns the slot key, non-default profiles own only their
namespaced key, held/corrupt records resolve no key, and Remember-off ignores
registry credentials. A supplied in-memory key remains namespaced to its own
holder. This prevents the old slot-key loader from even staging a fallback
credential for a restored non-default profile; it does not enable switching.

Shared host/native tests cover rounds/cap, expiry, success reset, no digest during
a lock, invalid input, cross-slot separation, corrupt state and failed Flush.
Adult-purpose verification now plans all holder ledgers before a single registry
transaction. It counts both PIN types and an existing slot-local Device Admin
record, never reveals holder names, penalizes only unlocked holders of the
attempted type, and resets only the successful holder. Per-type lockout differs
from all-holder lockout; the latter ends at the earliest holder expiry. Corrupt
records refuse instead of becoming the stranded-Child fallback. No Device Admin
creation/import or new salt API is provided. Forget removes only its own slot's
reserved record and ledger.

`ProfileAdultPinNavigation` supplies a separate adult-purpose native pad with
safe cancellation back to the caller's cover state. Its grant binds slot, active
profile, UI lifecycle UUID, purpose, holder and exact PIN material; it never
creates a profile-unlock grant. `ProfileManagementNavigation` supplies guarded
rename/avatar/order/role dialogs over atomic metadata plans. Role changes and
Child removal still require an adult PIN when one exists. Creating a stranded
kid-only state or an unpinned adult while a Child remains is refused in this
import-only phase. A private normal-app native fixture exercises roster/editor,
real keyboard rename, wrong/correct adult verification, learned length, default
key preservation and real ECP Back cancellation. These controllers are compiled
but **not yet exposed in normal adult Settings**: Child retirement/access, switching, removal,
full management UX and remote-focus qualification remain unfinished.

Child access/escape, picker, authenticated switching and the complete management
surface remain unfinished. Directions stays developer-only pending
certification; production entropy is required for future creation. `mrr.8` and
the epic remain in progress.

## Internal switching integration (not a public picker)

`UserProfileSwitch` validates incoming `/me/` ID and username, target PIN,
independent adult authority for leaving a Child, and a fresh switch-attempt UUID.
The management UI's UUID is separate from the incoming session ID. A non-default
lineup may not inherit the default's Channel Profile filters. Target metadata,
own key and scoped preferences commit in one transaction; a failed Flush restores
the outgoing active profile, keys and settings. Corrupt present settings refuse.

`ProfileSwitchNavigation` now exercises that boundary with real normal-app
Tasks. It stages only the target's own credential, retires outgoing callbacks,
blocks UI/remote renderers behind a scrim while permitting the tagged incoming
Task, and adopts runtime state only after storage succeeds. Failure restores the
previous profile under another fresh session UUID, with no autoplay. The private
same-slot A/B/A fixture verifies own keys/preferences and rejected-key rollback.
The populated-lineup fixture also cancels a delayed target `/me/` with real Back:
the old request cannot activate after returning to A, and no target lineup is
fetched. Numeric target-PIN and empty-pad cancellation variants use the real
stored verifier; cancelling before PIN verification sends no target request.
The first PIN-backed switch test exposed the learned-length write invalidating
the captured roster. The controller now accepts only that exact length update,
rejecting unrelated changes while the pad was open, before consuming the ticket.

Outgoing raw-key prompt/recheck bindings are explicitly retired with connection
and profile transitions, so a rapid same-slot A/B/A cannot resurrect them. Only
the same rejected default holder's re-login flow may carry its hold across its
own reset. Active non-default rejection revokes only its own credential and
stays covered without calling default setup or reloading the slot key. A native
active-refusal fixture verifies the default key and active profile are retained;
the separate own-sign-in/access UI is still unfinished.

Remember-off switching uses Scene-only credentials keyed by server address, slot
and local profile UUID. The outgoing verified key is captured under that exact
owner before switching; returning to the default cannot use a profile's key or
an address-edited/recreated slot bucket. The native memory-only A/B/A fixture
passes own lineups/settings, rejection and delayed-request cancellation while
both default and profile credential registry values remain absent. Active-key
refusal also deletes the corresponding in-memory owner bucket. A failed registry
rollback stays covered with no active runtime scope instead of reviving possibly
stale profile protection.

This is not the completed switch feature: the controller is unexposed, refuses
held/keyless/Child targets and pending roster writes, and still needs the real
sign-in/hold lifecycle, outgoing sync flush, target sync-session start, playback
confirmation, launch/picker integration and complete acceptance matrix.

## Child Settings boundary

The scoped Child Settings model now exposes only Live TV, Player, Appearance,
About (including its read-only detail pages), and Manage Profiles. Hidden deep
links return to that restricted root. Manage Profiles emits an immutable view
event to the existing adult-purpose gate; no holder names are shown before the
gate succeeds. Unknown or mismatched scoped authority has no action/write
permission, rather than borrowing even the Child's management exception.

The Scene rechecks the current scoped role for every Settings action and value
change, not the view's cached role. A same-session event from a formerly Standard
view cannot change hidden network, remote, library or DVR controls after a Child
role change. Closing management clears its rendered identity choices.

The private normal-app Child-role fixture checks the actual Settings component,
hidden deep-link sanitization and a forged setup event, then uses real ECP D-pad
navigation to reach Manage Profiles, verifies the generic adult pad, submits its
existing numeric PIN and cancels management with real Back. An inspected native
screenshot shows only the permitted pages. The first native run exposed an
unmapped rail icon crash; the shared renderer now has a safe existing-icon
fallback with a regression test. This does **not** enable Child launch/playback
sessions: whole setup/receiver/server-action fences, unavailable/own-sign-in UI
and authenticated escape integration remain unfinished before that activation.
The shared native policy suite now passes 578 assertions, including malformed
and wrong-primitive Settings values. Roku's native comparison raises on a
String/Boolean mismatch even though the host interpreter accepts the comparison;
admission now compares only compatible primitive kinds. A changed Settings model
also refreshes the rail categories so a formerly Standard rail is not retained.

Connection/receiver admission now re-reads the selected slot's persisted active
role before opening or changing general connection setup. A Child or unreadable
roster cannot use a forged connection action, picker, address/Remember change,
Channel Profile choice, add/remove/rename, HTTP header editor or phone-setup
payload/verification/commit to escape. This does not borrow management authority:
an adult-purpose grant is only for its management operation. Closed PIN/switch
gates also refuse setup. Empty first-time installations and full-access profiles
retain normal setup. Unit direct-handler probes and the private native Child
fixture exercise these refusals without mutating the selected connection.
This is an additional handler boundary, not a claim that Child activation,
server-action fencing, unavailable recovery or authenticated escape is complete.

The Guide receives an explicit local role in its authenticated configuration.
Child options omit group filters/management, legacy connection/general shortcuts,
library toggles and shared source switching; direct picker, setting, group-preview
and group-edit callbacks enforce the same boundary. Child uses the restricted
Settings Hub for permitted Live TV and appearance/player settings instead of the
legacy advanced Guide editor. The Scene independently denies shared source
operations for Child/unknown roles even if a stale capability snapshot says
admin source switching is allowed. The native Child fixture probes actual Guide
option lists and direct group handlers, then forges setup/receiver/source calls
before using the real adult-PIN management route. Public Child activation remains
disabled while the remaining lifecycle and recovery integration is unfinished.

Rejected-key bindings now derive the expected user from the current immutable
scope and matching active profile, not the selected connection's default account
metadata. Missing, retired or mismatched scoped authority cannot label a binding.
The slow recheck Task receives that holder's expected username as well as user ID
and refuses a same-ID/different-name or missing-name response. Legacy default
setup retains its explicit known account expectation. This corrects holder
selection; it does not complete the non-default refusal prompt, own-sign-in form,
or unavailable Child lifecycle, which remain separately gated work.

## Own-sign-in storage groundwork (not a sign-in UI)

`UserProfileOwnSignIn` separates password recovery from validating a saved key.
For an existing non-default profile it accepts only the saved username (case
insensitive), allowing a recreated server user to have a new integer ID. It
retains the local UUID, PIN and claimed metadata, refuses collisions with another
live profile, and never activates the target. Default and address-held recovery
remain explicitly refused until known-default identity and host tags are ready.

The storage commit rechecks the selected connection, exact roster and UI nonce.
Its single transaction replaces only the own key and moves that user's existing
preference blob to the new account scope, preserving other accounts and unknown
settings. Conflicting destination data and corrupt settings refuse without
overwriting either scope; absent settings stay absent. Native parsing uses the
OS 14.6 precision option and the strict serializer, not a lossy FormatJson rewrite
of unknown floating settings. Failed Flush restores the old ID, key and data.

This is not enabled recovery: the actual form, target PIN ticket lifecycle,
early own-key roster read, outgoing retirement, runtime scope adoption, other
scoped cache/progress handling and active Child recovery still need integration.
Changed rows also refuse regressed clocks. The same check now protects existing
rename/avatar/role/reorder plans, including every affected reorder row; no-op
claims keep their existing newer stamp (`AerioTV-Roku-xpn`).

`DispatcharrTask.ownProfileSignIn` now enforces an expected username before any
credential request, uses the contract's refused-login and missing-API-access
messages, and permits a recreated ID when only that username is expected. A
wrong username is refused before its API-access state is reported. Cancelled
Tasks clear credentials without starting a request. Ordinary setup/key checks
retain their existing behavior when this mode is off.

A private normal-app fixture runs actual token + bearer `/me/` requests for
refused credentials, a different username, a null API key, and the correct own
user recreated as ID 88. Only the last case commits the recovered own key and
preference move. The fixture verifies no mixed API-key/bearer authentication,
no target lineup requests during verify-only sign-in, unchanged default key and
active session, and no autoplay. Its registry/cache are isolated and its package
and source fixture are rejected by shipping guards. This qualifies the Task and
storage boundary, not the still-unimplemented native form/activation lifecycle.

## Internal inactive own-sign-in form (not publicly enabled)

`ProfileOwnSignInNavigation` now hosts the native form for an inactive,
non-default, non-address-held full-access target. Its own PIN is required before
credentials appear; that ticket belongs to this form and never activates a
profile. The username is prefilled, password entry uses the secured standard
keyboard, and passwords are masked then scrubbed on submit/cancel. Stale nodes,
replaced Tasks, changed roster/connection/session and failed rollback cannot
commit or uncover an outgoing caller whose authority changed.

While the form is pending, ordinary UI events, setup, switching and management
are fenced without retiring the credential Task's authenticated session. Back
cancels the owned request and returns only to the unchanged caller. A successful
inactive recovery adopts the complete migrated preference root, not just the
roster; otherwise A's next preference write could resurrect B's old scope.
There is no public entry and no automatic switch or playback. Active/default/
address-held/Child recovery and the complete transition/sync lifecycle remain
unfinished.

For `AerioTV-Roku-6qo`, scoped settings commits copy only the root/accounts
containers they replace and strictly serialize untouched extensions and foreign
accounts. Native Roku can expose a precision-parsed binary64 value as `roFloat`
after container assignment; all floating wrappers therefore use 17 significant
digits. The native regression recovers B to user ID 88 and then persists A,
verifying both root and B's unknown binary64 values survive exactly. Cold-load
and active-account normalization fidelity remain separate work (`AerioTV-Roku-rqq`).
The private native form fixture also exercises the actual numeric target-PIN
pad, cancellation before credential entry, four real credential outcomes and
Back while a delayed `/me/` is pending. The shared native suite passes 616
assertions, including unchanged caller containers after failed commits. Each
native run checksum-restores the exact preceding developer app.

For `AerioTV-Roku-rqq`, application startup and profile-roster reload explicitly
request precision parsing of `settingsV1`; malformed/newer roots or malformed
foreign accounts remain read-only instead of becoming empty writable defaults.
Preference normalization and canonical replacement now use a bounded structural
copy that preserves numeric values, literal key casing and independently owned
mutable containers. The general-purpose `copyJson` remains unchanged. Guide
nested values and profile-settings extensions use the same settings-only copy.
The copy does not truncate overly deep extensions: the strict writer refuses
them at its existing depth limit. Profile-switch storage also reads at precision
and strictly serializes the complete root rather than shortening inactive data.
Native regressions cold-load the stored root, normalize/change the active
account, commit, and switch to B; root, own/nested and foreign binary64 extensions
must survive each stage. Startup still applies legacy migration, lineup history
reconciliation and phone-import changes in their original order.
The legacy/device settings writer uses strict serialization too: switching to
an unprofiled provider must not shorten saved Dispatcharr profile extensions.
Its existing size/write/Flush failure and rollback behavior is retained.
These paths pass 623 shared native assertions. Cleanup/removal-specific writers
remain separately tracked as `AerioTV-Roku-5r1`; this is not a claim that every
unreleased profile/sync mutation path has been qualified for numeric fidelity.

`AerioTV-Roku-5r1` now uses the validated precision loader's raw form for
whole-slot Forget, single-profile removal and pulled-tombstone cleanup. These
transactions delete only owned scopes; they do not normalize another account's
known fields (which may contain values introduced by a future client). They
strictly serialize the retained root within the byte budget before their single
atomic Flush. Present empty settings are corruption, not an absent store.
Native red/green fixtures retain root/foreign binary64 values, integral-floating
number kinds and future Guide values through all three deletion paths; the
shared suite passes 627 assertions, including existing exact rollback failures.

Local deletion (`AerioTV-Roku-k6x6`) refuses a clock older than the removed
row's `updatedAt`, before any key/settings/roster write. Equal timestamps remain
valid because the shared tombstone rule wins ties. Pulled cleanup, address-held
removal and roster/paused-add undo remain local-only and need no new timestamp;
they do not manufacture or broadcast a tombstone.

## Server-address policy groundwork (not URL-handler integration)

Local roster metadata can now retain a validated `knownDefault` identity, frozen
`addressChangeSnapshot`, and each non-default profile's `defaultIdentityTag`.
Tags may be explicitly null (unknown); absence means a pre-feature record that
takes the recorded identity once. Unknown tags never gain trust from that legacy
migration. Malformed present identities/tags fence the roster. These fields are
local-only and must not enter the shared profiles-category writer.

`UserProfileAddressPolicy` compares scheme, case-insensitive host and effective
port (including IPv6/default ports), ignoring path-only changes. A changed
origin plans holds for every non-default profile, keyless included, and selects
the default. Active Child edits are refused. The old record/snapshot cannot be
refreshed during the change or while any holder remains held. A passing live
default ID plus username lifts only tags matching the captured identity; wrong,
missing or unknown tags remain held. Own verification can lift only that holder
and tags it with the live default answer, or explicit unknown if unavailable,
never the frozen record.

This remains pure policy: no URL or key writes, request scheduling, runtime
adoption, or public held-profile recovery has been enabled. The controller still
owes one atomic URL/hold/snapshot Flush, setup-update handling, credential and
scope retirement, URL-bound default verification, preference-scope transfer/
Copy rules, Child-default routing and whole-pause settlement before activation.
The shared native suite passes 675 assertions, including real private-registry
roundtrips of a long-integer default identity, keyless hold and explicit unknown
tag. The actual protected own-sign-in form also preserves the recorded identity
and tag while recovering a recreated user ID, and still passes delayed Back
cancellation with exact owner-app restoration.

## Inactive default recovery storage

The storage planner now accepts an inactive full-access default only when its
existing ID/name and known-default expectation both match. Recorded ID/name
takes precedence over the slot's default-written username, then the default
record's username; username-only fallbacks do not invent an authoritative ID.
Active-default recovery, default identity replacement, held recovery and Child
default routing remain refused. The native form still refuses default targets.

Successful recovery updates the slot key, never a non-default key. Remember-off
deletes the slot key; legacy recovery clears the old `apiKey` fallback in the
same transaction. Same-ID recovery leaves settings bytes and active selection
unchanged, retains trust metadata and preserves the outgoing remembered key.
Failed Flush restores the prior values. This does not activate a default or
complete its Task/form/runtime lifecycle.
