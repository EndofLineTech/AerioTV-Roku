' Private one-POST observation across commit, delayed Back, or PIN-stage Back.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        m.probeRecordOldSession = currentUserSessionId()
        m.probeSwitchRecordProfile = m.activeUserScope.profileId
        m.probeSwitchRecordWithheld = true
        m.probeSwitchRecordOtherVisited = false
        m.probeSwitchRecordStarted = m.activeUserScope.accountId = "8" and m.capabilities.dvr = "manage"
        if not m.probeSwitchRecordStarted then failSwitchRecordingProbe() : return
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
        m.recordTask.program = {id: "switch-program", title: "Synthetic switch program", startsAt: now + 600, endsAt: now + 3600}
        m.recordTask.observeField("result", "onRecordScheduled")
        m.probeSwitchRecordNode = m.recordTask
        m.recordTask.control = "RUN"
        m.managementProbePhase = 1
    else if phase = 1
        if m.recordTask = invalid then failSwitchRecordingProbe() : return
        if m.recordTask.scheduleSubmitted <> true then return
        store = loadUserProfileStore(m.registry, "slot-a")
        target = ""
        for each profile in store.profiles
            if profile.isDefault then target = profile.id
        end for
        if target = "" or not beginUserProfileSwitch(target) then failSwitchRecordingProbe() : return
        m.managementProbePhase = 2
    else if phase = 2
        if SWITCH_RECORD_PIN
            if m.profilePinDialog = invalid then failSwitchRecordingProbe() : return
            if m.probeSwitchRecordNode.state <> "done" then return
            covered = m.global.profilegateclosed and m.profileGateCover.visible and m.probeRecordConfirmed <> true and m.recordTask <> invalid and m.recordSettlementTask = invalid
            if type(m.probeSwitchRecordNode.result) <> "roAssociativeArray" then covered = false
            if covered then covered = m.probeSwitchRecordNode.result.ok = true
            print "[profile-management] "; FormatJson({kind: "record-covered", passed: covered})
            if not covered then failSwitchRecordingProbe() : return
            print "[profile-management] "; FormatJson({kind: "cancel-ready"})
            m.managementProbePhase = 3
        else if SWITCH_RECORD_CANCEL
            if m.profileSwitchTask = invalid then failSwitchRecordingProbe() : return
            print "[profile-management] "; FormatJson({kind: "cancel-ready"})
            m.managementProbePhase = 3
        else
            if m.busy or m.capabilityTask <> invalid or m.activeUserScope = invalid then return
            if m.activeUserScope.accountId <> "7" then return
            m.probeSwitchRecordOtherVisited = true
            if m.recordSettlementTask <> invalid then return
            held = m.probeRecordConfirmed <> true and type(m.recordSettlementOutcomes) = "roAssociativeArray"
            if held then held = m.recordSettlementOutcomes.count() = 1
            m.probeSwitchRecordWithheld = held
            print "[profile-management] "; FormatJson({kind: "record-withheld", passed: held})
            if not held then failSwitchRecordingProbe() : return
            if not beginUserProfileSwitch(m.probeSwitchRecordProfile) then failSwitchRecordingProbe() : return
            m.managementProbePhase = 3
        end if
    else
        if m.busy or m.capabilityTask <> invalid or m.page <> "guide" or m.activeUserScope = invalid then return
        if m.activeUserScope.accountId <> "8" or m.profileSwitchContext <> invalid then return
        if m.recordSettlementTask <> invalid or m.probeRecordConfirmed <> true then return
        m.managementProbeClock.control = "stop"
        own = m.activeUserScope.profileId = m.probeSwitchRecordProfile and currentUserSessionId() <> m.probeRecordOldSession and not m.profileGateCover.visible and not m.global.profilegateclosed
        keys = m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.probeSwitchRecordProfile)) = "synthetic-b"
        receipt = m.probeSwitchRecordNode.cancelRequested <> true and m.probeSwitchRecordNode.apiKey = "" and m.recordTask = invalid
        print "[profile-management] "; FormatJson({kind: "result", passed: m.probeSwitchRecordStarted and m.probeSwitchRecordWithheld and own and keys and receipt and m.playingChannel = invalid, own: own, keys_preserved: keys, receipt_only: receipt, other_visited: m.probeSwitchRecordOtherVisited, no_autoplay: m.playingChannel = invalid})
    end if
end sub

sub failSwitchRecordingProbe()
    m.managementProbeClock.control = "stop"
    print "[profile-management] "; FormatJson({kind: "result", passed: false})
end sub
