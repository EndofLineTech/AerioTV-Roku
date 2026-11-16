sub seedProfilePickerLaunchProbe(base as string, mode as string)
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Synthetic7", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
    b = setCanonicalPreference(b, "isDefault", false)
    m.pickerProbeMode = mode
    if mode = "pin" or mode = "import-pin"
        a = setCanonicalPreference(a, "pinType", "numbers")
        a = setCanonicalPreference(a, "pinSalt", "0123456789abcdef0123456789abcdef")
        a = setCanonicalPreference(a, "pinHash", userProfilePinHash(a.pinSalt, "2468"))
        b = setCanonicalPreference(b, "pinType", "numbers")
        b = setCanonicalPreference(b, "pinSalt", "0123456789abcdef0123456789abcdef")
        b = setCanonicalPreference(b, "pinHash", userProfilePinHash(b.pinSalt, "1234"))
    end if
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    store = setCanonicalPreference(store, "askAtLaunch", true)
    store = setCanonicalPreference(store, "pendingRoster", true)
    connection = normalizeConnectionEntry({id: "slot-a", name: "Synthetic startup", provider: "dispatcharr", url: base, accountId: "7", remember: true})
    m.registry.write("connectionsV1", FormatJson({schema: 1, selected: "slot-a", entries: [connection]}))
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
    m.registry.write("connKey_slot-a", "synthetic-a")
    m.registry.write(userProfileKeyName("slot-a", b.id), "synthetic-b")
    settings = defaultPreferenceStore()
    settings.accounts[preferenceScope(connectionPreferenceIdentity(connection, "7"))] = normalizeAccountPreferences({favoriteIds: ["7"], profileSettings: {themePreset: "midnight"}, startupBehavior: "guide"})
    settings.accounts[preferenceScope(connectionPreferenceIdentity(connection, "8"))] = normalizeAccountPreferences({favoriteIds: ["8"], profileSettings: {themePreset: "forest"}, startupBehavior: "guide"})
    m.registry.write("settingsV1", FormatJson(settings))
    m.registry.flush()
    m.pickerProbeA = a.id
    m.pickerProbeB = b.id
    m.pickerProbeClock = m.top.createChild("Timer")
    m.pickerProbeClock.duration = 1
    m.pickerProbeClock.repeat = true
    m.pickerProbeClock.observeField("fire", "onProfilePickerLaunchProbeTick")
    m.pickerProbeClock.control = "start"
end sub

sub onProfilePickerLaunchProbeTick()
    if m.profilePicker <> invalid and m.pickerProbeReady <> true
        m.pickerProbeReady = true
        ready = m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.profileStartupTask = invalid and m.profilePicker.model.focus = 0
        print "[picker-launch] "; FormatJson({kind: "ready", ready: ready})
    end if
    if m.profilePinDialog <> invalid
        freshDialog = m.pickerProbeDialog = invalid
        if not freshDialog then freshDialog = not m.profilePinDialog.isSameNode(m.pickerProbeDialog)
        if freshDialog
            m.pickerProbeDialog = m.profilePinDialog
            if m.pickerProbePinNumber = invalid then m.pickerProbePinNumber = 0
            m.pickerProbePinNumber++
            ready = m.profilePinContext.continuation = "startup-selection" and m.profilePinContext.profile.id = m.pickerProbeB and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.profileStartupTask = invalid
            print "[picker-launch] "; FormatJson({kind: "pin-ready", ready: ready, number: m.pickerProbePinNumber})
            return
        end if
        if m.pickerProbeSubmit = true
            m.pickerProbeSubmit = false
            event = {node: m.profilePinDialog, getRoSGNode: function() as object
                return m.node
            end function, getData: function() as integer
                return 0
            end function}
            m.profilePinDialog.textEditBox.text = "9999"
            onProfilePinSubmit(event)
            wrongCovered = m.profilePinDialog <> invalid and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.profileStartupTask = invalid
            value = "1234"
            if m.pickerProbePinNumber = 2 then value = "5678"
            m.profilePinDialog.textEditBox.text = value
            onProfilePinSubmit(event)
            verified = m.profilePinDialog = invalid and m.profileStartupTask <> invalid and m.activeUserScope = invalid and m.apiKey = "" and m.startupDialogOpen
            print "[picker-launch] "; FormatJson({kind: "pin-submitted", number: m.pickerProbePinNumber, wrong_covered: wrongCovered, verified: verified})
        end if
        return
    end if
    if m.page <> "guide" or m.busy then return
    m.pickerProbeClock.control = "stop"
    store = loadUserProfileStore(m.registry, "slot-a")
    settings = loadStrictPreferenceStore(m.registry)
    passed = m.activeUserScope <> invalid and m.profilePicker = invalid and m.profileStartupSelectionContext = invalid and m.profileStartupTask = invalid and not m.global.profilegateclosed and not m.global.profileswitchpending and m.playingChannel = invalid
    if passed then passed = m.activeUserScope.profileId = m.pickerProbeB and m.activeUserScope.accountId = "8" and m.activeUserScope.sessionId = m.global.activeusersession and userProfileLocalId(m.activeUserScope.sessionId) <> ""
    passed = passed and store.active = m.pickerProbeB and store.pendingRoster and m.apiKey = "synthetic-b" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.pickerProbeB)) = "synthetic-b"
    passed = passed and m.accountPreferences.favoriteIds[0] = "8" and m.accountPreferences.profileSettings.themePreset = "forest" and m.guide.callFunc("profilePickerProbeLineup") = "8"
    source = preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "7"))
    passed = passed and settings.accounts[source].favoriteIds[0] = "7" and not m.registry.exists(userProfileSyncAckKey("slot-a")) and m.startupDialogOpen = false
    print "[picker-launch] "; FormatJson({kind: "result", passed: passed})
end sub
