sub seedProfilePickerLaunchProbe(base as string, mode as string)
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Synthetic7", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
    b = setCanonicalPreference(b, "isDefault", false)
    m.pickerProbeMode = mode
    m.pickerProbePickerCount = 0
    m.pickerProbeChildTarget = left(mode, 6) = "child-"
    if m.pickerProbeChildTarget
        b = setCanonicalPreference(b, "role", "child")
        a = setCanonicalPreference(a, "pinType", "numbers")
        a = setCanonicalPreference(a, "pinSalt", "0123456789abcdef0123456789abcdef")
        a = setCanonicalPreference(a, "pinHash", userProfilePinHash(a.pinSalt, "2468"))
        if mode = "child-select-pin"
            b = setCanonicalPreference(b, "pinType", "numbers")
            b = setCanonicalPreference(b, "pinSalt", "0123456789abcdef0123456789abcdef")
            b = setCanonicalPreference(b, "pinHash", userProfilePinHash(b.pinSalt, "1234"))
        end if
    end if
    m.pickerProbeDefaultOwn = mode = "own-default" or mode = "own-default-pin"
    if mode = "own-default-pin"
        a = setCanonicalPreference(a, "pinType", "numbers")
        a = setCanonicalPreference(a, "pinSalt", "0123456789abcdef0123456789abcdef")
        a = setCanonicalPreference(a, "pinHash", userProfilePinHash(a.pinSalt, "2468"))
    end if
    if mode = "own-pin" or mode = "own-pin-link"
        b = setCanonicalPreference(b, "pinType", "numbers")
        b = setCanonicalPreference(b, "pinSalt", "0123456789abcdef0123456789abcdef")
        b = setCanonicalPreference(b, "pinHash", userProfilePinHash(b.pinSalt, "1234"))
    end if
    if mode = "own-held" then b = setCanonicalPreference(b, "addressHeld", true)
    if mode = "pin" or mode = "import-pin" or mode = "cold-link" or mode = "warm-link" or mode = "warm-pin-link" or mode = "warm-auth-link" or mode = "warm-import-pin-link" or mode = "warm-load-link" or mode = "own-link" or mode = "own-pin-link" or mode = "own-auth-link"
        a = setCanonicalPreference(a, "pinType", "numbers")
        a = setCanonicalPreference(a, "pinSalt", "0123456789abcdef0123456789abcdef")
        a = setCanonicalPreference(a, "pinHash", userProfilePinHash(a.pinSalt, "2468"))
        if mode = "pin" or mode = "import-pin" or mode = "warm-pin-link" or mode = "warm-import-pin-link"
            b = setCanonicalPreference(b, "pinType", "numbers")
            b = setCanonicalPreference(b, "pinSalt", "0123456789abcdef0123456789abcdef")
            b = setCanonicalPreference(b, "pinHash", userProfilePinHash(b.pinSalt, "1234"))
        end if
    end if
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    if mode = "baseline"
        store.profiles = [a]
        store = setCanonicalPreference(store, "askAtLaunch", false)
    end if
    ' Exercise the production default, rather than forcing Ask on in the probe.
    store = setCanonicalPreference(store, "pendingRoster", true)
    connection = normalizeConnectionEntry({id: "slot-a", name: "Synthetic startup", provider: "dispatcharr", url: base, accountId: "7", remember: true})
    if mode = "own-memory" then connection = setCanonicalPreference(connection, "remember", false)
    m.registry.write("connectionsV1", FormatJson({schema: 1, selected: "slot-a", entries: [connection]}))
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
    if not m.pickerProbeDefaultOwn and mode <> "own-memory" then m.registry.write("connKey_slot-a", "synthetic-a")
    if mode <> "baseline" and (left(mode, 4) <> "own-" or mode = "own-held" or m.pickerProbeDefaultOwn) then m.registry.write(userProfileKeyName("slot-a", b.id), "synthetic-b")
    settings = defaultPreferenceStore()
    settings.accounts[preferenceScope(connectionPreferenceIdentity(connection, "7"))] = normalizeAccountPreferences({favoriteIds: ["7"], profileSettings: {themePreset: "midnight"}, startupBehavior: "guide"})
    settings.accounts[preferenceScope(connectionPreferenceIdentity(connection, "8"))] = normalizeAccountPreferences({favoriteIds: ["8"], profileSettings: {themePreset: "forest"}, startupBehavior: "guide"})
    if mode = "baseline" then settings.accounts.delete(preferenceScope(connectionPreferenceIdentity(connection, "8")))
    m.registry.write("settingsV1", FormatJson(settings))
    m.registry.flush()
    m.pickerProbeA = a.id
    m.pickerProbeB = b.id
    m.pickerProbeTargetId = b.id
    if m.pickerProbeDefaultOwn then m.pickerProbeTargetId = a.id
    m.pickerProbeClock = m.top.createChild("Timer")
    m.pickerProbeClock.duration = 1
    m.pickerProbeClock.repeat = true
    m.pickerProbeClock.observeField("fire", "onProfilePickerLaunchProbeTick")
    m.pickerProbeClock.control = "start"
end sub

function baselineProbeEvent(node as object, choice as integer) as object
    return {node: node, choice: choice, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return m.choice
    end function}
end function

sub openBaselineProbeSwitcher()
    navigation = m.guide.findNode("primaryNavigation")
    navigation.selected = "profiles"
    navigation.active = true
    navigation.callFunc("handleNavigationKey", "OK", true)
    navigation.selected = "live"
end sub

