' Native feasibility fixture. Temporarily import in AerioScene and call installer;
' copy TimeshiftProbeTask.* as well. Remove all hooks after capture.
' Optional manifest timeshift_probe_restart_only=1 skips the one-minute pause run.
sub installTimeshiftProbe()
    m.timeProbeStage = 0
    m.timeProbeTicks = 0
    m.timeProbePeak = 0
    m.timeProbeMemory = CreateObject("roAppMemoryMonitor")
    m.timeProbeTimer = m.top.createChild("Timer")
    m.timeProbeTimer.duration = 1
    m.timeProbeTimer.repeat = true
    m.timeProbeTimer.observeField("fire", "timeshiftProbeTick")
    m.timeProbeTimer.control = "start"
    m.timeProbeVideo = m.top.createChild("Video")
    m.timeProbeVideo.width = 1920
    m.timeProbeVideo.height = 1080
    m.timeProbeVideo.visible = false
    m.timeProbeVideo.enableUI = false
end sub

function timeProbeTask(operation as string) as object
    task = CreateObject("roSGNode", "TimeshiftProbeTask")
    task.baseUrl = m.baseUrl
    task.apiKey = m.apiKey
    task.accountId = m.serverAccountId
    task.channelUuid = m.timeProbeChannel.uuid
    task.operation = operation
    return task
end function

sub sampleTimeshift(label as string)
    v = m.timeProbeVideo
    print "[timeshift-probe] "; FormatJson({label: label, second: m.timeProbeTicks, state: v.state, position: v.position, duration: v.duration, pauseStart: v.pauseBufferStart, pauseEnd: v.pauseBufferEnd, overflow: v.pauseBufferOverflow, positionInfo: v.positionInfo, memoryPercent: m.timeProbeMemory.getMemoryLimitPercent(), availableKB: m.timeProbeMemory.getChannelAvailableMemory()})
end sub

