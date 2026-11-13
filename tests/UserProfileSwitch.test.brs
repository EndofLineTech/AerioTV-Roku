sub main()
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    b.isDefault = false
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    connection = {id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true}
    verified = {ok: true, apiKey: "bob-own-key", verifiedUser: {id: 8, username: "bob", user_level: 1}, accountId: "8", accountUsername: "bob", channels: [], groups: [], generation: "generation-b"}
    session = "00000000-0000-4000-8000-000000000090"
    planned = userProfileSwitchPlan(connection, store, b.id, verified, invalid, invalid, invalid, session, session)
    check(planned.ok and planned.store.active = b.id and planned.scope.profileId = b.id and planned.scope.accountId = "8", "own verified lineup stages a target-bound immutable scope")
    check(store.active = a.id and connection.accountId = "7", "switch planning never adopts early or replaces default connection identity")
    wrong = copyJson(verified)
    wrong.verifiedUser.id = 7
    check(not userProfileSwitchPlan(connection, store, b.id, wrong, invalid, invalid, invalid, session, session).ok, "a default credential cannot authenticate a non-default target")
    wrong = copyJson(verified)
    wrong.verifiedUser.username = "another"
    check(not userProfileSwitchPlan(connection, store, b.id, wrong, invalid, invalid, invalid, session, session).ok, "matching user ID does not excuse a changed username")
    check(not userProfileSwitchPlan(connection, store, b.id, verified, invalid, invalid, invalid, session, "00000000-0000-4000-8000-000000000091").ok, "retired staging lifecycle cannot commit after same-slot A/B/A")
    store.profiles[1].addressHeld = true
    check(not userProfileSwitchPlan(connection, store, b.id, verified, invalid, invalid, invalid, session, session).ok, "a held target requires a separate verified address-recovery transaction")
    store.profiles[1].addressHeld = false
    store.profiles[1].pinType = "numbers"
    store.profiles[1].pinHash = string(64, "a")
    store.profiles[1].pinSalt = string(32, "b")
    check(not userProfileSwitchPlan(connection, store, b.id, verified, invalid, invalid, invalid, session, session).ok, "lineup staging cannot bypass target PIN protection")
    pin = {slot: "slot-a", id: b.id, pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    check(userProfileSwitchPlan(connection, store, b.id, verified, pin, invalid, invalid, session, session).ok, "verified target material permits target PIN boundary")
    store.profiles[0].role = "child"
    check(not userProfileSwitchPlan(connection, store, b.id, verified, pin, invalid, invalid, session, session).ok, "a Child cannot leave through an incoming target PIN alone")
    adult = {slot: "slot-a", active: a.id, nonce: session, purpose: "manage-profiles", kind: "pin", id: b.id, pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    check(userProfileSwitchPlan(connection, store, b.id, verified, pin, invalid, adult, session, session, session).ok, "current adult-purpose authority independently permits leaving Child")
    nextAttempt = "00000000-0000-4000-8000-000000000092"
    nextPlan = userProfileSwitchPlan(connection, store, b.id, verified, pin, invalid, adult, nextAttempt, nextAttempt, session)
    check(nextPlan.ok and nextPlan.scope.sessionId = nextAttempt, "fresh switching attempt is independent of an existing adult-management UI lifecycle")
    wrong = copyJson(verified)
    wrong.profileId = "default-filter"
    check(not userProfileSwitchPlan(connection, store, b.id, wrong, pin, invalid, adult, nextAttempt, nextAttempt, session).ok, "non-default lineup cannot inherit default Channel Profile filters")
    store.profiles[0].role = "user"
    registry = switchRegistryFixture(connection, store)
    outgoing = userProfileSessionScope(connection, a.id, 7, "outgoing-generation", "00000000-0000-4000-8000-000000000093")
    committed = commitUserProfileSwitch(registry, connection, store, b.id, verified, pin, invalid, "", nextAttempt, nextAttempt, outgoing, outgoing)
    check(committed.ok and committed.scope.sessionId = nextAttempt and loadUserProfileStore(registry, "slot-a").active = b.id, "switch commits target activation only with current outgoing and incoming lifecycles")
    check(registry.flushes = 1 and registry.read("connKey_slot-a") = "default-key" and registry.read(userProfileKeyName("slot-a", b.id)) = "bob-own-key", "target active/settings/own key share one Flush and preserve the default key")
    check(committed.preferences.favoriteIds.count() = 0 and committed.preferences.profileSettings.themePreset = "forest", "incoming preferences are its own scope, never outgoing favorites or appearance")
    registry = switchRegistryFixture(connection, store)
    before = FormatJson(registry.values)
    registry.failOnce = true
    committed = commitUserProfileSwitch(registry, connection, store, b.id, verified, pin, invalid, "", nextAttempt, nextAttempt, outgoing, outgoing)
    check(not committed.ok and FormatJson(registry.values) = before and loadUserProfileStore(registry, "slot-a").active = a.id, "failed switch Flush restores prior active profile, all settings and all keys without runtime adoption")
    registry = switchRegistryFixture(connection, store)
    otherSession = userProfileSessionScope(connection, a.id, 7, "outgoing-generation", "00000000-0000-4000-8000-000000000094")
    committed = commitUserProfileSwitch(registry, connection, store, b.id, verified, pin, invalid, "", nextAttempt, nextAttempt, outgoing, otherSession)
    check(not committed.ok and registry.flushes = 0, "old A callback cannot commit after B then new A even when user/profile IDs match")
    registry = switchRegistryFixture(connection, store)
    registry.write("settingsV1", "not-json")
    committed = commitUserProfileSwitch(registry, connection, store, b.id, verified, pin, invalid, "", nextAttempt, nextAttempt, outgoing, outgoing)
    check(not committed.ok and registry.flushes = 0 and registry.read("settingsV1") = "not-json", "corrupt present preferences cannot be replaced by empty incoming settings")
    learned = normalizeUserProfileStore(store, "slot-a")
    learned.profiles[1] = setCanonicalPreference(learned.profiles[1], "pinLength", 4)
    check(userProfileSwitchAcceptPinStore(store, learned, b.id, pin), "successful target verification may update only its locally learned PIN length before staging")
    learned.profiles[0] = setCanonicalPreference(learned.profiles[0], "displayName", "Changed while waiting")
    check(not userProfileSwitchAcceptPinStore(store, learned, b.id, pin), "PIN wait cannot authorize an unrelated roster change or stale switch snapshot")
    print "ALL TESTS PASSED"
end sub

function switchRegistryFixture(connection as object, store as object) as object
    values = {}
    values["connectionsV1"] = FormatJson({schema: 1, selected: "slot-a", entries: [normalizeConnectionEntry(connection)]})
    values[userProfileStoreKey("slot-a")] = FormatJson(store)
    values["connKey_slot-a"] = "default-key"
    prefs = defaultPreferenceStore()
    prefs.accounts[preferenceScope(connectionPreferenceIdentity(connection, "7"))] = normalizeAccountPreferences({favoriteIds: ["outgoing-only"], profileSettings: {themePreset: "midnight"}})
    prefs.accounts[preferenceScope(connectionPreferenceIdentity(connection, "8"))] = normalizeAccountPreferences({profileSettings: {themePreset: "forest"}})
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
