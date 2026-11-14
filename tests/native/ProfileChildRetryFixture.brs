' Private Child network failure, own Retry, delayed loading Back and retry again.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if OWN_CHILD_PIN and m.childRetryPinDone <> true
            if m.profilePinDialog = invalid then return
            m.childRetryPinDone = true
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
            return
        end if
        if m.childUnavailableDialog = invalid then return
        store = loadUserProfileStore(m.registry, "slot-a")
        m.childRetryProfile = store.active
        m.childRetryRoster = m.registry.read(userProfileStoreKey("slot-a"))
        m.childRetryPassed = childRetryUnavailable()
        print "[profile-management] "; FormatJson({kind: "retry-ready", passed: m.childRetryPassed})
        onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, 0))
        m.managementProbePhase = 1
    else if phase = 1
        if m.page <> "profile-loading" or m.task = invalid then return
        print "[profile-management] "; FormatJson({kind: "cancel-ready"})
        m.managementProbePhase = 2
    else if phase < 8
        m.managementProbePhase++
    else if phase = 8
        cancelled = childRetryUnavailable() and m.task = invalid and m.profileRosterContext = invalid and m.profileRosterGrant = invalid and m.childRetryRoster = m.registry.read(userProfileStoreKey("slot-a"))
        m.childRetryPassed = m.childRetryPassed and cancelled
        print "[profile-management] "; FormatJson({kind: "retry-cancelled", passed: cancelled})
        if not cancelled
            m.managementProbeClock.control = "stop"
            print "[profile-management] "; FormatJson({kind: "result", passed: false})
            return
        end if
        onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, 0))
        m.managementProbePhase = 9
    else
        if m.busy or m.capabilityTask <> invalid or m.page <> "guide" or m.activeUserScope = invalid then return
        m.managementProbeClock.control = "stop"
        own = m.activeUserScope.profileId = m.childRetryProfile and m.activeUserScope.accountId = OWN_CHILD_ACCOUNT and currentUserSettingsRole() = "child" and not m.profileGateCover.visible
        print "[profile-management] "; FormatJson({kind: "result", passed: m.childRetryPassed and own and m.playingChannel = invalid, own: own, no_autoplay: m.playingChannel = invalid})
    end if
end sub

function childRetryUnavailable() as boolean
    if m.childUnavailableDialog = invalid then return false
    return m.page = "profile-unavailable" and m.childUnavailableDialog.buttons.count() = 2 and m.childUnavailableDialog.buttons[0] = "Retry" and m.apiKey = "" and m.activeUserScope = invalid and currentUserSessionId() = "" and m.global.profilegateclosed and m.profileGateCover.visible and m.top.exitRequested <> true
end function
