' A single midstream reconnect per intentional tune. Startup recovery owns the
' replacement's deadline, with its own extra retry disabled. No probing client.
function retryInterruptedLive(state as string, code as integer, detail as string) as boolean
    if not requestGateRendererAllowed(m.video) then return false
    if m.playingChannel = invalid or m.video.content = invalid or not m.streamReady then return false
    if m.liveRetryCount >= 1 or m.page = "setup" or m.video.state = "paused" then return false
    if m.pendingChannel <> invalid or m.heldZap <> "" then return false
    if m.recoveryTask <> invalid or m.sourceTask <> invalid or m.sourceWatchState <> invalid then return false
    if nativePlaybackRefusal(detail) <> "" then return false
    ' The native timeout code can accompany an explicit temporary refusal.
    ' Use the existing wait guidance and manual Retry rather than reminting now.
    if state = "error" and code = -2
        if nativePlaybackReports503(detail) and CreateObject("roRegex", "\b(channel (is )?stopping|temporar(il)?y unavailable)\b", "i").isMatch(detail) then return false
    end if
    supported = state = "finished" or state = "buffering"
    if state = "error" then supported = isStartupBufferingStall(code, detail) or code = -2
    if not supported then return false
    replacement = m.video.content.clone(false)
    bindColdLiveReader(coldLiveReaderToken(), replacement)
    m.liveRetryCount++
    m.liveBufferWatch = invalid
    m.audioCheck.control = "stop"
    m.streamReady = false
    m.decoderSnapshot = {}
    ' This is the one midstream reconnect, not a fresh startup tune. It must
    ' never consume the user-configured startup retry budget a second time.
    m.startupRetryCount = m.startupRetryLimit
    m.video.control = "stop"
    if m.hlsSession <> invalid
        retryOwnedHlsPlayback(replacement, false)
    else
        m.video.content = replacement
        beginStartupWatch(replacement, true)
        m.video.control = "play"
    end if
    m.banner.playbackState = "buffering"
    showNotice("Live stream interrupted. Reconnecting once with the same audio setting...")
    print "[live-recovery] local reconnect 1/1; same transport and profile"
    return true
end function

sub checkLivePlayback()
    if m.playingChannel = invalid or not m.streamReady or m.video.state <> "buffering"
        m.liveBufferWatch = invalid
        return
    end if
    if m.pendingChannel <> invalid or m.heldZap <> "" then return
    if m.recoveryTask <> invalid or m.sourceTask <> invalid or m.sourceWatchState <> invalid
        m.liveBufferWatch = invalid
        return
    end if
    if m.liveBufferWatch <> invalid
        if not m.liveBufferWatch.content.isSameNode(m.video.content) then m.liveBufferWatch = invalid
    end if
    if m.liveBufferWatch = invalid
        clock = CreateObject("roTimespan")
        clock.mark()
        m.liveBufferWatch = {content: m.video.content, clock: clock}
        return
    end if
    if m.liveBufferWatch.clock.totalMilliseconds() < 20000 then return
    if retryInterruptedLive("buffering", -2, "") then return
    failLivePlayback(-2, "Live playback remained buffering for 20 seconds. The automatic reconnect budget is exhausted.")
end sub
