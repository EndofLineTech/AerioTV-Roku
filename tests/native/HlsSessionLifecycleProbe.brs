' One temporary tune on the authorized saved Dispatcharr connection.
sub installHlsSessionLifecycleProbe()
    m.hlsLifecycleTicks = 0
    m.hlsLifecycleStarted = false
    m.hlsLifecycleSwitched = false
    m.hlsLifecycleStopped = false
    m.hlsLifecyclePlaying = 0
    m.hlsLifecycleTimer = m.top.createChild("Timer")
    m.hlsLifecycleTimer.duration = 1
    m.hlsLifecycleTimer.repeat = true
    m.hlsLifecycleTimer.observeField("fire", "hlsLifecycleTick")
    m.hlsLifecycleTimer.control = "start"
end sub

sub hlsLifecycleTick()
    m.hlsLifecycleTicks++
    if m.hlsLifecycleStopped
        if m.hlsStopTasks.count() = 0
            print "[hls-lifecycle-probe] complete"
            m.hlsLifecycleTimer.control = "stop"
        end if
        return
    end if
    if m.hlsLifecycleTicks > 75
        print "[hls-lifecycle-probe] timeout state="; m.video.state
        stopPlayback()
        m.hlsLifecycleTimer.control = "stop"
        return
    end if
    if not m.hlsLifecycleStarted
        if m.page <> "guide" or m.guide.config = invalid then return
        if m.guide.config.providerType <> "dispatcharr" then return
        if m.guide.config.channels.count() = 0 then return
        m.hlsLifecycleStarted = true
        m.devicePreferences.liveTransport = "hls"
        startPlayback(m.guide.config.channels[0], true)
        print "[hls-lifecycle-probe] tune-started"
    else if m.video.state = "playing" and m.hlsSession <> invalid
        m.hlsLifecyclePlaying++
        if m.hlsLifecyclePlaying >= 5
            if not m.hlsLifecycleSwitched and m.guide.config.channels.count() > 1
                m.hlsLifecycleSwitched = true
                m.hlsLifecyclePlaying = 0
                print "[hls-lifecycle-probe] first-playing-format="; m.video.content.streamFormat
                startPlayback(m.guide.config.channels[1], true)
                print "[hls-lifecycle-probe] retune-requested"
            else
                print "[hls-lifecycle-probe] final-playing-format="; m.video.content.streamFormat
                stopPlayback()
                m.hlsLifecycleStopped = true
                print "[hls-lifecycle-probe] stop-requested"
            end if
        end if
    else if m.playbackFailureDialog <> invalid
        print "[hls-lifecycle-probe] playback-failed"
        m.hlsLifecycleTimer.control = "stop"
    end if
end sub
