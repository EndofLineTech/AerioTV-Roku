sub main()
    ' Host interpreter lacks Roku OS 14.6 ParseJson flags; native probe removes this seam.
    m.profileOwnSignInSettingsDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
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
    registry = ownSignInRegistry(entry, store)
    nonce = "00000000-0000-4000-8000-000000000090"
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
