sub main()
    resetFailure()
    dialog = m.playbackFailureDialog
    event = failureEvent(dialog, 0)
    onPlaybackFailureAction(event)
    if m.starts <> 1 or not m.mini or m.playbackRetry <> invalid or not dialog.close then stop
    onPlaybackFailureAction(event)
    if m.starts <> 1 then stop

    resetFailure()
    onPlaybackFailureAction(failureEvent(m.playbackFailureDialog, 1))
    if m.starts <> 0 or not m.focusRestored then stop

    resetFailure()
    m.accountIdentity = "other-account"
    onPlaybackFailureAction(failureEvent(m.playbackFailureDialog, 0))
    if m.starts <> 0 then stop

    resetFailure()
    onPlaybackFailureAction(failureEvent(failureDialog(9), 0))
    if m.starts <> 0 or m.playbackRetry = invalid then stop
    onPlaybackFailureClosed(failureEvent(m.playbackFailureDialog, invalid))
    if m.playbackRetry <> invalid or not m.focusRestored then stop
    print "ALL TESTS PASSED"
end sub

sub resetFailure()
    m.playbackRetry = {account: "account", channel: {uuid: "channel"}, useAac: true, mini: true}
    m.accountIdentity = "account"
    m.playbackFailureDialog = failureDialog(1)
    m.starts = 0
    m.mini = false
    m.focusRestored = false
end sub

function failureDialog(serial)
    return {serial: serial, close: false, isSameNode: function(other)
        return m.serial = other.serial
    end function, unobserveField: sub(field)
    end sub}
end function

function failureEvent(node, data)
    return {node: node, data: data, getRoSGNode: function()
        return m.node
    end function, getData: function()
        return m.data
    end function}
end function

sub startPlayback(channel, forced, useAac)
    if not forced or not useAac or channel.uuid <> "channel" then stop
    m.starts++
    m.playingChannel = channel
end sub

sub minimizePlayback()
    m.mini = true
end sub

sub onDialogClosed()
    m.focusRestored = true
end sub

sub stopPlayback()
end sub
