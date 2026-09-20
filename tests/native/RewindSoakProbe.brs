' Temporary native-only 60-minute retention/seek experiment. No shared stop.
sub installRewindSoakProbe()
    m.soakStage = 0
    m.soakTicks = 0
    m.soakMemory = CreateObject("roAppMemoryMonitor")
    m.soakClock = CreateObject("roTimespan")
    m.soakClock.mark()
    m.soakVideo = m.top.createChild("Video")
    m.soakVideo.width = 1920
    m.soakVideo.height = 1080
    m.soakVideo.enableUI = false
    m.soakVideo.enableScreenSaverWhilePlaying = false
    m.soakVideo.visible = false
    m.soakTimer = m.top.createChild("Timer")
    m.soakTimer.duration = 1
    m.soakTimer.repeat = true
    m.soakTimer.observeField("fire", "rewindSoakTick")
    m.soakTimer.control = "start"
end sub

function soakStatusTask() as object
    task = CreateObject("roSGNode", "TimeshiftProbeTask")
    task.baseUrl = m.baseUrl
    task.apiKey = m.apiKey
    task.channelUuid = m.soakChannel.uuid
    task.operation = "status"
    task.control = "RUN"
    return task
end function

sub reportRewindSoak(label as string)
    v = m.soakVideo
    print "[rewind-soak] "; FormatJson({label: label, wallSeconds: m.soakClock.totalSeconds(), state: v.state, position: v.position, duration: v.duration, start: v.pauseBufferStart, end: v.pauseBufferEnd, overflow: v.pauseBufferOverflow, memoryPercent: m.soakMemory.getMemoryLimitPercent(), availableKB: m.soakMemory.getChannelAvailableMemory()})
end sub

sub rewindSoakTick()
    m.soakTicks++
    if m.soakStage < 4
        if m.soakMemory.getMemoryLimitPercent() >= 60 or m.soakClock.totalSeconds() > 3800
            reportRewindSoak("resource-or-time-limit")
            stopRewindSoak()
            return
        end if
        if m.soakStage > 1 and (m.soakVideo.state = "error" or m.soakVideo.state = "finished")
            reportRewindSoak("media-ended")
            print "[rewind-soak] code="; m.soakVideo.errorCode; " detail="; sanitizePlaybackDiagnostic(m.soakVideo.errorStr, m.apiKey)
            stopRewindSoak()
            return
        end if
    end if
    if m.soakStage = 0
        if m.guide.config = invalid or m.page <> "guide" then return
        for each channel in m.guide.config.channels
            if channel.number = "3.3" then m.soakChannel = channel
        end for
        if m.soakChannel = invalid then return
        m.soakStatus = soakStatusTask()
        m.soakStage = 1
    else if m.soakStage = 1
        if type(m.soakStatus.result) <> "roAssociativeArray" then return
        m.soakBaseline = m.soakStatus.result
        print "[rewind-soak] baseline-known="; m.soakBaseline.ok; " clients="; m.soakBaseline.count
        content = CreateObject("roSGNode", "ContentNode")
        content.setFields(livePlaybackDescriptor(m.baseUrl, m.soakChannel))
        content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
        content.httpHeaders = mediaPlaybackHeaders(m.apiKey)
        m.soakVideo.content = content
        m.guide.active = false
        m.guide.visible = false
        m.soakVideo.visible = true
        m.soakVideo.control = "play"
        m.soakStage = 2
    else if m.soakStage = 2
        if m.soakVideo.state <> "playing" then return
        if m.soakPlayingAt = invalid
            m.soakPlayingAt = m.soakClock.totalSeconds()
            reportRewindSoak("first-playing")
        end if
        if m.soakTicks mod 60 = 0 then reportRewindSoak("live-minute")
        if m.soakClock.totalSeconds() - m.soakPlayingAt < 3610 then return
        reportRewindSoak("before-hour-rewind")
        m.soakTarget = m.soakVideo.position - 3600
        if m.soakTarget < 0 then m.soakTarget = 0
        print "[rewind-soak] seek-target="; m.soakTarget
        m.soakVideo.seek = m.soakTarget
        m.soakSeekAt = m.soakClock.totalSeconds()
        m.soakStage = 3
    else if m.soakStage = 3
        if m.soakClock.totalSeconds() - m.soakSeekAt < 15 then return
        reportRewindSoak("after-hour-rewind")
        stopRewindSoak()
    else if m.soakStage = 4
        if m.soakClock.totalSeconds() - m.soakStoppedAt < 10 then return
        m.soakStatus = soakStatusTask()
        m.soakStage = 5
    else if m.soakStage = 5
        if type(m.soakStatus.result) <> "roAssociativeArray" then return
        result = m.soakStatus.result
        print "[rewind-soak] final-known="; result.ok; " clients="; result.count
        if result.ok and m.soakBaseline.ok
            missing = 0
            for each id in m.soakBaseline.clients
                if not result.clients.doesExist(id) then missing++
            end for
            print "[rewind-soak] missing-baseline-clients="; missing
        end if
        m.guide.visible = true
        m.guide.active = true
        m.soakTimer.control = "stop"
        print "[rewind-soak] complete"
    end if
end sub

sub stopRewindSoak()
    m.soakVideo.control = "stop"
    m.soakVideo.content = invalid
    m.soakVideo.visible = false
    m.soakStoppedAt = m.soakClock.totalSeconds()
    m.soakStage = 4
end sub
