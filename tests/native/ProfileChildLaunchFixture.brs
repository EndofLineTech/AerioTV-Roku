' Cold protected/held Child: its own launch PIN precedes unavailable controls.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.childLaunchDiagnostic <> true
            m.childLaunchDiagnostic = true
            store = loadUserProfileStore(m.registry, "slot-a")
            gate = selectedUserProfileGate()
            print "[profile-management] gate="; gate.reason; " readonly="; store.readOnly; " count="; store.profiles.count(); " page="; m.page
        end if
        if m.profilePinDialog = invalid then return
        m.childLaunchPassed = m.childUnavailableDialog = invalid and m.profileManagementDialog = invalid and m.task = invalid and m.activeUserScope = invalid and m.profileGateCover.visible and m.global.profilegateclosed
        print "[profile-management] "; FormatJson({kind: "launch_pin", covered: m.childLaunchPassed})
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        m.managementProbePhase = 1
    else if phase = 1
        if m.childUnavailableDialog = invalid then return
        store = loadUserProfileStore(m.registry, "slot-a")
        m.childLaunchPassed = m.childLaunchPassed and store.active = store.profiles[1].id and m.activeUserScope = invalid and m.task = invalid and m.childUnavailableDialog.buttons.count() = 1 and m.childUnavailableDialog.buttons[0] = "Manage Profiles"
        m.childLaunchPassed = m.childLaunchPassed and instr(1, m.childUnavailableDialog.title + m.childUnavailableDialog.message, "Synthetic7") = 0 and instr(1, m.childUnavailableDialog.title + m.childUnavailableDialog.message, "Synthetic8") = 0
        onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, 0))
        m.childLaunchPassed = m.childLaunchPassed and m.adultPinDialog <> invalid and m.profileManagementDialog = invalid
        m.adultPinDialog.textEditBox.text = "1234"
        onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 0))
        m.childLaunchPassed = m.childLaunchPassed and m.profileManagementDialog <> invalid
        m.managementProbeClock.control = "stop"
        print "[profile-management] "; FormatJson({kind: "launch-safe", passed: m.childLaunchPassed, covered: m.profileGateCover.visible, own_pin_then_adult: m.profileManagementGrant <> invalid, no_scope: m.activeUserScope = invalid, no_autoplay: m.playingChannel = invalid})
        onProfileManagementClosed(managementProbeEvent(m.profileManagementDialog, 0))
        if m.childUnavailableDialog = invalid
            print "[profile-management] "; FormatJson({kind: "result", exited: false})
            return
        end if
        print "[profile-management] "; FormatJson({kind: "cancel-ready"})
    end if
end sub
