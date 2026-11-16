sub seedProfilePickerLaunchProbe(base as string, mode as string)
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Synthetic7", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
    b = setCanonicalPreference(b, "isDefault", false)
    m.pickerProbeMode = mode
    m.pickerProbePickerCount = 0
    if mode = "own-pin"
        b = setCanonicalPreference(b, "pinType", "numbers")
        b = setCanonicalPreference(b, "pinSalt", "0123456789abcdef0123456789abcdef")
        b = setCanonicalPreference(b, "pinHash", userProfilePinHash(b.pinSalt, "1234"))
    end if
    if mode = "own-held" then b = setCanonicalPreference(b, "addressHeld", true)
    if mode = "pin" or mode = "import-pin" or mode = "cold-link" or mode = "warm-link" or mode = "warm-pin-link" or mode = "warm-auth-link" or mode = "warm-import-pin-link" or mode = "warm-load-link"
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
    ' Exercise the production default, rather than forcing Ask on in the probe.
    store = setCanonicalPreference(store, "pendingRoster", true)
    connection = normalizeConnectionEntry({id: "slot-a", name: "Synthetic startup", provider: "dispatcharr", url: base, accountId: "7", remember: true})
    m.registry.write("connectionsV1", FormatJson({schema: 1, selected: "slot-a", entries: [connection]}))
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
    m.registry.write("connKey_slot-a", "synthetic-a")
    if mode <> "own-keyless" and mode <> "own-pin" and mode <> "own-cancel" then m.registry.write(userProfileKeyName("slot-a", b.id), "synthetic-b")
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
    ownForm = m.pickerProbeMode = "own-keyless" or m.pickerProbeMode = "own-pin" or m.pickerProbeMode = "own-held" or m.pickerProbeMode = "own-cancel"
    sourceLink = m.pickerProbeMode = "cold-link" or m.pickerProbeMode = "warm-link" or m.pickerProbeMode = "warm-pin-link" or m.pickerProbeMode = "warm-auth-link" or m.pickerProbeMode = "warm-import-pin-link" or m.pickerProbeMode = "warm-load-link"
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
        admission = startupProfileOwnSignInAdmission(m.pickerProbeB)
        ready = ready and admission.ok and m.activeUserScope = invalid and m.apiKey = "" and m.profileStartupTask = invalid
        print "[picker-launch] "; FormatJson({kind: "ready", ready: ready, own_form_admission: admission.ok})
    end if
    if (m.pickerProbeMode = "reject" or m.pickerProbeMode = "identity") and m.profilePicker <> invalid
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
            ready = m.profilePinContext.continuation = "startup-selection" and m.profilePinContext.profile.id = m.pickerProbeB and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.profileStartupTask = invalid
            if ownForm then ready = m.profilePinContext.continuation = "own-signin" and m.profilePinContext.profile.id = m.pickerProbeB and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.profileOwnSignInTask = invalid and m.profileOwnSignInDialog = invalid
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
    if ownForm and m.profileOwnSignInDialog <> invalid and m.profileOwnSignInTask = invalid
        if m.pickerProbeFormReady <> true
            m.pickerProbeFormReady = true
            ready = m.profileOwnSignInContext <> invalid and m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible and m.global.profileownsigninpending and m.profileOwnSignInContext.target.id = m.pickerProbeB and m.profileStartupTask = invalid
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
            onProfileOwnSignInChoice(event)
            if m.pickerProbeOwnCancelled <> true then m.pickerProbeCredentialTask = m.profileOwnSignInTask
        end if
        return
    end if
    if m.page <> "guide" or m.busy then return
    if m.pickerProbeMode = "warm-auth-link" or m.pickerProbeMode = "warm-load-link" or m.pickerProbeMode = "own-cancel"
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
        passed = passed and store.active = m.pickerProbeA and store.pendingRoster and m.apiKey = "synthetic-a" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.pickerProbeB)) = "synthetic-b"
        passed = passed and m.accountPreferences.favoriteIds[0] = "7" and m.guide.callFunc("profilePickerProbeLineup") = "7" and m.pickerProbePickerCount = expectedCount and m.profileLaunchPickerDeepLink and m.profileLaunchPickerResolved and m.pendingLaunch = invalid and not m.startupDialogOpen
        if m.pickerProbeMode = "warm-pin-link" then passed = passed and m.pickerProbeStaleRefused = true
        if m.pickerProbeMode = "warm-import-pin-link"
            passed = passed and m.pickerProbeStaleRefused = true
            for each profile in store.profiles
                if profile.id = m.pickerProbeB then passed = passed and profile.pinType = "numbers" and profile.pinHash = userProfilePinHash("0123456789abcdef0123456789abcdef", "5678")
            end for
        end if
        if m.pickerProbeMode = "warm-auth-link" or m.pickerProbeMode = "warm-load-link" then passed = passed and m.pickerProbeTask.cancelRequested and m.pickerProbeTask.apiKey = "" and m.pickerProbeTask.aeriosession <> m.activeUserScope.sessionId
        targetSettings = preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "8"))
        passed = passed and settings.accounts[targetSettings].favoriteIds[0] = "8" and settings.accounts[targetSettings].profileSettings.themePreset = "forest" and not m.registry.exists(userProfileSyncAckKey("slot-a"))
        print "[picker-launch] "; FormatJson({kind: "result", passed: passed, source_link: true, picker_count: m.pickerProbePickerCount})
        return
    end if
    passed = m.activeUserScope <> invalid and m.profilePicker = invalid and m.profileStartupSelectionContext = invalid and m.profileStartupTask = invalid and not m.global.profilegateclosed and not m.global.profileswitchpending and m.playingChannel = invalid
    if passed then passed = m.activeUserScope.profileId = m.pickerProbeB and m.activeUserScope.accountId = "8" and m.activeUserScope.sessionId = m.global.activeusersession and userProfileLocalId(m.activeUserScope.sessionId) <> ""
    passed = passed and store.active = m.pickerProbeB and store.pendingRoster and m.apiKey = "synthetic-b" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.pickerProbeB)) = "synthetic-b"
    passed = passed and m.accountPreferences.favoriteIds[0] = "8" and m.accountPreferences.profileSettings.themePreset = "forest" and m.guide.callFunc("profilePickerProbeLineup") = "8"
    source = preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "7"))
    passed = passed and settings.accounts[source].favoriteIds[0] = "7" and not m.registry.exists(userProfileSyncAckKey("slot-a")) and m.startupDialogOpen = false
    if m.pickerProbeMode = "own-cancel" then passed = passed and m.pickerProbeOwnCancelled = true and m.pickerProbeCredentialTask.cancelRequested and m.pickerProbeCredentialTask.password = "" and m.pickerProbeCredentialTask.aeriosession <> m.activeUserScope.sessionId
    print "[picker-launch] "; FormatJson({kind: "result", passed: passed})
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
