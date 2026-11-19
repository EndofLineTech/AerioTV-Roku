' App-side evidence only. Native Video.state is not reader-tagged, and none
' of these outcomes emit or defer the Roku launch beacon.
function coldPlaybackLaunchRequest(raw as dynamic, cold as boolean) as dynamic
    request = normalizeLaunchRequest(raw)
    if cold and request <> invalid then request.coldToken = CreateObject("roDeviceInfo").getRandomUUID()
    return request
end function

sub beginColdPlayback(request as object)
    clock = CreateObject("roTimespan")
    clock.mark()
    m.coldPlaybackOutcome = invalid
    m.coldPlayback = {
        token: request.coldToken, kind: request.kind, id: request.id, clock: clock
        session: currentUserSessionId(), holder: m.accountIdentity, playlist: m.selectedConnectionId
        base: m.baseUrl, key: m.apiKey, phase: "admitted"
    }
    if m.coldPlaybackClock <> invalid then m.coldPlaybackClock.control = "start"
end sub

function coldPlaybackCurrent(token as string) as boolean
    attempt = m.coldPlayback
    if token = "" or attempt = invalid or token <> attempt.token then return false
    if m.top.exitRequested = true or userProfileUiClosed() or m.userProfileRecoveryRequired = true then return false
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return false
    return attempt.session = currentUserSessionId() and attempt.holder = m.accountIdentity and attempt.playlist = m.selectedConnectionId and attempt.base = m.baseUrl and attempt.key = m.apiKey
end function

function settleColdPlayback(token as string, result as string) as boolean
    if m.coldPlayback = invalid or token = "" then return false
    if m.coldPlayback.token <> token then return false
    m.coldPlaybackOutcome = {token: token, kind: m.coldPlayback.kind, result: result}
    m.coldPlayback = invalid
    if m.coldPlaybackClock <> invalid then m.coldPlaybackClock.control = "stop"
    print "[cold-playback] kind="; m.coldPlaybackOutcome.kind; " result="; result
    return true
end function

sub retireColdPlayback(result as string)
    if m.coldPlayback <> invalid then settleColdPlayback(m.coldPlayback.token, result)
end sub

function coldAacToken() as string
    if m.pendingAacTune = invalid then return ""
    token = textValue(m.pendingAacTune.coldToken)
    if coldPlaybackCurrent(token) then return token
    return ""
end function

function coldLiveReaderToken() as string
    attempt = m.coldPlayback
    if attempt = invalid or attempt.reader = invalid or m.video.content = invalid then return ""
    if not coldPlaybackCurrent(attempt.token) or m.playingChannel = invalid then return ""
    if m.playingChannel.uuid <> attempt.id or not attempt.reader.isSameNode(m.video.content) then return ""
    return attempt.token
end function

sub bindColdLiveReader(token as string, reader as object)
    if not coldPlaybackCurrent(token) then return
    m.coldPlayback.phase = "live"
    m.coldPlayback.reader = reader
    m.coldPlayback.position = invalid
end sub

function coldPlaybackExpired(attempt as object) as boolean
    ' Use one budget across AAC, HLS mint, and replacement readers. Keep the
    ' existing live retry budgets (up to four 30+60s openings plus AAC).
    deadline = 390000
    if attempt.kind <> "live" then deadline = 60000
    return attempt.clock.totalMilliseconds() >= deadline
end function

sub checkColdPlayback()
    attempt = m.coldPlayback
    if attempt = invalid then return
    token = attempt.token
    if not coldPlaybackCurrent(token)
        if attempt.phase = "aac" and m.pendingAacTune <> invalid
            if m.pendingAacTune.coldToken = token then cancelAacWait()
        end if
        settleColdPlayback(token, "cancelled")
        if attempt.phase = "vod-resolver" and coldVodResolverOwns(token) then cancelVodDeepLink()
        return
    end if
    expired = coldPlaybackExpired(attempt)
    if attempt.phase = "live"
        if coldLiveReaderToken() = "" or m.page <> "player" or m.mini or m.pendingChannel <> invalid or m.heldZap <> ""
            settleColdPlayback(token, "replaced")
        else if expired and m.top.dialog <> invalid
            settleColdPlayback(token, "cancelled")
        else if expired
            failLivePlayback(-2, "No playable video started before the linked tune deadline.")
        else if m.hlsMintTask = invalid and m.video.visible and m.video.state = "playing" and requestGateRendererAllowed(m.video) and m.top.dialog = invalid
            if m.video.hasFocus() and mediaNumber(m.video.position)
                position = m.video.position
                if mediaNumber(attempt.position)
                    if position > attempt.position then settleColdPlayback(token, "ready")
                end if
                attempt.position = position
                return
            end if
        end if
        attempt.position = invalid
    else if attempt.phase = "vod-renderer"
        if m.page <> "onDemand" or m.mediaIdentity <> attempt.identity
            settleColdPlayback(token, "replaced")
            return
        end if
        owner = vodDeepLinkOwner(true)
        if owner = invalid
            settleColdPlayback(token, "cancelled")
            return
        end if
        if owner.protection <> attempt.protection
            settleColdPlayback(token, "cancelled")
            return
        end if
        result = m.mediaPlayer.callFunc("checkColdVodPlayback", token, attempt.identity, expired, m.top.dialog = invalid)
        if textValue(result) <> "" then settleColdPlayback(token, result)
    else if attempt.phase = "vod-resolver"
        if not coldVodResolverOwns(token)
            settleColdPlayback(token, "cancelled")
        else if not vodDeepLinkOwnerCurrent(m.vodDeepLinkTask, m.vodDeepLinkOwner)
            cancelVodDeepLink()
        else if expired
            settleColdPlayback(token, "timeout")
            cancelVodDeepLink()
            showVodDeepLinkUnavailable()
        end if
    else if attempt.phase = "aac"
        if coldAacToken() = "" or m.page <> attempt.waitPage
            settleColdPlayback(token, "cancelled")
        else if expired
            request = m.pendingAacTune
            cancelAacWait()
            showAacUnavailable(request, "No playable video started before the linked tune deadline.")
            settleColdPlayback(token, "timeout")
        end if
    else if expired
        settleColdPlayback(token, "cancelled")
    end if
end sub

function coldVodResolverOwns(token as string) as boolean
    if m.vodDeepLinkTask = invalid or m.vodDeepLinkOwner = invalid then return false
    return m.vodDeepLinkOwner.request.coldToken = token
end function
