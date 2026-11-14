' Actual active nondefault rejection, prompt, PIN, own form and fresh reload.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        m.activeOwnProfile = m.activeUserScope.profileId
        m.activeOwnOldSession = currentUserSessionId()
        store = loadUserProfileStore(m.registry, "slot-a")
        target = store.profiles[1]
        target = setCanonicalPreference(target, "pinType", "numbers")
        target = setCanonicalPreference(target, "pinSalt", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        target = setCanonicalPreference(target, "pinHash", "OWN_PROBE_PIN_HASH")
        store.profiles[1] = target
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.flush()
        m.activeOwnPassed = m.activeUserScope.accountId = "8"
        m.activeOwnCases = ["rejected", "name", "no-api", "correct"]
        m.activeOwnCase = 0
        print "[own-signin] "; FormatJson({kind: "revoke-ready"})
        m.managementProbePhase = 1
    else if phase = 1
        refreshCapabilities()
        m.managementProbePhase = 2
    else if phase = 2
        if m.capabilityTask <> invalid then return
        if not m.global.profilegateclosed or m.activeUserScope <> invalid then return
        store = loadUserProfileStore(m.registry, "slot-a")
        m.activeOwnPassed = m.activeOwnPassed and store.active = m.activeOwnProfile and m.registry.read("connKey_slot-a") = "synthetic-a" and not m.registry.exists(userProfileKeyName("slot-a", m.activeOwnProfile)) and m.profileRecoveryDialog <> invalid
        if m.profileRecoveryDialog = invalid
            m.managementProbeClock.control = "stop"
            print "[own-signin] "; FormatJson({kind: "result", passed: false, prompt: false})
            return
        end if
        m.activeOwnPassed = m.activeOwnPassed and m.profileRecoveryDialog.buttons.count() = 2 and m.profileRecoveryDialog.buttons[0] = "Sign In with Remote"
        onActiveUserProfileRecoveryChoice(managementProbeEvent(m.profileRecoveryDialog, 0))
        m.activeOwnPassed = unlockActiveOwnPin() and m.activeOwnPassed
        m.activeOwnStore = m.registry.read(userProfileStoreKey("slot-a"))
        m.managementProbePhase = 3
    else if phase = 3
        if m.profileOwnSignInDialog = invalid
            m.managementProbeClock.control = "stop"
            print "[own-signin] "; FormatJson({kind: "result", passed: false, form: false})
            return
        end if
        before = m.profileOwnSignInDialog
        showConnection()
        openUserProfileManagement()
        m.activeOwnPassed = m.activeOwnPassed and m.profileOwnSignInDialog.isSameNode(before) and m.profileManagementDialog = invalid and m.activeUserScope = invalid and m.profileGateCover.visible
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 1))
        m.activeOwnPassed = m.activeOwnPassed and m.profileOwnSignInDialog.subtype() = "StandardKeyboardDialog" and m.profileOwnSignInDialog.keyboardDomain = "password" and m.profileOwnSignInDialog.textEditBox.secureMode
        m.profileOwnSignInDialog.text = "synthetic-" + m.activeOwnCases[m.activeOwnCase]
        onProfileOwnSignInEdited(managementProbeEvent(m.profileOwnSignInDialog, 0))
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 2))
        m.managementProbePhase = 4
    else if phase = 4
        if m.profileOwnSignInTask <> invalid or m.busy then return
        scenario = m.activeOwnCases[m.activeOwnCase]
        if scenario = "correct"
            if m.page <> "guide" or m.activeUserScope = invalid then return
            if m.capabilityTask <> invalid then return
            store = loadUserProfileStore(m.registry, "slot-a")
            entry = connectionStoreEntry(m.connectionStore, "slot-a")
            passed = store.active = m.activeOwnProfile and store.profiles[1].userId = 88 and m.activeUserScope.accountId = "88" and currentUserSessionId() <> m.activeOwnOldSession and not m.profileGateCover.visible
            passed = passed and m.accountPreferences.favoriteIds.count() = 1 and m.devicePreferences.themePreset = "forest" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.activeOwnProfile)) = "synthetic-new-own-key"
            passed = passed and not m.preferenceStore.accounts.doesExist(preferenceScope(connectionPreferenceIdentity(entry, "8")))
            m.activeOwnPassed = m.activeOwnPassed and passed
            print "[own-signin] "; FormatJson({kind: "case", scenario: scenario, passed: passed})
            print "[own-signin] "; FormatJson({kind: "revoke-new-ready"})
            m.managementProbePhase = 5
            return
        end if
        expected = "Dispatcharr did not accept that username or password."
        if scenario = "no-api" then expected = "This account has no API key yet. Ask your Dispatcharr administrator to turn on API access for it."
        passed = m.profileOwnSignInContext <> invalid and m.activeUserScope = invalid and m.profileOwnSignInDialog.message = expected and m.registry.read(userProfileStoreKey("slot-a")) = m.activeOwnStore and m.profileGateCover.visible
        m.activeOwnPassed = m.activeOwnPassed and passed
        print "[own-signin] "; FormatJson({kind: "case", scenario: scenario, passed: passed})
        m.activeOwnCase++
        m.managementProbePhase = 3
    else if phase = 5
        refreshCapabilities()
        m.managementProbePhase = 6
    else if phase = 6
        if m.capabilityTask <> invalid or not m.global.profilegateclosed then return
        m.activeOwnCancelSettings = m.registry.read("settingsV1")
        m.activeOwnCancelStore = m.registry.read(userProfileStoreKey("slot-a"))
        onActiveUserProfileRecoveryChoice(managementProbeEvent(m.profileRecoveryDialog, 0))
        onProfilePinClosed(managementProbeEvent(m.profilePinDialog, 0))
        m.activeOwnPassed = m.activeOwnPassed and m.profileOwnSignInContext = invalid and m.profileGateCover.visible and m.global.profilegateclosed and m.activeUserScope = invalid
        started = beginUserProfileOwnSignIn(m.activeOwnProfile, true)
        m.activeOwnPassed = started and unlockActiveOwnPin() and m.activeOwnPassed
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 1))
        m.profileOwnSignInDialog.text = "synthetic-delayed"
        onProfileOwnSignInEdited(managementProbeEvent(m.profileOwnSignInDialog, 0))
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 2))
        m.managementProbePhase = 7
    else if phase = 7
        if m.profileOwnSignInTask.progress <> "Verifying account" then return
        print "[own-signin] "; FormatJson({kind: "cancel-ready"})
        m.managementProbePhase = 8
    else if phase < 13
        m.managementProbePhase++
    else
        m.managementProbeClock.control = "stop"
        store = loadUserProfileStore(m.registry, "slot-a")
        cancelled = m.profileOwnSignInContext = invalid and m.profileOwnSignInTask = invalid and m.activeUserScope = invalid and m.profileGateCover.visible and m.global.profilegateclosed and m.registry.read("settingsV1") = m.activeOwnCancelSettings and m.registry.read(userProfileStoreKey("slot-a")) = m.activeOwnCancelStore and m.top.exitRequested <> true
        print "[own-signin] "; FormatJson({kind: "result", passed: m.activeOwnPassed and cancelled, cancelled: cancelled, default_preserved: m.registry.read("connKey_slot-a") = "synthetic-a", own_key_absent: not m.registry.exists(userProfileKeyName("slot-a", m.activeOwnProfile)), active_preserved: store.active = m.activeOwnProfile and store.profiles[1].userId = 88, no_autoplay: m.playingChannel = invalid})
    end if
end sub

function unlockActiveOwnPin() as boolean
    if m.profilePinDialog = invalid or m.profileOwnSignInDialog <> invalid then return false
    native = m.profilePinDialog.subtype() = "StandardPinPadDialog" and m.global.profilegateclosed
    m.profilePinDialog.textEditBox.text = "1234"
    onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
    return native and m.profileOwnSignInDialog <> invalid and m.profileGateCover.visible and m.activeUserScope = invalid and not m.global.profilegateclosed
end function
