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
    m.seekingArchive = false
    m.archiveDialog = invalid
end sub

sub openMedia()
    request = m.top.request
    if request = invalid then return
    closeArchiveActions()
    m.opening = true
    m.seekingArchive = false
    m.video.control = "stop"
    m.message.text = "Opening " + request.title + "... Back returns."
    m.session = mediaSession(request.account, request.identity, request.mode, request.key, uiNow())
    if request.programStart <> invalid then m.session.programStart = request.programStart
    m.finished = false
    m.startPaused = request.startPaused = true
    m.mediaFailed = false
    m.closing = false
    content = CreateObject("roSGNode", "ContentNode")
    content.url = request.url
    content.streamFormat = request.streamFormat
    if request.streamFormat = "mpegts" then content.streamFormat = "ts"
    content.live = false
    content.title = request.title
    content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    ' Dispatcharr's VOD proxy forwards Authorization upstream. X-API-Key alone
    ' authenticates to Dispatcharr without forwarding that credential header.
    content.httpHeaders = mediaPlaybackHeaders(request.apiKey)
    m.pendingResume = 0
    if request.resume <> invalid then m.pendingResume = int(request.resume)
    m.video.content = content
    print "[on-demand] reader="; content.streamFormat; " mode="; request.mode
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
        if state = "playing" and m.startPaused
            m.startPaused = false
            m.video.control = "pause"
            return
        end if
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
        if m.session.mode = "catchup" then m.message.text = "ARCHIVE: " + m.top.request.title + chr(10) + "Play/Pause  Pause    Rew / FF  Previous / next minute    Up  Controls / Go Live    Back  Guide"
        reportProgress()
    else if state = "error"
        m.mediaFailed = true
        m.top.diagnostic = {mode: m.session.mode, code: m.video.errorCode, message: sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)}
        print "[on-demand] failure code="; m.video.errorCode; " detail="; sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)
        m.message.text = playbackFailureText(m.video.errorCode, sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)) + chr(10) + "OK Retry    Back Return"
        if m.session.mode = "vod" then m.message.text += chr(10) + "If this source keeps failing: Back to the title, then Choose source version (authorized accounts)."
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
    if m.session.mode = "catchup" and mediaNumber(m.session.position)
        elapsed = int(m.session.position)
        if m.top.request.offset <> invalid then elapsed += m.top.request.offset
        m.message.text = "ARCHIVE: " + m.top.request.title + " — program offset " + elapsed.toStr() + "s" + chr(10) + "Play/Pause  Pause    Rew / FF  Previous / next minute    Up  Controls / Go Live    Back  Guide"
    end if
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
    closeArchiveActions()
    if m.seekingArchive
        m.seekingArchive = false
        m.top.visible = false
        m.top.closed = true
        return
    end if
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
    if m.seekingArchive
        if key = "back" and press then closeMedia()
        return true
    end if
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
        if key = "up"
            openArchiveActions()
            return true
        end if
        if (key = "rewind" or key = "fastforward") and (m.video.state = "playing" or m.video.state = "paused")
            offset = 0
            if m.top.request.offset <> invalid then offset = m.top.request.offset
            position = offset + int(m.video.position)
            if key = "rewind" then position -= 60 else position += 60
            plan = catchupSeekPlan(m.top.request.program, position)
            if plan <> invalid then m.top.archiveSeek = plan.offset
            return true
        end if
        if key = "play" or key = "OK"
            if m.video.state = "paused" then m.video.control = "resume" else if m.video.state = "playing" then m.video.control = "pause"
        end if
        return key <> "options"
    end if
    return false
end function

function suspendArchive() as object
    closeArchiveActions()
    paused = m.video.state = "paused"
    reportProgress()
    m.seekingArchive = true
    m.session = invalid
    m.clock.control = "stop"
    m.video.control = "stop"
    m.video.content = invalid
    m.top.request = invalid
    m.message.text = "Opening the requested archive minute... Back cancels."
    m.top.setFocus(true)
    return {paused: paused}
end function

sub openArchiveActions()
    if m.session = invalid then return
    if m.session.mode <> "catchup" or m.seekingArchive then return
    closeArchiveActions()
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Archive controls"
    dialog.message = "Go Live returns to the current broadcast of this channel."
    dialog.buttons = ["Go Live", "Keep watching archive"]
    dialog.observeField("buttonSelected", "onArchiveAction")
    dialog.observeField("wasClosed", "onArchiveActionsClosed")
    m.archiveDialog = dialog
    m.top.getScene().dialog = dialog
end sub

sub closeArchiveActions()
    if m.archiveDialog = invalid then return
    dialog = m.archiveDialog
    m.archiveDialog = invalid
    dialog.unobserveField("buttonSelected")
    dialog.unobserveField("wasClosed")
    dialog.close = true
end sub

sub onArchiveAction(event as object)
    if m.archiveDialog = invalid then return
    if not m.archiveDialog.isSameNode(event.getRoSGNode()) then return
    goLive = event.getData() = 0
    closeArchiveActions()
    if goLive then m.top.goLiveRequested = true else m.top.setFocus(true)
end sub

sub onArchiveActionsClosed(event as object)
    if m.archiveDialog = invalid then return
    if not m.archiveDialog.isSameNode(event.getRoSGNode()) then return
    m.archiveDialog = invalid
    if m.session <> invalid then m.top.setFocus(true)
end sub
