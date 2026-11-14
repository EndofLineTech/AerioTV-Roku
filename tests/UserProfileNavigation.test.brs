sub main()
    m.profilePreferenceDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    resetProfileNavigation()
    check(ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "legacy replacement fixture establishes old holder")
    m.registry.values["preferences"] = FormatJson({favoriteIds: ["old-private"]})
    m.registry.values["accountIdentity"] = "https://example.test|7"
    snapshot = FormatJson(m.registry.values)
    check(not ensureConnectedUserProfile({phase: "verified", accountId: "7", accountUsername: "DifferentAlice", verifiedUser: {id: 7, username: "DifferentAlice", user_level: 1}}, "", 101), "same-ID replacement refuses while unscoped legacy personal data has no safe migrated owner")
    check(FormatJson(m.registry.values) = snapshot, "legacy replacement refusal preserves all old private bytes and creates no empty canonical root")
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
    known = loadUserProfileStore(m.registry, "slot-a")
    check(known.doesExist("knownDefault") and known["knownDefault"]["userId"] = 7 and known["knownDefault"]["username"] = "Alice", "successful default verification records its own identity in the migration Flush")
    anchored = copyJson(known)
    anchored.profiles[0] = setCanonicalPreference(anchored.profiles[0], "preferenceAnchor", "https://old.test|7|slot-a")
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(anchored))
    preferences = {schema: 1, device: {}, accounts: {}}
    preferences.accounts[preferenceScope("https://old.test|7|slot-a")] = {favoriteIds: ["default-only"], futureField: {value: 9}}
    preferences.accounts["foreign"] = {favoriteIds: ["foreign-only"]}
    m.registry.write("settingsV1", FormatJson(preferences))
    beforeMigration = FormatJson(m.registry.values)
    m.registry.failFlush = true
    check(not ensureConnectedUserProfile(profileResult(), "", 100) and FormatJson(m.registry.values) = beforeMigration, "failed default data migration restores its old anchor, old blob and exact settings bytes")
    before = m.registry.flushes
    check(ensureConnectedUserProfile(profileResult(), "", 100), "verified same default migrates its anchored data to the current address")
    migrated = ParseJson(m.registry.read("settingsV1"))
    newKey = preferenceScope(connectionPreferenceIdentity(m.connectionStore.entries[0], "7"))
    check(m.registry.flushes = before + 1 and not migrated.accounts.doesExist(preferenceScope("https://old.test|7|slot-a")) and migrated.accounts[newKey].favoriteIds[0] = "default-only" and migrated.accounts.foreign.favoriteIds[0] = "foreign-only", "default anchor migration moves only its own blob in the same metadata Flush")
    check(userProfileConnectionSetupAllowed(), "Standard can configure its selected connection")
    m.profileOwnSignInContext = {nonce: "pending-own-sign-in"}
    check(not userProfileConnectionSetupAllowed(), "general setup cannot replace a pending own-profile credential form")
    m.profileOwnSignInContext = invalid
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
    frozen = setCanonicalPreference(m.userProfileStore, "knownDefault", {userId: 70, username: "FrozenDefault"})
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 8, username: "Bob", user_level: 1}, 1)
    b.isDefault = false
    b.addressHeld = true
    frozen.profiles.push(b)
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(frozen))
    check(ensureConnectedUserProfile(profileResult(), "", 102), "default verification may continue while another profile is held")
    known = loadUserProfileStore(m.registry, "slot-a")
    check(known["knownDefault"]["userId"] = 70 and known.profiles[1]["defaultIdentityTag"]["userId"] = 70, "ordinary default reconnect freezes the old identity and migrates legacy held tags from that record")
    frozen = setCanonicalPreference(frozen, "addressChangeSnapshot", {userId: 70, username: "FrozenDefault"})
    frozen.profiles.pop()
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(frozen))
    check(ensureConnectedUserProfile(profileResult(), "", 103), "default verification retains a pending address-change snapshot even when no non-default profile remains")
    check(loadUserProfileStore(m.registry, "slot-a")["knownDefault"]["userId"] = 70, "a default /me from the same pending address change cannot record the new user over its own comparison baseline")
    resetProfileNavigation()
    wrong = profileResult()
    wrong.verifiedUser.id = 8
    check(not ensureConnectedUserProfile(wrong, "00000000-0000-4000-8000-000000000001", 100) and m.registry.flushes = 0, "task identity mismatch cannot be committed")
    resetProfileNavigation()
    m.registry.failFlush = true
    check(not ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "failed migration does not authorize runtime")
    check(not m.registry.exists("userProfilesV1_slot-a"), "failed migration restores absence")
    for each failReplacement in [false, true]
        resetProfileNavigation()
        ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100)
        previousId = m.userProfileStore.active
        staged = copyJson(m.userProfileStore)
        staged.profiles[0] = setCanonicalPreference(staged.profiles[0], "preferenceAnchor", "https://old.test|7|slot-a")
        b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 8, username: "Bob", user_level: 1}, 1)
        b.isDefault = false
        b.addressHeld = true
        staged.profiles.push(b)
        staged = setCanonicalPreference(staged, "addressChangeSnapshot", {userId: 7, username: "Alice"})
        m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(staged)
        prefs = {schema: 1, device: {}, accounts: {}}
        oldKey = preferenceScope("https://old.test|7|slot-a")
        prefs.accounts[oldKey] = {startupBehavior: "mini", favoriteIds: ["alice-only"], recent: ["private-history"], futurePrivate: true, guide: {groupSort: "name", hiddenGroups: ["private-group"], startupGroup: "private-group"}, profileSettings: {themePreset: "forest"}}
        prefs.accounts["foreign"] = {favoriteIds: ["foreign-only"]}
        m.registry.values["settingsV1"] = FormatJson(prefs)
        memoryKey = preferenceScope(m.connectionStore.entries[0].url + "|slot-a|" + previousId)
        foreignMemory = preferenceScope("https://other.test|slot-b|" + previousId)
        m.profileSessionKeys = {}
        m.profileSessionKeys[memoryKey] = "synthetic-old-default"
        m.profileSessionKeys[foreignMemory] = "synthetic-foreign"
        snapshot = FormatJson(m.registry.values)
        m.registry.failFlush = failReplacement
        replaced = ensureConnectedUserProfile({phase: "verified", accountId: "70", accountUsername: "NewAlice", verifiedUser: {id: 70, username: "NewAlice", user_level: 1}}, "", 101)
        if failReplacement
            check(not replaced and FormatJson(m.registry.values) = snapshot, "failed default replacement restores the exact old identity, snapshot and private blobs")
            check(m.profileSessionKeys[memoryKey] = "synthetic-old-default", "failed default replacement retains the old holder's memory credential")
        else
            check(replaced and m.userProfileStore.active = previousId and m.userProfileStore.profiles[0].userId = 70 and m.userProfileStore["knownDefault"]["userId"] = 7 and m.userProfileStore.profiles[1].addressHeld, "verified slot replacement keeps local default identity and frozen holds while rebuilding server identity")
            loaded = ParseJson(m.registry.read("settingsV1"))
            newKey = preferenceScope(connectionPreferenceIdentity(m.connectionStore.entries[0], "70"))
            own = loaded.accounts[newKey]
            check(own.favoriteIds.count() = 0 and own.recent.count() = 0 and not own.doesExist("futurePrivate") and own.guide.hiddenGroups.count() = 0 and own.profileSettings.themePreset = "forest" and own.startupBehavior = "mini", "a rebuilt default gets only the approved Copy settings and no old holder personal or unknown data")
            check(loaded.accounts[oldKey].favoriteIds[0] = "alice-only" and loaded.accounts.foreign.favoriteIds[0] = "foreign-only", "replacement preserves old and foreign blobs instead of moving private data to the new holder")
            check(not m.registry.exists("connKey_slot-a") and not m.profileSessionKeys.doesExist(memoryKey) and m.profileSessionKeys[foreignMemory] = "synthetic-foreign", "rebuilt default cannot inherit the old default's stored or memory key while another slot's key remains untouched")
            lateSnapshot = FormatJson(m.registry.values)
            check(not ensureConnectedUserProfile({accountId: "71", accountUsername: "Unexpected", verifiedUser: {id: 71, username: "Unexpected", user_level: 1}}, "", 102) and FormatJson(m.registry.values) = lateSnapshot, "a late full-lineup /me identity change cannot skip the new holder's early roster and protection read")
        end if
    end for
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
