sub main()
    for each failFlush in [false, true]
        resetRemovalFixture()
        m.registry.failFlush = failFlush
        snapshot = {}
        snapshot.append(m.registry.values)
        result = removeUserProfile(m.registry, m.connection, m.store, m.other.id, 200, "normal")
        if failFlush
            check(not result.ok and not result.recoveryRequired, "failed removal rolls back without adopting scope")
            for each key in snapshot
                check(m.registry.read(key) = snapshot[key], "removal rollback preserves metadata, keys and all preference blobs")
            end for
        else
            check(result.ok and m.registry.flushes = 1, "metadata/key/preference removal is one transaction")
            check(result.store.profiles.count() = 1 and result.store.removed[0][0] = "bob", "removal retains default and own tombstone")
            check(not m.registry.exists(userProfileKeyName("slot-a", m.other.id)), "only removed profile's key is deleted")
            check(m.registry.read("connKey_slot-a") = "default-key" and m.registry.read(userProfileKeyName("slot-b", m.other.id)) = "other-slot-key", "removal preserves default and identical ID in other slot")
            check(result.preferences.accounts.count() = 2 and not result.preferences.accounts.doesExist(preferenceScope("https://example.test|2|slot-a")), "removal deletes only target user's preference scope")
        end if
    end for
    resetRemovalFixture()
    m.store.active = m.other.id
    result = removeUserProfile(m.registry, m.connection, m.store, m.other.id, 200, "pull")
    check(not result.ok and result.needsDefaultSwitch and m.registry.flushes = 0, "active profile cannot be removed before controller retires its session")
    print "ALL TESTS PASSED"
end sub

sub resetRemovalFixture()
    m.connection = normalizeConnectionEntry({id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://example.test", accountId: "1", remember: true})
    first = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 1, username: "Alice", user_level: 1}, 100)
    m.other = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 2, username: "Bob", user_level: 1}, 100)
    m.other.isDefault = false
    m.store = defaultUserProfileStore("slot-a")
    m.store.profiles = [first, m.other]
    m.store.active = first.id
    m.store = normalizeUserProfileStore(m.store, "slot-a")
    preferences = defaultPreferenceStore()
    for each identity in ["https://example.test|1|slot-a", "https://example.test|2|slot-a", "https://example.test|2|slot-b"]
        preferences.accounts[preferenceScope(identity)] = {favoriteIds: ["synthetic"]}
    end for
    m.registry = {values: {}, flushes: 0, failFlush: false
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            m.flushes++
            if m.failFlush
                m.failFlush = false
                return false
            end if
            return true
        end function
    }
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.store)
    m.registry.values[userProfileKeyName("slot-a", m.other.id)] = "own-key"
    m.registry.values[userProfileKeyName("slot-b", m.other.id)] = "other-slot-key"
    m.registry.values["connKey_slot-a"] = "default-key"
    m.registry.values["settingsV1"] = FormatJson(preferences)
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
