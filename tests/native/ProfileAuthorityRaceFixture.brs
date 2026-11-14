' Private normal-app fixture. Server must change B authority on its THIRD me:
' target authentication, own roster verification, final pre-lineup verification.
sub onManagementProbeTick()
    if m.authorityRaceStarted <> true
        if m.busy or m.page <> "guide" or m.activeUserScope = invalid or m.capabilityTask <> invalid then return
        m.authorityRaceStarted = true
        m.authorityRaceOutgoing = m.activeUserScope
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        store = loadUserProfileStore(m.registry, "slot-a")
        target = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
        target = setCanonicalPreference(target, "isDefault", false)
        store.profiles.push(target)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.write(userProfileKeyName("slot-a", target.id), "synthetic-b")
        m.registry.flush()
        m.authorityRaceAdmitted = beginUserProfileSwitch(target.id)
        return
    end if
    if m.profileSwitchContext <> invalid then return
    store = loadUserProfileStore(m.registry, "slot-a")
    retained = m.activeUserScope <> invalid
    if retained then retained = m.activeUserScope.profileId = m.authorityRaceOutgoing.profileId and m.activeUserScope.sessionId <> m.authorityRaceOutgoing.sessionId and m.apiKey = "synthetic-a" and store.active = m.activeUserScope.profileId
    passed = m.authorityRaceAdmitted and retained and m.profilePinDialog = invalid and not m.profileGateCover.visible and not m.global.profilegateclosed and m.page = "guide" and m.playingChannel = invalid and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002")) = "synthetic-b"
    print "[profile-management] "; FormatJson({kind: "result", authority_race_refused: passed, passed: passed})
    m.managementProbeClock.control = "stop"
end sub
