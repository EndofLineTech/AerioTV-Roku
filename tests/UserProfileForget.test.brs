sub main()
    ' Host interpreter lacks ParseJson(d); native builder removes this seam.
    m.profilePreferenceDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    for each failure in ["", "write", "flush", "rollback"]
        registry = forgetRegistry()
        before = normalizeConnectionStore(ParseJson(registry.read("connectionsV1")))
        snapshot = {}
        snapshot.append(registry.values)
        registry.failure = failure
        result = forgetUserProfileConnection(registry, before, "slot-a")
        if failure = ""
            check(result.ok and registry.flushes = 1, "Forget uses a single atomic Flush")
            check(not registry.exists("userProfilesV1_slot-a") and not registry.exists("connKey_slot-a") and not registry.exists(userProfileKeyPrefix("slot-a") + "orphan"), "Forget cleans a corrupt slot roster plus all owned keys")
            check(registry.read("connKey_slot-b") = "other-slot-key" and registry.read(userProfileKeyPrefix("slot-b") + "orphan") = "other-profile-key", "Forget cannot delete another slot's keys")
            check(not registry.exists(userProfileDeviceAdminKey("slot-a")) and not registry.exists(userProfilePinBackoffKey("slot-a", "device-admin")), "Forget clears its reserved Device Admin record and ledger atomically")
            check(registry.read(userProfileDeviceAdminKey("slot-b")) = "other-admin-record" and registry.read(userProfilePinBackoffKey("slot-b", "device-admin")) = "other-admin-ledger", "Forget preserves another slot's Device Admin authority")
            check(result.preferences.accounts.count() = 1 and result.preferences.accounts[preferenceScope("https://example.test|7|slot-b")].favoriteIds[0] = "other", "Forget cleans every own user scope, preserves other slot preferences")
            check(result.connections.entries.count() = 1 and result.connections.selected = "slot-b", "Forgotten connection removed without creating tombstones")
        else
            check(not result.ok and result.recoveryRequired = (failure = "rollback"), "Forget reports write/flush/recovery outcome")
            for each key in snapshot
                check(registry.read(key) = snapshot[key], "failed Forget restores exact previous values")
            end for
        end if
    end for
    registry = forgetRegistry()
    before = normalizeConnectionStore(ParseJson(registry.read("connectionsV1")))
    registry.values["settingsV1"] = "not-json"
    check(not forgetUserProfileConnection(registry, before, "slot-a").ok and registry.flushes = 0, "corrupt unrelated preferences cannot be silently replaced during Forget")
    print "ALL TESTS PASSED"
end sub

function forgetRegistry() as object
    connections = connectionStoreAdd(defaultConnectionStore(), "slot-a", "A")
    connections = connectionStoreUpdate(connections, "slot-a", {url: "https://example.test", accountId: "7"})
    connections = connectionStoreAdd(connections, "slot-b", "B")
    connections = connectionStoreUpdate(connections, "slot-b", {url: "https://example.test", accountId: "7"})
    preferences = defaultPreferenceStore()
    preferences.accounts[preferenceScope("https://example.test|7|slot-a")] = {favoriteIds: ["own-default"]}
    preferences.accounts[preferenceScope("https://old.example.test|99|slot-a")] = {favoriteIds: ["own-other-user"]}
    preferences.accounts[preferenceScope("https://example.test|7|slot-b")] = {favoriteIds: ["other"]}
    values = {}
    values["connectionsV1"] = FormatJson(connections)
    values["settingsV1"] = FormatJson(preferences)
    values["connKey_slot-a"] = "own-key"
    values["connKey_slot-b"] = "other-slot-key"
    values["userProfilesV1_slot-a"] = "corrupt-profile-json"
    values[userProfileKeyPrefix("slot-a") + "orphan"] = "own-profile-key"
    values[userProfileKeyPrefix("slot-b") + "orphan"] = "other-profile-key"
    values[userProfileDeviceAdminKey("slot-a")] = "own-admin-record"
    values[userProfileDeviceAdminKey("slot-b")] = "other-admin-record"
    values[userProfilePinBackoffKey("slot-a", "device-admin")] = "own-admin-ledger"
    values[userProfilePinBackoffKey("slot-b", "device-admin")] = "other-admin-ledger"
    return {values: values, flushes: 0, failure: ""
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        getKeyList: function() as object
            ' brs lowercases AA keys; the real registry preserves key spelling.
            result = []
            for each key in m.values.keys()
                if lcase(left(key, 8)) = "profkey_"
                    result.push("profKey_" + mid(key, 9))
                else if lcase(left(key, 8)) = "pinhold_"
                    result.push("pinHold_" + mid(key, 9))
                else
                    result.push(key)
                end if
            end for
            return result
        end function
        write: function(key as string, value as string) as boolean
            if m.failure = "write"
                m.failure = ""
                return false
            end if
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            if m.failure = "write"
                m.failure = ""
                return false
            end if
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            m.flushes++
            if m.failure = "rollback" then return false
            if m.failure = "flush"
                m.failure = ""
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