sub timeshiftProbeTick()
    m.timeProbeTicks++
    percent = m.timeProbeMemory.getMemoryLimitPercent()
    if percent > m.timeProbePeak then m.timeProbePeak = percent
    if m.timeProbeTicks > 230
        print "[timeshift-probe] timeout stage="; m.timeProbeStage
        finishTimeshiftProbe()
        return
    end if
    if m.timeProbeStage = 0
        if m.capabilities.catchup <> "allowed" then return
        now = uiNow()
        for each channel in m.guide.config.channels
            if instr(1, lcase(channel.name), "espn") > 0 and m.channelFacts.doesExist(channel.id)
                if m.channelFacts[channel.id].catchupDays > 0
                    info = m.guide.callFunc("cachedPlaybackInfo", channel, now)
                    for each program in info.programs
                        if program.startsAt < now - 300 and program.endsAt > now
                            m.timeProbeChannel = channel
                            m.timeProbeProgram = program
                            exit for
                        end if
                    end for
                    if m.timeProbeChannel <> invalid then exit for
                end if
            end if
        end for
        if m.timeProbeChannel = invalid then return
        print "[timeshift-probe] current-program ageSeconds="; now - m.timeProbeProgram.startsAt; " remainingSeconds="; m.timeProbeProgram.endsAt - now
        m.timeProbeStatus = timeProbeTask("status")
        m.timeProbeStatus.control = "RUN"
        m.timeProbeStage = 1
    else if m.timeProbeStage = 1
        if type(m.timeProbeStatus.result) <> "roAssociativeArray" then return
        result = m.timeProbeStatus.result
        print "[timeshift-probe] baseline-known="; result.ok; " clients="; result.count
        m.timeProbeBaseline = invalid
        if result.ok then m.timeProbeBaseline = result.clients
        if CreateObject("roAppInfo").getValue("timeshift_probe_restart_only") = "1"
            m.timeProbeStoppedAt = m.timeProbeTicks - 8
            m.timeProbeStage = 5
            return
        end if
        content = CreateObject("roSGNode", "ContentNode")
        content.setFields(livePlaybackDescriptor(m.baseUrl, m.timeProbeChannel))
        content.streamFormat = "ts"
        content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
        content.httpHeaders = mediaPlaybackHeaders(m.apiKey)
        m.guide.active = false
        m.guide.visible = false
        m.timeProbeVideo.content = content
        m.timeProbeVideo.visible = true
        m.timeProbeVideo.control = "play"
        m.timeProbeStage = 2
    else if m.timeProbeStage = 2
        if m.timeProbeVideo.state <> "playing" then return
        sampleTimeshift("live-playing")
        m.timeProbePauseAt = m.timeProbeTicks
        m.timeProbeVideo.control = "pause"
        m.timeProbeStage = 3
    else if m.timeProbeStage = 3
        elapsed = m.timeProbeTicks - m.timeProbePauseAt
        if elapsed = 1 or elapsed = 30 or elapsed = 60 then sampleTimeshift("live-paused")
        if elapsed = 30
            m.timeProbeStatus = timeProbeTask("status")
            m.timeProbeStatus.control = "RUN"
        end if
        if elapsed < 60 then return
        if type(m.timeProbeStatus.result) = "roAssociativeArray" then print "[timeshift-probe] paused-clients="; m.timeProbeStatus.result.count
        m.timeProbeVideo.control = "resume"
        m.timeProbeResumeAt = m.timeProbeTicks
        m.timeProbeStage = 4
    else if m.timeProbeStage = 4
        if m.timeProbeTicks - m.timeProbeResumeAt < 10 then return
        sampleTimeshift("live-resumed")
        m.timeProbeVideo.control = "stop"
        m.timeProbeVideo.content = invalid
        m.timeProbeStoppedAt = m.timeProbeTicks
        m.timeProbeStage = 5
    else if m.timeProbeStage = 5
        if m.timeProbeTicks - m.timeProbeStoppedAt < 8 then return
        m.timeProbeStatus = timeProbeTask("status")
        m.timeProbeStatus.control = "RUN"
        m.timeProbeTask = timeProbeTask("restart")
        m.timeProbeTask.startEpoch = m.timeProbeProgram.startsAt
        m.timeProbeTask.durationMinutes = int((uiNow() - m.timeProbeProgram.startsAt + 59) / 60)
        m.timeProbeTask.control = "RUN"
        m.timeProbeStage = 6
    else if m.timeProbeStage = 6
        if type(m.timeProbeTask.result) <> "roAssociativeArray" then return
        result = m.timeProbeTask.result
        print "[timeshift-probe] restart-create="; result.status; " ongoing="; m.timeProbeProgram.endsAt > uiNow()
        if not result.ok
            finishTimeshiftProbe()
            return
        end if
        m.timeProbeSession = result.sessionId
        m.guide.active = false
        m.guide.visible = false
        m.timeProbeVideo.visible = true
        content = CreateObject("roSGNode", "ContentNode")
        content.url = result.url
        content.streamFormat = "ts"
        content.live = false
        content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
        content.httpHeaders = mediaPlaybackHeaders(m.apiKey)
        m.timeProbeVideo.content = content
        m.timeProbeVideo.control = "play"
        m.timeProbeRestartAt = m.timeProbeTicks
        m.timeProbeStage = 7
    else if m.timeProbeStage = 7
        if m.timeProbeVideo.state = "playing"
            sampleTimeshift("ongoing-restart-playing")
            print "[timeshift-probe] original-start-echo-matches="; guideEpoch(m.timeProbeTask.result.echoedStart) = m.timeProbeProgram.startsAt
            m.timeProbeNearLivePending = true
            finishTimeshiftProbe()
        else if m.timeProbeVideo.state = "error" or m.timeProbeTicks - m.timeProbeRestartAt > 30
            print "[timeshift-probe] restart-failure="; m.timeProbeVideo.errorCode; " detail="; sanitizePlaybackDiagnostic(m.timeProbeVideo.errorStr, m.apiKey)
            finishTimeshiftProbe()
        end if
    else if m.timeProbeStage = 9
        if type(m.timeProbeCleanup.result) <> "roAssociativeArray" then return
        print "[timeshift-probe] delete="; m.timeProbeCleanup.result.status
        if m.timeProbeNearLivePending = true
            m.timeProbeNearLivePending = false
            m.timeProbeTask = timeProbeTask("restart")
            m.timeProbeTask.startEpoch = uiNow() - 120
            m.timeProbeTask.durationMinutes = 2
            m.timeProbeTask.control = "RUN"
            m.timeProbeStage = 10
        else
            completeTimeshiftProbe()
        end if
    else if m.timeProbeStage = 10
        if type(m.timeProbeTask.result) <> "roAssociativeArray" then return
        result = m.timeProbeTask.result
        print "[timeshift-probe] near-live-create="; result.status
        if not result.ok
            completeTimeshiftProbe()
            return
        end if
        m.timeProbeSession = result.sessionId
        content = CreateObject("roSGNode", "ContentNode")
        content.url = result.url
        content.streamFormat = "ts"
        content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
        content.httpHeaders = mediaPlaybackHeaders(m.apiKey)
        m.timeProbeVideo.content = content
        m.timeProbeVideo.control = "play"
        m.timeProbeRestartAt = m.timeProbeTicks
        m.timeProbeStage = 11
    else if m.timeProbeStage = 11
        if m.timeProbeVideo.state = "playing"
            sampleTimeshift("near-live-window-playing")
            finishTimeshiftProbe()
        else if m.timeProbeVideo.state = "error" or m.timeProbeTicks - m.timeProbeRestartAt > 30
            print "[timeshift-probe] near-live-failure="; m.timeProbeVideo.errorCode; " detail="; sanitizePlaybackDiagnostic(m.timeProbeVideo.errorStr, m.apiKey)
            finishTimeshiftProbe()
        end if
    end if
end sub

sub finishTimeshiftProbe()
    m.timeProbeVideo.control = "stop"
    m.timeProbeVideo.content = invalid
    m.timeProbeVideo.visible = false
    if m.timeProbeSession <> invalid
        m.timeProbeCleanup = timeProbeTask("delete")
        m.timeProbeCleanup.sessionId = m.timeProbeSession
        m.timeProbeCleanup.control = "RUN"
        m.timeProbeSession = invalid
        m.timeProbeStage = 9
    else
        completeTimeshiftProbe()
    end if
end sub

sub completeTimeshiftProbe()
    if m.timeProbeStatus <> invalid
        result = m.timeProbeStatus.result
        if type(result) = "roAssociativeArray"
            print "[timeshift-probe] after-live-clients="; result.count
            if result.ok and m.timeProbeBaseline <> invalid
                missing = 0
                for each id in m.timeProbeBaseline
                    if not result.clients.doesExist(id) then missing++
                end for
                print "[timeshift-probe] missing-baseline-clients="; missing
            end if
        end if
    end if
    m.guide.visible = true
    m.guide.active = true
    m.timeProbeTimer.control = "stop"
    print "[timeshift-probe] complete peak="; m.timeProbePeak
end sub
