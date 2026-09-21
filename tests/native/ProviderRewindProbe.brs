' Native production-controller history test. Aged tune time is injected to test
' the hour boundary without another warmup; actual provider media must still play.
sub installProviderRewindProbe()
    m.rewindProbeStage = 0
    m.rewindProbeTicks = 0
    m.rewindProbeFailed = false
    m.rewindProbeMemory = CreateObject("roAppMemoryMonitor")
    m.rewindProbePeak = 0
    m.rewindProbeTimer = m.top.createChild("Timer")
    m.rewindProbeTimer.duration = 1
    m.rewindProbeTimer.repeat = true
    m.rewindProbeTimer.observeField("fire", "providerRewindTick")
    m.rewindProbeTimer.control = "start"
end sub

sub rewindProbeCheck(ok as boolean, label as string)
    print "[provider-rewind] "; label; "="; ok
    if not ok then m.rewindProbeFailed = true
end sub

sub providerRewindTick()
    m.rewindProbeTicks++
    memory = m.rewindProbeMemory.getMemoryLimitPercent()
    if memory > m.rewindProbePeak then m.rewindProbePeak = memory
    if memory >= 60 then m.rewindProbeFailed = true
    if m.rewindProbeTicks > 180 or m.rewindProbeFailed
        print "[provider-rewind] halted stage="; m.rewindProbeStage
        m.rewindProbeFailed = true
        finishProviderRewindProbe()
        return
    end if
    if m.page = "onDemand" and m.rewindProbeStage >= 2 and m.rewindProbeStage <> 7 and m.rewindProbeStage <> 8
        if not m.mediaPlayer.findNode("mediaVideo").visible and m.mediaPlayer.diagnostic <> invalid
            if m.mediaPlayer.diagnostic.code < 0
                unavailable = false
                for each child in m.mediaPlayer.getChildren(-1, 0)
                    if child.subtype() = "Label"
                        if instr(1, child.text, "Archive not yet available") > 0 then unavailable = true
                    end if
                end for
                print "[provider-rewind] availability-case; remaining window-playback steps skipped"
                rewindProbeCheck(unavailable and m.playingChannel = invalid, "unavailable-message-no-live-substitution")
                m.mediaPlayer.callFunc("openArchiveActions")
                m.top.dialog.buttonSelected = 0
                m.rewindProbeStage = 7
                return
            end if
        end if
    end if
    if m.rewindProbeStage = 0
        if m.page <> "guide" or m.capabilities.catchup <> "allowed" then return
        wanted = CreateObject("roAppInfo").getValue("provider_rewind_channel")
        if wanted = "" then wanted = "3.3"
        for each channel in m.guide.config.channels
            if channel.number = wanted and catchupChannelDays(m.capabilities.catchup, m.channelFacts, channel.id) > 0 then m.rewindProbeChannel = channel
        end for
        if m.rewindProbeChannel = invalid then return
        m.rewindProbeSkip = m.devicePreferences.archiveSkipSeconds
        m.rewindProbeHistory = {recent: m.accountPreferences.recent, previous: m.accountPreferences.previous, lastWatched: m.accountPreferences.lastWatched}
        startPlayback(m.rewindProbeChannel, true)
        m.rewindProbeStage = 1
    else if m.rewindProbeStage = 1
        if m.video.state <> "playing" then return
        facts = m.channelFacts
        m.channelFacts = {}
        openLiveRewind()
        rewindProbeCheck(m.page = "player" and m.video.state = "playing", "unsupported-keeps-live")
        m.channelFacts = facts
        m.rewindProbeTune = uiNow() - 7200
        m.liveSession.openedAt = m.rewindProbeTune
        m.devicePreferences.archiveSkipSeconds = 300
        print "[provider-rewind] injected-tune-age=7200"
        openLiveRewind()
        m.rewindProbeStage = 2
    else if m.rewindProbeStage = 2
        if m.page <> "onDemand" or m.mediaPlayer.findNode("mediaVideo").state <> "playing" then return
        rewindProbeCheck(m.mediaPlayer.request.rewind and m.archiveContext.tuneStart = m.rewindProbeTune, "provider-mode-and-tune-scope")
        rewindProbeCheck(guideEpoch(m.archiveServerStart) = m.archiveContext.program.startsAt + m.archiveOffset, "requested-utc-echo")
        m.rewindProbeSession = m.archiveSession
        m.rewindProbeRequestedAt = uiNow()
        m.mediaPlayer.archiveSeek = -999999
        m.rewindProbeStage = 3
    else if m.rewindProbeStage = 3
        if m.archiveSession = invalid or m.archiveSession = m.rewindProbeSession then return
        video = m.mediaPlayer.findNode("mediaVideo")
        if video.state <> "playing" or video.position < 5 then return
        start = guideEpoch(m.archiveServerStart)
        print "[provider-rewind] oldest-age-at-request="; m.archiveWindowRequestedAt - start; " native-position="; video.position
        rewindProbeCheck(m.archiveWindowRequestedAt - start >= 3540 and m.archiveWindowRequestedAt - start <= 3600, "hour-boundary-served")
        rewindProbeCheck(m.archiveCleanupTask.result.status = 204, "old-window-released")
        if m.mediaPlayer.broadcastInfo <> invalid then print "[provider-rewind] historical-program-known="; m.mediaPlayer.broadcastInfo.title <> "Program information unavailable for playback time"
        m.mediaPlayer.findNode("mediaVideo").control = "pause"
        m.rewindProbeSession = m.archiveSession
        m.rewindProbeOldOffset = m.archiveOffset
        m.rewindProbePausedAt = m.rewindProbeTicks
        m.rewindProbePausedPosition = video.position
        m.rewindProbeStage = 4
    else if m.rewindProbeStage = 4
        if m.mediaPlayer.findNode("mediaVideo").state <> "paused" then return
        if m.rewindProbeTicks - m.rewindProbePausedAt < 70 then return
        clock = rewindPlaybackClock(m.archiveContext.program, m.archiveContext.tuneStart, m.archiveOffset, m.mediaPlayer.findNode("mediaVideo").position, uiNow())
        warning = false
        for each child in m.mediaPlayer.getChildren(-1, 0)
            if child.subtype() = "Label"
                if instr(1, child.text, "older than the current range") > 0 then warning = true
            end if
        end for
        rewindProbeCheck(clock.outside and warning and m.archiveSession = m.rewindProbeSession, "paused-position-ages-out-with-explicit-warning")
        m.rewindProbeExpiredAt = uiNow()
        m.mediaPlayer.archiveSeek = -999999
        m.rewindProbeStage = 41
    else if m.rewindProbeStage = 41
        if m.archiveSession = invalid or m.archiveSession = m.rewindProbeSession then return
        if m.mediaPlayer.findNode("mediaVideo").state <> "paused" then return
        start = guideEpoch(m.archiveServerStart)
        rewindProbeCheck(start >= m.rewindProbeExpiredAt - 3600 and m.archiveOffset > m.rewindProbeOldOffset, "expired-target-clamped-to-current-window")
        m.rewindProbeSession = m.archiveSession
        m.rewindProbeStage = 42
    else if m.rewindProbeStage = 42
        m.mediaPlayer.archiveSeek = uiNow() - 120 - m.archiveContext.program.startsAt
        m.rewindProbeStage = 5
    else if m.rewindProbeStage = 5
        if m.archiveSession = invalid or m.archiveSession = m.rewindProbeSession then return
        if m.mediaPlayer.findNode("mediaVideo").state <> "paused" then return
        age = uiNow() - guideEpoch(m.archiveServerStart)
        rewindProbeCheck(age >= 120 and age < 240, "recent-window-paused")
        m.rewindProbeSession = m.archiveSession
        m.mediaPlayer.callFunc("handleArchiveKey", "rewind", true)
        m.rewindProbeHoldAt = m.rewindProbeTicks
        m.rewindProbeStage = 6
    else if m.rewindProbeStage = 6
        if m.rewindProbeTicks - m.rewindProbeHoldAt < 2 then return
        m.mediaPlayer.callFunc("handleArchiveKey", "rewind", false)
        preview = false
        for each child in m.mediaPlayer.getChildren(-1, 0)
            if child.subtype() = "Label"
                if instr(1, child.text, "REWIND PREVIEW:") > 0 then preview = true
            end if
        end for
        rewindProbeCheck(preview and m.archiveSession = m.rewindProbeSession, "rolling-preview-no-reopen")
        m.mediaPlayer.callFunc("handleArchiveKey", "back", true)
        m.mediaPlayer.callFunc("openArchiveActions")
        m.top.dialog.buttonSelected = 0
        m.rewindProbeStage = 7
    else if m.rewindProbeStage = 7
        if m.page <> "player" or m.video.state <> "playing" then return
        rewindProbeCheck(m.liveSession.openedAt = m.rewindProbeTune and m.playingChannel.uuid = m.rewindProbeChannel.uuid, "go-live-preserves-tune-history")
        openLiveRewind()
        onKeyEvent("back", true)
        m.rewindProbeCancelAt = m.rewindProbeTicks
        m.rewindProbeStage = 8
    else if m.rewindProbeStage = 8
        if m.rewindProbeTicks - m.rewindProbeCancelAt < 5 then return
        rewindProbeCheck(m.page = "guide" and m.archiveTask = invalid and m.archiveContext = invalid and m.archiveSession = invalid, "cancel-no-late-open")
        finishProviderRewindProbe()
    end if
end sub

sub finishProviderRewindProbe()
    m.rewindProbeTimer.control = "stop"
    m.mediaPlayer.callFunc("closeMedia")
    cancelArchiveLoad()
    releaseArchive()
    stopPlayback()
    if m.rewindProbeSkip <> invalid
        m.devicePreferences.archiveSkipSeconds = m.rewindProbeSkip
        persistPreferences()
    end if
    if m.rewindProbeHistory <> invalid
        for each key in m.rewindProbeHistory
            m.accountPreferences[key] = m.rewindProbeHistory[key]
        end for
        persistAccountPreferences()
        m.guide.recentIds = m.accountPreferences.recent
    end if
    print "[provider-rewind] peak-memory-percent="; m.rewindProbePeak
    print "[provider-rewind] finished passed="; not m.rewindProbeFailed
end sub
