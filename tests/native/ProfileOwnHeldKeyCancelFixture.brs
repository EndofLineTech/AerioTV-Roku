' Private broker acknowledgement delay: Cancel must invalidate proof before commit.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        m.heldCancelProfile = m.activeUserScope.profileId
        m.heldCancelRoster = m.registry.read(userProfileStoreKey("slot-a"))
        m.heldCancelSettings = m.registry.read("settingsV1")
        print "[own-signin] "; FormatJson({kind: "revoke-ready"})
        m.managementProbePhase = 1
    else if phase = 1
        refreshCapabilities()
        m.managementProbePhase = 2
    else if phase = 2
        if m.capabilityTask <> invalid then return
        if m.profileRecoveryDialog = invalid then return
        onActiveUserProfileRecoveryChoice(managementProbeEvent(m.profileRecoveryDialog, 0))
        if m.profileOwnSignInContext = invalid then return
        m.profileOwnSignInContext.password = "synthetic-correct"
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 2))
        m.managementProbePhase = 3
    else if phase = 3
        if m.profileOwnSignInHold = invalid then return
        print "[own-signin] "; FormatJson({kind: "cancel-ready"})
        m.managementProbePhase = 4
    else if phase < 10
        m.managementProbePhase++
    else
        m.managementProbeClock.control = "stop"
        unchanged = m.registry.read(userProfileStoreKey("slot-a")) = m.heldCancelRoster and m.registry.read("settingsV1") = m.heldCancelSettings and not m.registry.exists(userProfileKeyName("slot-a", m.heldCancelProfile)) and m.registry.read("connKey_slot-a") = "synthetic-a"
        retired = m.profileOwnSignInContext = invalid and m.profileOwnSignInHold = invalid and m.global.profileownsigninnonce = "" and m.activeUserScope = invalid and m.apiKey = "" and currentUserSessionId() = "" and m.global.profilegateclosed and m.profileGateCover.visible
        held = m.requestGate.snapshot.keys.count() = 1
        print "[own-signin] "; FormatJson({kind: "result", passed: unchanged and retired and held and m.playingChannel = invalid, unchanged: unchanged, retired: retired, held: held, no_autoplay: m.playingChannel = invalid})
    end if
end sub
