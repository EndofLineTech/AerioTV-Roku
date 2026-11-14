' Private keyless Child own form, real credential outcomes and delayed Back.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if OWN_CHILD_PIN and m.childFormLaunchPinDone <> true
            if m.profilePinDialog = invalid then return
            if m.childFormLaunchPinSeen <> true
                m.childFormLaunchPinSeen = true
                m.childFormPinSafe = m.task = invalid and m.activeUserScope = invalid and m.global.profilegateclosed and m.profileGateCover.visible
                print "[own-signin] "; FormatJson({kind: "child-pin-ready", covered: m.childFormPinSafe})
                return
            end if
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
            m.childFormLaunchPinDone = true
            return
        end if
        if m.childUnavailableDialog = invalid then return
        rawDevice = strictJsonEncode(m.preferenceStore.device).text
        settingsBeforeReset = m.registry.read("settingsV1")
        resetConnectionRuntime()
        sparseReset = strictJsonEncode(m.preferenceStore.device).text = rawDevice and m.registry.read("settingsV1") = settingsBeforeReset and m.devicePreferences.networkTimeoutSeconds > 0 and m.devicePreferences.refreshSeconds > 0
        if not showUnavailableChildProfile()
            m.managementProbeClock.control = "stop"
            print "[own-signin] "; FormatJson({kind: "result", passed: false, sparse_reset: false})
            return
        end if
        store = loadUserProfileStore(m.registry, "slot-a")
        m.childFormProfile = store.active
        m.childFormStore = m.registry.read(userProfileStoreKey("slot-a"))
        m.childFormSettings = m.registry.read("settingsV1")
        m.childFormPassed = sparseReset and m.childUnavailableDialog.buttons.count() = 2 and m.childUnavailableDialog.buttons[0] = "Sign in to Dispatcharr" and m.activeUserScope = invalid and m.apiKey = ""
        otherName = "Synthetic7"
        if OWN_CHILD_DEFAULT then otherName = "Synthetic8"
        m.childFormPassed = m.childFormPassed and instr(1, m.childUnavailableDialog.title + m.childUnavailableDialog.message, otherName) = 0
        if OWN_CHILD_PIN then m.childFormPassed = m.childFormPassed and m.childFormPinSafe
        print "[own-signin] "; FormatJson({kind: "child-form-ready", covered: m.childFormPassed})
        m.managementProbePhase = 1
    else if phase = 1
        onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, 0))
        if m.profileOwnSignInDialog = invalid or m.profileOwnSignInContext = invalid or m.profilePinDialog <> invalid
            m.managementProbeClock.control = "stop"
            print "[own-signin] "; FormatJson({kind: "result", passed: false, own_form: false})
            return
        end if
        m.childFormPassed = m.childFormPassed and m.profileOwnSignInDialog <> invalid and m.profilePinDialog = invalid and m.profileOwnSignInContext.childRecovery and m.activeUserScope = invalid
        m.childFormCases = ["rejected", "name"]
        if OWN_CHILD_DEFAULT then m.childFormCases.push("id")
        m.childFormCases.push("no-api")
        m.childFormCase = 0
        m.managementProbePhase = 2
    else if phase = 2
        m.childFormPassed = submitChildOwnPassword(m.childFormCases[m.childFormCase]) and m.childFormPassed
        m.managementProbePhase = 3
    else if phase = 3
        if m.profileOwnSignInTask <> invalid then return
        scenario = m.childFormCases[m.childFormCase]
        expected = "Dispatcharr did not accept that username or password."
        if scenario = "no-api" then expected = "This account has no API key yet. Ask your Dispatcharr administrator to turn on API access for it."
        passed = m.profileOwnSignInContext <> invalid and m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible and instr(1, m.profileOwnSignInDialog.message, expected) > 0 and m.registry.read("settingsV1") = m.childFormSettings and m.registry.read(userProfileStoreKey("slot-a")) = m.childFormStore
        if OWN_CHILD_HELD then passed = passed and instr(1, m.profileOwnSignInDialog.message, "The server address for Synthetic changed. Sign in again to use this profile.") > 0
        m.childFormPassed = m.childFormPassed and passed
        print "[own-signin] "; FormatJson({kind: "case", scenario: scenario, passed: passed})
        m.childFormCase++
        m.managementProbePhase = 2
        if m.childFormCase >= m.childFormCases.count() then m.managementProbePhase = 4
    else if phase = 4
        m.childFormPassed = submitChildOwnPassword("delayed") and m.childFormPassed
        m.managementProbePhase = 5
    else if phase = 5
        if m.profileOwnSignInTask = invalid then return
        if m.profileOwnSignInTask.progress <> "Verifying account" then return
        print "[own-signin] "; FormatJson({kind: "cancel-ready"})
        m.managementProbePhase = 6
    else if phase < 12
        m.managementProbePhase++
    else if phase = 12
        cancelled = m.profileOwnSignInContext = invalid and m.profileOwnSignInTask = invalid and m.activeUserScope = invalid and m.apiKey = "" and currentUserSessionId() = "" and m.global.profilegateclosed and m.profileGateCover.visible and m.childUnavailableDialog <> invalid and m.top.exitRequested <> true and m.registry.read("settingsV1") = m.childFormSettings and m.registry.read(userProfileStoreKey("slot-a")) = m.childFormStore
        m.childFormPassed = m.childFormPassed and cancelled
        print "[own-signin] "; FormatJson({kind: "cancelled", passed: cancelled})
        if not cancelled
            m.managementProbeClock.control = "stop"
            print "[own-signin] "; FormatJson({kind: "result", passed: false, cancelled: false})
            return
        end if
        onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, 0))
        m.childFormPassed = submitChildOwnPassword("correct") and m.childFormPassed
        m.managementProbePhase = 13
    else
        if m.busy or m.capabilityTask <> invalid or m.activeUserScope = invalid or m.page <> "guide" then return
        m.managementProbeClock.control = "stop"
        store = loadUserProfileStore(m.registry, "slot-a")
        account = "88"
        content = "8"
        theme = "forest"
        if OWN_CHILD_DEFAULT then account = "7" : content = "7" : theme = "midnight"
        own = store.active = m.childFormProfile and m.activeUserScope.profileId = m.childFormProfile and m.activeUserScope.accountId = account and currentUserSettingsRole() = "child" and not m.profileGateCover.visible
        runtime = m.devicePreferences.networkTimeoutSeconds > 0 and m.global.networkTimeoutMs = m.devicePreferences.networkTimeoutSeconds * 1000 and m.devicePreferences.refreshSeconds > 0
        data = m.accountPreferences.favoriteIds.count() = 1 and m.devicePreferences.themePreset = theme and m.guide.callFunc("profileSwitchProbeLineup") = content
        if data then data = m.accountPreferences.favoriteIds[0] = "00000000-0000-4000-8000-" + right("000000000000" + content, 12)
        credentials = m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.childFormProfile)) = "synthetic-new-own-key"
        if OWN_CHILD_DEFAULT then credentials = m.registry.read("connKey_slot-a") = "synthetic-new-own-key" and m.registry.read(userProfileKeyName("slot-a", store.profiles[1].id)) = "synthetic-b"
        held = false
        for each profile in store.profiles
            if profile.id = m.childFormProfile then held = profile.addressHeld
        end for
        print "[own-signin] "; FormatJson({kind: "case", scenario: "correct", passed: own and data and credentials and not held})
        print "[own-signin] "; FormatJson({kind: "result", passed: m.childFormPassed and own and data and credentials and runtime and not held and m.playingChannel = invalid, own: own, data: data, credentials: credentials, runtime_defaults: runtime, no_autoplay: m.playingChannel = invalid})
    end if
end sub

function submitChildOwnPassword(scenario as string) as boolean
    if m.profileOwnSignInDialog = invalid then return false
    before = m.profileOwnSignInDialog
    showConnection()
    openUserProfileManagement()
    protected = m.profileOwnSignInDialog.isSameNode(before) and m.profileManagementDialog = invalid and m.activeUserScope = invalid and m.profileGateCover.visible
    onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 1))
    secure = m.profileOwnSignInDialog.subtype() = "StandardKeyboardDialog" and m.profileOwnSignInDialog.keyboardDomain = "password" and m.profileOwnSignInDialog.textEditBox.secureMode
    m.profileOwnSignInDialog.text = "synthetic-" + scenario
    onProfileOwnSignInEdited(managementProbeEvent(m.profileOwnSignInDialog, 0))
    onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 2))
    return protected and secure and m.profileOwnSignInTask <> invalid
end function
