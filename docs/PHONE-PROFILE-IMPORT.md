# Phone profile import — Profiles-only Beta

The bounded Dispatcharr profile-import implementation (`e3e.4`) is closed.
The owner explicitly accepted the
[bounded Profiles-only Beta](MRR-DELIVERY-STATUS.md#integrated-owner-acceptance-checklist-mrr11),
not full phone setup or peer Sync parity (`e3e.8` / `e3e.7`), release, or Store
submission. Live changed-server replacement was not verified; physical Android
is deferred to Beta users, and current same-LAN Bonjour is unverified.
This page does not establish Xtream/M3U playlist-option parity; see
[wire compatibility](PHONE-SETUP-COMPATIBILITY.md) for those behaviors.

## Normal Beta and saved-import evidence

- **Live, released receiver:** Normal v0.3.102 enables encrypted direct setup
  and Dispatcharr profile import without the old developer manifest flags or a
  replacement entropy provider. The [v0.3.102 notes](BETA-CANDIDATE-0.3.102.md#evidence-and-boundaries)
  record four isolated native runs with pinned, unmodified Apple and Android
  encoders and live own-account verification: a protected default plus either
  an adult or a Child in separate runs. These verify receipt/decryption, own
  credentials, retained IDs/PINs, Child admission and explicit Sync decline.
  They are not a three-role live batch, physical phone-app testing or a
  same-LAN Bonjour result.
- **Live, saved same-origin candidate (`ajp9`):** The immutable v0.3.102 run
  could not reopen setup from an already PIN-admitted default. A private overlay
  of the candidate fix on v0.3.102 passed a second encrypted Apple transfer with
  the same playlist ID in different case, in-place slot update, retention of the
  default ID/PIN and existing secondary ID/name, both own keys and the prior Sync
  decline. Home exit and cold relaunch showed a covered picker without an
  authenticated actor or autoplay; the original PIN admitted the correct
  account to Guide. The probe cleaned up and restored exact v0.3.102
  (`out/phone-normal-apple-saved-relaunch-53237951.json`, saved QA run).
  The fix is integrated through `518f170`; the passing probe was not run on
  unpatched v0.3.102. It does not prove live changed-origin replacement, every
  interrupted-save case or full provider parity.
- **Controlled and owner evidence:** The older policy/controller runs below
  cover batch order, partial adds, fence checks, recovery, and consent. Some
  onboarding probes use live own-account reads with a decoded payload and the
  scheduler/writer disabled; that is not a live encoder or App Data write test.
  The owner reported iOS use without an exact physical sender build; physical
  Android is deferred to Beta users and current same-LAN Bonjour is unverified.
  No new PIN or Device Admin creation was enabled.

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
`profilePhoneImportReady` is enabled by normal Beta profile readiness, but
does not bypass the account, PIN/Child or storage admission checks. With
`ajp9`, setup can reopen after verified profile admission; receipt and commit
recheck the initiating context, and a fenced import stays bound to the original
own credential.

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

These historical probes invoke an already-decoded payload in a private
registry; they do not qualify listener crypto or entropy. See the normal
Beta runs above for named encoder interoperability.

## Post-admission onboarding source

`PhoneSetupOnboardingNavigation.brs` now resumes only after a verified full-access
profile has been admitted. A payload requesting Sync triggers a separate
**Turn On / Not Now** offer; payload data itself never writes Sync settings.
Turn On uses existing current-session Sync admission and remains unavailable
when that build's Sync controls are gated. Existing per-category opt-outs are
retained. Not Now records a device-local decline without enabling Sync or
changing account data; Back does not invent consent or a persistent decline.
Prior enabled/declined choices suppress repeated offers.

The next dialog is **Who watches on this TV?**, with existing Added profiles,
Add through the established own-credential path, and Continue. Only profiles
added in this onboarding lifecycle get Remove/undo controls. Undo reuses the
existing roster/plain-add removal policy and target-only key/data cleanup.
Child sessions skip the full-access dialogs. New-salt/Device Admin creation is
still unavailable.

The pending step is carried through the verified startup-picker adoption
boundary, not through arbitrary later profile switches. That path now consumes
the imported playlist options once and clears the phone-commit marker.
The source has focused host/compiler checks in
`out/mrr-phone-onboarding-adoption-host.log` and
`out/mrr-phone-onboarding-adoption-build.log`. Actual native onboarding
qualification now passes `out/mrr-phone-baseline-onboarding-native.log`/`.json`
without a fixture override of the controller gate. It checks the actual
developer-baseline source: protected import and PIN admission, one-time VOD/
guide options, Not Now retained through later preference persistence, Who
watches/Continue, recovery, own keys/source preservation, cleanup and exact
installed-baseline restoration. This does not establish actual Add/undo UI,
Turn On, or Android/Apple sender acceptance.

The prior complete regression passed
`out/mrr-phone-onboarding-adoption-full-verify.log` (379-file verified ZIP);
focused final host, builder, compiler/build and package checks also pass.
Native finding `dsb7` was a missing `roInteger` wire-validation alias: the
successful native log records that actual boxed type for `guideDays`.

The protected Add handoff is additionally qualified in
`out/mrr-phone-add-continuation-native.log` / `.json`: Who watches → Add →
actual adult numeric PIN → own-credential form → Cancel → Who watches →
Continue, followed by existing recovery/cleanup/exact baseline restoration.
`49uu` preserves explicit onboarding return intent through the deferred adult
gate and prevents the Who watches dialog from replacing that gate. Current
adult-gate cancellation also returns; retired gate callbacks cannot reopen it.
Host regression evidence is `out/mrr-phone-add-continuation-confirmed-red.log`
and `out/mrr-sync-phone-final-focused-host.log`. The corrected fixture was
checked against the original two-argument handoff in an external temporary copy.
This is not successful Add/Undo or Turn On qualification.

`--phone-import-add` provides the remaining core Add/Undo acceptance flow:
import one default, add the other approved account through its own sign-in,
Undo the newly added profile, then continue/recover. Its first attempt
(`out/mrr-phone-onboarding-add-undo-native.log`) stopped at the installed-app
preflight with **No route to host**, before any installation or registry work.
That attempt is not a passing result; no network/device changes or retries
were made in that run. The later successful native journey is below.

### Sync-enabled Add integration

Source no longer requires turning Sync off before Add (`4kdm`). Own-credential
Add waits for existing scheduled/outgoing Sync transactions to finish, then uses
the same protection read, own-key commit and roster/plain-add semantics. The
existing own-form scheduler guard prevents new flights and rejects delayed
receipts while the form owns the UI. Outside onboarding, form exit resumes the
existing timer; Add retains unsent roster intent and does not reset category
choices or acknowledge a write.

The scheduler also defers while the overall phone onboarding context is pending.
Otherwise a newly enabled background pull could change Who watches' captured
roster root, leaving its Continue/Add controls stale. Continue releases the
existing timer to perform fresh own discovery; consent itself is not a PUT.
This has a failing-before-fix actual scheduler regression in
`out/mrr-sync-onboarding-defer-red.log`.

Host checks in `out/mrr-sync-enabled-add-integration-host.log` cover admission,
own-form suspension/resumption, delayed receipt refusal and credential cleanup.
The actual Add storage test also preserves Sync On, Profiles Off, unknown choices
and both source accounts' private data. Compiler/build checks and full
requalification pass in `out/mrr-sync-enabled-add-full-verify.log` (380-file ZIP).
This checkpoint changed no readiness flag or persistent installed app. Actual
Turn On → Add/Undo was qualified by the later run below.

Delivery follow-up found and removed a second obsolete Sync-Off restriction in
the own-form ownership check, not just Add admission. The actual-controller
regression fails before the fix and passes after it:
`out/mrr-delivery-sync-add-context-{red,green}.log`.
The native Add journey now chooses **Turn On** explicitly and uses the real owned
form Sign In callback. Only private controls are enabled for this fixture;
writer/scheduler remain off, so approved real accounts cannot receive App Data
uploads. Its final native verdict is recorded separately below.

That same main journey now passes in
`out/mrr-delivery-onboarding-qualified-native.log`/`.json`: protected slot-first
import, explicit Turn On, the actual suggested-name UI, real own-account sign-in/
protection read/Add, Undo, Continue and recovery. All result flags, isolated
cleanup and exact baseline restoration are true. The suggestion is a private
read hint, not a named phone sender. The fixture enables only private controls,
not the writer/scheduler; this proves consent/Add integration without real
App Data mutation. It does not establish listener crypto, actual Android/Apple
sender interoperability or owner/public acceptance.

The completed source-row Add/Undo integration is additionally qualified in
`out/mrr-delivery-source-roster-onboarding-native.log`/`.json`: the received
display name/stamp and `roster` origin survive real own-account Add even without
a target envelope, and Undo removes only the local addition/key with **zero
tombstones**. All final flags, cleanup and exact restoration pass. Full regression:
`out/mrr-delivery-final-verify.log` (380-file verified normal ZIP).

The same source-row onboarding journey also passes using **API key alone** in
`out/mrr-delivery-api-key-onboarding-native.log`/`.json`: secure native key-editor
callbacks, live own identity discovery with no typed username/password, own
protection read, Add and zero-tombstone roster Undo. All result flags, cleanup and
exact restoration pass. This is a real key-authentication path, not keyboard/
voice certification or an actual phone sender.

One native onboarding run lost device access during cleanup/restoration.
The exact baseline was manually restored and verified; a read-only native scan
found no `AerioPickerLaunchProbe-*` sections. Evidence is
`out/mrr-phone-onboarding-recovered-baseline.json` and the referenced logs.
The failed run remains failed. Reports now retain the private section identifier
and cleanup/restore exit codes for safe, bounded recovery.
