sub cancelPlaybackFailure()
    if m.playbackFailureDialog <> invalid
        dialog = m.playbackFailureDialog
        m.playbackFailureDialog = invalid
        dialog.unobserveField("buttonSelected")
        dialog.unobserveField("wasClosed")
        dialog.close = true
    end if
    m.playbackRetry = invalid
end sub

sub failLivePlayback(code as integer, detail as string)
    ' The outgoing mini reader does not own an independently admitted Guide
    ' link. Do not let its teardown or modal invalidate that continuation.
    if m.mini = true and m.page = "guide" and m.vodDeepLinkTask <> invalid
        if vodDeepLinkOwnerCurrent(m.vodDeepLinkTask, m.vodDeepLinkOwner)
            stopPlayback(true)
            showNotice("Live mini-player stopped while opening this link.")
            return
        end if
    end if
    context = invalid
    if m.playingChannel <> invalid
        context = {channel: m.playingChannel, account: m.accountIdentity, useAac: m.activeAudioProfile <> "", mini: m.mini}
    end if
    token = coldLiveReaderToken()
    if token <> "" then m.coldPlayback.failing = true
    stopPlayback()
    m.playbackRetry = context
    showPlaybackFailure(code, detail)
    settleColdPlayback(token, "failed")
end sub

sub showPlaybackFailure(code as integer, detail as string)
    if m.playbackFailureDialogFactory <> invalid
        dialog = m.playbackFailureDialogFactory()
    else
        dialog = CreateObject("roSGNode", "AerioDialog")
    end if
    dialog.title = "Unable to play this channel"
    dialog.message = playbackFailureText(code, sanitizePlaybackDiagnostic(detail, m.apiKey))
    dialog.buttons = ["Return to guide"]
    if m.playbackRetry <> invalid
        dialog.title = "Playback interrupted: " + m.playbackRetry.channel.name
        dialog.buttons = ["Retry channel", "Return to guide"]
    end if
    m.playbackFailureDialog = dialog
    dialog.observeField("buttonSelected", "onPlaybackFailureAction")
    dialog.observeField("wasClosed", "onPlaybackFailureClosed")
    m.top.dialog = dialog
end sub

sub onPlaybackFailureAction(event as object)
    if not isCurrentTaskEvent(event, m.playbackFailureDialog) then return
    context = m.playbackRetry
    retry = event.getData() = 0 and context <> invalid
    cancelPlaybackFailure()
    if retry
        if context.account = m.accountIdentity
            startPlayback(context.channel, true, context.useAac)
            if context.mini and m.playingChannel <> invalid then minimizePlayback()
            return
        end if
    end if
    onDialogClosed()
end sub

sub onPlaybackFailureClosed(event as object)
    if not isCurrentTaskEvent(event, m.playbackFailureDialog) then return
    cancelPlaybackFailure()
    onDialogClosed()
end sub
