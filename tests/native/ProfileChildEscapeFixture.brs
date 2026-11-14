' Private held-Child escape: no borrowed/fabricated outgoing authentication.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        store = loadUserProfileStore(m.registry, "slot-a")
        m.childEscapeId = store.active
        adult = store.profiles[0]
        adult = setCanonicalPreference(adult, "pinType", "numbers")
        adult = setCanonicalPreference(adult, "pinSalt", string(32, "b"))
        adult = setCanonicalPreference(adult, "pinHash", userProfilePinHash(adult.pinSalt, "1234"))
        store.profiles[0] = adult
        store.profiles[1] = setCanonicalPreference(store.profiles[1], "role", "child")
        store.profiles[1] = setCanonicalPreference(store.profiles[1], "addressHeld", true)
        store = setCanonicalPreference(store, "pendingRoster", true)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.flush()
        resetConnectionRuntime()
        applySelectedConnection()
        m.apiKey = ""
        protectedStore = loadUserProfileStore(m.registry, "slot-a")
        protectedStore.profiles[1] = setCanonicalPreference(protectedStore.profiles[1], "pinType", "numbers")
        protectedStore.profiles[1] = setCanonicalPreference(protectedStore.profiles[1], "pinSalt", string(32, "b"))
        protectedStore.profiles[1] = setCanonicalPreference(protectedStore.profiles[1], "pinHash", adult.pinHash)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(protectedStore))
        m.registry.flush()
        protectedHidden = not showUnavailableChildProfile() and m.childUnavailableDialog = invalid
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.flush()
        m.childEscapePassed = showUnavailableChildProfile()
        m.childEscapePassed = m.childEscapePassed and protectedHidden
        print "[profile-management] "; FormatJson({kind: "child-unavailable"})
        m.childEscapePassed = m.childEscapePassed and m.childUnavailableDialog.buttons.count() = 1 and m.childUnavailableDialog.buttons[0] = "Manage Profiles" and instr(1, m.childUnavailableDialog.message, "Synthetic7") = 0
        retiredDialog = m.childUnavailableDialog
        m.childEscapePassed = showUnavailableChildProfile() and m.childEscapePassed
        onUnavailableChildChoice(managementProbeEvent(retiredDialog, 0))
        m.childEscapePassed = m.childEscapePassed and m.adultPinDialog = invalid and m.profileManagementDialog = invalid
        m.childEscapePassed = m.childEscapePassed and not beginUserProfileSwitch(adult.id, true)
        onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, 0))
        m.childEscapePassed = m.childEscapePassed and m.adultPinDialog <> invalid and m.profileManagementDialog = invalid
        onAdultProfilePinClosed(managementProbeEvent(m.adultPinDialog, 0))
        m.childEscapePassed = m.childEscapePassed and m.childUnavailableDialog <> invalid and m.profileManagementGrant = invalid and m.global.profilegateclosed
        m.managementProbePhase = 1
    else if phase = 1
        m.childEscapePassed = prepareChildEscape("synthetic-a") and m.childEscapePassed
        onProfilePinClosed(managementProbeEvent(m.profilePinDialog, 0))
        m.childEscapePassed = m.childEscapePassed and childEscapeStillUnavailable()
        m.managementProbePhase = 2
    else if phase = 2
        m.childEscapePassed = prepareChildEscape("rejected-synthetic-key") and m.childEscapePassed
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        m.managementProbePhase = 3
    else if phase = 3
        if m.profileSwitchContext <> invalid then return
        m.childEscapePassed = m.childEscapePassed and childEscapeStillUnavailable()
        m.childEscapePassed = prepareChildEscape("delayed-a") and m.childEscapePassed
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        m.managementProbePhase = 4
    else if phase = 4
        if m.profileSwitchTask = invalid then return
        print "[profile-management] "; FormatJson({kind: "cancel-ready"})
        m.managementProbePhase = 5
    else if phase < 11
        m.managementProbePhase++
    else if phase = 11
        m.childEscapePassed = m.childEscapePassed and childEscapeStillUnavailable()
        m.childEscapePassed = prepareChildEscape("synthetic-a") and m.childEscapePassed
        connectionsBefore = m.registry.read("connectionsV1")
        changed = loadConnectionStore(m.registry)
        changed.entries[0] = setCanonicalPreference(changed.entries[0], "name", "Replaced connection lifecycle")
        m.registry.write("connectionsV1", FormatJson(changed))
        m.registry.flush()
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        m.childEscapePassed = m.childEscapePassed and childEscapeStillUnavailable() and m.profileSwitchTask = invalid
        m.registry.write("connectionsV1", connectionsBefore)
        m.registry.flush()
        m.childEscapePassed = showUnavailableChildProfile() and m.childEscapePassed
        m.childEscapePassed = prepareChildEscape("synthetic-a") and m.childEscapePassed
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        m.managementProbePhase = 12
    else
        if m.profileSwitchContext <> invalid or m.busy or m.capabilityTask <> invalid then return
        m.managementProbeClock.control = "stop"
        store = loadUserProfileStore(m.registry, "slot-a")
        own = m.page = "guide" and m.activeUserScope <> invalid
        if own then own = m.activeUserScope.accountId = "7" and store.active = store.profiles[0].id and currentUserSessionId() <> ""
        data = m.accountPreferences.favoriteIds.count() = 1 and m.devicePreferences.themePreset = "midnight"
        if data then data = m.accountPreferences.favoriteIds[0] = "00000000-0000-4000-8000-000000000007"
        preserved = store.pendingRoster and store.profiles[1].role = "child" and store.profiles[1].addressHeld and m.registry.read(userProfileKeyName("slot-a", m.childEscapeId)) = "synthetic-b"
        print "[profile-management] "; FormatJson({kind: "result", passed: m.childEscapePassed and own and data and preserved and m.playingChannel = invalid, own: own, data: data, preserved: preserved, no_autoplay: m.playingChannel = invalid})
    end if
end sub

function childEscapeStillUnavailable() as boolean
    store = loadUserProfileStore(m.registry, "slot-a")
    return store.active = m.childEscapeId and m.activeUserScope = invalid and m.apiKey = "" and currentUserSessionId() = "" and m.global.profilegateclosed and m.profileGateCover.visible and m.childUnavailableDialog <> invalid and m.page = "profile-unavailable" and m.top.exitRequested <> true
end function

function prepareChildEscape(key as string) as boolean
    m.registry.write("connKey_slot-a", key)
    m.registry.flush()
    onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, 0))
    if m.adultPinDialog = invalid then return false
    generic = m.adultPinDialog.title = "Enter a PIN from an Admin or Standard profile" and m.profileManagementDialog = invalid
    m.adultPinDialog.textEditBox.text = "1234"
    onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 0))
    if m.profileManagementDialog = invalid then return false
    onProfileManagementChoice(managementProbeEvent(m.profileManagementDialog, 0))
    if m.profileManagementDialog = invalid then return false
    if m.profileManagementChoices[0].action <> "switch-unavailable" then return false
    onProfileManagementChoice(managementProbeEvent(m.profileManagementDialog, 0))
    return generic and m.profilePinDialog <> invalid and m.activeUserScope = invalid and m.profileGateCover.visible
end function
