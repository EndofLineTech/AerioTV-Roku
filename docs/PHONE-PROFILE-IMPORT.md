# Phone profile import (`e3e.8`)

## Qualified batch core

`source/PhoneSetupProfileImport.brs` stages import-only profile metadata after a
Dispatcharr slot has been independently verified. It processes the default,
all non-Child entries, then Child entries, retaining order inside each group.
Every new user needs its own matching current-address identity/key proof.
The existing default UUID and selected holder remain stable; a new slot gets
its captured generated default UUID. Free valid incoming UUIDs are lowercased.
Existing non-default usernames are skipped, not overwritten. Capacity remains
four profiles including the default.

Valid imported PIN material is retained with unknown length until actual entry.
Unsafe Child/full-access additions are skipped rather than creating salts or
weakening existing adult protection. Other successful entries still finish.
Metadata stamps retain pending roster intent. Private settings and the
previously committed default slot key are not copied or rewritten.

`commitPhoneSetupProfileBatch` rechecks the independent callback nonce, exact
connection root, selected entry and previous roster, then commits metadata and
non-default keys in one second transaction. The sync helper returns only
whether a separate explicit offer is appropriate; it never enables Sync.
The local Device Admin record is re-read before commit; a changed exit-PIN
record cannot be accepted from an older captured context.

Host evidence: `out/mrr-phone-profile-batch-host.log`. Native synthetic batch
and fake-registry transaction evidence: `out/mrr-phone-profile-batch-native.log`
and `.json`, zero failed assertions and exact installed-app restoration.
The latest record-recheck qualification passes in
`out/mrr-phone-profile-batch-repeat-native.log`/`.json`. The preceding run
failed before entering any suite with the known native function-lookup symptom;
its log and exact probe ZIP are retained under `d43d`, not declared fixed by
the passing repeat.

## Receiver boundary

The source now has a receiver controller in
`components/PhoneSetupProfileNavigation.brs`. It matches incoming playlist IDs
case-insensitively and verifies only the default first. Existing live-lineup
verification/duplicate confirmation precedes the fenced slot save; only then
does a second bounded Task verify the other supplied accounts. It reuses the
already verified default proof, not a second default `/me/` attempt. This keeps
additional password attempts/throttle waits out of the first slot transaction.
The second transaction installs successful profile metadata/own keys before
returning to existing startup picker/PIN/Child admission.
Lost verification cannot retry or commit as an ordinary unprotected connection.
The new `profilePhoneImportReady` gate remains **false**, including baseline
builds, pending address/identity acceptance, recovery and onboarding work.
Production entropy/access gates are
unchanged. This is not Android/Apple sender interoperability or owner acceptance.

The credential service passed real read-only native verification in
`out/mrr-phone-verification-real-native.log`/`.json`: matching own proofs,
supplied-password fallback, cleared Task inputs, unchanged registry/runtime,
private cleanup and exact installed-app restoration.

## Durable protection across the two saves

`phoneSetupCommitFencedConnection` atomically writes the verified slot/key with
a credential-free `profileImportV1_<slot>` journal containing its nonce,
previous non-secret slot metadata/selection and a SHA-256 digest of the original
profile root. It contains no backup password or API key.
Ordinary and retirement profile loaders both refuse a present journal, including
empty/corrupt values. Only the exact captured import lifecycle can prepare the
second transaction, which installs profile metadata/own keys and removes the
journal in that same Flush. Failed second-stage commits retain the fence.
No incoming payload supplies a PIN grant or enables Sync.

Focused host evidence is `out/mrr-phone-fence-host.log` and
`out/mrr-phone-receiver-admission-host.log`. Native synthetic save/loader/
controller composition passes in `out/mrr-phone-receiver-policy-fixed-native.log`
and `.json`, with zero failed assertions and exact baseline restoration.
The preceding native package had a duplicate host stub; it failed compilation
and restored the baseline before the corrected run.

The first actual native receiver-controller main flow passed in
`out/mrr-phone-receiver-validated-flow-native.log`/`.json`: separate playlist
confirmation, own keys, profile picker, protected default admission, unchanged
source playlist and exact cleanup/restoration. Its predecessor passed an
unvalidated fixture payload and failed before any save; the fixture now calls
the production wire validator. The subsequent slot-first ordering correction
passes `out/mrr-phone-slot-first-host.log` and
`out/mrr-phone-slot-first-native.log`/`.json`, including the same protected
admission/source preservation/cleanup/restoration assertions.

Matched address edits now reuse the established hold/snapshot policy before
authentication, retiring old persisted keys in that transaction and affected
memory keys/runtime before starting the new-origin Task. The batch uses
`userProfileEnsureDefault` for an in-place changed-default rebuild, preserving
its UUID/inherited PIN, and `userProfileDefaultAddressCheck` for current-address
settlement. Unresolved other-user holds and the original comparison snapshot
remain intact; duplicate usernames never silently acquire replacement keys.
Matching a playlist ID updates it in place without relying on URL/account
duplicate matching. Host and native policy evidence is
`out/mrr-phone-address-settlement-{host,native}.log`.

Cold interruption now has an explicit **Discard incomplete setup** action.
It requires the exact journal and unchanged original profile-root digest,
restores only the old slot metadata (or removes a newly added slot), deletes
the overwritten default key, and retains all old profile/PIN/personal data.
No background retry or borrowed credential is used. Native SHA-256/transaction
checks pass `out/mrr-phone-recovery-policy-native.log`/`.json`, with exact app
restoration. The source recovery dialog is reachable from deferred startup and
connection recovery. The later actual receiver/recovery UI flow passes in
`out/mrr-phone-receiver-recovery-final-native.log`/`.json`: protected slot-first
import and PIN admission, explicit discard of a subsequent interrupted new
slot, preserved prior profile root, restored selection, no authenticated actor
or retained unlock grant/autoplay, private cleanup and exact baseline restore.
The journal records a typed `hadPrevious` flag instead of relying on a
serialized `invalid` member to distinguish new and existing slots. Discard also
retires any previous unlock grant and never autoplays restored content.
Native finding `t8la` was the empty-root hash: Roku's digest API returns an
empty result for empty input. The implementation uses the standard SHA-256
empty-message value; the native vector/transaction suite passes
`out/mrr-phone-empty-root-qualified-native.log`/`.json`. Failed diagnostic runs
are retained, not reclassified as passing evidence.

Explicit Sync offer/decline, complete onboarding continuation, sender
interoperability and acceptance remain unfinished; the receiver gate must not
be enabled on the strength of the batch/service checks alone.
