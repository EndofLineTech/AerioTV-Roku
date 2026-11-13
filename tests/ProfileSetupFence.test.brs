sub main()
    m.connectionStore = connectionStoreAdd(defaultConnectionStore(), "slot-a", "Synthetic")
    m.selectedConnectionId = "slot-a"
    profile = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Child", user_level: 1}, 1)
    profile.role = "child"
    store = defaultUserProfileStore("slot-a")
    store.profiles = [profile]
    store.active = profile.id
    m.registry = {data: FormatJson(store), writes: 0, exists: function(key as string) as boolean
        return key = "userProfilesV1_slot-a"
    end function, read: function(key as string) as string
        return m.data
    end function}
    before = FormatJson(m.connectionStore)
    openConnectionPicker()
    openConnectionManager()
    openConnectionAdvanced()
    openConnectionAuthModes()
    openConnectionAgentEditor()
    openConnectionRefererEditor()
    onConnectionRefererSaved({})
    onConnectionAgentSaved({})
    openConnectionDialog("forged", "forged", [])
    onConnectionChoice({})
    openConnectionRename()
    onConnectionRenamed({})
    openRemoveConnectionConfirmation()
    openPermittedProfiles()
    selectPermittedProfile({id: "forged"})
    updateConnectionGuideUrl("https://forged.test")
    changeConnectionRemember(false)
    updateConnectionUrl("https://forged.test")
    saveConnectionRequestChoice({authMode: "bearer"}, "forged")
    switchSavedConnection("slot-b")
    addSavedConnection()
    removeSelectedConnection()
    openPhoneSetup()
    acceptPhoneSetupPayload({})
    startPhoneVerification()
    showPhoneSetupConfirmation()
    onPhoneSetupChoice({})
    commitPhoneSetup("add")
    check(FormatJson(m.connectionStore) = before and m.selectedConnectionId = "slot-a" and m.page = invalid, "forged Child setup/receiver calls return before forms, requests, runtime retirement or connection mutations")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
