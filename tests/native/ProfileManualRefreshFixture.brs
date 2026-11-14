' Manual refresh must retire changed authority, not merely replace channels.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        m.manualOldSession = currentUserSessionId()
        m.manualProfile = m.activeUserScope.profileId
        m.manualStarted = m.activeUserScope.accountId = "8" and m.guide.callFunc("profileSwitchProbeLineup") = "8"
        print "[profile-management] "; FormatJson({kind: "assignment-ready", own: m.manualStarted})
        m.managementProbePhase = 1
    else if phase = 1
        refreshChannelLineup()
        m.managementProbePhase = 2
    else
        if m.busy or m.refreshTask <> invalid or m.capabilityTask <> invalid then return
        m.managementProbeClock.control = "stop"
        own = m.activeUserScope <> invalid
        if own then own = m.activeUserScope.profileId = m.manualProfile and m.activeUserScope.accountId = "8"
        retired = currentUserSessionId() <> m.manualOldSession and not userEventCurrent(userViewEvent({action: "connection"}, m.manualOldSession))
        lineup = m.guide.callFunc("profileSwitchProbeLineup") = "80"
        credentials = m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.manualProfile)) = "synthetic-b"
        print "[profile-management] "; FormatJson({kind: "result", passed: m.manualStarted and own and retired and lineup and credentials and m.capabilities.movies = "denied" and m.playingChannel = invalid, own: own, retired: retired, lineup: lineup, credentials: credentials, movies_denied: m.capabilities.movies = "denied", no_autoplay: m.playingChannel = invalid})
    end if
end sub
