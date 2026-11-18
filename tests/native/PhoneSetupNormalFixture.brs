' Real full-app receiver -> encrypted payload -> confirmation -> profiles -> PIN.
' Only storage and the provider HTTP fixture are disposable. No receiver, crypto,
' import, PIN, switch or consent controller is replaced or force-enabled.
sub startPhoneNormalProbe()
    if m.phoneNormalClock <> invalid then return
    m.phoneNormalPhase = 0
    m.phoneNormalClock = m.top.createChild("Timer")
    m.phoneNormalClock.duration = 0.2
    m.phoneNormalClock.repeat = true
    m.phoneNormalClock.observeField("fire", "onPhoneNormalProbeTick")
    m.phoneNormalClock.control = "start"
    m.phoneNormalFault = CreateObject("roSGNode", "PhoneEntropyFaultProbe")
    m.phoneNormalFault.control = "RUN"
end sub

function phoneNormalEvent(node as object, index as integer) as object
    return {node: node, index: index, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return m.index
    end function}
end function

sub onPhoneNormalProbeTick()
    phase = m.phoneNormalPhase
    if m.phoneNormalLoggedPhase <> phase
        m.phoneNormalLoggedPhase = phase
        print "[setup-phone-normal] "; FormatJson({kind: "stage", stage: phase, page: m.page, picker: m.profilePicker <> invalid, pin: m.profilePinDialog <> invalid})
    end if
    if (phase = 2 or phase = 3) and m.phoneSetup.retryAvailable and m.phonePending = invalid
        finishPhoneNormalProbe(false, "import-controller-refusal")
        return
    end if
    if phase = 0
        if type(m.phoneNormalFault.result) <> "roAssociativeArray" then return
        m.phoneNormalChecks = m.phoneNormalFault.result.checks
        if not m.phoneNormalFault.result.passed then finishPhoneNormalProbe(false, "native-device-faults") : return
        if m.page <> "welcome" or m.busy then return
        if m.profilePhoneImportReady <> true or m.profileBaselineReady <> true then finishPhoneNormalProbe(false, "normal-readiness") : return
        openPhoneSetup()
        if m.page <> "phoneSetup" or not m.phoneSetup.active then finishPhoneNormalProbe(false, "open-receiver") : return
        m.phoneNormalPhase = 1
    else if phase = 1
        info = m.phoneSetup.sessionInfo
        if type(info) <> "roAssociativeArray" then return
        if info.kind = "unavailable" or info.kind = "error" then finishPhoneNormalProbe(false, "receiver-unavailable") : return
        if info.kind <> "ready" then return
        print "[setup-phone-normal] "; FormatJson({kind: "ready", normal_provider: true, fault_checks: m.phoneNormalChecks})
        m.phoneNormalPhase = 2
    else if phase = 2
        ' A new playlist commits after verification without a replace dialog.
        if m.phoneProfileImport = invalid and (m.profilePicker <> invalid or m.profilePinDialog <> invalid)
            print "[setup-phone-normal] "; FormatJson({kind: "received", real_listener: true, live_profiles_committed: true})
            m.phoneNormalPhase = 3
            return
        end if
        taskState = ""
        if m.phoneProfileVerifyTask <> invalid then taskState = m.phoneProfileVerifyTask.state
        importPhase = ""
        if m.phoneProfileImport <> invalid then importPhase = m.phoneProfileImport.phase
        state = FormatJson({kind: "receive-state", page: m.page, active: m.phoneSetup.active, ui_phase: m.phoneSetup.phase, gate: m.global.profilegateclosed, pending: m.phonePending <> invalid, import_phase: importPhase, verify_state: taskState, dialog: m.phoneDialog <> invalid})
        if state <> m.phoneNormalLastState
            m.phoneNormalLastState = state
            print "[setup-phone-normal] "; state
        end if
        if m.phoneDialog = invalid or m.phoneResult = invalid then return
        if m.phoneProfileImport = invalid then finishPhoneNormalProbe(false, "profile-verification") : return
        print "[setup-phone-normal] "; FormatJson({kind: "received", real_listener: true})
        onPhoneSetupChoice(phoneNormalEvent(m.phoneDialog, 0))
        m.phoneNormalPhase = 3
    else if phase = 3
        if m.profilePinDialog <> invalid
            m.phoneNormalPhase = 4
            return
        end if
        if m.profilePicker = invalid then return
        m.profilePicker.intent = {action: userProfilePickerChoice(m.profilePicker.model, 0), index: 0}
        m.phoneNormalPhase = 4
    else if phase = 4
        if m.profilePinDialog = invalid then return
        m.phoneNormalDefaultCovered = m.global.profilegateclosed and m.profileGateCover.visible and m.activeUserScope = invalid
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(phoneNormalEvent(m.profilePinDialog, 0))
        m.phoneNormalPhase = 5
    else if phase = 5
        if m.busy or m.page <> "guide" or m.activeUserScope = invalid then return
        if m.phoneProfileOnboardingDialog = invalid or m.phoneProfileOnboarding = invalid then return
        if m.phoneProfileOnboarding.phase <> "offer" then return
        choice = phoneSetupSyncOfferChoice(m.registry)
        settings = loadDispatcharrSyncSettings(m.registry)
        m.phoneNormalExplicitSync = not choice.enabled and settings.ok and not settings.enabled
        onPhoneProfileOnboardingChoice(phoneNormalEvent(m.phoneProfileOnboardingDialog, 1))
        m.phoneNormalPhase = 6
    else if phase = 6
        if m.phoneProfileOnboardingDialog = invalid then return
        choices = m.phoneProfileOnboardingChoices
        if choices.count() < 1 then return
        if choices[choices.count() - 1].action <> "continue" then finishPhoneNormalProbe(false, "onboarding-actions") : return
        onPhoneProfileOnboardingChoice(phoneNormalEvent(m.phoneProfileOnboardingDialog, choices.count() - 1))
        m.phoneNormalPhase = 7
    else if phase = 7
        store = loadUserProfileStore(m.registry, m.selectedConnectionId)
        m.phoneNormalRetained = store.profiles.count() = 2
        m.phoneNormalRetained = m.phoneNormalRetained and m.selectedConnectionId = "00000000-0000-4000-8000-000000000070"
        m.phoneNormalChild = invalid
        for each profile in store.profiles
            if profile.userId = m.phoneNormalDefaultUser
                m.phoneNormalRetained = m.phoneNormalRetained and profile.id = "00000000-0000-4000-8000-000000000007"
                m.phoneNormalRetained = m.phoneNormalRetained and profile.isDefault and profile.pinType = "numbers" and profile.pinHash = userProfilePinHash(profile.pinSalt, "1234")
                m.phoneNormalRetained = m.phoneNormalRetained and phoneSetupProfileRootHash(m.registry.read(connectionRegistryKey(m.selectedConnectionId))) = m.phoneNormalDefaultKeyHash
            else if profile.userId = m.phoneNormalSecondaryUser
                m.phoneNormalRetained = m.phoneNormalRetained and profile.id = "00000000-0000-4000-8000-000000000009"
                m.phoneNormalChild = profile
                m.phoneNormalRetained = m.phoneNormalRetained and profile.role = m.phoneNormalExpectedRole
                if m.phoneNormalExpectedRole = "child"
                    m.phoneNormalRetained = m.phoneNormalRetained and profile.pinType = "directions" and profile.pinHash = userProfilePinHash(profile.pinSalt, "UDLR")
                end if
                m.phoneNormalRetained = m.phoneNormalRetained and phoneSetupProfileRootHash(m.registry.read(userProfileKeyName(m.selectedConnectionId, profile.id))) = m.phoneNormalSecondaryKeyHash
            end if
        end for
        choice = phoneSetupSyncOfferChoice(m.registry)
        m.phoneNormalExplicitSync = m.phoneNormalExplicitSync and not choice.enabled and choice.declined
        if not m.phoneNormalRetained or m.phoneNormalChild = invalid then finishPhoneNormalProbe(false, "retained-profiles") : return
        if not beginUserProfileSwitch(m.phoneNormalChild.id) then finishPhoneNormalProbe(false, "child-selection") : return
        m.phoneNormalPhase = 8
    else if phase = 8
        if m.phoneNormalExpectedRole = "user"
            m.phoneNormalChildCovered = true
            m.phoneNormalPhase = 9
            return
        end if
        if m.profilePinDialog = invalid then return
        m.phoneNormalChildCovered = m.global.profilegateclosed and m.profileGateCover.visible and m.profileSwitchTask = invalid
        m.profilePinDialog.textEditBox.text = "up down left right"
        onProfilePinSubmit(phoneNormalEvent(m.profilePinDialog, 0))
        m.phoneNormalPhase = 9
    else if phase = 9
        if m.busy or m.page <> "guide" or m.activeUserScope = invalid or m.capabilityTask <> invalid then return
        passed = m.phoneNormalRetained and m.phoneNormalExplicitSync and m.phoneNormalDefaultCovered and m.phoneNormalChildCovered
        passed = passed and m.activeUserScope.accountId = m.phoneNormalSecondaryUser.toStr() and currentUserSettingsRole() = m.phoneNormalExpectedRole and m.playingChannel = invalid
        finishPhoneNormalProbe(passed, "complete")
    end if
end sub

sub finishPhoneNormalProbe(passed as boolean, stage as string)
    m.phoneNormalClock.control = "stop"
    childPinPassed = invalid
    if m.phoneNormalExpectedRole = "child" then childPinPassed = m.phoneNormalChildCovered
    print "[setup-phone-normal] "; FormatJson({kind: "result", passed: passed, stage: stage, default_pin: m.phoneNormalDefaultCovered, child_pin: childPinPassed, secondary_role: m.phoneNormalExpectedRole, profiles_retained: m.phoneNormalRetained, explicit_sync: m.phoneNormalExplicitSync, fault_checks: m.phoneNormalChecks})
end sub
