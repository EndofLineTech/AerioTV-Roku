' Private normal-app case: B is actually active; C's own read tombstones B.
' The real default A has a stored PIN, but this SYSTEM return must not prompt.
sub advanceProfileActiveRetirementProbe()
    if m.switchProbeActiveSeeded <> true
        m.switchProbeActiveSeeded = true
        m.switchProbeDefaultMode = ACTIVE_DEFAULT_MODE
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        store = loadUserProfileStore(m.registry, "slot-a")
        m.switchProbeRemovedId = store.active
        m.switchProbeRemovedSession = currentUserSessionId()
        for i = 0 to store.profiles.count() - 1
            profile = store.profiles[i]
            if profile.isDefault
                profile = setCanonicalPreference(profile, "pinType", "numbers")
                profile = setCanonicalPreference(profile, "pinSalt", string(32, "e"))
                profile = setCanonicalPreference(profile, "pinHash", userProfilePinHash(profile.pinSalt, "1234"))
                if m.switchProbeDefaultMode = "child" then profile = setCanonicalPreference(profile, "role", "child")
                store.profiles[i] = profile
            end if
        end for
        third = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 9, username: "Synthetic9", user_level: 1}, 1)
        third = setCanonicalPreference(third, "isDefault", false)
        store.profiles.push(third)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.write(userProfileKeyName("slot-a", third.id), "synthetic-c")
        m.registry.write(userProfilePinBackoffKey("slot-a", store.active), FormatJson({failures: 1, round: 0, until: 0}))
        m.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(entry, "9"))] = {favoriteIds: ["99"]}
        m.preferenceStore.accounts[preferenceScope("https://foreign.test|99|slot-b")] = {future: "retain"}
        m.registry.write("settingsV1", FormatJson(m.preferenceStore))
        if m.switchProbeDefaultMode = "missing" then m.registry.delete("connKey_slot-a")
        m.registry.flush()
        m.switchProbeExpectedPinLength = 0
        if m.switchProbeDefaultMode = "held"
            print "[profile-management] "; FormatJson({kind: "active-default-reject-ready"})
            return
        end if
    end if
    if m.switchProbeDefaultMode = "held" and m.switchProbeDefaultHoldAttempted <> true
        m.switchProbeDefaultHoldAttempted = true
        m.switchProbeDefaultHoldStarted = beginUserProfileSwitch(m.switchProbeDefault)
        if m.profilePinDialog <> invalid
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        end if
        return
    end if
    if m.switchProbeDefaultMode = "held" and m.switchProbeDefaultHoldVerified <> true
        if m.profileSwitchContext <> invalid then return
        m.switchProbeDefaultHoldVerified = m.switchProbeDefaultHoldStarted and m.activeUserScope <> invalid and m.activeUserScope.profileId = m.switchProbeRemovedId and m.registry.read("connKey_slot-a") = "synthetic-a"
        if not m.switchProbeDefaultHoldVerified
            m.managementProbeClock.control = "stop"
            print "[profile-management] "; FormatJson({kind: "result", active_retired: false, passed: false})
            return
        end if
        m.switchProbeExpectedPinLength = 4
    end if
    if m.switchProbeActiveStarted <> true
        m.switchProbeActiveStarted = true
        m.switchProbeActiveAdmitted = beginUserProfileSwitch("00000000-0000-4000-8000-000000000003")
        m.switchProbeActiveContext = m.profileSwitchContext
        return
    end if
    if m.profileSwitchContext <> invalid then return
    m.managementProbeClock.control = "stop"
    entry = connectionStoreEntry(m.connectionStore, "slot-a")
    store = loadUserProfileStore(m.registry, "slot-a")
    preferences = ParseJson(m.registry.read("settingsV1"), "d")
    own = m.activeUserScope <> invalid
    if own then own = store.active = m.switchProbeDefault and m.activeUserScope.profileId = m.switchProbeDefault and m.activeUserScope.accountId = "7" and currentUserSessionId() <> m.switchProbeRemovedSession and currentUserSessionId() <> m.switchProbeFirstSession and m.apiKey = "synthetic-a" and m.guide.callFunc("profileSwitchProbeLineup") = "7" and m.banner.session.apiKey = "synthetic-a" and m.accountPreferences.favoriteIds[0] = "7"
    removedAccount = preferenceScope(connectionPreferenceIdentity(entry, "8"))
    foreignAccount = preferenceScope("https://foreign.test|99|slot-b")
    removedBucket = preferenceScope(entry.url + "|slot-a|" + m.switchProbeRemovedId)
    cleaned = store.profiles.count() = 2 and store.removed.count() = 0 and not m.registry.exists(userProfileKeyName("slot-a", m.switchProbeRemovedId)) and not m.registry.exists(userProfilePinBackoffKey("slot-a", m.switchProbeRemovedId)) and not preferences.accounts.doesExist(removedAccount) and not m.preferenceStore.accounts.doesExist(removedAccount) and not m.profileSessionKeys.doesExist(removedBucket) and preferences.accounts[foreignAccount].future = "retain"
    defaultPin = false
    for each profile in store.profiles
        if profile.isDefault then defaultPin = profile.pinType = "numbers" and profile.pinHash = userProfilePinHash(profile.pinSalt, "1234") and profile.pinLength = m.switchProbeExpectedPinLength
    end for
    wiped = m.switchProbeActiveContext.key = "" and m.switchProbeActiveContext.authentication.apiKey = ""
    keyPreserved = m.registry.read("connKey_slot-a") = "synthetic-a"
    if m.switchProbeDefaultMode = "missing" then keyPreserved = not m.registry.exists("connKey_slot-a")
    surface = own and not m.global.profilegateclosed and not m.profileGateCover.visible
    if m.switchProbeDefaultMode <> "usable" then surface = store.active = m.switchProbeDefault and m.activeUserScope = invalid and m.apiKey = "" and m.global.activeusersession = "" and m.global.profilegateclosed and m.profileGateCover.visible
    passed = m.switchProbeB and m.switchProbeActiveAdmitted and surface and cleaned and defaultPin and wiped and keyPreserved and m.profilePinDialog = invalid and m.playingChannel = invalid and m.registry.read(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000003")) = "synthetic-c"
    print "[profile-management] "; FormatJson({kind: "result", active_retired: passed, passed: passed})
end sub
