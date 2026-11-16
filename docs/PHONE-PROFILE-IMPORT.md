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

This is not sender interoperability or completed receiver integration.
The existing receiver still rejects unsupported protected-default imports and
does not call the new batch core. Its production entropy/access gates remain
unchanged. The controller still needs the incoming playlist-ID match before
duplicate handling, pre-verification address-hold transaction, bounded per-user
key/password verification, covered second-stage adoption, partial-failure
reporting, explicit Sync offer and onboarding continuation. Android/Apple
sender acceptance and owner acceptance remain in Beads.

The batch refuses unresolved address-held rosters until that controller uses
the existing current-address/default-identity settlement rules; it does not
guess from a frozen old-server snapshot.