sub onProfileBaselineProbeTick()
    if m.pickerProbeBaselineStage = invalid then m.pickerProbeBaselineStage = 0
    stage = m.pickerProbeBaselineStage
    if m.pickerProbeBaselineTicks = invalid then m.pickerProbeBaselineTicks = 0
    m.pickerProbeBaselineTicks++
    if m.pickerProbeBaselineTicks mod 5 = 1
        taskState = ""
        if m.task <> invalid then taskState = m.task.state
        print "[picker-launch] "; FormatJson({kind: "baseline-state", stage: stage, page: m.page, busy: m.busy, gate: m.global.profilegateclosed, ownPending: m.global.profileownsigninpending, sourceTask: taskState, picker: m.profilePicker <> invalid, ownForm: m.profileOwnSignInDialog <> invalid, baselineMenu: m.profileBaselineMenu <> invalid})
        if m.page = "setup" and not m.busy
            print "[picker-launch] "; FormatJson({kind: "baseline-source-failure", message: m.status})
            m.pickerProbeClock.control = "stop"
            print "[picker-launch] "; FormatJson({kind: "result", passed: false, baseline: true})
        end if
    end if
    if stage = 0
        if m.page <> "guide" or m.busy or m.activeUserScope = invalid then return
        m.pickerProbeBaselineSettings = m.registry.read("settingsV1")
        openSettingsHub()
        m.settingsHub.callFunc("selectSettingsCategory", 0)
        m.settingsHub.callFunc("selectSetting", 1)
        m.settingsHub.callFunc("selectSetting", 1)
        m.pickerProbeBaselineStage = 1
        return
    end if
    if stage = 1
        if m.profileOwnSignInContext = invalid or m.profileOwnSignInDialog = invalid then return
        m.profileOwnSignInContext.username = "Synthetic8"
        m.profileOwnSignInContext.password = "synthetic-password"
        m.pickerProbeBaselineStage = 2
        onProfileOwnSignInChoice(baselineProbeEvent(m.profileOwnSignInDialog, 2))
        return
    end if
    if stage = 2
        if m.profileOwnSignInContext <> invalid then return
        store = loadUserProfileStore(m.registry, "slot-a")
        if store.profiles.count() <> 2 then return
        for each profile in store.profiles
            if profile.userId = 8
                m.pickerProbeAdded = profile.id
                m.pickerProbeAddedUsername = lcase(profile.username)
            end if
        end for
        valid = store.active = m.pickerProbeA and store.pendingRoster and m.registry.read("connKey_slot-a") = "synthetic-a"
        valid = valid and m.registry.read(userProfileKeyName("slot-a", m.pickerProbeAdded)) = "synthetic-b" and m.registry.read("settingsV1") = m.pickerProbeBaselineSettings
        m.pickerProbeBaselineValid = valid
        m.pickerProbeBaselineAddValid = valid
        candidate = copyJson(store)
        for i = 0 to candidate.profiles.count() - 1
            if candidate.profiles[i].id = m.pickerProbeAdded then candidate.profiles[i] = setCanonicalPreference(candidate.profiles[i], "avatar", {icon: "rocket", color: "purple"})
        end for
        if not commitUserProfileStore(m.registry, store, candidate, {}, true).ok then return
        m.userProfileStore = candidate
        closeProfileBaselineMenu()
        closeSettingsHub()
        openBaselineProbeSwitcher()
        m.pickerProbeBaselineStage = 20
        return
    end if
    if stage = 20
        if m.profileSwitcher = invalid then return
        m.pickerProbeBaselineSwitcherValid = m.activeUserScope.profileId = m.pickerProbeA and m.apiKey = "synthetic-a" and m.global.activeusersession = m.activeUserScope.sessionId
        model = m.profileSwitcher.model
        for i = 0 to model.tiles.count() - 1
            if model.tiles[i].id = m.pickerProbeAdded
                m.profileSwitcher.intent = {action: "switch", index: i, uiNonce: model.uiNonce}
            end if
        end for
        m.pickerProbeBaselineStage = 3
        return
    end if
    if stage = 3
        if m.busy or m.profileSwitchContext <> invalid or m.activeUserScope = invalid then return
        if m.activeUserScope.accountId <> "8" then return
        m.pickerProbeBaselineSwitchValid = m.apiKey = "synthetic-b" and m.userProfileStore.pendingRoster and m.accountPreferences.favoriteIds.count() = 0
        m.pickerProbeBaselineSwitchValid = m.pickerProbeBaselineSwitchValid and m.guide.profileSwitcher.avatarUri = "pkg:/images/profile-avatar-rocket.png"
        m.pickerProbeBaselineValid = m.pickerProbeBaselineValid and m.pickerProbeBaselineSwitchValid
        openBaselineProbeSwitcher()
        m.pickerProbeBaselineStage = 30
        return
    end if
    if stage = 30
        if m.profileSwitcher = invalid then return
        model = m.profileSwitcher.model
        m.pickerProbeLiveMoveIndex = model.focus
        m.profileSwitcher.intent = {action: "reorder", index: model.focus, uiNonce: model.uiNonce}
        m.pickerProbeBaselineStage = 31
        return
    end if
    if stage = 31
        if m.profileSwitcherMoveTarget <> m.pickerProbeAdded then return
        model = m.profileSwitcher.model
        m.profileSwitcher.intent = {action: "reorder-release", index: m.pickerProbeLiveMoveIndex, uiNonce: model.uiNonce}
        m.pickerProbeBaselineStage = 32
        return
    end if
    if stage = 32
        if m.profileSwitcherMoveDialog = invalid then return
        onUserProfileSwitcherMove(baselineProbeEvent(m.profileSwitcherMoveDialog, 0))
        m.pickerProbeBaselineStage = 33
        return
    end if
    if stage = 33
        if m.profileSwitcher = invalid then return
        model = m.profileSwitcher.model
        if model.tiles[0].id <> m.pickerProbeAdded or model.focus <> 0 then return
        m.profileSwitcher.intent = {action: "close", index: 0, uiNonce: model.uiNonce}
        m.pickerProbeBaselineStage = 34
        return
    end if
    if stage = 34
        if m.profileSwitcher <> invalid then return
        store = loadUserProfileStore(m.registry, "slot-a")
        candidate = copyJson(store)
        for i = 0 to candidate.profiles.count() - 1
            if candidate.profiles[i].id = m.pickerProbeAdded
                target = candidate.profiles[i]
                target = setCanonicalPreference(target, "pinType", "numbers")
                target = setCanonicalPreference(target, "pinSalt", "00112233445566778899aabbccddeeff")
                target = setCanonicalPreference(target, "pinHash", userProfilePinHash(target.pinSalt, "1234"))
                target = setCanonicalPreference(target, "pinLength", 4)
                candidate.profiles[i] = target
            end if
        end for
        if not commitUserProfileStore(m.registry, store, candidate, {}, true).ok then return
        m.userProfileStore = candidate
        openUserProfileManagement()
        if m.profileManagementDialog = invalid then return
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, 0))
        m.pickerProbeBaselineStage = 35
        return
    end if
    if stage = 35
        pinIndex = -1
        for i = 0 to m.profileManagementChoices.count() - 1
            if m.profileManagementChoices[i].action = "pin-remove" then pinIndex = i
        end for
        if pinIndex < 0 then return
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, pinIndex))
        m.pickerProbeBaselineStage = 36
        return
    end if
    if stage = 36
        if m.profilePinDialog = invalid then return
        onProfilePinSubmit(baselineProbeEvent(m.profilePinDialog, 1))
        m.pickerProbePinCancelValid = m.profilePinDialog = invalid and m.profileManagementPinContext = invalid and not m.global.profilegateclosed
        m.pickerProbeBaselineStage = 37
        return
    end if
    if stage = 37
        pinIndex = -1
        for i = 0 to m.profileManagementChoices.count() - 1
            if m.profileManagementChoices[i].action = "pin-remove" then pinIndex = i
        end for
        if pinIndex < 0 then return
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, pinIndex))
        m.pickerProbeBaselineStage = 38
        return
    end if
    if stage = 38
        if m.profilePinDialog = invalid then return
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(baselineProbeEvent(m.profilePinDialog, 0))
        store = loadUserProfileStore(m.registry, "slot-a")
        m.pickerProbePinRemovalValid = false
        for each profile in store.profiles
            if profile.id = m.pickerProbeAdded then m.pickerProbePinRemovalValid = profile.pinType = "none" and profile.pinHash = "" and profile.pinSalt = ""
        end for
        m.pickerProbeBeforeChild = store
        candidate = copyJson(store)
        for i = 0 to candidate.profiles.count() - 1
            target = candidate.profiles[i]
            role = "user"
            if target.isDefault then role = "child"
            target = setCanonicalPreference(target, "role", role)
            target = setCanonicalPreference(target, "pinType", "numbers")
            target = setCanonicalPreference(target, "pinSalt", "00112233445566778899aabbccddeeff")
            target = setCanonicalPreference(target, "pinHash", userProfilePinHash(target.pinSalt, "1234"))
            target = setCanonicalPreference(target, "pinLength", 4)
            candidate.profiles[i] = target
        end for
        if not commitUserProfileStore(m.registry, store, candidate, {}, true).ok then return
        closeProfileManagementDialog()
        m.userProfileStore = candidate
        m.profileChildAccessReady = true
        if not openUserProfileSwitcher(m.pickerProbeA) then return
        model = m.profileSwitcher.model
        m.profileSwitcher.intent = {action: "switch", index: model.focus, uiNonce: model.uiNonce}
        m.pickerProbeBaselineStage = 39
        return
    end if
    if stage = 39
        if m.profilePinDialog = invalid then return
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(baselineProbeEvent(m.profilePinDialog, 0))
        m.pickerProbeBaselineStage = 40
        return
    end if
    if stage = 40
        if m.busy or m.profileSwitchContext <> invalid or m.activeUserScope = invalid then return
        if m.activeUserScope.profileId <> m.pickerProbeA then return
        m.pickerProbeChildLiveValid = currentUserSettingsRole() = "child" and m.guide.profileSwitcher = invalid and m.apiKey = "synthetic-a"
        openSettingsHub()
        openUserProfileManagement()
        m.pickerProbeBaselineStage = 41
        return
    end if
    if stage = 41
        if m.adultPinDialog = invalid then return
        m.adultPinDialog.textEditBox.text = "1234"
        onAdultProfilePinSubmit(baselineProbeEvent(m.adultPinDialog, 0))
        m.pickerProbeBaselineStage = 42
        return
    end if
    if stage = 42
        if m.profileManagementDialog = invalid then return
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, 0))
        switchIndex = -1
        for i = 0 to m.profileManagementChoices.count() - 1
            if m.profileManagementChoices[i].action = "switch" then switchIndex = i
        end for
        if switchIndex < 0 then return
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, switchIndex))
        m.pickerProbeBaselineStage = 43
        return
    end if
    if stage = 43
        if m.profilePinDialog = invalid then return
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(baselineProbeEvent(m.profilePinDialog, 0))
        m.pickerProbeBaselineStage = 44
        return
    end if
    if stage = 44
        if m.busy or m.profileSwitchContext <> invalid or m.activeUserScope = invalid then return
        if m.activeUserScope.profileId <> m.pickerProbeAdded then return
        m.pickerProbeChildLiveValid = m.pickerProbeChildLiveValid and currentUserSettingsRole() = "user" and m.apiKey = "synthetic-b"
        current = loadUserProfileStore(m.registry, "slot-a")
        if not commitUserProfileStore(m.registry, current, m.pickerProbeBeforeChild, {}, true).ok then return
        m.userProfileStore = m.pickerProbeBeforeChild
        m.profileUnlockGrant = invalid
        openUserProfileManagement()
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, 0))
        m.pickerProbeBaselineStage = 4
        return
    end if
    if stage = 4
        store = loadUserProfileStore(m.registry, "slot-a")
        sorted = userProfileSorted(store.profiles)
        m.pickerProbeBaselineReorderValid = sorted[0].id = m.pickerProbeAdded and store.active = m.pickerProbeAdded and store.pendingRoster
        removeIndex = -1
        for i = 0 to m.profileManagementChoices.count() - 1
            if m.profileManagementChoices[i].action = "remove" then removeIndex = i
        end for
        if removeIndex < 0 then return
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, removeIndex))
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, 0))
        m.pickerProbeBaselineStage = 5
        return
    end if
    if stage = 5
        if m.busy or m.profileSwitchContext <> invalid then return
        if m.activeUserScope = invalid or m.activeUserScope.profileId <> m.pickerProbeA then return
        if m.profileManagementRemovalContext = invalid or m.profileManagementDialog = invalid then return
        onProfileManagementChoice(baselineProbeEvent(m.profileManagementDialog, 0))
        m.pickerProbeBaselineStage = 6
        return
    end if
    if stage = 6
        m.pickerProbeClock.control = "stop"
        store = loadUserProfileStore(m.registry, "slot-a")
        removed = store.profiles.count() = 1 and store.active = m.pickerProbeA and not m.registry.exists(userProfileKeyName("slot-a", m.pickerProbeAdded))
        removed = removed and store.removed.count() = 1 and store.removed[0][0] = m.pickerProbeAddedUsername and store.pendingRoster
        passed = m.pickerProbeBaselineValid and m.pickerProbeBaselineSwitcherValid and m.pickerProbeBaselineReorderValid and removed and m.apiKey = "synthetic-a" and m.registry.read("connKey_slot-a") = "synthetic-a"
        passed = passed and m.pickerProbePinCancelValid and m.pickerProbePinRemovalValid and m.pickerProbeChildLiveValid
        print "[picker-launch] "; FormatJson({kind: "result", passed: passed, baseline: true, addIsolated: m.pickerProbeBaselineAddValid, switchIsolated: m.pickerProbeBaselineSwitchValid, reordered: m.pickerProbeBaselineReorderValid, switcher: m.pickerProbeBaselineSwitcherValid, removed: removed, pinCancel: m.pickerProbePinCancelValid, pinRemoved: m.pickerProbePinRemovalValid, childLive: m.pickerProbeChildLiveValid})
    end if
