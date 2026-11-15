sub runProfileRetirementColdProbe()
    store = loadUserProfileStore(m.registry, "slot-a")
    if m.retirementColdPinReady <> true
        retiredId = "00000000-0000-4000-8000-000000000002"
        ready = store.readOnly <> true and store.profiles.count() = 2 and not m.registry.exists(userProfileRetirementKey("slot-a")) and not m.registry.exists(userProfileKeyName("slot-a", retiredId)) and not m.registry.exists(userProfilePinBackoffKey("slot-a", retiredId)) and m.activeUserScope = invalid and m.profilePinDialog <> invalid and m.global.profilegateclosed
        for each profile in store.profiles
            if profile.isDefault then ready = ready and profile.pinHash = userProfilePinHash(profile.pinSalt, "5678") and profile.displayName = "Protected default"
        end for
        if not ready
            m.managementProbeClock.control = "stop"
            print "[profile-management] "; FormatJson({kind: "result", active_retired: false, cold_recovered: false})
            return
        end if
        m.retirementColdPinReady = true
        print "[profile-management] "; FormatJson({kind: "retirement-cold-pin-ready", ready: ready})
        return
    end if
    if m.retirementColdOldRefused <> true
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        m.retirementColdOldRefused = m.profilePinDialog <> invalid and m.activeUserScope = invalid and m.global.profilegateclosed
        print "[profile-management] "; FormatJson({kind: "retirement-cold-old-pin-refused", refused: m.retirementColdOldRefused})
        return
    end if
    if m.retirementColdPinSubmitted <> true
        m.retirementColdPinSubmitted = true
        m.profilePinDialog.textEditBox.text = "5678"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        return
    end if
    if m.busy or m.activeUserScope = invalid or m.page <> "guide" then return
    m.managementProbeClock.control = "stop"
    entry = connectionStoreEntry(m.connectionStore, "slot-a")
    preferences = ParseJson(m.registry.read("settingsV1"), "d")
    own = m.activeUserScope.accountId = "7" and m.activeUserScope.profileId = store.active and m.activeUserScope.sessionId <> m.retirementColdIntentId and m.apiKey = "synthetic-a" and m.guide.callFunc("profileSwitchProbeLineup") = "7" and m.banner.session.apiKey = "synthetic-a" and m.accountPreferences.favoriteIds[0] = "7"
    cleaned = not preferences.accounts.doesExist(preferenceScope(connectionPreferenceIdentity(entry, "8"))) and not m.preferenceStore.accounts.doesExist(preferenceScope(connectionPreferenceIdentity(entry, "8"))) and preferences.accounts[preferenceScope("https://foreign.test|99|slot-b")].future = "retain"
    pin = false
    for each profile in store.profiles
        if profile.isDefault then pin = profile.pinType = "numbers" and profile.pinLength = 4 and profile.pinHash = userProfilePinHash(profile.pinSalt, "5678") and m.retirementColdOldRefused = true
    end for
    passed = own and cleaned and pin and m.profilePinDialog = invalid and not m.global.profilegateclosed and not m.profileGateCover.visible and m.playingChannel = invalid and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000003")) = "synthetic-c"
    print "[profile-management] "; FormatJson({kind: "result", active_retired: passed, cold_recovered: passed})
end sub
