' Exercise the real startup/reconnect controller, not the switch controller.
sub onManagementProbeTick()
    if m.managementProbePhase = 0
        if m.busy or m.page <> "guide" or m.activeUserScope = invalid or m.capabilityTask <> invalid then return
        m.guardCase = OWN_FAULT_CASE
        m.guardStage = "startup-ready"
        m.guardStartupRoot = m.registry.read(userProfileStoreKey("slot-a"))
        m.guardStartupSettings = m.registry.read("settingsV1")
        print "[switch-fault] "; FormatJson({kind: "startup-ready"})
        m.managementProbePhase = 1
    else if m.managementProbePhase = 1
        if m.guardAuthHeld <> true then return
        m.guardStage = "startup-reconnect"
        resetConnectionRuntime()
        applySelectedConnection()
        connectServer(true)
        m.managementProbePhase = 2
    else
        if m.busy or m.task <> invalid then return
        m.guardStage = "authority-refused"
        passed = m.userProfileRecoveryRequired and m.activeUserScope = invalid and m.global.activeusersession = ""
        passed = passed and m.global.profilegateclosed and m.profileGateCover.visible and not m.guide.active
        passed = passed and m.profileRosterContext = invalid and m.profileRosterGrant = invalid and m.profilePinDialog = invalid
        passed = passed and m.registry.read(userProfileStoreKey("slot-a")) = m.guardStartupRoot and m.registry.read("settingsV1") = m.guardStartupSettings
        passed = passed and m.registry.read("connKey_slot-a") = "synthetic-a"
        reportSwitchFault(passed)
    end if
end sub
