sub init()
    m.top.focusable = true
    m.video = m.top.findNode("mediaVideo")
    m.video.observeField("state", "onMediaState")
    m.clock = m.top.findNode("progressClock")
    m.clock.observeField("fire", "reportProgress")
    m.message = uiLabel(m.top, "", 160, 780, 1600, 230, 28)
    m.message.wrap = true
    m.session = invalid
    m.opening = false
end sub

sub openMedia()
    request = m.top.request
    if request = invalid then return
    m.opening = true
    m.video.control = "stop"
    m.message.text = "Opening " + request.title + "... Back returns."
    m.session = mediaSession(request.account, request.identity, request.mode, request.key, uiNow())
    if request.programStart <> invalid then m.session.programStart = request.programStart
    m.finished = false
    m.mediaFailed = false
    m.closing = false
    content = CreateObject("roSGNode", "ContentNode")
    content.url = request.url
    content.streamFormat = request.streamFormat
    content.live = false
    content.title = request.title
    content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    content.httpHeaders = ["X-API-Key: " + request.apiKey, "Authorization: ApiKey " + request.apiKey]
    m.pendingResume = 0
    if request.resume <> invalid then m.pendingResume = int(request.resume)
    m.video.content = content
    m.video.enableUI = request.mode <> "catchup"
    m.video.enableTrickPlay = request.mode <> "catchup"
    m.video.visible = true
    m.top.visible = true
    m.opening = false
    m.video.control = "play"
    if request.mode = "catchup" then m.top.setFocus(true) else m.video.setFocus(true)
    m.elapsed = CreateObject("roTimespan")
    m.elapsed.mark()
    m.clock.control = "start"
end sub

sub onMediaState()
    if m.session = invalid or m.opening then return
    state = m.video.state
    print "[on-demand] mode="; m.session.mode; " state="; state
    if state = "playing" or state = "paused"
        if state = "playing" and m.pendingResume > 0
            target = m.pendingResume
            m.pendingResume = 0
            if m.video.duration > target
                m.message.text = "Resuming..."
                m.video.seek = target
                return
            end if
        end if
        m.message.text = ""
        if m.session.mode = "catchup" then m.message.text = "ARCHIVE: " + m.top.request.title + chr(10) + "Play/Pause  Pause or resume    Back  Guide / Watch LIVE    Seeking unavailable"
        reportProgress()
    else if state = "error"
        m.mediaFailed = true
        m.top.diagnostic = {mode: m.session.mode, code: m.video.errorCode, message: sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)}
        print "[on-demand] failure code="; m.video.errorCode; " detail="; sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)
        m.message.text = playbackFailureText(m.video.errorCode, sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)) + chr(10) + "OK Retry    Back Return"
        if m.session.mode = "catchup" then m.message.text = "Archive unavailable or expired. Return to the guide and open the program again for a new session." + chr(10) + "OK / Back  Return"
        m.video.visible = false
        m.top.setFocus(true)
        m.clock.control = "stop"
    else if state = "finished"
        if m.mediaFailed then return
        m.finished = true
        closeMedia()
    end if
end sub

sub reportProgress()
    if m.session = invalid then return
    ' A buffering seek target is not a committed playhead. Persist only native
    ' playing/paused samples; an exit during buffering retains the last sample.
    if m.video.state = "playing" or m.video.state = "paused"
        mediaObserve(m.session, m.video.state, m.video.position, m.video.duration, invalid)
    else
        m.session.state = m.video.state
    end if
    m.top.progress = {account: m.session.account, identity: m.session.identity, key: m.session.item, mode: m.session.mode, position: m.session.position, duration: m.session.duration, finished: m.finished, state: m.video.state, closing: m.closing}
    if m.video.state = "buffering"
        m.message.text = "Buffering (" + m.elapsed.totalSeconds().toStr() + "s). Back returns."
        if m.elapsed.totalSeconds() >= 45
            m.mediaFailed = true
            m.video.control = "stop"
            m.message.text = "Media did not start within 45 seconds. OK Retry    Back Return"
            if m.session.mode = "catchup" then m.message.text = "Archive startup timed out. OK / Back returns to the guide; reopen the program for a new session."
            m.video.visible = false
            m.clock.control = "stop"
            m.top.setFocus(true)
        end if
    else if m.video.state = "playing" or m.video.state = "paused"
        m.elapsed.mark()
    end if
end sub

sub closeMedia()
    if m.session = invalid then return
    m.closing = true
    reportProgress()
    mediaEnd(m.session)
    m.session = invalid
    m.clock.control = "stop"
    m.video.control = "stop"
    m.video.content = invalid
    m.top.request = invalid
    m.top.visible = false
    m.top.closed = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if m.session = invalid or not press then return false
    if key = "back"
        closeMedia()
        return true
    end if
    if key = "OK" and not m.video.visible
        if m.session.mode = "catchup" then closeMedia() else openMedia()
        return true
    end if
    if m.session.mode = "catchup"
        if key = "play" or key = "OK"
            if m.video.state = "paused" then m.video.control = "resume" else if m.video.state = "playing" then m.video.control = "pause"
        end if
        return key <> "options"
    end if
    return false
end function
