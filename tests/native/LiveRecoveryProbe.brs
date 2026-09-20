' Native controller fixture: temporarily copy this and LiveStatusProbeTask.*
' into components, import this script in AerioScene.xml and call its installer
' from init. It tunes live media and injects controller failure signals; remove
' all hooks after collecting evidence. Never ship in a normal app package.
sub installLiveRecoveryProbe()
    m.liveProbeStage = 0
    m.liveProbeClock = CreateObject("roTimespan")
    m.liveProbeClock.mark()
    m.liveProbeTimer = m.top.createChild("Timer")
    m.liveProbeTimer.duration = 2
    m.liveProbeTimer.repeat = true
    m.liveProbeTimer.observeField("fire", "onLiveProbeTick")
    m.liveProbeTimer.control = "start"
end sub

sub onLiveProbeTick()
    if m.liveProbeClock.totalSeconds() > 110
        print "[live-probe] timeout stage="; m.liveProbeStage
        stopPlayback()
        m.liveProbeTimer.control = "stop"
        return
    end if
    if m.liveProbeStage = 0
        if m.guide.config = invalid then return
        for each channel in m.guide.config.channels
            if instr(1, lcase(channel.name), "espn") > 0
                m.liveProbeStatus = CreateObject("roSGNode", "LiveStatusProbeTask")
                m.liveProbeStatus.baseUrl = m.baseUrl
                m.liveProbeStatus.apiKey = m.apiKey
                m.liveProbeStatus.channelUuid = channel.uuid
                m.liveProbeStatus.control = "RUN"
                m.liveProbeChannel = channel
                m.liveProbeStage = 10
                exit for
            end if
        end for
    else if m.liveProbeStage = 10 and m.liveProbeStatus.ready
        startPlayback(m.liveProbeChannel)
        m.liveProbeStage = 1
    else if m.liveProbeStage = 1 and m.video.state = "playing"
        m.liveProbeContent = m.video.content
        ok = retryInterruptedLive("finished", 0, "")
        print "[live-probe] injected-end reconnect="; ok; " count="; m.liveRetryCount
        m.liveProbeStage = 2
    else if m.liveProbeStage = 2 and m.video.state = "playing"
        print "[live-probe] resumed sameUrl="; m.video.content.url = m.liveProbeContent.url; " replacedContent="; not m.video.content.isSameNode(m.liveProbeContent)
        print "[live-probe] second-auto-rejected="; not retryInterruptedLive("finished", 0, "")
        failLivePlayback(-2, "Controlled native recovery fixture timeout")
        print "[live-probe] retry-dialog buttons="; m.playbackFailureDialog.buttons.count()
        m.liveProbeStage = 3
    else if m.liveProbeStage = 3
        m.playbackFailureDialog.buttonSelected = 0
        m.liveProbeStage = 4
    else if m.liveProbeStage = 4 and m.video.state = "playing"
        print "[live-probe] manual-retry playing count="; m.liveRetryCount; " sameChannel="; m.playingChannel.uuid = m.liveProbeStatus.channelUuid
        m.liveProbeContent = m.video.content
        minimizePlayback()
        m.liveProbeStage = 6
    else if m.liveProbeStage = 6
        print "[live-probe] mini="; m.mini; " sameContent="; m.video.content.isSameNode(m.liveProbeContent)
        m.video.control = "pause"
        m.liveProbeStage = 7
    else if m.liveProbeStage = 7 and m.video.state = "paused"
        checkLivePlayback()
        print "[live-probe] paused no-watch="; m.liveBufferWatch = invalid; " count="; m.liveRetryCount
        m.video.control = "resume"
        m.liveProbeStage = 8
    else if m.liveProbeStage = 8 and m.video.state = "playing"
        stopPlayback()
        m.liveProbeStoppedAt = m.liveProbeClock.totalSeconds()
        m.liveProbeStage = 5
    else if m.liveProbeStage = 5
        if m.liveProbeClock.totalSeconds() - m.liveProbeStoppedAt < 15 then return
        m.liveProbeStatus.cancelRequested = true
        print "[live-probe] complete stopped="; m.playingChannel = invalid
        m.liveProbeTimer.control = "stop"
    end if
end sub
