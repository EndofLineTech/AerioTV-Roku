' Startup-only local recovery. Never mutate the shared channel or audio mode.
sub beginStartupWatch(content as object, recovering = false as boolean)
    clock = CreateObject("roTimespan")
    clock.mark()
    m.startupWatch = {content: content, channelUuid: m.playingChannel.uuid, clock: clock, recovering: recovering}
end sub

sub cancelStartupWatch()
    m.startupWatch = invalid
end sub

function startupWatchIsCurrent() as boolean
    if m.startupWatch = invalid or m.playingChannel = invalid or m.video.content = invalid then return false
    if m.startupWatch.channelUuid <> m.playingChannel.uuid then return false
    return m.startupWatch.content.isSameNode(m.video.content)
end function

sub completeStartupWatch()
    if m.startupWatch = invalid then return
    if m.startupWatch.recovering then print "[startup-recovery] playback ready after local retry"
    cancelStartupWatch()
end sub

function retryStartupPlayback() as boolean
    if not startupWatchIsCurrent() then return false
    if m.startupRetryCount >= 1 or m.page = "setup" then return false
    if m.video.state = "playing" or m.video.state = "paused" then return false
    if m.pendingChannel <> invalid or m.heldZap <> "" then return false
    replacement = m.video.content.clone(false)
    m.startupRetryCount++
    cancelStartupWatch()
    m.audioCheck.control = "stop"
    m.streamReady = false
    m.decoderSnapshot = {}
    ' Close this local attempt before replacing it. Clone retains exact URL,
    ' MPEG-TS transport, authentication headers and selected output profile.
    m.video.control = "stop"
    m.video.content = replacement
    beginStartupWatch(replacement, true)
    m.video.control = "play"
    m.banner.playbackState = "buffering"
    showNotice("Channel startup stalled. Retrying once with the same audio setting...")
    print "[startup-recovery] local retry 1/1; same playback URL and profile"
    return true
end function

function handleStartupFailure(code as integer, detail as string) as boolean
    if not isStartupBufferingStall(code, detail) then return false
    return retryStartupPlayback()
end function

sub checkStartupPlayback()
    if m.startupWatch = invalid then return
    if not startupWatchIsCurrent()
        cancelStartupWatch()
        return
    end if
    if m.video.state = "playing" or m.video.state = "paused"
        completeStartupWatch()
        return
    end if
    if m.video.state <> "buffering" and m.video.state <> "none" then return
    if m.pendingChannel <> invalid or m.heldZap <> "" then return
    ' Monotonic elapsed time prevents a late clock callback from an earlier tune
    ' expiring a new attempt. Once-per-second clock gives a bounded ~25s deadline.
    if m.startupWatch.clock.totalMilliseconds() < 25000 then return
    if retryStartupPlayback() then return
    failLivePlayback(-2, "Startup buffering timed out (25 seconds). The automatic retry budget for this tune has already been used.")
end sub
