' Native integration fixture: import temporarily in AerioScene and call its
' installer from init. It opens and replaces only this client's archive sessions.
sub installArchiveSeekProbe()
    for each format in ["mp4", "mkv", "mpegts", "ts", "mpeg2ts", "mpeg2", "mpeg-ts", "mp2t", "MPEGTS"]
        node = CreateObject("roSGNode", "ContentNode")
        node.streamFormat = format
        print "[archive-format] input="; format; " stored="; node.streamFormat
    end for
    m.archiveProbeStage = 0
    m.archiveProbeTicks = 0
    m.archiveProbeTimer = m.top.createChild("Timer")
    m.archiveProbeTimer.duration = 1
    m.archiveProbeTimer.repeat = true
    m.archiveProbeTimer.observeField("fire", "archiveProbeTick")
    m.archiveProbeTimer.control = "start"
end sub

sub archiveProbeTick()
    m.archiveProbeTicks++
    if m.archiveProbeTicks > 120
        print "[archive-seek-probe] timeout stage="; m.archiveProbeStage
        m.archiveProbeTimer.control = "stop"
        m.mediaPlayer.callFunc("closeMedia")
        return
    end if
    if m.archiveProbeStage = 0
        if m.capabilities.catchup <> "allowed" then return
        for each channel in m.guide.config.channels
            if instr(1, lcase(channel.name), "espn") > 0 and m.channelFacts.doesExist(channel.id)
                if m.channelFacts[channel.id].catchupDays > 0
                    m.archiveProbeStart = uiNow() - 7200
                    program = {id: "native-archive-seek", title: "Archive seek fixture", startsAt: m.archiveProbeStart, endsAt: m.archiveProbeStart + 300}
                    m.guide.archiveRequest = {channel: channel, program: program, scope: m.guide.config.scope}
                    m.archiveProbeStage = 1
                    exit for
                end if
            end if
        end for
    else if m.archiveProbeStage = 1
        video = m.mediaPlayer.findNode("mediaVideo")
        if video.state <> "playing" or m.page <> "onDemand" then return
        print "[archive-seek-probe] initial-playing offset="; m.archiveOffset; " duration="; video.duration
        m.archiveProbeOld = m.archiveSession
        m.mediaPlayer.archiveSeek = 60
        m.archiveProbeStage = 2
    else if m.archiveProbeStage = 2
        video = m.mediaPlayer.findNode("mediaVideo")
        if video.errorCode <> 0 and m.archiveSeeking <> true
            print "[archive-seek-probe] seek-failed="; video.errorCode; " offset="; m.archiveOffset; " echo="; m.archiveServerStart
            m.archiveProbeTimer.control = "stop"
            m.mediaPlayer.callFunc("closeMedia")
            return
        end if
        if m.archiveSeeking = true or video.state <> "playing" or m.archiveOffset <> 60 then return
        print "[archive-seek-probe] forward-playing newSession="; m.archiveSession <> m.archiveProbeOld; " serverStartDelta="; guideEpoch(m.archiveServerStart) - m.archiveProbeStart; " deleted="; m.archiveCleanupTask.result.status
        m.archiveProbeOld = m.archiveSession
        video.control = "pause"
        m.archiveProbeStage = 3
    else if m.archiveProbeStage = 3
        video = m.mediaPlayer.findNode("mediaVideo")
        if video.state <> "paused" then return
        m.mediaPlayer.archiveSeek = 0
        m.archiveProbeStage = 4
    else if m.archiveProbeStage = 4
        video = m.mediaPlayer.findNode("mediaVideo")
        if m.archiveSeeking = true or video.state <> "paused" or m.archiveOffset <> 0 then return
        print "[archive-seek-probe] backward-paused newSession="; m.archiveSession <> m.archiveProbeOld; " serverStartDelta="; guideEpoch(m.archiveServerStart) - m.archiveProbeStart; " deleted="; m.archiveCleanupTask.result.status
        video.control = "resume"
        m.archiveProbeStage = 5
    else if m.archiveProbeStage = 5
        video = m.mediaPlayer.findNode("mediaVideo")
        if video.state <> "playing" then return
        m.archiveProbeChannel = m.archiveContext.channel.uuid
        m.mediaPlayer.callFunc("openArchiveActions")
        print "[archive-seek-probe] controls="; m.top.dialog.buttons.count()
        m.top.dialog.buttonSelected = 0
        m.archiveProbeStage = 6
    else if m.archiveProbeStage = 6
        if m.page <> "player" or m.video.state <> "playing" then return
        if type(m.archiveCleanupTask.result) <> "roAssociativeArray" then return
        print "[archive-seek-probe] go-live-playing sameChannel="; m.playingChannel.uuid = m.archiveProbeChannel; " archiveReleased="; m.archiveSession = invalid; " delete="; m.archiveCleanupTask.result.status
        stopPlayback()
        m.archiveProbeTimer.control = "stop"
        print "[archive-seek-probe] complete"
    end if
end sub