end sub

sub onProfilePickerLaunchProbeTick()
    if m.pickerProbeMode = "baseline"
        onProfileBaselineProbeTick()
        return
    end if
    ownForm = left(m.pickerProbeMode, 4) = "own-"
    ownLink = m.pickerProbeMode = "own-link" or m.pickerProbeMode = "own-pin-link" or m.pickerProbeMode = "own-auth-link"
    sourceLink = m.pickerProbeMode = "cold-link" or m.pickerProbeMode = "warm-link" or m.pickerProbeMode = "warm-pin-link" or m.pickerProbeMode = "warm-auth-link" or m.pickerProbeMode = "warm-import-pin-link" or m.pickerProbeMode = "warm-load-link" or ownLink or m.pickerProbeMode = "child-select-link"
    if m.pickerProbeMode = "cold-link" and m.profilePinDialog <> invalid and m.pickerProbeReady <> true
        m.pickerProbeReady = true
        ready = m.profilePicker = invalid and m.pickerProbePickerCount = 0 and m.profileStartupScreenReady and not m.profileStartupDeferred and m.activeUserScope = invalid and m.global.profilegateclosed and m.profilePinContext.profile.id = m.pickerProbeA and m.profilePinContext.continuation = "connect" and m.task = invalid
        print "[picker-launch] "; FormatJson({kind: "ready", ready: ready, cold_link: true})
    end if
    if m.profilePicker <> invalid and m.pickerProbeReady <> true
        m.pickerProbeReady = true
        m.pickerProbeStoreRoot = m.registry.read(userProfileStoreKey("slot-a"))
        m.pickerProbeSettingsRoot = m.registry.read("settingsV1")
        ready = m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.profileStartupTask = invalid and m.profilePicker.model.focus = 0
        admission = startupProfileOwnSignInAdmission(m.pickerProbeTargetId)
        formAdmissionExpected = admission.ok
        if m.pickerProbeChildTarget then formAdmissionExpected = not admission.ok
        ready = ready and formAdmissionExpected and m.activeUserScope = invalid and m.apiKey = "" and m.profileStartupTask = invalid
        print "[picker-launch] "; FormatJson({kind: "ready", ready: ready, own_form_admission: admission.ok})
    end if
    if m.pickerProbeMode = "reorder"
        if m.profilePickerReorderDialog <> invalid and m.pickerProbeReorderMenuReady <> true
            m.pickerProbeReorderMenuReady = true
            dialog = m.profilePickerReorderDialog
            ready = dialog.title = "Synthetic8" and dialog.buttons.count() = 3 and dialog.buttons[0] = "Move Left" and dialog.buttons[1] = "Move to Front" and dialog.buttons[2] = "Cancel"
            ready = ready and m.activeUserScope = invalid and m.apiKey = "" and m.profileStartupTask = invalid and m.global.profilegateclosed and m.profilePicker.busy
            print "[picker-launch] "; FormatJson({kind: "reorder-menu", ready: ready})
        else if m.pickerProbeReorderMenuReady = true and m.profilePickerReorderDialog = invalid
            m.pickerProbeClock.control = "stop"
            store = loadUserProfileStore(m.registry, "slot-a")
            passed = store.active = m.pickerProbeA and store.pendingRoster and m.profilePicker.model.tiles[0].id = m.pickerProbeB and m.profilePicker.focusIndex = 0 and not m.profilePicker.busy
            passed = passed and m.activeUserScope = invalid and m.apiKey = "" and m.global.activeusersession = "" and m.global.profilegateclosed and m.profileStartupTask = invalid and m.profilePickerReorderContext = invalid and m.profilePickerReorderNonce = ""
            passed = passed and m.registry.read("settingsV1") = m.pickerProbeSettingsRoot and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.pickerProbeB)) = "synthetic-b"
            print "[picker-launch] "; FormatJson({kind: "result", passed: passed, reordered: true})
        end if
        return
    end if
    if (m.pickerProbeMode = "reject" or m.pickerProbeMode = "identity" or m.pickerProbeMode = "child-select-reject") and m.profilePicker <> invalid
        failureMessage = "The API key for Synthetic8 was rejected."
        retryMessage = "This profile needs its own protected sign-in. No account was switched."
        initial = true
        if m.pickerProbeMode = "identity"
            failureMessage = "Sign in as Synthetic8 to verify this profile's account."
            retryMessage = failureMessage
            initial = m.pickerProbeSelectionCount = 1
        end if
        if m.profilePicker.message = failureMessage and initial
            passed = m.activeUserScope = invalid and m.apiKey = "" and m.profileStartupTask = invalid and m.profileStartupSelectionContext = invalid and m.global.profilegateclosed and not m.profilePicker.busy and m.top.dialog = invalid
            passed = passed and m.registry.read(userProfileStoreKey("slot-a")) = m.pickerProbeStoreRoot and m.registry.read("settingsV1") = m.pickerProbeSettingsRoot and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.pickerProbeB)) = "synthetic-b"
            if m.pickerProbeRejectedReady <> true
                m.pickerProbeRejectedReady = true
                print "[picker-launch] "; FormatJson({kind: "rejected-ready", ready: passed and m.profilePicker.focusIndex = 1, focus: m.profilePicker.focusIndex})
            end if
            return
        end if
        if m.pickerProbeRejectedReady = true and m.profilePicker.message = retryMessage
            m.pickerProbeClock.control = "stop"
            passed = m.activeUserScope = invalid and m.apiKey = "" and m.profileStartupTask = invalid and m.profileStartupSelectionContext = invalid and m.global.profilegateclosed and not m.profilePicker.busy and m.profilePicker.focusIndex = 1
            passed = passed and m.registry.read(userProfileStoreKey("slot-a")) = m.pickerProbeStoreRoot and m.registry.read("settingsV1") = m.pickerProbeSettingsRoot and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.pickerProbeB)) = "synthetic-b"
            if m.pickerProbeMode = "identity"
                passed = m.activeUserScope = invalid and m.apiKey = "" and m.profileStartupTask = invalid and m.profileStartupSelectionContext = invalid and m.profileGateCover.visible and m.profileOwnSignInContext <> invalid and m.profileOwnSignInDialog <> invalid
                if passed then passed = m.profileOwnSignInContext.startupRecovery and m.global.profileownsigninpending
                passed = passed and m.registry.read(userProfileStoreKey("slot-a")) = m.pickerProbeStoreRoot and m.registry.read("settingsV1") = m.pickerProbeSettingsRoot and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.pickerProbeB)) = "synthetic-b"
            end if
            noHold = not m.requestGate.snapshot.keys.doesExist(requestGateCredentialHash("synthetic-b"))
            print "[picker-launch] "; FormatJson({kind: "result", passed: passed, rejected: true, held_refused: true, no_broker_hold: noHold})
            return
        end if
    end if
    if m.pickerProbeMode = "own-keyboard" and m.profileOwnSignInDialog <> invalid and m.profileOwnSignInDialogKind <> "form"
        if m.pickerProbeKeyboardReadyPending = true
            m.pickerProbeKeyboardReadyPending = false
            keyboard = m.profileOwnSignInDialog
            ready = m.profileOwnSignInDialogKind = m.pickerProbeKeyboardExpected and keyboard.keyboardDomain = m.pickerProbeKeyboardDomain and m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible and m.global.profileownsigninpending and m.profileOwnSignInTask = invalid
            if m.pickerProbeKeyboardExpected = "password" then ready = ready and keyboard.textEditBox.secureMode
            print "[picker-launch] "; FormatJson({kind: "keyboard-ready", field: m.pickerProbeKeyboardExpected, ready: ready})
            return
        end if
        if m.pickerProbeSubmit = true
            m.pickerProbeSubmit = false
            keyboard = m.profileOwnSignInDialog
            kind = m.profileOwnSignInDialogKind
            event = {node: keyboard, getRoSGNode: function() as object
                return m.node
            end function, getData: function() as integer
                return 0
            end function}
            onProfileOwnSignInEdited(event)
            if kind = "username"
                m.pickerProbeUsernameEdited = m.profileOwnSignInContext.username = "Synthetic8"
                openStartupPickerProbeKeyboard(1)
            else
                m.pickerProbeKeyboardCompleted = m.pickerProbeUsernameEdited and m.profileOwnSignInContext.password = "synthetic-password" and keyboard.text = "" and keyboard.textEditBox.text = ""
                m.pickerProbeKeyboardCompleted = m.pickerProbeKeyboardCompleted and instr(1, FormatJson(m.profileOwnSignInDialog.buttons), "synthetic-password") = 0
                event.node = m.profileOwnSignInDialog
                event.getData = function() as integer
                    return 2
                end function
                onProfileOwnSignInChoice(event)
                current = m.profileOwnSignInTask
                stale = {node: keyboard, getRoSGNode: function() as object
                    return m.node
                end function, getData: function() as integer
                    return 0
                end function}
                onProfileOwnSignInEdited(stale)
                m.pickerProbeKeyboardCompleted = m.pickerProbeKeyboardCompleted and m.profileOwnSignInTask <> invalid and m.profileOwnSignInContext.password = ""
                if m.pickerProbeKeyboardCompleted then m.pickerProbeKeyboardCompleted = m.profileOwnSignInTask.isSameNode(current)
                print "[picker-launch] "; FormatJson({kind: "keyboard-result", passed: m.pickerProbeKeyboardCompleted})
            end if
        end if
        return
    end if
    if m.profilePinDialog <> invalid
        targetBeforeLink = m.pickerProbeMode = "warm-pin-link" and m.profilePinContext.continuation = "startup-selection"
        if m.pickerProbeMode = "warm-import-pin-link" and m.profilePinContext.continuation = "startup-selection"
            targetBeforeLink = m.profileStartupSelectionContext.authenticated = true
        end if
        sourcePin = sourceLink and m.profilePinContext.continuation = "connect"
        freshDialog = m.pickerProbeDialog = invalid
        if not freshDialog then freshDialog = not m.profilePinDialog.isSameNode(m.pickerProbeDialog)
        if freshDialog
            m.pickerProbeDialog = m.profilePinDialog
            if m.pickerProbePinNumber = invalid then m.pickerProbePinNumber = 0
            m.pickerProbePinNumber++
            if targetBeforeLink then m.pickerProbeRetiredDialog = m.profilePinDialog
            if sourcePin and m.pickerProbeRetiredDialog <> invalid
                stale = {node: m.pickerProbeRetiredDialog, getRoSGNode: function() as object
                    return m.node
                end function, getData: function() as integer
                    return 0
                end function}
                current = m.profilePinDialog
                onProfilePinSubmit(stale)
                onProfilePinClosed(stale)
                m.pickerProbeStaleRefused = m.profilePinDialog <> invalid and m.top.exitRequested <> true and m.activeUserScope = invalid and m.global.profilegateclosed
                if m.pickerProbeStaleRefused then m.pickerProbeStaleRefused = m.profilePinDialog.isSameNode(current) and m.profilePinContext.profile.id = m.pickerProbeA
            end if
            if sourcePin and ownLink
                stale = {node: m.pickerProbeRetiredForm, getRoSGNode: function() as object
                    return m.node
                end function, getData: function() as integer
                    return 2
                end function}
                current = m.profilePinDialog
                onProfileOwnSignInChoice(stale)
                onProfileOwnSignInClosed(stale)
                m.pickerProbeStaleFormRefused = m.profileOwnSignInContext = invalid and m.profileOwnSignInTask = invalid and m.profilePinDialog <> invalid and m.top.exitRequested <> true and m.global.profileownsigninpending <> true and m.global.profileownsigninnonce = ""
                if m.pickerProbeStaleFormRefused then m.pickerProbeStaleFormRefused = m.profilePinDialog.isSameNode(current) and m.profilePinContext.profile.id = m.pickerProbeA
            end if
            ready = m.profilePinContext.continuation = "startup-selection" and m.profilePinContext.profile.id = m.pickerProbeB and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.profileStartupTask = invalid
            if ownForm then ready = m.profilePinContext.continuation = "own-signin" and m.profilePinContext.profile.id = m.pickerProbeTargetId and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.profileOwnSignInTask = invalid and m.profileOwnSignInDialog = invalid
            if sourcePin then ready = m.profilePinContext.continuation = "connect" and m.profilePinContext.profile.id = m.pickerProbeA and m.activeUserScope = invalid and m.apiKey = "synthetic-a" and m.global.profilegateclosed and m.task = invalid and m.profilePicker = invalid
            print "[picker-launch] "; FormatJson({kind: "pin-ready", ready: ready, number: m.pickerProbePinNumber, target_before_link: targetBeforeLink, source_pin: sourcePin})
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
            if sourcePin then wrongCovered = m.profilePinDialog <> invalid and m.activeUserScope = invalid and m.apiKey = "synthetic-a" and m.global.profilegateclosed and m.task = invalid
            value = "1234"
            if m.pickerProbePinNumber = 2 then value = "5678"
            if sourcePin then value = "2468"
            if m.pickerProbeDefaultOwn then value = "2468"
            m.profilePinDialog.textEditBox.text = value
            onProfilePinSubmit(event)
            verified = m.profilePinDialog = invalid and m.profileStartupTask <> invalid and m.activeUserScope = invalid and m.apiKey = "" and m.startupDialogOpen
            if ownForm then verified = m.profilePinDialog = invalid and m.profileOwnSignInDialog <> invalid and m.profileOwnSignInTask = invalid and m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible and m.startupDialogOpen
            if sourcePin then verified = m.profilePinDialog = invalid and m.task <> invalid and m.activeUserScope = invalid and m.apiKey = "synthetic-a" and not m.startupDialogOpen
            print "[picker-launch] "; FormatJson({kind: "pin-submitted", number: m.pickerProbePinNumber, wrong_covered: wrongCovered, verified: verified})
        end if
        return
    end if
    if m.pickerProbeMode = "own-cancel" and m.pickerProbeFormReady = true and m.pickerProbeOwnCancelled <> true and m.profileOwnSignInContext = invalid and m.profilePicker <> invalid and m.profileStartupSelectionContext = invalid
        m.pickerProbeOwnCancelled = true
        m.pickerProbeFormReady = false
        passed = m.activeUserScope = invalid and m.apiKey = "" and m.global.activeusersession = "" and m.global.profilegateclosed and m.profileGateCover.visible and not m.profilePicker.busy and m.profilePicker.focusIndex = 1
        passed = passed and m.registry.read(userProfileStoreKey("slot-a")) = m.pickerProbeStoreRoot and m.registry.read("settingsV1") = m.pickerProbeSettingsRoot and m.registry.read("connKey_slot-a") = "synthetic-a" and not m.registry.exists(userProfileKeyName("slot-a", m.pickerProbeB))
        passed = passed and m.pickerProbeCredentialTask.cancelRequested and m.pickerProbeCredentialTask.password = "" and m.pickerProbeCredentialTask.apiKey = ""
        print "[picker-launch] "; FormatJson({kind: "own-cancelled", passed: passed})
        return
    end if
    if m.pickerProbeMode = "own-wrong" and m.profileOwnSignInDialog <> invalid and m.profileOwnSignInTask = invalid and m.pickerProbeOwnRejected <> true
        if m.profileOwnSignInDialog.message = "Dispatcharr did not accept that username or password."
            m.pickerProbeOwnRejected = true
            passed = m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible and m.global.profileownsigninpending and m.profileStartupTask = invalid and m.profileOwnSignInContext.password = ""
            passed = passed and m.registry.read(userProfileStoreKey("slot-a")) = m.pickerProbeStoreRoot and m.registry.read("settingsV1") = m.pickerProbeSettingsRoot and m.registry.read("connKey_slot-a") = "synthetic-a" and not m.registry.exists(userProfileKeyName("slot-a", m.pickerProbeB))
            print "[picker-launch] "; FormatJson({kind: "own-rejected", passed: passed})
            return
        end if
    end if
    if ownForm and m.profileOwnSignInDialog <> invalid and m.profileOwnSignInTask = invalid
        if m.pickerProbeFormReady <> true
            m.pickerProbeFormReady = true
            if ownLink then m.pickerProbeRetiredForm = m.profileOwnSignInDialog
            ready = m.profileOwnSignInContext <> invalid and m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible and m.global.profileownsigninpending and m.profileOwnSignInContext.target.id = m.pickerProbeTargetId and m.profileStartupTask = invalid
            if m.pickerProbeMode = "own-held" then ready = ready and instr(1, m.profileOwnSignInDialog.message, "server address") > 0
            print "[picker-launch] "; FormatJson({kind: "own-form-ready", ready: ready})
        end if
        if m.pickerProbeSubmit = true
            m.pickerProbeSubmit = false
            event = {node: m.profileOwnSignInDialog, getRoSGNode: function() as object
                return m.node
            end function, getData: function() as integer
                return 2
            end function}
            m.profileOwnSignInContext.password = "synthetic-password"
            if m.pickerProbeMode = "own-keyboard"
                m.profileOwnSignInContext.password = ""
                openStartupPickerProbeKeyboard(0)
                return
            end if
            if m.pickerProbeMode = "own-wrong" and m.pickerProbeOwnRejected <> true then m.profileOwnSignInContext.password = "synthetic-rejected"
            onProfileOwnSignInChoice(event)
            if m.pickerProbeOwnCancelled <> true then m.pickerProbeCredentialTask = m.profileOwnSignInTask
        end if
        return
    end if
    if m.page <> "guide" or m.busy then return
    if m.pickerProbeMode = "warm-auth-link" or m.pickerProbeMode = "warm-load-link" or m.pickerProbeMode = "own-cancel" or m.pickerProbeMode = "own-auth-link" or m.pickerProbeMode = "child-select-link"
        if m.pickerProbeWarmWait = invalid
            m.pickerProbeWarmWait = CreateObject("roTimeSpan")
            m.pickerProbeWarmWait.mark()
        end if
        if m.pickerProbeWarmWait.totalMilliseconds() < 6000 then return
    end if
    m.pickerProbeClock.control = "stop"
    store = loadUserProfileStore(m.registry, "slot-a")
    settings = loadStrictPreferenceStore(m.registry)
    if sourceLink
        expectedCount = 0
        if m.pickerProbeMode <> "cold-link" then expectedCount = 1
        passed = m.activeUserScope <> invalid and m.profilePicker = invalid and m.profileStartupSelectionContext = invalid and m.profileStartupTask = invalid and not m.global.profilegateclosed and not m.global.profileswitchpending and m.playingChannel = invalid
        if passed then passed = m.activeUserScope.profileId = m.pickerProbeA and m.activeUserScope.accountId = "7" and m.activeUserScope.sessionId = m.global.activeusersession
        ownKeyCorrect = m.registry.read(userProfileKeyName("slot-a", m.pickerProbeB)) = "synthetic-b"
        if ownLink then ownKeyCorrect = not m.registry.exists(userProfileKeyName("slot-a", m.pickerProbeB))
        passed = passed and store.active = m.pickerProbeA and store.pendingRoster and m.apiKey = "synthetic-a" and m.registry.read("connKey_slot-a") = "synthetic-a" and ownKeyCorrect
        passed = passed and m.accountPreferences.favoriteIds[0] = "7" and m.guide.callFunc("profilePickerProbeLineup") = "7" and m.pickerProbePickerCount = expectedCount and m.profileLaunchPickerDeepLink and m.profileLaunchPickerResolved and m.pendingLaunch = invalid and not m.startupDialogOpen
        if m.pickerProbeMode = "warm-pin-link" then passed = passed and m.pickerProbeStaleRefused = true
        if m.pickerProbeMode = "warm-import-pin-link"
            passed = passed and m.pickerProbeStaleRefused = true
            for each profile in store.profiles
                if profile.id = m.pickerProbeB then passed = passed and profile.pinType = "numbers" and profile.pinHash = userProfilePinHash("0123456789abcdef0123456789abcdef", "5678")
            end for
        end if
        if m.pickerProbeMode = "warm-auth-link" or m.pickerProbeMode = "warm-load-link" or m.pickerProbeMode = "child-select-link" then passed = passed and m.pickerProbeTask.cancelRequested and m.pickerProbeTask.apiKey = "" and m.pickerProbeTask.aeriosession <> m.activeUserScope.sessionId
        if m.pickerProbeMode = "child-select-link"
            passed = passed and currentUserSettingsRole() = "user" and m.guide.callFunc("profilePickerProbeRole") = "user"
            for each profile in store.profiles
                if profile.id = m.pickerProbeB then passed = passed and profile.role = "child"
            end for
        end if
        if ownLink then passed = passed and m.pickerProbeStaleFormRefused = true
        if m.pickerProbeMode = "own-auth-link" then passed = passed and m.pickerProbeCredentialTask.cancelRequested and m.pickerProbeCredentialTask.password = "" and m.pickerProbeCredentialTask.apiKey = "" and m.pickerProbeCredentialTask.aeriosession <> m.activeUserScope.sessionId
        targetSettings = preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "8"))
        passed = passed and settings.accounts[targetSettings].favoriteIds[0] = "8" and settings.accounts[targetSettings].profileSettings.themePreset = "forest" and not m.registry.exists(userProfileSyncAckKey("slot-a"))
        print "[picker-launch] "; FormatJson({kind: "result", passed: passed, source_link: true, picker_count: m.pickerProbePickerCount})
        return
    end if
    passed = m.activeUserScope <> invalid and m.profilePicker = invalid and m.profileStartupSelectionContext = invalid and m.profileStartupTask = invalid and not m.global.profilegateclosed and not m.global.profileswitchpending and m.playingChannel = invalid
    wantedUser = "8"
    wantedKey = "synthetic-b"
    wantedTheme = "forest"
    if m.pickerProbeMode = "own-recreated" then wantedUser = "88"
    if m.pickerProbeDefaultOwn
        wantedUser = "7"
        wantedKey = "synthetic-a"
        wantedTheme = "midnight"
    end if
    if passed then passed = m.activeUserScope.profileId = m.pickerProbeTargetId and m.activeUserScope.accountId = wantedUser and m.activeUserScope.sessionId = m.global.activeusersession and userProfileLocalId(m.activeUserScope.sessionId) <> ""
    savedKeys = m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.pickerProbeB)) = "synthetic-b"
    if m.pickerProbeMode = "own-memory"
        bucket = preferenceScope(m.baseUrl + "|slot-a|" + m.pickerProbeB)
        savedKeys = not m.registry.exists("connKey_slot-a") and not m.registry.exists(userProfileKeyName("slot-a", m.pickerProbeB)) and m.profileSessionKeys[bucket] = "synthetic-b"
    end if
    passed = passed and store.active = m.pickerProbeTargetId and store.pendingRoster and m.apiKey = wantedKey and savedKeys
    wantedFavorite = "8"
    if m.pickerProbeDefaultOwn then wantedFavorite = "7"
    passed = passed and m.accountPreferences.favoriteIds[0] = wantedFavorite and m.accountPreferences.profileSettings.themePreset = wantedTheme and m.guide.callFunc("profilePickerProbeLineup") = wantedUser
    source = preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "7"))
    passed = passed and settings.accounts[source].favoriteIds[0] = "7" and not m.registry.exists(userProfileSyncAckKey("slot-a")) and m.startupDialogOpen = false
    if m.pickerProbeMode = "own-cancel" then passed = passed and m.pickerProbeOwnCancelled = true and m.pickerProbeCredentialTask.cancelRequested and m.pickerProbeCredentialTask.password = "" and m.pickerProbeCredentialTask.aeriosession <> m.activeUserScope.sessionId
    if m.pickerProbeMode = "own-wrong" then passed = passed and m.pickerProbeOwnRejected = true
    if m.pickerProbeMode = "own-keyboard" then passed = passed and m.pickerProbeKeyboardCompleted = true
    if m.pickerProbeChildTarget
        passed = passed and currentUserSettingsRole() = "child" and m.guide.callFunc("profilePickerProbeRole") = "child" and not userProfileConnectionSetupAllowed()
        for each profile in store.profiles
            if profile.id = m.pickerProbeB then passed = passed and profile.role = "child" and profile.displayName = "Synthetic8"
        end for
        if m.pickerProbeMode = "child-select-pin"
            for each profile in store.profiles
                if profile.id = m.pickerProbeB then passed = passed and profile.pinType = "numbers" and profile.pinHash = userProfilePinHash("0123456789abcdef0123456789abcdef", "1234")
            end for
        end if
    end if
    if m.pickerProbeMode = "own-recreated"
        oldAccount = preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "8"))
        newAccount = preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "88"))
        passed = passed and not settings.accounts.doesExist(oldAccount) and settings.accounts[newAccount].favoriteIds[0] = "8"
    end if
    print "[picker-launch] "; FormatJson({kind: "result", passed: passed})
