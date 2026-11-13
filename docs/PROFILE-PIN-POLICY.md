# Import-only PIN verification policy (in progress)

`UserProfilePinPolicy` adds per-holder verification/backoff primitives, not a
public PIN gate. It never generates salt or creates/changes a PIN.

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

Shared host/native tests cover rounds/cap, expiry, success reset, no digest
during a lock, invalid input, cross-slot separation, corrupt state and failed
Flush. Native dialog wiring, launch cancellation, adult-gate holder selection
and handler/Child enforcement remain unfinished. Directions stays developer-only
pending certification; production entropy is required for future creation.
`mrr.8` remains in progress.
