sub main()
    ' Host interpreter lacks ParseJson(d); native builder removes this seam.
    m.profilePreferenceDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    connection = normalizeConnectionEntry({id: "slot-a", name: "A", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true})
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    b.isDefault = false
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    store = normalizeUserProfileStore(store, "slot-a")
    scope = userProfileSessionScope(connection, a.id, "7", "generation", "00000000-0000-4000-8000-000000000090")
    data = dispatcharrSyncRosterDecode({rows: [], removed: [["bob", 200]]})
    for each fault in ["", "write", "flush", "rollback"]
        registry = syncPullRegistry(connection, store, fault)
        before = FormatJson(registry.values)
        result = commitDispatcharrRosterPull(registry, connection, store, data, true, 300, scope, scope)
        if fault = ""
            check(result.ok and registry.flushes = 1 and result.store.profiles.count() = 1, "one atomic Flush commits tombstone cleanup and roster")
            check(not registry.exists(userProfileKeyName("slot-a", b.id)) and registry.read("connKey_slot-a") = "default-key", "pull removes only nondefault own key")
            check(not registry.exists(userProfilePinBackoffKey("slot-a", b.id)), "removed profile holder backoff is cleaned in the same transaction")
            check(result.preferences.accounts.count() = 2 and result.preferences.accounts.doesExist(preferenceScope(scope.preferenceIdentity)), "removed user blob cleaned while default/other-slot remain")
            check(result.store.removed.count() = 0, "remote tombstone cleanup creates no local tombstone")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(registry.values) = before, "atomic pull fault restores roster keys and user data together")
        end if
    end for
    registry = syncPullRegistry(connection, store, "")
    newer = setCanonicalPreference(scope, "sessionId", "00000000-0000-4000-8000-000000000091")
    check(not commitDispatcharrRosterPull(registry, connection, store, data, true, 300, scope, newer).ok and registry.flushes = 0, "old pull cannot write after A/B/A session retirement")
    store.active = b.id
    registry = syncPullRegistry(connection, store, "")
    bscope = userProfileSessionScope(connection, b.id, "8", "generation", "00000000-0000-4000-8000-000000000092")
    result = commitDispatcharrRosterPull(registry, connection, store, data, true, 300, bscope, bscope)
    check(not result.ok and result.needsDefaultSwitch and registry.flushes = 0, "active tombstone cannot delete running credential without authenticated default switch")
    print "ALL TESTS PASSED"
end sub

function syncPullRegistry(connection as object, store as object, fault as string) as object
    values = {}
    values[userProfileStoreKey(store.playlistId)] = FormatJson(store)
    values["connKey_slot-a"] = "default-key"
    values[userProfileKeyName("slot-a", store.profiles[1].id)] = "bob-key"
    values[userProfilePinBackoffKey("slot-a", store.profiles[1].id)] = "{""failures"":0,""round"":1,""until"":200}"
    preferences = defaultPreferenceStore()
    for each identity in ["https://example.test|7|slot-a", "https://example.test|8|slot-a", "https://example.test|8|slot-b"]
        preferences.accounts[preferenceScope(identity)] = normalizeAccountPreferences({favoriteIds: ["private"]})
    end for
    values["settingsV1"] = FormatJson(preferences)
    return {values: values, fault: fault, flushes: 0
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            m.values[key] = value
            if m.fault = "write"
                m.fault = ""
                return false
            end if
            return true
        end function
        delete: function(key as string) as boolean
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            m.flushes++
            if m.fault = "rollback" then return false
            if m.fault = "flush"
                m.fault = ""
                return false
            end if
            return true
        end function
    }
end function

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
