sub main()
    ' Host interpreter lacks Roku OS 14.6 ParseJson flags; native probe removes this seam.
    m.profileOwnSignInSettingsDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    m.profilePreferenceDecoder = m.profileOwnSignInSettingsDecoder
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 1)
    b.isDefault = false
    b.pinType = "numbers"
    b.pinSalt = string(32, "b")
    b.pinHash = string(64, "a")
    b.displayName = "Living room"
    b.displayNameClaimed = true
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    entry = {id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://example.test", accountId: "7", accountUsername: "Alice", remember: true}
    result = {ok: true, apiKey: "synthetic-new-own-key", verifiedUser: {id: 88, username: "BOB", user_level: 1}}
    planned = userProfileOwnSignInPlan(entry, store, b.id, result, 100)
    childStore = copyJson(store)
    childStore.profiles[1] = setCanonicalPreference(childStore.profiles[1], "role", "child")
    childResult = copyJson(result)
    childResult.verifiedBaseUrl = entry.url
    chosenChild = userProfileOwnSignInPlan(entry, childStore, b.id, childResult, 100, false, false, true)
    check(chosenChild.ok and chosenChild.target.role = "child" and chosenChild.store.active = a.id, "explicit adult-chosen Child own recovery preserves Child and outgoing selection")
    check(not userProfileOwnSignInPlan(entry, childStore, b.id, childResult, 100).ok, "ordinary own recovery cannot silently acquire chosen Child authority")
    check(planned.ok and planned.target.id = b.id and planned.target.userId = 88, "non-default own sign-in accepts its recreated username with a new server user ID")
    check(planned.store.active = a.id and store.profiles[1].userId = 8 and entry.accountId = "7", "own sign-in planning cannot activate early or mutate the default holder")
    check(planned.target.pinHash = b.pinHash and planned.target.pinSalt = b.pinSalt and planned.target.displayName = "Living room", "credential recovery preserves local UUID, PIN and claimed profile metadata")
    check(planned.oldIdentity = connectionPreferenceIdentity(entry, "8") and planned.newIdentity = connectionPreferenceIdentity(entry, "88") and planned.store.pendingRoster and planned.target.updatedAt = 100, "recreated account explicitly stages scoped-data migration and a newer own roster row")
    wrong = copyJson(result)
    wrong.verifiedUser.username = "SomeoneElse"
    check(not userProfileOwnSignInPlan(entry, store, b.id, wrong, 100).ok, "own sign-in cannot change which username this profile belongs to")
    wrong.verifiedUser.username = "Alice"
    check(userProfileOwnSignInPlan(entry, store, a.id, wrong, 100).reason = "default-recovery-not-ready", "default recovery stays fenced until recorded known-user authority is integrated")
    wrong = copyJson(result)
    wrong.verifiedUser.id = 7
    check(not userProfileOwnSignInPlan(entry, store, b.id, wrong, 100).ok, "recreated username cannot collide with another live profile's account ID")
    wrong = copyJson(result)
    wrong.apiKey = invalid
    check(not userProfileOwnSignInPlan(entry, store, b.id, wrong, 100).ok, "an own account without API access cannot stage a credential commit")
    entry = normalizeConnectionEntry(entry)
    newId = "00000000-0000-4000-8000-000000000003"
    addedProof = {ok: true, apiKey: "cara-own-key", verifiedBaseUrl: entry.url, verifiedUser: {id: 9, username: "CARA", user_level: 1}}
    addedRead = {ok: true, state: "missing", verifiedBaseUrl: entry.url, accountId: "9", accountUsername: "CARA", verifiedUser: {id: 9, username: "CARA", user_level: 1}}
    addPlan = userProfileAddPlan(entry, store, newId, "Cara", addedProof, addedRead, 300)
    check(addPlan.ok and addPlan.store.active = a.id and addPlan.target.userId = 9 and not addPlan.target.isDefault and addPlan.store.pendingRoster, "baseline Add creates only an own-verified inactive profile")
    check(userProfileAddSyncAvailable({ok: true, enabled: true}, invalid, invalid), "explicit Sync On does not prohibit own-credential Add")
    check(userProfileAddSyncAvailable({ok: true, enabled: false}, invalid, invalid), "local-only Add remains available with Sync Off")
    check(not userProfileAddSyncAvailable({ok: false, enabled: true}, invalid, invalid), "unreadable Sync choices cannot authorize Add")
    check(not userProfileAddSyncAvailable({ok: true, enabled: true}, {kind: "scheduled"}, invalid), "Add waits for a scheduled Sync transaction instead of racing its saved roots")
    check(not userProfileAddSyncAvailable({ok: true, enabled: true}, invalid, {kind: "outgoing"}), "Add cannot overlap outgoing Sync flush")
    importedRead = copyJson(addedRead)
    importedRead.state = "ready"
    importedRead.profilesState = "ready"
    importedRead.data = {categories: {profiles: {data: {rows: [[9, "Cara", "Imported Cara", "numbers", string(64, "a"), string(32, "b"), "user", 200, {}, 0]], removed: []}}}}
    importedAdd = userProfileAddPlan(entry, store, newId, "Cara", addedProof, importedRead, 300)
    check(importedAdd.ok and importedAdd.target.pinType = "numbers" and importedAdd.target.updatedAt = 200 and importedAdd.target.addOrigin = "roster", "Add reads and inherits existing protection before stamping a newer unprotected row")
    sourceRows = importedRead.data.categories.profiles.data.rows
    sourceAdd = userProfileAddPlan(entry, store, newId, "Cara", addedProof, addedRead, 300, sourceRows)
    check(sourceAdd.ok and sourceAdd.target.pinType = "numbers" and sourceAdd.target.displayName = "Imported Cara" and sourceAdd.target.updatedAt = 200 and sourceAdd.target.addOrigin = "roster", "suggested or manual Add retains the source roster row even when the new account has no own envelope")
    pausedStore = copyJson(store)
    pausedStore.profiles[1].addressHeld = true
    pausedAdd = userProfileAddPlan(entry, pausedStore, newId, "Cara", addedProof, invalid, 300, sourceRows)
    check(pausedAdd.ok and pausedAdd.target.addOrigin = "paused" and pausedAdd.target.updatedAt = 300 and pausedAdd.target.pinType = "none" and not pausedAdd.store.pendingRoster, "held sibling allows own-verified provisional Add without granting protection or queueing a write")
    undone = userProfileRemovalPlan(pausedAdd.store, newId, 310, "undo")
    check(undone.ok and not undone.pushRequired and undone.store.removed.count() = 0 and not undone.store.pendingRoster and undone.store.profiles[1].addressHeld, "undoing an otherwise clean paused Add cannot leave a future mutation queued")
    pendingPaused = setCanonicalPreference(pausedAdd.store, "pendingRoster", true)
    undone = userProfileRemovalPlan(pendingPaused, newId, 310, "undo")
    check(undone.ok and undone.store.pendingRoster, "paused Add Undo does not acknowledge another pending edit")
    check(not userProfileAddPlan(entry, store, newId, "Cara", addedProof, invalid, 300).ok, "ordinary Add still requires a fresh protection read")
    richChild = [[9, "Cara", "Imported Child", "numbers", string(64, "a"), string(32, "b"), "child", 200, {}, 0]]
    check(not userProfileAddPlan(entry, store, newId, "Cara", addedProof, addedRead, 300, richChild).ok, "protected roster Child cannot be added while an adult lacks a PIN")
    protectedStore = copyJson(store)
    protectedStore.profiles[0].pinType = "numbers"
    protectedStore.profiles[0].pinHash = string(64, "a")
    protectedStore.profiles[0].pinSalt = string(32, "b")
    protectedStore.removed = [["cara", 199]]
    readd = userProfileAddPlan(entry, protectedStore, newId, "Cara", addedProof, addedRead, 300, richChild)
    check(readd.ok and readd.target.role = "child" and readd.target.pinType = "numbers" and readd.target.updatedAt = 200 and readd.target.addOrigin = "roster", "intentional newer peer re-add keeps source Child role, PIN and stamp when all local adults are protected")
    protectedStore.removed = [["cara", 200]]
    check(not userProfileAddPlan(entry, protectedStore, newId, "Cara", addedProof, addedRead, 300, richChild).ok, "equal removal stamp still blocks re-add")
    wrongAdd = copyJson(addedProof)
    wrongAdd.verifiedBaseUrl = "https://foreign.test"
    check(not userProfileAddPlan(entry, store, newId, "Cara", wrongAdd, addedRead, 300).ok, "Add refuses foreign-address proof")
    check(not userProfileAddPlan(entry, store, newId, "Bob", addedProof, addedRead, 300).ok, "Add binds the typed username to its actual own identity")
    sourceScope = userProfileSessionScope(entry, a.id, 7, "add-source", "00000000-0000-4000-8000-000000000093")
    addNonce = "00000000-0000-4000-8000-000000000094"
    managementNonce = "00000000-0000-4000-8000-000000000095"
    addContext = {connection: entry, store: store, target: {id: newId}, username: "Cara", scope: sourceScope, nonce: addNonce, addGrant: {slot: entry.id, active: a.id, nonce: managementNonce, purpose: "manage-profiles", kind: "pin", id: b.id, pinType: b.pinType, pinHash: b.pinHash, pinSalt: b.pinSalt}}
    addContext.addRosterRows = sourceRows
    addContext.addRosterScope = sourceScope
    addRegistry = ownSignInRegistry(entry, store)
    addSettings = ParseJson(addRegistry.read("settingsV1"))
    addSettings.device = {dispatcharrSyncEnabled: true, dispatcharrSyncProfiles: false, futureChoice: true}
    addRegistry.write("settingsV1", FormatJson(addSettings))
    oldAddSettings = addRegistry.read("settingsV1")
    savedAdd = commitUserProfileAdd(addRegistry, addContext, addedProof, addedRead, 300, addNonce, sourceScope, managementNonce)
    check(savedAdd.ok and addRegistry.read(userProfileKeyName(entry.id, newId)) = "cara-own-key" and addRegistry.read("connKey_slot-a") = "default-key" and addRegistry.read("settingsV1") = oldAddSettings, "Sync-enabled Add saves only its own credential/record, preserving opt-outs and source private data")
    check(savedAdd.store.pendingRoster, "Sync-enabled Add retains dirty intent for the scheduler instead of acknowledging an unsent row")
    check(savedAdd.target.pinType = "none" and savedAdd.target.addOrigin = "plain", "Profiles Off does not adopt source roster hints during Add")
    blockedAdd = ownSignInRegistry(entry, store)
    blockedAdd.write("settingsV1", oldAddSettings)
    protectedBefore = FormatJson(blockedAdd.values)
    blocked = commitUserProfileAdd(blockedAdd, addContext, addedProof, importedRead, 300, addNonce, sourceScope, managementNonce)
    check(not blocked.ok and FormatJson(blockedAdd.values) = protectedBefore, "Profiles Off cannot apply a target roster or install a known protected roster holder without its protection")
    registry = ownSignInRegistry(entry, store)
    nonce = "00000000-0000-4000-8000-000000000090"
    startupResult = {ok: true, apiKey: "startup-default-key", verifiedBaseUrl: entry.url, verifiedUser: {id: 7, username: "ALICE", user_level: 1}}
    startup = userProfileOwnSignInPlan(entry, store, a.id, startupResult, 100, false, true)
    check(startup.ok and startup.store.active = a.id and startup.target.id = a.id and startup.target.userId = 7, "explicit startup default recovery keeps the exact known holder without early selection")
    foreignStartup = copyJson(startupResult)
    foreignStartup.verifiedBaseUrl = "https://foreign.test"
    check(not userProfileOwnSignInPlan(entry, store, a.id, foreignStartup, 100, false, true).ok, "startup recovery requires exact current-address verification even without a hold")
    foreignStartup = copyJson(startupResult)
    foreignStartup.verifiedUser.id = 70
    check(not userProfileOwnSignInPlan(entry, store, a.id, foreignStartup, 100, false, true).ok, "startup default form never replaces the default's recorded server identity")
    check(not userProfileOwnSignInPlan(entry, store, a.id, startupResult, 100, true, true).ok, "startup full-access recovery cannot borrow Child admission")
    for each failStartup in [false, true]
        startupRegistry = ownSignInRegistry(entry, store)
        oldStartup = FormatJson(startupRegistry.values)
        oldOther = startupRegistry.read(userProfileKeyName(entry.id, b.id))
        startupRegistry.failOnce = failStartup
        savedStartup = commitUserProfileOwnSignIn(startupRegistry, entry, store, a.id, startupResult, 100, nonce, nonce, false, true)
        if failStartup
            check(not savedStartup.ok and FormatJson(startupRegistry.values) = oldStartup, "startup default commit failure restores exact credentials and roots")
        else
            check(savedStartup.ok and startupRegistry.read("connKey_slot-a") = "startup-default-key" and startupRegistry.read(userProfileKeyName(entry.id, b.id)) = oldOther and savedStartup.store.active = a.id, "startup default own credentials commit without touching another holder or creating runtime adoption")
        end if
    end for
    heldStore = copyJson(store)
    heldStore.profiles[1] = setCanonicalPreference(heldStore.profiles[1], "addressHeld", true)
    heldStore = setCanonicalPreference(heldStore, "knownDefault", {userId: 70, username: "OldDefault"})
    heldStore = setCanonicalPreference(heldStore, "addressChangeSnapshot", {userId: 70, username: "OldDefault"})
    heldStore = setCanonicalPreference(heldStore, "verifiedDefaultAtAddress", {url: entry.url, identity: {userId: 7, username: "Alice"}})
    heldResult = setCanonicalPreference(result, "verifiedBaseUrl", entry.url)
    for each failure in [false, true]
        heldRegistry = ownSignInRegistry(entry, heldStore)
        heldRegistry.failOnce = failure
        beforeHeld = FormatJson(heldRegistry.values)
        recovered = commitUserProfileOwnSignIn(heldRegistry, entry, heldStore, b.id, heldResult, 100, nonce, nonce)
        if failure
            check(not recovered.ok and FormatJson(heldRegistry.values) = beforeHeld, "failed held commit restores exact hold, live proof, frozen baseline, own key and data")
        else
            check(recovered.ok and not recovered.target.addressHeld and recovered.target["defaultIdentityTag"]["userId"] = 7 and recovered.store["knownDefault"]["userId"] = 70 and not recovered.store.doesExist("addressChangeSnapshot"), "held commit atomically saves its own key, migrated identity and current-address tag without rewriting the frozen baseline")
        end if
    end for
    saved = commitUserProfileOwnSignIn(registry, entry, store, b.id, result, 100, nonce, nonce)
    check(saved.ok and saved.preferencesMoved and registry.flushes = 1, "own identity, key and data migration commit in one Flush without runtime activation")
    check(saved.preferenceStore.accounts[preferenceScope(planned.newIdentity)].favoriteIds[0] = "bob-only", "recovery returns the new complete preference root so outgoing writes cannot resurrect the old scope")
    check(registry.read("connKey_slot-a") = "default-key" and registry.read(userProfileKeyName("slot-a", b.id)) = "synthetic-new-own-key", "own recovered key never replaces the default credential")
    prefs = ParseJson(registry.read("settingsV1"))
    check(not prefs.accounts.doesExist(preferenceScope(planned.oldIdentity)) and prefs.accounts[preferenceScope(planned.newIdentity)].favoriteIds[0] = "bob-only" and prefs.accounts[preferenceScope(planned.newIdentity)].futureField.value = 9, "move preserves own settings, history and unknown fields rather than copying the default or dropping data")
    check(loadUserProfileStore(registry, "slot-a").active = a.id, "credential recovery never changes the active local profile")
    registry = ownSignInRegistry(entry, store)
    before = FormatJson(registry.values)
    registry.failOnce = true
    saved = commitUserProfileOwnSignIn(registry, entry, store, b.id, result, 100, nonce, nonce)
    check(not saved.ok and FormatJson(registry.values) = before, "failed recovery Flush restores old user ID, old preferences and every key")
    registry = ownSignInRegistry(entry, store)
    saved = commitUserProfileOwnSignIn(registry, entry, store, b.id, result, 100, nonce, "00000000-0000-4000-8000-000000000091")
    check(not saved.ok and registry.flushes = 0, "retired own-sign-in UI cannot commit a verified token")
    registry = ownSignInRegistry(entry, store)
    prefs = ParseJson(registry.read("settingsV1"))
    prefs.accounts[preferenceScope(planned.newIdentity)] = {favoriteIds: ["different-existing-data"]}
    registry.write("settingsV1", FormatJson(prefs))
    before = FormatJson(registry.values)
    saved = commitUserProfileOwnSignIn(registry, entry, store, b.id, result, 100, nonce, nonce)
    check(not saved.ok and saved.reason = "scope-conflict" and registry.flushes = 0 and FormatJson(registry.values) = before, "conflicting destination data is preserved rather than silently overwritten")
    registry = ownSignInRegistry(entry, store)
    registry.delete("settingsV1")
    saved = commitUserProfileOwnSignIn(registry, entry, store, b.id, result, 100, nonce, nonce)
    check(saved.ok and not registry.exists("settingsV1"), "key recovery never creates an empty canonical settings store over absent or unmigrated legacy data")
    future = copyJson(store)
    future.profiles[1] = setCanonicalPreference(future.profiles[1], "updatedAt", 200)
    check(not userProfileOwnSignInPlan(entry, future, b.id, result, 100).ok, "clock regression cannot stamp a recreated-user row older than its saved metadata")
    sessionEntry = setCanonicalPreference(entry, "remember", false)
    registry = ownSignInRegistry(sessionEntry, store)
    registry.delete("connKey_slot-a")
    saved = commitUserProfileOwnSignIn(registry, sessionEntry, store, b.id, result, 100, nonce, nonce)
    check(saved.ok and not registry.exists("connKey_slot-a") and not registry.exists(userProfileKeyName("slot-a", b.id)), "Remember-off recovery commits identity/data without persisting the recovered key")
    defaultStore = copyJson(store)
    anchored = copyJson(store)
    anchored.profiles[1] = setCanonicalPreference(anchored.profiles[1], "preferenceAnchor", "https://old.test|8|slot-a")
    registry = ownSignInRegistry(entry, anchored)
    prefs = ParseJson(registry.read("settingsV1"))
    oldScope = preferenceScope(connectionPreferenceIdentity(entry, "8"))
    prefs.accounts[preferenceScope("https://old.test|8|slot-a")] = prefs.accounts[oldScope]
    prefs.accounts.delete(oldScope)
    registry.values["settingsV1"] = FormatJson(prefs)
    saved = commitUserProfileOwnSignIn(registry, entry, anchored, b.id, result, 100, nonce, nonce)
    check(saved.ok and saved.oldIdentity = "https://old.test|8|slot-a" and saved.target["preferenceAnchor"] = connectionPreferenceIdentity(entry, "88") and saved.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(entry, "88"))].favoriteIds[0] = "bob-only", "own recovery moves its original-address data and anchor together even when both address and server ID changed")
    defaultStore.active = b.id
    defaultStore = setCanonicalPreference(defaultStore, "knownDefault", {userId: 7, username: "alice"})
    defaultResult = {ok: true, apiKey: "synthetic-recovered-default-key", verifiedUser: {id: 7, username: "ALICE", user_level: 1}}
    defaultPlan = userProfileOwnSignInPlan(entry, defaultStore, a.id, defaultResult, 100)
    check(defaultPlan.ok and defaultPlan.target.isDefault and defaultPlan.store.active = b.id, "an inactive full-access default can recover only its existing known holder without activating it")
    registry = ownSignInRegistry(entry, defaultStore)
    beforeSettings = registry.read("settingsV1")
    saved = commitUserProfileOwnSignIn(registry, entry, defaultStore, a.id, defaultResult, 100, nonce, nonce)
    check(saved.ok and registry.flushes = 1 and registry.read("connKey_slot-a") = "synthetic-recovered-default-key" and registry.read(userProfileKeyName("slot-a", b.id)) = "old-bob-key", "default recovery writes only its slot key and metadata in one transaction, never the outgoing own key")
    check(registry.read("settingsV1") = beforeSettings and loadUserProfileStore(registry, "slot-a").active = b.id, "same-identity default recovery cannot rewrite user blobs or change the active profile")
    check(not registry.exists(userProfileKeyName("slot-a", a.id)) and loadUserProfileStore(registry, "slot-a")["knownDefault"]["userId"] = 7, "default recovery retains frozen trust metadata and cannot create a non-default key for the default")
    legacyKnown = copyJson(defaultStore)
    legacyKnown.delete("knownDefault")
    registry = ownSignInRegistry(entry, legacyKnown)
    saved = commitUserProfileOwnSignIn(registry, entry, legacyKnown, a.id, defaultResult, 100, nonce, nonce)
    check(saved.ok and saved.store.doesExist("knownDefault") and saved.store["knownDefault"]["userId"] = 7, "successful inactive-default own verification records a missing known identity in the credential Flush")
    registry = ownSignInRegistry(entry, defaultStore)
    beforeDefault = FormatJson(registry.values)
    registry.failOnce = true
    saved = commitUserProfileOwnSignIn(registry, entry, defaultStore, a.id, defaultResult, 100, nonce, nonce)
    check(not saved.ok and FormatJson(registry.values) = beforeDefault, "failed default recovery restores its old key and exact trust metadata")
    check(not userProfileOwnSignInPlan(entry, store, a.id, defaultResult, 100).ok, "active-default recovery stays fenced until its lifecycle adoption is integrated")
    registry = ownSignInRegistry(sessionEntry, defaultStore)
    saved = commitUserProfileOwnSignIn(registry, sessionEntry, defaultStore, a.id, defaultResult, 100, nonce, nonce)
    check(saved.ok and not registry.exists("connKey_slot-a") and not registry.exists(userProfileKeyName("slot-a", a.id)), "Remember-off default recovery never stores its key in either slot or non-default namespaces")
    trustedDefault = setCanonicalPreference(defaultStore, "knownDefault", {userId: 70, username: "OtherAlice"})
    check(not userProfileOwnSignInPlan(entry, trustedDefault, a.id, defaultResult, 100).ok, "matching the old default row cannot override a different authoritative known-default record")
    childDefault = copyJson(defaultStore)
    childDefault.profiles[0] = setCanonicalPreference(childDefault.profiles[0], "role", "child")
    check(not userProfileOwnSignInPlan(entry, childDefault, a.id, defaultResult, 100).ok, "inactive Child default recovery remains fenced until Child routing is ready")
    legacyEntry = setCanonicalPreference(entry, "id", "legacy")
    legacyStore = copyJson(defaultStore)
    legacyStore.playlistId = "legacy"
    for i = 0 to legacyStore.profiles.count() - 1
        legacyStore.profiles[i] = setCanonicalPreference(legacyStore.profiles[i], "playlistId", "legacy")
    end for
    registry = ownSignInRegistry(legacyEntry, legacyStore)
    registry.values["apiKey"] = "legacy-fallback-key"
    saved = commitUserProfileOwnSignIn(registry, legacyEntry, legacyStore, a.id, defaultResult, 100, nonce, nonce)
    check(saved.ok and registry.read("connKey_legacy") = defaultResult.apiKey and not registry.exists("apiKey"), "legacy default recovery clears the old fallback in the same atomic transaction")
    print "ALL TESTS PASSED"
end sub

function ownSignInRegistry(entry as object, store as object) as object
    values = {}
    values["connectionsV1"] = FormatJson({schema: 1, selected: entry.id, entries: [entry]})
    values[userProfileStoreKey(entry.id)] = FormatJson(store)
    values["connKey_slot-a"] = "default-key"
    values[userProfileKeyName(entry.id, store.profiles[1].id)] = "old-bob-key"
    prefs = defaultPreferenceStore()
    prefs.accounts[preferenceScope(connectionPreferenceIdentity(entry, "8"))] = {favoriteIds: ["bob-only"], recent: ["bob-history"], futureField: {value: 9}}
    prefs.accounts[preferenceScope(connectionPreferenceIdentity(entry, "7"))] = {favoriteIds: ["default-only"]}
    values["settingsV1"] = FormatJson(prefs)
    return {values: values, flushes: 0, failOnce: false, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function, write: function(key as string, value as string) as boolean
        m.values[key] = value
        return true
    end function, delete: function(key as string) as boolean
        m.values.delete(key)
        return true
    end function, flush: function() as boolean
        m.flushes++
        if m.failOnce then m.failOnce = false : return false
        return true
    end function}
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