end sub

sub openStartupPickerProbeKeyboard(choice as integer)
    event = {node: m.profileOwnSignInDialog, choice: choice, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return m.choice
    end function}
    onProfileOwnSignInChoice(event)
    keyboard = m.profileOwnSignInDialog
    keyboard.text = ""
    keyboard.textEditBox.text = ""
    expectedKind = "username"
    domain = "email"
    if choice = 1
        expectedKind = "password"
        domain = "password"
    end if
    m.pickerProbeKeyboardExpected = expectedKind
    m.pickerProbeKeyboardDomain = domain
    m.pickerProbeKeyboardReadyPending = true
end sub

sub verifyStartupPickerProbeCancel()
    if m.pickerProbeMode <> "back" then return
    m.pickerProbeClock.control = "stop"
    passed = m.activeUserScope = invalid and m.apiKey = "" and m.profileStartupTask = invalid and m.profileStartupSelectionContext = invalid and m.profilePicker = invalid and m.global.profilegateclosed and not m.global.profileswitchpending and m.global.activeusersession = ""
    passed = passed and m.registry.read(userProfileStoreKey("slot-a")) = m.pickerProbeStoreRoot and m.registry.read("settingsV1") = m.pickerProbeSettingsRoot and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.pickerProbeB)) = "synthetic-b"
    passed = passed and m.pickerProbeTask <> invalid
    if passed then passed = m.pickerProbeTask.cancelRequested and m.pickerProbeTask.apiKey = ""
    m.top.pickerProbeCancelPassed = passed
    print "[picker-launch] "; FormatJson({kind: "cancelled", passed: passed})
end sub
