' Manual refresh must retire changed authority, not merely replace channels.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        if MANUAL_RECORDING and m.manualRecordStarted <> true
            m.manualRecordStarted = true
            m.recordTask = CreateObject("roSGNode", "DvrRecordingTask")
            tagTaskForCurrentUser(m.recordTask)
            m.recordAccount = m.accountIdentity
            m.recordScope = textValue(m.guide.config.scope)
            m.recordTask.baseUrl = m.baseUrl
            m.recordTask.apiKey = m.apiKey
            m.recordTask.accountId = m.serverAccountId
            m.recordTask.action = "schedule"
            m.recordTask.channelId = "8"
            now = CreateObject("roDateTime").asSeconds()
            m.recordTask.program = {id: "synthetic-program", title: "Synthetic program", startsAt: now + 600, endsAt: now + 3600}
            m.recordTask.observeField("result", "onRecordScheduled")
            m.recordTask.control = "RUN"
            return
        end if
        if MANUAL_RECORDING
            if m.recordTask = invalid
                m.managementProbeClock.control = "stop"
                print "[profile-management] "; FormatJson({kind: "result", passed: false, submitted_marker: false})
                return
            end if
            if m.recordTask.scheduleSubmitted <> true then return
        end if
        m.manualOldSession = currentUserSessionId()
        m.manualProfile = m.activeUserScope.profileId
        m.manualRoster = m.registry.read(userProfileStoreKey("slot-a"))
        m.manualSettings = m.registry.read("settingsV1")
        m.manualStarted = m.activeUserScope.accountId = "8" and m.guide.callFunc("profileSwitchProbeLineup") = "8"
        print "[profile-management] "; FormatJson({kind: "assignment-ready", own: m.manualStarted})
        m.managementProbePhase = 1
    else if phase = 1
        refreshChannelLineup()
        m.managementProbePhase = 2
    else
        if m.busy or m.refreshTask <> invalid or m.capabilityTask <> invalid then return
        if MANUAL_RECORDING
            if m.recordSettlementTask <> invalid or m.recordTask <> invalid then return
            if type(m.recordSettlementOutcomes) = "roAssociativeArray"
                if m.recordSettlementOutcomes.count() > 0 then return
            end if
        end if
        m.managementProbeClock.control = "stop"
        if MANUAL_IDENTITY
            safe = m.activeUserScope = invalid and currentUserSessionId() = "" and m.apiKey = "" and m.global.profilegateclosed and m.profileGateCover.visible and m.profileRecoveryDialog <> invalid
            preserved = m.registry.read(userProfileStoreKey("slot-a")) = m.manualRoster and m.registry.read("settingsV1") = m.manualSettings and m.registry.read("connKey_slot-a") = "synthetic-a" and not m.registry.exists(userProfileKeyName("slot-a", m.manualProfile))
            print "[profile-management] "; FormatJson({kind: "result", passed: m.manualStarted and safe and preserved, recovery: safe, preserved: preserved})
            return
        end if
        if MANUAL_UNCHANGED or MANUAL_TRANSIENT
            safe = m.activeUserScope <> invalid and currentUserSessionId() = m.manualOldSession and m.guide.callFunc("profileSwitchProbeLineup") = "8"
            if safe then safe = m.activeUserScope.profileId = m.manualProfile and m.activeUserScope.accountId = "8"
            recording = true
            if MANUAL_RECORDING then recording = m.manualRecordingSettled = true
            preserved = m.registry.read(userProfileStoreKey("slot-a")) = m.manualRoster and m.registry.read("settingsV1") = m.manualSettings
            print "[profile-management] "; FormatJson({kind: "result", passed: m.manualStarted and safe and preserved and recording, same_session: safe, preserved: preserved, roster_exact: m.registry.read(userProfileStoreKey("slot-a")) = m.manualRoster, settings_exact: m.registry.read("settingsV1") = m.manualSettings, recording_settled: recording})
            return
        end if
        own = m.activeUserScope <> invalid
        if own then own = m.activeUserScope.profileId = m.manualProfile and m.activeUserScope.accountId = "8"
        retired = currentUserSessionId() <> m.manualOldSession and not userEventCurrent(userViewEvent({action: "connection"}, m.manualOldSession))
        lineup = m.guide.callFunc("profileSwitchProbeLineup") = "80"
        credentials = m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.manualProfile)) = "synthetic-b"
        recording = true
        if MANUAL_RECORDING then recording = m.manualRecordingSettled = true
        print "[profile-management] "; FormatJson({kind: "result", passed: m.manualStarted and own and retired and lineup and credentials and recording and m.capabilities.movies = "denied" and m.playingChannel = invalid, own: own, retired: retired, lineup: lineup, credentials: credentials, recording_settled: recording, movies_denied: m.capabilities.movies = "denied", no_autoplay: m.playingChannel = invalid})
    end if
end sub
