' Gate mandatory AAC before constructing/opening any new media request.
function deferRequiredAacTune(channel as object, forceRetune as boolean, useAac as boolean, preserveBudget as boolean, tuneStartedAt = 0 as integer) as boolean
    if m.devicePreferences.audioMode <> "aac" and not useAac then return false
    if m.aacProfile <> invalid then return false
    clock = CreateObject("roTimespan")
    clock.mark()
    m.pendingAacTune = {
        channel: channel, forceRetune: forceRetune, preserveBudget: preserveBudget
        account: m.accountIdentity, mode: m.devicePreferences.audioMode, clock: clock
        tuneStartedAt: tuneStartedAt
    }
    m.guide.pendingTune = true
    m.aacWaitingMessage = "Waiting for the existing AAC profile... Back or Stop cancels this tune."
    showNotice(m.aacWaitingMessage)
    m.noticeTimer.control = "stop"
    m.aacWaitTimer.control = "start"
    if m.capabilityTask = invalid then refreshCapabilities()
    processAacWait()
    return true
end function

sub cancelAacWait()
    m.pendingAacTune = invalid
    if m.aacWaitTimer <> invalid then m.aacWaitTimer.control = "stop"
    if m.guide <> invalid then m.guide.pendingTune = false
    if m.noticeText <> invalid
        if m.noticeText.text = m.aacWaitingMessage then hideNotice()
    end if
end sub

sub processAacWait()
    request = m.pendingAacTune
    if request = invalid then return
    if request.account <> m.accountIdentity or request.mode <> m.devicePreferences.audioMode
        cancelAacWait()
        return
    end if
    ' Deadline wins over a late result, even if the timer callback was delayed.
    message = ""
    if request.clock.totalMilliseconds() >= 20000
        message = "AAC profile discovery timed out after 20 seconds."
    else if m.aacProfile <> invalid
        cancelAacWait()
        startPlayback(request.channel, request.forceRetune, true, request.preserveBudget, request.tuneStartedAt)
        return
    else if m.aacDiscoveryState = "unavailable" or m.aacDiscoveryState = "error"
        message = m.aacDiscoveryMessage
    end if
    if message <> ""
        cancelAacWait()
        showAacUnavailable(request, message)
    end if
end sub
