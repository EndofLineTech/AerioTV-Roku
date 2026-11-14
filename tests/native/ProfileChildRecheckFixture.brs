' Real-minute rejected Child probe restores only own Retry, never an auth scope.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if OWN_CHILD_PIN and m.profilePinDialog <> invalid
            if m.childProbePinSeen <> true
                m.childProbePinSeen = true
                print "[own-signin] "; FormatJson({kind: "child-pin-ready", covered: m.activeUserScope = invalid and m.global.profilegateclosed})
                return
            end if
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
            return
        end if
        if m.busy or m.capabilityTask <> invalid or m.page <> "guide" then return
        m.childProbeProfile = m.activeUserScope.profileId
        m.childProbeOldSession = currentUserSessionId()
        print "[own-signin] "; FormatJson({kind: "revoke-ready"})
        m.managementProbePhase = 1
    else if phase = 1
        refreshCapabilities()
        m.managementProbePhase = 2
    else if phase = 2
        if m.childRejectedDialog = invalid then return
        count = 1
        if OWN_CHILD_DEFAULT then count = 2
        m.childProbePassed = m.childRejectedDialog.title = "API key no longer valid" and m.childRejectedDialog.buttons.count() = count and m.activeUserScope = invalid and m.apiKey = "" and currentUserSessionId() = "" and m.global.profilegateclosed and m.profileGateCover.visible
        m.childProbeOldNode = m.childRejectedDialog
        onChildRejectedKeyChoice(managementProbeEvent(m.childRejectedDialog, count - 1))
        m.childProbePassed = m.childProbePassed and m.childUnavailableDialog <> invalid and m.profileOwnSignInContext = invalid and m.requestGateBinding <> invalid
        print "[own-signin] "; FormatJson({kind: "recheck-ready", covered: m.childProbePassed})
        m.managementProbePhase = 3
    else if phase = 3
        if m.childUnavailableDialog = invalid then return
        if m.childUnavailableDialog.buttons[0] <> "Retry" then return
        covered = m.activeUserScope = invalid and m.apiKey = "" and currentUserSessionId() = "" and m.global.profilegateclosed and m.profileGateCover.visible and m.requestGateBinding = invalid and m.requestGateRecheck = invalid and textValue(m.global.requestgaterecovery) = "" and m.profileOwnSignInContext = invalid
        onChildRejectedKeyChoice(managementProbeEvent(m.childProbeOldNode, 0))
        m.childProbePassed = m.childProbePassed and covered and m.profileOwnSignInContext = invalid
        print "[own-signin] "; FormatJson({kind: "child-retry-ready", covered: covered, no_form: m.profileOwnSignInContext = invalid})
        onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, 0))
        m.managementProbePhase = 4
    else
        if m.busy or m.capabilityTask <> invalid or m.page <> "guide" or m.activeUserScope = invalid then return
        m.managementProbeClock.control = "stop"
        account = "8"
        theme = "forest"
        if OWN_CHILD_DEFAULT
            account = "7"
            theme = "midnight"
        end if
        own = m.activeUserScope.profileId = m.childProbeProfile and m.activeUserScope.accountId = account and currentUserSettingsRole() = "child" and currentUserSessionId() <> m.childProbeOldSession and not m.profileGateCover.visible
        data = m.accountPreferences.favoriteIds.count() = 1 and m.devicePreferences.themePreset = theme
        if data then data = m.accountPreferences.favoriteIds[0] = "00000000-0000-4000-8000-" + right("000000000000" + account, 12)
        credentials = m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002")) = "synthetic-b"
        print "[own-signin] "; FormatJson({kind: "result", passed: m.childProbePassed and own and data and credentials and m.playingChannel = invalid, own: own, data: data, credentials: credentials, no_autoplay: m.playingChannel = invalid})
    end if
end sub
