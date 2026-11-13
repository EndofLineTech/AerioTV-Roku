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
Adult-gate holder selection, Child access/escape, picker, authenticated switching
and management remain unfinished. Directions stays developer-only pending
certification; production entropy is required for future creation. `mrr.8` and
the epic remain in progress.
