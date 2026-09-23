' Temporary native-only probe. Exactly one future server schedule is created,
' checked and cancelled. Never log auth, URL, channel or program metadata.
sub installDvrRecordingProbe()
    m.dvrProbeStage = "wait"
    m.dvrProbeTicks = 0
    m.dvrProbeCreated = ""
    m.dvrProbeTask = invalid
    m.dvrProbeTimer = m.top.createChild("Timer")
    m.dvrProbeTimer.duration = 1
    m.dvrProbeTimer.repeat = true
    m.dvrProbeTimer.observeField("fire", "dvrProbeTick")
    m.dvrProbeTimer.control = "start"
end sub

sub dvrProbeTick()
    m.dvrProbeTicks++
    if m.dvrProbeTicks > 90
        print "[dvr-probe] timeout stage="; m.dvrProbeStage; " cleanup-needed="; m.dvrProbeCreated <> ""
        m.dvrProbeTimer.control = "stop"
        return
    end if
    if m.dvrProbeStage <> "wait" or m.page <> "guide" then return
    if m.capabilities.dvr <> "manage"
        if m.capabilities.dvr = "unknown" then return
        print "[dvr-probe] unavailable: no manage capability"
        m.dvrProbeTimer.control = "stop"
        return
    end if
    now = uiNow()
    channels = m.guide.config.channels
    maximum = channels.count() - 1
    if maximum > 9 then maximum = 9
    for i = 0 to maximum
        channel = channels[i]
        if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(channel.id) then exit for
        info = m.guide.callFunc("cachedPlaybackInfo", channel, now)
        if info.status = "ready"
            for each program in info.programs
                if program.startsAt > now + 1200 and program.startsAt < now + 7200 and program.endsAt > program.startsAt
                    if CreateObject("roRegex", "^[0-9]{1,10}$", "").isMatch(program.id)
                        m.dvrProbeChannelId = channel.id
                        m.dvrProbeProgram = program
                        m.dvrProbeStage = "schedule"
                        print "[dvr-probe] future candidate found start-type="; type(program.startsAt); " end-type="; type(program.endsAt)
                        dvrProbeRun("schedule")
                        return
                    end if
                end if
            end for
        end if
    end for
end sub

sub dvrProbeRun(action as string)
    task = CreateObject("roSGNode", "DvrRecordingTask")
    task.baseUrl = m.baseUrl
    task.apiKey = m.apiKey
    task.channelId = m.dvrProbeChannelId
    task.program = m.dvrProbeProgram
    task.recordingId = m.dvrProbeCreated
    task.preRoll = 0
    task.postRoll = 0
    task.action = action
    m.dvrProbeTask = task
    task.observeField("result", "onDvrProbeResult")
    task.control = "RUN"
end sub

sub onDvrProbeResult(event as object)
    if not isCurrentTaskEvent(event, m.dvrProbeTask) then return
    result = event.getData()
    m.dvrProbeTask.unobserveField("result")
    m.dvrProbeTask = invalid
    if m.dvrProbeStage = "schedule"
        if not result.ok
            reason = "other"
            if result.message = "Program times or ID are missing." then reason = "program-type-or-id"
            if result.message = "Select a valid channel and program." then reason = "channel-or-program"
            if result.message = "Invalid program time range." then reason = "time-range"
            if result.message = "The selected program has ended." then reason = "ended"
            if result.message = "The server did not return a JSON list." then reason = "list-not-json"
            if result.message = "Unexpected recording response; check the server before retrying." then reason = "response-shape"
            print "[dvr-probe] schedule refused reason="; reason; " category="; textValue(result.category)
            m.dvrProbeTimer.control = "stop"
            return
        end if
        m.dvrProbeCreated = result.recording.id
        m.dvrProbeStage = "status"
        print "[dvr-probe] scheduled one future recording"
        dvrProbeRun("status")
    else if m.dvrProbeStage = "status"
        match = result.ok and result.recording.channelId = m.dvrProbeChannelId and result.recording.programId = m.dvrProbeProgram.id
        print "[dvr-probe] status identity match="; match
        m.dvrProbeStage = "cancel"
        dvrProbeRun("cancel")
    else if m.dvrProbeStage = "cancel"
        if not result.ok
            print "[dvr-probe] cancellation failed category="; textValue(result.category); " cleanup-needed id="; m.dvrProbeCreated
            m.dvrProbeTimer.control = "stop"
            return
        end if
        m.dvrProbeStage = "verifyRemoval"
        print "[dvr-probe] cancelled newly created future recording"
        dvrProbeRun("status")
    else if m.dvrProbeStage = "verifyRemoval"
        print "[dvr-probe] removed="; (not result.ok and result.category = "not-found")
        m.dvrProbeStage = "complete"
        m.dvrProbeCreated = ""
        m.dvrProbeTimer.control = "stop"
        print "[dvr-probe] complete"
    end if
end sub
