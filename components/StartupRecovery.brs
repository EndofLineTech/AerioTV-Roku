' Startup-only local recovery. Never mutate the shared channel or audio mode.
sub beginStartupWatch(content as object, recovering = false as boolean, waitForSources = false as boolean)
    clock = CreateObject("roTimespan")
    clock.mark()
    m.startupWatch = {content: content, channelUuid: m.playingChannel.uuid, clock: clock, recovering: recovering, waitForSources: waitForSources}
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

' A replaced Video reader can publish its old finished event after the AAC
' replacement ContentNode has already been assigned. Ignore only that first
' immediate terminal event; if the new reader never buffers/plays, the normal
' startup watchdog still fails/retries with a bounded budget.
function ignoreOutgoingAacFinish() as boolean
    if m.aacDecodeRetried <> true or m.activeAudioProfile = "" or m.streamReady then return false
    if m.page <> "player" or m.video.state <> "finished" then return false
    if not startupWatchIsCurrent() then return false
    if m.startupWatch.ignoredOutgoingFinish = true then return false
    if m.startupWatch.clock.totalMilliseconds() > 2000 then return false
    m.startupWatch.ignoredOutgoingFinish = true
    print "[aac-recovery] ignored outgoing reader finish"
    return true
end function

function retryStartupPlayback() as boolean
    if not startupWatchIsCurrent() then return false
    if m.startupRetryCount >= m.startupRetryLimit or m.page = "setup" then return false
    if m.video.state = "playing" or m.video.state = "paused" then return false
    if m.pendingChannel <> invalid or m.heldZap <> "" then return false
    waitForSources = m.startupWatch.waitForSources = true
    replacement = m.video.content.clone(false)
    m.startupRetryCount++
    cancelStartupWatch()
    m.audioCheck.control = "stop"
    m.streamReady = false
    m.decoderSnapshot = {}
    ' Close this local attempt before replacing it. Clone retains exact URL,
    ' transport, authentication headers and selected output profile.
    m.video.control = "stop"
    m.video.content = replacement
    beginStartupWatch(replacement, true, waitForSources)
    m.video.control = "play"
    m.banner.playbackState = "buffering"
    showNotice("Channel startup stalled. Retrying " + m.startupRetryCount.toStr() + "/" + m.startupRetryLimit.toStr() + " with the same audio setting...")
    print "[startup-recovery] local retry " + m.startupRetryCount.toStr() + "/" + m.startupRetryLimit.toStr() + "; same playback URL and profile"
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
    if m.video.state <> "buffering" and m.video.state <> "none"
        if m.startupWatch.ignoredOutgoingFinish <> true then return
        if m.video.state <> "finished" and m.video.state <> "stopped" then return
    end if
    if m.pendingChannel <> invalid or m.heldZap <> "" then return
    ' Dispatcharr may still be trying later member streams after 25 seconds.
    ' Keep its existing request alive for up to a minute before reopening it;
    ' direct M3U/Xtream and midstream recovery retain the shorter deadline.
    deadlineMs = 25000
    if m.startupWatch.waitForSources = true then deadlineMs = 60000
    if m.startupWatch.clock.totalMilliseconds() < deadlineMs then return
    if retryStartupPlayback() then return
    failLivePlayback(-2, "Startup buffering timed out while waiting for a playable stream. The automatic retry budget for this tune has already been used.")
end sub
