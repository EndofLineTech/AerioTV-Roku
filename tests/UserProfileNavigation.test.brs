sub main()
    resetProfileNavigation()
    check(selectedUserProfileGate().allowed, "absent roster permits verified legacy migration")
    check(userProfileConnectionSetupAllowed(), "absent roster retains first-time setup")
    m.userProfileRecoveryRequired = true
    check(not selectedUserProfileGate().allowed, "failed rollback remains fenced until process recovery")
    m.userProfileRecoveryRequired = false
    m.registry.values["userProfilesV1_slot-a"] = ""
    check(not selectedUserProfileGate().allowed, "present empty roster fences connection before a request")
    before = m.registry.flushes
    check(not ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "corruption cannot be replaced with an unrestricted default after authentication")
    check(m.registry.flushes = before, "recovery refusal writes nothing")
    resetProfileNavigation()
    check(ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "verified default migration persists")
    check(m.userProfileStore.profiles[0].username = "Alice" and m.userProfileStore.profiles[0].updatedAt = 0, "migration uses verified identity and stays unstamped")
    check(userProfileConnectionSetupAllowed(), "Standard can configure its selected connection")
    m.global = {profilegateclosed: true}
    check(not userProfileConnectionSetupAllowed(), "closed profile gates refuse setup even for a saved Standard role")
    m.global = invalid
    childStore = copyJson(m.userProfileStore)
    childStore.profiles[0] = setCanonicalPreference(childStore.profiles[0], "role", "child")
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(childStore))
    check(not userProfileConnectionSetupAllowed(), "persisted Child cannot open general setup without an active authenticated scope")
    m.profileManagementGrant = {kind: "pin", purpose: "manage-profiles"}
    check(not userProfileConnectionSetupAllowed(), "adult management authority never grants Child general setup or receiver access")
    m.registry.write(userProfileStoreKey("slot-a"), "not-json")
    check(not userProfileConnectionSetupAllowed(), "corrupt persisted authority cannot become an unrestricted setup form")
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(m.userProfileStore))
    check(m.registry.read("connKey_slot-a") = "default-key", "migration cannot move the default key")
    check(ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000002", 101), "reconnect preserves default identity")
    check(m.userProfileStore.profiles[0].id = "00000000-0000-4000-8000-000000000001", "reconnect does not create another UUID")
    resetProfileNavigation()
    wrong = profileResult()
    wrong.verifiedUser.id = 8
    check(not ensureConnectedUserProfile(wrong, "00000000-0000-4000-8000-000000000001", 100) and m.registry.flushes = 0, "task identity mismatch cannot be committed")
    resetProfileNavigation()
    m.registry.failFlush = true
    check(not ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "failed migration does not authorize runtime")
    check(not m.registry.exists("userProfilesV1_slot-a"), "failed migration restores absence")
    resetProfileNavigation()
    m.connectionStore.entries[0].provider = "xtream"
    check(selectedUserProfileGate().allowed, "XC/M3U never acquire a profile gate")
    m.connectionStore = {}
    check(not userProfileConnectionSetupAllowed(), "malformed connection authority cannot grant setup access")
    print "ALL TESTS PASSED"
end sub

function profileResult() as object
    return {accountId: "7", accountUsername: "Alice", verifiedUser: {id: 7, username: "Alice", user_level: 1}}
end function

sub resetProfileNavigation()
    m.connectionStore = connectionStoreAdd(defaultConnectionStore(), "slot-a", "Synthetic")
    m.connectionStore = connectionStoreUpdate(m.connectionStore, "slot-a", {url: "https://example.test", accountId: "7"})
    m.selectedConnectionId = "slot-a"
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
    m.registry.values["connKey_slot-a"] = "default-key"
    m.userProfileStore = invalid
    m.userProfileRecoveryRequired = false
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
