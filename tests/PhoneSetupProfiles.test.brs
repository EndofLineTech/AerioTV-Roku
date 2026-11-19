sub main()
    ' Host interpreter lacks ByteArray/EVPDigest; native probe removes this seam.
    m.phoneProfileRootHasher = function(text as string) as string
        if m.phoneProfileTestRoots = invalid then m.phoneProfileTestRoots = {}
        if not m.phoneProfileTestRoots.doesExist(text) then m.phoneProfileTestRoots[text] = right(string(64, "0") + m.phoneProfileTestRoots.count().toStr(), 64)
        return m.phoneProfileTestRoots[text]
    end function
    if m.phoneProfileRootHasher = invalid then check(phoneSetupProfileRootHash("") = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "native empty profile root has the standard SHA-256 digest")
    entry = normalizeConnectionEntry({id: "slot-a", name: "Import", provider: "dispatcharr", url: "https://example.test", accountId: "1", accountUsername: "Alice", remember: true})
    roster = {schema: 1, selected: entry.id, entries: [entry]}
    matched = phoneSetupPlaylistIdentityPlan(roster, "SLOT-A", "fresh-slot")
    check(matched.ok and matched.matchedId = entry.id and matched.id = entry.id and roster.selected = entry.id, "incoming playlist ID matches case-insensitively before account/URL duplicate choices")
    fresh = phoneSetupPlaylistIdentityPlan(roster, "PHONE-SLOT", "fresh-slot")
    check(fresh.ok and fresh.id = "phone-slot" and fresh.matchedId = "", "free registry-safe incoming ID is retained in lowercase")
    check(phoneSetupPlaylistIdentityPlan(roster, "../unsafe", "fresh-slot").id = "fresh-slot", "unsafe incoming IDs cannot name registry values")
    check(phoneSetupProfileNextAttempt("key", true, {ok: false, relogin: true}) = "password", "refused supplied key gets one supplied-password attempt")
    check(phoneSetupProfileNextAttempt("password", true, {ok: false, relogin: true}) = "skip", "password failure never starts a retry loop")
    check(phoneSetupProfileNextAttempt("key", true, {ok: false, rateLimited: true}) = "stop", "server rate limit stops the remaining batch")
    check(phoneSetupProfileNextAttempt("key", true, {ok: false}) = "skip", "generic failures do not turn into speculative password retries")
    ids = {defaultId: "00000000-0000-4000-8000-000000000001", byUsername: {bob: "00000000-0000-4000-8000-00000000000b", kid: "00000000-0000-4000-8000-00000000000c"}}
    pin = {pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    adult = {username: "Bob", displayName: "Living Room", role: "user", order: 1, id: ucase(ids.byUsername.bob), avatar: {icon: "rocket", color: "purple"}}
    adult.append(pin)
    defaultRow = {username: "Alice", displayName: "Home", role: "user", isDefault: true, order: 0}
    defaultRow.append(pin)
    child = {username: "Kid", displayName: "Kids", role: "child", order: 0, pinType: "none"}
    rows = [child, adult, defaultRow]
    proofs = {}
    for each pair in [["Alice", 1], ["Bob", 2], ["Kid", 3]]
        proofs[lcase(pair[0])] = {ok: true, verifiedBaseUrl: entry.url, apiKey: pair[0] + "-own-key", verifiedUser: {id: pair[1], username: pair[0], user_level: 1}}
    end for
    empty = defaultUserProfileStore(entry.id)
    bootstrap = phoneSetupProfileBatchPlan(entry, empty, [], proofs, ids, 100)
    check(bootstrap.ok and bootstrap.store.profiles[0].updatedAt = 0 and not bootstrap.store.pendingRoster, "ordinary default bootstrap stays unstamped instead of creating a remote roster edit")
    planned = phoneSetupProfileBatchPlan(entry, empty, rows, proofs, ids, 100)
    check(planned.ok and planned.store.profiles.count() = 3 and planned.store.active = ids.defaultId, "handoff creates default and verified chosen users without selecting another holder")
    check(planned.store.profiles[0].username = "Alice" and planned.store.profiles[1].username = "Bob" and planned.store.profiles[2].role = "child", "default then all non-Child then Child, not merely order or input order")
    check(planned.store.profiles[1].id = ids.byUsername.bob and planned.store.profiles[1].avatar.icon = "rocket", "free incoming UUID is lowercased and metadata is applied")
    check(not planned.store.profiles[1].displayNameClaimed and not planned.store.profiles[1].avatarClaimed, "setup metadata is not an explicit local name/avatar claim")
    check(planned.store.profiles[0].pinLength = 0 and planned.store.profiles[1].pinType = "numbers" and planned.store.pendingRoster, "existing valid PIN material imports with unknown length and roster intent")
    check(not planned.keys.doesExist(ids.defaultId) and planned.keys[ids.byUsername.bob] = "Bob-own-key", "profile batch never writes a default-holder key or password")
    suppliedDefault = copyJson(defaultRow)
    suppliedDefault.id = "00000000-0000-4000-8000-0000000000AD"
    suppliedRows = [child, adult, suppliedDefault]
    copiedMetadata = phoneSetupProfileMetadata(bootstrap.store.profiles[0], suppliedDefault, 100)
    check(userProfilePinRecordValid(suppliedDefault) and copiedMetadata.pinType = suppliedDefault.pinType and copiedMetadata.pinHash = suppliedDefault.pinHash and copiedMetadata.pinSalt = suppliedDefault.pinSalt, "parsed lowercase-key PIN metadata retains the same valid protection as the literal row")
    malformedPin = setCanonicalPreference(copyJson(suppliedDefault), "pinHash", "malformed")
    retainedPin = phoneSetupProfileMetadata(copiedMetadata, malformedPin, 101)
    check(retainedPin.pinType = copiedMetadata.pinType and retainedPin.pinHash = copiedMetadata.pinHash and retainedPin.pinSalt = copiedMetadata.pinSalt, "malformed parsed PIN metadata cannot erase existing valid protection")
    freshIds = phoneSetupProfileBatchPlan(entry, empty, suppliedRows, proofs, ids, 100)
    check(freshIds.ok and freshIds.store.profiles[0].id = lcase(suppliedDefault.id) and freshIds.store.active = lcase(suppliedDefault.id), "new phone playlist preserves supplied default UUID as well as nondefault UUIDs")
    retainedIds = phoneSetupProfileBatchPlan(entry, planned.store, suppliedRows, proofs, ids, 101)
    check(retainedIds.ok and retainedIds.store.profiles[0].id = ids.defaultId, "matched existing default keeps its local UUID despite a different sender UUID")
    suppliedDefault.id = "../not-a-profile-id"
    fallbackIds = phoneSetupProfileBatchPlan(entry, empty, [suppliedDefault], proofs, ids, 100)
    check(fallbackIds.ok and fallbackIds.store.profiles[0].id = ids.defaultId, "invalid default sender UUID falls back to generated safe UUID")
    existing = planned.store
    repeated = phoneSetupProfileBatchPlan(entry, existing, rows, proofs, ids, 101)
    check(repeated.ok and repeated.store.profiles.count() = 3 and repeated.keys.count() = 0 and repeated.skipped.count() = 2, "existing nondefault usernames skip idempotently instead of replacing their keys")
    unprotected = copyJson(defaultRow)
    unprotected = setCanonicalPreference(unprotected, "pinType", "none")
    unprotected = setCanonicalPreference(unprotected, "pinHash", "")
    unprotected = setCanonicalPreference(unprotected, "pinSalt", "")
    unsafe = phoneSetupProfileBatchPlan(entry, empty, [child, adult, unprotected], proofs, ids, 100)
    check(unsafe.ok and unsafe.store.profiles.count() = 2 and unsafe.skipped.count() = 1, "import-only phase skips unsafe Child instead of inventing a new adult PIN")
    missing = {}
    missing.append(proofs)
    missing.delete("bob")
    partial = phoneSetupProfileBatchPlan(entry, empty, rows, missing, ids, 100)
    check(partial.ok and partial.store.profiles.count() = 2 and partial.keys.doesExist(ids.byUsername.kid), "one missing own proof is skipped while other protected entries finish")
    check(phoneSetupProfileSyncOffer({provider: "dispatcharr", enabled: true}, {enabled: false, declined: false}), "eligible handoff requests a separate explicit sync offer")
    check(not phoneSetupProfileSyncOffer({provider: "dispatcharr", enabled: true}, {enabled: false, declined: true}), "prior decline is honored without auto-enabling sync")
    registry = {values: {}, flushes: 0, read: function(key as string) as string
        if m.values.doesExist(key) then return m.values[key]
        return ""
    end function, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, write: function(key as string, value as string) as boolean
        if lcase(key) = textValue(m.failRestoreKey) then return false
        m.values[key] = value
        return true
    end function, delete: function(key as string) as boolean
        m.values.delete(key)
        return true
    end function, flush: function() as boolean
        m.flushes++
        if m.failNextFlush = true
            m.failNextFlush = false
            return false
        end if
        if m.trackDurable = true
            m.durable = {}
            m.durable.append(m.values)
        end if
        return true
    end function}
    registry.values["connectionsV1"] = FormatJson({schema: 1, selected: entry.id, entries: [entry]})
    registry.values["connKey_slot-a"] = "default-slot-key"
    registry.values["settingsV1"] = "untouched-private-root"
    nonce = "00000000-0000-4000-8000-000000000090"
    context = {nonce: nonce, connection: entry, connectionRoot: registry.read("connectionsV1"), store: empty, rows: rows, proofs: proofs, ids: ids, deviceAdmin: invalid}
    saved = commitPhoneSetupProfileBatch(registry, context, 100, nonce)
    check(saved.ok and registry.flushes = 1 and registry.read("connKey_slot-a") = "default-slot-key" and registry.read("settingsV1") = "untouched-private-root", "second Flush atomically adds roster/own keys without touching committed slot credential or personal data")
    check(not commitPhoneSetupProfileBatch(registry, context, 101, nonce).ok and registry.flushes = 1, "old batch cannot overwrite a successor roster")
    registry.values = {}
    registry.values["connectionsV1"] = FormatJson(defaultConnectionStore())
    staged = {schema: 1, selected: entry.id, entries: [entry]}
    fenced = phoneSetupCommitFencedConnection(registry, defaultConnectionStore(), staged, "default-slot-key", nonce)
    check(fenced.ok and registry.exists(userProfileImportKey(entry.id)), "verified slot and durable import fence commit together")
    check(loadUserProfileStore(registry, entry.id).readOnly = true and loadUserProfileStoreForRetirement(registry, entry.id).readOnly = true, "cold loaders cannot bootstrap a partially imported default")
    context.connectionRoot = registry.read("connectionsV1")
    context.importRoot = fenced.importRoot
    check(not commitPhoneSetupProfileBatch(registry, context, 100, "00000000-0000-4000-8000-000000000091").ok, "successor nonce cannot remove the protection fence")
    registry.failNextFlush = true
    failed = commitPhoneSetupProfileBatch(registry, context, 100, nonce)
    check(not failed.ok and registry.exists(userProfileImportKey(entry.id)) and loadUserProfileStore(registry, entry.id).readOnly = true, "failed metadata Flush retains the protection fence")
    recovered = commitPhoneSetupProfileBatch(registry, context, 100, nonce)
    check(recovered.ok and not registry.exists(userProfileImportKey(entry.id)) and loadUserProfileStore(registry, entry.id).profiles[0].pinType = "numbers", "metadata own keys and fence removal share the second Flush")
    checkPhoneSetupRememberOffCommit(registry, entry, ids, rows, proofs, nonce)
    if m.phoneProfileRootHasher <> invalid then checkPhoneSetupRollbackFailure(registry, entry, proofs, nonce)
    currentConnections = loadConnectionStore(registry)
    held = phoneSetupHoldMatchedAddress(registry, currentConnections, entry.id, "https://other.example.test")
    check(held.ok and held.store.addressChangeSnapshot.userId = 1 and held.store.profiles[1].addressHeld, "matched new origin snapshots the old recorded default and holds nondefault users before authentication")
    check(registry.read("connKey_slot-a") = "" and registry.read(userProfileKeyName(entry.id, ids.byUsername.bob)) = "", "new-origin hold transaction retires saved default and other-user keys")
    check(held.store.profiles[0].preferenceAnchor = connectionPreferenceIdentity(entry, "1"), "address hold preserves the old preference ownership anchor")
    nextEntry = connectionStoreEntry(held.connections, entry.id)
    nextEntry.accountId = "9"
    nextEntry.accountUsername = "NewDefault"
    changedProof = {ok: true, apiKey: "new-default-own-key", verifiedBaseUrl: nextEntry.url, verifiedUser: {id: 9, username: "NewDefault", user_level: 1}}
    changed = phoneSetupProfileBatchPlan(nextEntry, held.store, [], {newdefault: changedProof}, ids, 102)
    check(changed.ok and changed.store.profiles[0].id = ids.defaultId and changed.store.profiles[0].userId = 9, "new default identity reuses the established in-place rebuild and stable local UUID")
    check(changed.store.profiles[0].pinType = "numbers" and changed.store.profiles[1].addressHeld and changed.store.addressChangeSnapshot.userId = 1, "default replacement retains inherited PIN and frozen old-server holds")
    recoveryBefore = loadConnectionStore(registry)
    originalRoot = registry.read(userProfileStoreKey(entry.id))
    stagedRecovery = copyJson(recoveryBefore)
    stagedRecovery.entries[0].name = "Incomplete phone edit"
    interrupted = phoneSetupCommitFencedConnection(registry, recoveryBefore, stagedRecovery, "temporary-new-default-key", nonce)
    check(interrupted.ok and loadUserProfileStore(registry, entry.id).readOnly = true, "interrupted existing-slot edit stays fenced after first save")
    registry.values[userProfileStoreKey(entry.id)] = originalRoot + " "
    check(not phoneSetupDiscardIncompleteImport(registry, loadConnectionStore(registry), entry.id, interrupted.importRoot).ok, "discard cannot restore an old operation over a changed profile root")
    registry.values[userProfileStoreKey(entry.id)] = originalRoot
    discarded = phoneSetupDiscardIncompleteImport(registry, loadConnectionStore(registry), entry.id, interrupted.importRoot)
    check(discarded.ok and registry.read(userProfileStoreKey(entry.id)) = originalRoot and registry.read("connKey_slot-a") = "", "explicit discard restores original protected profile root without restoring or borrowing a key")
    check(connectionStoreEntry(discarded.connections, entry.id).name = "Import" and not registry.exists(userProfileImportKey(entry.id)), "discard restores non-secret original slot metadata and removes only its fence")
    registry.values = {}
    registry.values["connectionsV1"] = FormatJson(defaultConnectionStore())
    interrupted = phoneSetupCommitFencedConnection(registry, defaultConnectionStore(), staged, "temporary-new-default-key", nonce)
    discarded = phoneSetupDiscardIncompleteImport(registry, loadConnectionStore(registry), entry.id, interrupted.importRoot)
    check(discarded.ok and discarded.connections.entries.count() = 0 and registry.read("connKey_slot-a") = "", "discard of an incomplete new slot removes that slot and its key: " + textValue(discarded.reason))
    print "ALL TESTS PASSED"
end sub

sub checkPhoneSetupRollbackFailure(registry as object, entry as object, proofs as object, nonce as string)
    originalValues = registry.values
    previous = defaultConnectionStore()
    registry.values = {connectionsV1: FormatJson(previous)}
    registry.trackDurable = true
    registry.durable = {}
    staged = {schema: 1, selected: entry.id, entries: [entry]}
    fenced = phoneSetupCommitFencedConnection(registry, previous, staged, proofs.alice.apiKey, nonce)
    journalKey = userProfileImportKey(entry.id)
    check(fenced.ok and registry.durable[journalKey] = fenced.importRoot, "first Flush durably stores the protected slot and journal")
    m.registry = registry
    m.phoneSetup = {retryAvailable: true}
    m.phoneProfileImport = {nonce: nonce, connection: entry, connectionRoot: registry.read("connectionsV1"), previous: defaultUserProfileStore(entry.id), rows: [], proofs: copyJson(proofs), saved: fenced}
    m.phonePending = {entry: entry}
    m.phoneResult = {apiKey: proofs.alice.apiKey}
    registry.failNextFlush = true
    registry.failRestoreKey = lcase(journalKey)
    before = registry.flushes
    finishPhoneProfileCommit()
    check(not registry.exists(journalKey), "the second transaction removed the staged journal and rollback could not put it back")
    check(registry.flushes = before + 1, "a failed journal restore must not Flush the incomplete rollback")
    failure = m.phoneFailedImport
    check(failure <> invalid, "the actual phase-two controller retains failed import state after retiring the transient context")
    check(failure.slot = entry.id and failure.root = fenced.importRoot and failure.restartRequired, "the phase-two controller propagates rollback recoveryRequired for the exact failed slot and journal")
    check(m.phoneProfileImport = invalid and m.phonePending = invalid and m.phoneResult = invalid and not m.phoneSetup.retryAvailable, "rollback failure retires credentials and refuses setup retry")
    lateWrite = m.registry.write("settingsV1", "late-write")
    lateDelete = m.registry.delete("connectionsV1")
    lateFlush = m.registry.flush()
    check(not lateWrite and not lateDelete and not lateFlush and registry.flushes = before + 1, "later Scene registry operations cannot publish the unsafe staged deletion")
    cold = {values: registry.durable, read: registry.read, exists: registry.exists}
    check(cold.read(journalKey) = fenced.importRoot and loadUserProfileStore(cold, entry.id).readOnly, "cold load still sees the original durable journal and refuses profile admission")
    registry.trackDurable = false
    registry.failRestoreKey = invalid
    registry.values = originalValues
    m.registry = registry
    m.userProfileRecoveryRequired = false
end sub

sub checkPhoneSetupRememberOffCommit(registry as object, entry as object, ids as object, rows as object, proofs as object, nonce as string)
    originalValues = registry.values
    registry.values = {}
    priorPlan = phoneSetupProfileBatchPlan(entry, defaultUserProfileStore(entry.id), [rows[1], rows[2]], proofs, ids, 100)
    check(priorPlan.ok, "Remember Off fixture starts with a protected default and existing Adult")
    prior = priorPlan.store
    off = setCanonicalPreference(copyJson(entry), "remember", false)
    previous = {schema: 1, selected: off.id, entries: [off]}
    registry.values["connectionsV1"] = FormatJson(previous)
    registry.values[userProfileStoreKey(off.id)] = FormatJson(prior)
    staged = copyJson(previous)
    staged.entries[0].name = "Reimported"
    fenced = phoneSetupCommitFencedConnection(registry, previous, staged, proofs.alice.apiKey, nonce)
    check(fenced.ok and not registry.exists(connectionRegistryKey(off.id)), "first save of a Remember Off replacement does not persist the new default key")
    savedEntry = connectionStoreEntry(loadConnectionStore(registry), off.id)
    context = {nonce: nonce, connection: savedEntry, connectionRoot: registry.read("connectionsV1"), store: prior, rows: rows, proofs: proofs, ids: ids, deviceAdmin: invalid, importRoot: fenced.importRoot}
    applied = commitPhoneSetupProfileBatch(registry, context, 101, nonce)
    check(applied.ok and not savedEntry.remember and not registry.exists(userProfileImportKey(off.id)), "profile save settles the fence without turning Remember back on")
    check(not registry.exists(userProfileKeyName(off.id, ids.byUsername.bob)) and not registry.exists(userProfileKeyName(off.id, ids.byUsername.kid)), "neither old nor new nondefault keys are persisted")
    prefix = off.url + "|" + off.id + "|"
    adultBucket = preferenceScope(prefix + ids.byUsername.bob)
    defaultBucket = preferenceScope(prefix + ids.defaultId)
    kidBucket = preferenceScope(prefix + ids.byUsername.kid)
    m.profileSessionKeys = {}
    m.profileSessionKeys[adultBucket] = "existing-own-lease"
    adoptPhoneProfileSessionKeys(savedEntry, applied.store, proofs.alice.apiKey, applied.keys)
    check(m.profileSessionKeys[defaultBucket] = proofs.alice.apiKey and m.profileSessionKeys[kidBucket] = proofs.kid.apiKey, "current-session default and newly accepted profile receive only their own keys")
    check(m.profileSessionKeys[adultBucket] = "existing-own-lease", "a skipped duplicate cannot replace its existing session-only lease")
    check(loadUserProfileStore(registry, off.id).profiles[0].pinType = "numbers", "Remember Off does not weaken the default PIN")
    m.profileSessionKeys = invalid
    registry.values = originalValues
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub

sub failPhoneSetup(message as string)
    m.phoneResult = invalid
    m.phoneSetup.phase = message
    m.phoneSetup.retryAvailable = true
end sub
