' Private active-B capability refresh with a real changed assignment/permission.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        m.assignmentBefore = currentUserSessionId()
        m.assignmentProfile = m.activeUserScope.profileId
        m.assignmentStarted = m.activeUserScope.accountId = "8" and m.guide.callFunc("profileSwitchProbeLineup") = "8"
        print "[profile-management] "; FormatJson({kind: "assignment-ready", own: m.assignmentStarted})
        m.managementProbePhase = 1
    else if phase = 1
        refreshCapabilities()
        m.managementProbePhase = 2
    else if phase = 2
        if m.busy or m.capabilityTask <> invalid then return
        if currentUserSessionId() = m.assignmentBefore then return
        m.managementProbeClock.control = "stop"
        store = loadUserProfileStore(m.registry, "slot-a")
        own = m.activeUserScope <> invalid
        if own then own = m.activeUserScope.accountId = "8" and m.activeUserScope.profileId = m.assignmentProfile and store.active = m.assignmentProfile
        lineup = m.guide.callFunc("profileSwitchProbeLineup") = "80"
        preserved = m.accountPreferences.favoriteIds.count() = 1 and m.devicePreferences.themePreset = "forest" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.assignmentProfile)) = "synthetic-b"
        if preserved then preserved = m.accountPreferences.favoriteIds[0] = "00000000-0000-4000-8000-000000000008"
        retired = not userEventCurrent(userViewEvent({action: "connection"}, m.assignmentBefore))
        print "[profile-management] "; FormatJson({kind: "result", passed: m.assignmentStarted and own and lineup and preserved and retired and m.capabilities.movies = "denied" and m.playingChannel = invalid, own: own, lineup: lineup, preserved: preserved, retired: retired, movies_denied: m.capabilities.movies = "denied", no_autoplay: m.playingChannel = invalid})
    end if
end sub
