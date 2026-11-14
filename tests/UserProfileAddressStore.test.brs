sub main()
    entry = normalizeConnectionEntry({id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://old.test/base", accountId: "8", accountUsername: "Alice", remember: true})
    a = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    b = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 1)
    b.isDefault = false
    store = defaultUserProfileStore(entry.id)
    store.profiles = [a, b]
    store.active = b.id
    recorded = userProfileRecordDefaultIdentity(store, false)
    store = recorded.store
    scope = userProfileSessionScope(entry, b.id, "8", "generation-b", "00000000-0000-4000-8000-000000000090")
    connections = {schema: 1, selected: entry.id, entries: [entry]}
    originalStore = FormatJson(store)
    originalConnections = FormatJson(connections)
    registry = addressRegistry(connections, store, "")
    registry.values["preferences"] = "unmigrated-private-legacy"
    legacySnapshot = FormatJson(registry.values)
    check(not commitUserProfileAddressChange(registry, connections, store, "https://new.test", scope, scope).ok and FormatJson(registry.values) = legacySnapshot, "address edits cannot strand unmigrated unscoped legacy preferences or erase their ownership evidence")
    for each fault in ["", "write", "flush", "rollback"]
        registry = addressRegistry(connections, store, fault)
        before = FormatJson(registry.values)
        saved = commitUserProfileAddressChange(registry, connections, store, "https://new.test", scope, scope)
        if fault = ""
            check(saved.ok and registry.flushes = 1 and saved.changed, "URL, snapshot, all holds and key retirement share one successful Flush")
            actual = loadUserProfileStore(registry, entry.id)
            check(actual.active = a.id and actual.profiles[1].addressHeld and actual["addressChangeSnapshot"]["userId"] = 7, "origin change commits default selection and keyless-inclusive holds against the frozen default record")
            actualConnection = connectionStoreEntry(loadConnectionStore(registry), entry.id)
            check(actualConnection.url = "https://new.test" and not actualConnection.remember and actualConnection.accountId = "", "URL edits disable Remember and clear stale connection identity")
            check(not registry.exists("connKey_slot-a") and not registry.exists(userProfileKeyName(entry.id, b.id)), "no old saved slot or profile key survives an origin change")
            check(registry.read("settingsV1") = "opaque-settings-untouched" and registry.read("connKey_slot-b") = "foreign-key", "address storage does not move personal data, normalize settings or touch another slot")
        else
            check(not saved.ok and saved.recoveryRequired = (fault = "rollback"), "write and Flush failures refuse adoption and report failed rollback")
            check(FormatJson(registry.values) = before, "failed address transactions restore exact URL, keys, selection, snapshot and settings bytes")
        end if
        check(FormatJson(store) = originalStore and FormatJson(connections) = originalConnections, "address planning and failed transactions never mutate caller-owned connection or roster snapshots")
    end for
    registry = addressRegistry(connections, store, "")
    saved = commitUserProfileAddressChange(registry, connections, store, "HTTPS://OLD.test:443/other", scope, scope)
    check(saved.ok and not saved.changed and saved.store.active = b.id and not saved.store.profiles[1].addressHeld, "path/case/default-port edit deletes saved keys but neither holds nor switches profiles")
    check(not registry.exists("connKey_slot-a") and not registry.exists(userProfileKeyName(entry.id, b.id)), "Remember-off applies even when origin did not change")
    registry = addressRegistry(connections, store, "")
    before = FormatJson(registry.values)
    stale = setCanonicalPreference(scope, "sessionId", "00000000-0000-4000-8000-000000000091")
    check(not commitUserProfileAddressChange(registry, connections, store, "https://new.test", stale, scope).ok and registry.flushes = 0, "stale outgoing session cannot commit an address change")
    changed = connectionStoreRename(connections, entry.id, "Changed")
    registry.values["connectionsV1"] = FormatJson(changed)
    check(not commitUserProfileAddressChange(registry, connections, store, "https://new.test", scope, scope).ok and registry.flushes = 0, "changed persisted connection snapshot refuses before key deletion")
    registry = addressRegistry(connections, store, "")
    registry.values[userProfileStoreKey(entry.id)] = FormatJson(setCanonicalPreference(store, "askAtLaunch", true))
    check(not commitUserProfileAddressChange(registry, connections, store, "https://new.test", scope, scope).ok and registry.flushes = 0, "changed persisted roster refuses before URL or key writes")
    registry = addressRegistry(connections, store, "")
    registry.values.delete(userProfileKeyName(entry.id, b.id))
    saved = commitUserProfileAddressChange(registry, connections, store, "https://new.test", scope, scope)
    check(saved.ok and saved.store.profiles[1].addressHeld, "a keyless non-default profile receives a persistent hold in the URL transaction")
    childDefault = copyJson(store)
    childDefault.profiles[0] = setCanonicalPreference(childDefault.profiles[0], "role", "child")
    registry = addressRegistry(connections, childDefault, "")
    saved = commitUserProfileAddressChange(registry, connections, childDefault, "https://new.test", scope, scope)
    check(saved.ok and saved.childDefault and saved.store.active = a.id, "an adult's address edit identifies a Child-default destination for the controller rather than authorizing setup")
    malformed = copyJson(store)
    malformed.profiles[1] = setCanonicalPreference(malformed.profiles[1], "userId", {})
    registry = addressRegistry(connections, store, "")
    check(not commitUserProfileAddressChange(registry, connections, malformed, "https://new.test", scope, scope).ok and registry.flushes = 0, "malformed outgoing identity refuses safely before any URL or key write")
    childActive = copyJson(store)
    childActive.profiles[1] = setCanonicalPreference(childActive.profiles[1], "role", "child")
    registry = addressRegistry(connections, childActive, "")
    check(not commitUserProfileAddressChange(registry, connections, childActive, "https://new.test", scope, scope).ok and registry.flushes = 0, "active Child cannot use a matching authenticated scope to edit server addresses")
    legacyConnections = copyJson(connections)
    legacyConnections.entries[0] = setCanonicalPreference(entry, "id", "legacy")
    legacyConnections.selected = "legacy"
    legacyStore = copyJson(store)
    legacyStore.playlistId = "legacy"
    for i = 0 to legacyStore.profiles.count() - 1
        legacyStore.profiles[i] = setCanonicalPreference(legacyStore.profiles[i], "playlistId", "legacy")
    end for
    legacyScope = userProfileSessionScope(legacyConnections.entries[0], b.id, "8", "generation-b", scope.sessionId)
    registry = addressRegistry(legacyConnections, legacyStore, "")
    registry.values["apiKey"] = "legacy-default-key"
    registry.values["serverUrl"] = entry.url
    registry.values["accountIdentity"] = "old-scope"
    registry.values["rememberApiKey"] = "true"
    saved = commitUserProfileAddressChange(registry, legacyConnections, legacyStore, "https://new.test", legacyScope, legacyScope)
    check(saved.ok and registry.flushes = 1 and not registry.exists("apiKey") and registry.read("serverUrl") = "https://new.test" and not registry.exists("accountIdentity") and registry.read("rememberApiKey") = "false", "legacy URL/fallback recovery metadata shares the hold transaction instead of a later Flush")
    print "ALL TESTS PASSED"
end sub

function addressRegistry(connections as object, store as object, fault as string) as object
    values = {}
    values["connectionsV1"] = FormatJson(connections)
    values[userProfileStoreKey(store.playlistId)] = FormatJson(store)
    values[connectionRegistryKey(store.playlistId)] = "old-default-key"
    values[userProfileKeyName(store.playlistId, store.profiles[1].id)] = "old-own-key"
    values["settingsV1"] = "opaque-settings-untouched"
    values["connKey_slot-b"] = "foreign-key"
    return {values: values, fault: fault, failed: false, flushes: 0, read: function(key as string) as string
        if m.values.doesExist(key) then return m.values[key]
        return ""
    end function, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, write: function(key as string, value as string) as boolean
        m.values[key] = value
        if m.fault = "write" and not m.failed then m.failed = true : return false
        return true
    end function, delete: function(key as string) as boolean
        m.values.delete(key)
        return true
    end function, flush: function() as boolean
        m.flushes++
        if m.fault = "rollback" then return false
        if m.fault = "flush" and not m.failed then m.failed = true : return false
        return true
    end function}
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
