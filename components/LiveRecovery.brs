' A single midstream reconnect per intentional tune. Startup recovery owns the
' replacement's deadline, with its own extra retry disabled. No probing client.
function retryInterruptedLive(state as string, code as integer, detail as string) as boolean
    if m.playingChannel = invalid or m.video.content = invalid or not m.streamReady then return false
    if m.liveRetryCount >= 1 or m.page = "setup" or m.video.state = "paused" then return false
    if m.pendingChannel <> invalid or m.heldZap <> "" then return false
    if m.recoveryTask <> invalid or m.sourceTask <> invalid or m.sourceWatchState <> invalid then return false
    if nativePlaybackRefusal(detail) <> "" then return false
    supported = state = "finished" or state = "buffering"
    if state = "error" then supported = isStartupBufferingStall(code, detail) or code = -2
    if not supported then return false
    replacement = m.video.content.clone(false)
    m.liveRetryCount++
    m.liveBufferWatch = invalid
    m.audioCheck.control = "stop"
    m.streamReady = false
    m.decoderSnapshot = {}
    m.startupRetryCount = 1
    m.video.control = "stop"
    m.video.content = replacement
    beginStartupWatch(replacement, true)
    m.video.control = "play"
    m.banner.playbackState = "buffering"
    showNotice("Live stream interrupted. Reconnecting once with the same audio setting...")
    print "[live-recovery] local reconnect 1/1; same URL/profile"
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
