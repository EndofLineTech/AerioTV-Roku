sub init()
    m.top.focusable = true
    m.video = m.top.findNode("mediaVideo")
    m.video.observeField("state", "onMediaState")
    m.clock = m.top.findNode("progressClock")
    m.clock.observeField("fire", "reportProgress")
    m.scrubTimer = m.top.findNode("scrubTimer")
    m.scrubTimer.observeField("fire", "repeatArchiveScrub")
    m.scrub = invalid
    m.archivePanel = uiRect(m.top, 136, 734, 1648, 290, "0x081525E6")
    m.archiveTrack = uiRect(m.top, 160, 756, 1600, 6, "0x52667AFF")
    m.archiveFill = uiRect(m.top, 160, 756, 0, 6, "0x1AC4D8FF")
    m.archivePreview = uiRect(m.top, 160, 750, 4, 18, "0xFFFFFFFF")
    m.archivePreview.visible = false
    m.archivePanel.visible = false
    m.archiveTrack.visible = false
    m.archiveFill.visible = false
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
    cancelArchiveScrub()
    m.archivePanel.visible = request.mode = "catchup"
    m.archiveTrack.visible = false
    m.archiveFill.visible = false
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
    content.live = request.growing = true
    content.title = request.title
    content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    ' Dispatcharr's VOD proxy forwards Authorization upstream. X-API-Key alone
    ' authenticates to Dispatcharr without forwarding that credential header.
    content.httpHeaders = mediaPlaybackHeaders(request.apiKey)
    m.pendingResume = 0
    m.resumeNoticeUntil = 0
    m.resumeTarget = 0
    m.resumeWatch = invalid
    if request.resume <> invalid then m.pendingResume = int(request.resume)
    m.video.content = content
    print "[on-demand] reader="; content.streamFormat; " mode="; request.mode
    m.video.enableUI = request.mode <> "catchup" and request.growing <> true
    m.video.enableTrickPlay = request.mode <> "catchup" and request.growing <> true
    m.video.visible = true
    m.top.visible = true
    m.opening = false
    m.video.control = "play"
    if request.mode = "catchup" or request.growing = true then m.top.setFocus(true) else m.video.setFocus(true)
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
                if m.session.mode = "recording" then print "[dvr-resume] seeking saved second="; target
                if m.session.mode = "recording"
                    m.resumeTarget = target
                    m.resumeWatch = CreateObject("roTimespan")
                    m.resumeWatch.mark()
                end if
                m.video.seek = target
                return
            else
                if m.session.mode = "recording" then print "[dvr-resume] saved position unavailable in current file"
                m.resumeNoticeUntil = uiNow() + 8
            end if
        end if
        m.message.text = ""
        if m.resumeNoticeUntil > uiNow() then m.message.text = "Resume unavailable for this rendition; playing from beginning."
        if m.session.mode = "catchup" then m.message.text = "ARCHIVE: " + m.top.request.title + chr(10) + "Play/Pause  Pause    Rew / FF  Previous / next minute    Up  Controls / Go Live    Back  Guide"
        reportProgress()
    else if state = "error"
        cancelArchiveScrub()
        m.mediaFailed = true
        m.top.diagnostic = {mode: m.session.mode, code: m.video.errorCode, message: sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)}
        print "[on-demand] failure code="; m.video.errorCode; " detail="; sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)
        m.message.text = playbackFailureText(m.video.errorCode, sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)) + chr(10) + "OK Retry    Back Return"
        if m.session.mode = "vod" then m.message.text += chr(10) + "If this source keeps failing: Back to the title, then Choose source version (authorized accounts)."
        if m.session.mode = "catchup" then m.message.text = "Archive unavailable or expired. Return to the guide and open the program again for a new session." + chr(10) + "OK / Back  Return"
        if m.top.request.restart = true or m.top.request.rewind = true
            if nativePlaybackRefusal(m.video.errorStr) = "" then m.message.text = "Archive not yet available, or playback was interrupted. Try again later." else m.message.text = playbackFailureText(m.video.errorCode, sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey))
            m.message.text += chr(10) + "Up  Go Live    OK / Back  Return"
        end if
        m.video.visible = false
        m.top.setFocus(true)
        m.clock.control = "stop"
    else if state = "finished"
        cancelArchiveScrub()
        if m.mediaFailed then return
        m.finished = true
        if m.top.request.restart = true or m.top.request.rewind = true
            m.clock.control = "stop"
            m.video.visible = false
            m.message.text = "Reached the end of the available archive window." + chr(10) + "Up  Go Live    OK / Back  Return"
            m.top.setFocus(true)
            return
        end if
        closeMedia()
    end if
end sub

sub reportProgress()
    if m.session = invalid then return
    if m.session.mode = "vod" and m.resumeNoticeUntil <> invalid
        if m.resumeNoticeUntil > 0 and uiNow() >= m.resumeNoticeUntil
            m.message.text = ""
            m.resumeNoticeUntil = 0
        end if
    end if
    ' A buffering seek target is not a committed playhead. Persist only native
    ' playing/paused samples; an exit during buffering retains the last sample.
    if m.video.state = "playing" or m.video.state = "paused"
        mediaObserve(m.session, m.video.state, m.video.position, m.video.duration, invalid)
    else
        m.session.state = m.video.state
    end if
    m.top.progress = {account: m.session.account, identity: m.session.identity, key: m.session.item, mode: m.session.mode, position: m.session.position, duration: m.session.duration, finished: m.finished, state: m.video.state, closing: m.closing}
    if m.session.mode = "recording" and m.video.state = "playing"
        if m.resumeTarget <> invalid
            if m.resumeTarget > 0
                if mediaNumber(m.video.position)
                    if m.video.position >= m.resumeTarget - 2
                        print "[dvr-resume] reached saved second="; int(m.video.position)
                        m.resumeTarget = 0
                        m.resumeWatch = invalid
                    end if
                end if
                if m.resumeWatch <> invalid
                    if m.resumeWatch.totalSeconds() >= 10
                        print "[dvr-resume] seek did not reach saved position"
                        m.message.text = "Resume was not confirmed; use Play from beginning if the server file changed."
                        m.resumeTarget = 0
                        m.resumeWatch = invalid
                    end if
                end if
            end if
        end if
    end if
    if m.session.mode = "catchup" and (m.video.state = "playing" or m.video.state = "paused")
        renderArchiveProgress()
    end if
    if m.video.state = "buffering"
        m.message.text = "Buffering (" + m.elapsed.totalSeconds().toStr() + "s). Back returns."
        if m.elapsed.totalSeconds() >= 45
            m.mediaFailed = true
            m.video.control = "stop"
            m.message.text = "Media did not start within 45 seconds. OK Retry    Back Return"
            if m.session.mode = "catchup" then m.message.text = "Archive startup timed out. OK / Back returns to the guide; reopen the program for a new session."
            if m.top.request.restart = true or m.top.request.rewind = true then m.message.text = "Archive not yet available. Try again later." + chr(10) + "Up  Go Live    OK / Back  Return"
            m.video.visible = false
            m.clock.control = "stop"
            m.top.setFocus(true)
        end if
    else if m.video.state = "playing" or m.video.state = "paused"
        m.elapsed.mark()
    end if
end sub

sub closeMedia()
    cancelArchiveScrub()
    closeArchiveActions()
    if m.archivePanel <> invalid
        m.archivePanel.visible = false
        m.archiveTrack.visible = false
        m.archiveFill.visible = false
    end if
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
    return handleArchiveKey(key, press)
end function

function handleArchiveKey(key as string, press as boolean) as boolean
    if m.seekingArchive
        if key = "back" and press then closeMedia()
        return true
    end if
    if m.session = invalid then return false
    if m.session.mode = "catchup" and (key = "rewind" or key = "fastforward")
        if press
            beginArchiveScrub(key)
        else if m.scrub <> invalid
            if m.scrub.key = key
                m.scrub.key = ""
                m.scrubTimer.control = "stop"
                if not m.scrub.held then commitArchiveScrub()
            end if
        end if
        return true
    end if
    if not press then return false
    if m.scrub <> invalid
        if key = "OK" or key = "play"
            commitArchiveScrub()
        else if key = "back"
            cancelArchiveScrub()
            renderArchiveProgress()
        else if key = "up"
            cancelArchiveScrub()
            openArchiveActions()
        end if
        return true
    end if
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
        if key = "play" or key = "OK"
            if m.video.state = "paused" then m.video.control = "resume" else if m.video.state = "playing" then m.video.control = "pause"
        end if
        return key <> "options"
    end if
    if m.session.mode = "recording" and m.top.request.growing = true
        if key = "play" or key = "OK"
            if m.video.state = "paused" then m.video.control = "resume" else if m.video.state = "playing" then m.video.control = "pause"
        end if
        return key <> "options"
    end if
    return false
end function

function suspendArchive() as object
    cancelArchiveScrub()
    closeArchiveActions()
    paused = m.video.state = "paused"
    reportProgress()
    m.archiveTrack.visible = false
    m.archiveFill.visible = false
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

sub renderArchiveProgress()
    if m.session = invalid then return
    if m.session.mode <> "catchup" then return
    if m.video.state <> "playing" and m.video.state <> "paused" then return
    if m.closing = true or m.seekingArchive = true then return
    request = m.top.request
    offset = 0
    if request.offset <> invalid then offset = request.offset
    if request.rewind = true
        renderRewindProgress(offset)
        return
    end if
    clock = catchupPlaybackClock(request.program, offset, m.session.position, uiNow())
    if clock = invalid then return
    m.archiveTrack.visible = true
    m.archiveFill.visible = true
    m.archiveFill.width = 1600 * clock.fraction
    stateLabel = "ARCHIVE"
    lengthLabel = "guide length"
    if request.restart = true
        stateLabel = "RESTART"
        lengthLabel = "guide length; availability varies"
    end if
    if m.video.state = "paused" then stateLabel += " (paused)"
    title = left(request.title, 100)
    m.message.text = stateLabel + ": " + title + chr(10)
    m.message.text += "Position " + catchupElapsedText(clock.position) + " / " + catchupElapsedText(clock.duration) + " (" + lengthLabel + ")"
    if clock.pastEnd then m.message.text += " — past listed end"
    m.message.text += chr(10) + "Estimated broadcast: " + uiLocalDate(clock.broadcast) + " " + uiTime(clock.broadcast) + "   |   Behind live: " + catchupElapsedText(clock.behindLive)
    m.message.text += chr(10) + "Provider seek window: 0:00 - " + catchupElapsedText(clock.seekEnd) + " (availability varies)"
    m.message.text += chr(10) + "Play/Pause  Pause    Rew / FF  Skip " + catchupElapsedText(archiveSkipSeconds()) + " / hold to preview    Up  Controls    Back  Guide"
    if m.scrub <> invalid
        m.archivePreview.visible = true
        m.archivePreview.translation = [160 + 1596 * m.scrub.target / clock.duration, 750]
        m.message.text = "SEEK PREVIEW: " + catchupElapsedText(m.scrub.target) + " / " + catchupElapsedText(clock.duration) + chr(10) + "Estimated broadcast: " + uiLocalDate(request.program.startsAt + m.scrub.target) + " " + uiTime(request.program.startsAt + m.scrub.target) + chr(10) + "Preview only — no seek is sent until you commit." + chr(10) + "Hold Rew / FF  Move preview    OK / Play Seek    Back  Cancel"
    end if
end sub

function archiveSkipSeconds() as integer
    seconds = m.top.skipSeconds
    if seconds <> 60 and seconds <> 120 and seconds <> 300 then return 60
    return seconds
end function

sub beginArchiveScrub(key as string)
    if m.video.state <> "playing" and m.video.state <> "paused" then return
    if m.scrub <> invalid
        if m.scrub.key = key then return
    else
        offset = 0
        if m.top.request.offset <> invalid then offset = m.top.request.offset
        m.scrub = {identity: m.session.identity, target: offset + int(m.video.position), held: false, key: ""}
    end if
    m.scrub.key = key
    stepArchiveScrub()
    m.scrubTimer.control = "stop"
    m.scrubTimer.control = "start"
end sub

sub stepArchiveScrub()
    if m.scrub = invalid then return
    target = m.scrub.target
    if m.scrub.key = "rewind" then target -= archiveSkipSeconds() else target += archiveSkipSeconds()
    plan = catchupSeekPlan(m.top.request.program, target, uiNow())
    if m.top.request.rewind = true then plan = rewindSeekPlan(m.top.request.program, m.top.request.tuneStart, target, uiNow())
    if plan = invalid
        cancelArchiveScrub()
        return
    end if
    m.scrub.target = plan.offset
    renderArchiveProgress()
end sub

sub renderRewindProgress(offset as integer)
    request = m.top.request
    clock = rewindPlaybackClock(request.program, request.tuneStart, offset, m.session.position, uiNow())
    if clock = invalid
        m.archiveTrack.visible = false
        m.archiveFill.visible = false
        cancelArchiveScrub()
        m.message.text = "Rewind timing unavailable. Up  Go Live    Back  Return"
        return
    end if
    m.archiveTrack.visible = true
    m.archiveFill.visible = true
    m.archiveFill.width = 1600 * clock.fraction
    title = "Program information unavailable for playback time"
    if m.top.broadcastInfo <> invalid
        title = m.top.broadcastInfo.title
        if title <> "Program information unavailable for playback time"
            if m.top.broadcastInfo.status = "stale" or m.top.broadcastInfo.status = "unavailable" then title += " (cached guide)"
        end if
    end if
    m.message.text = "REWIND (provider): " + left(title, 100) + chr(10)
    m.message.text += "Estimated broadcast: " + uiLocalDate(clock.broadcast) + " " + uiTime(clock.broadcast) + "   |   Behind live: " + catchupElapsedText(clock.behindLive)
    m.message.text += chr(10) + "Requestable history: " + uiTime(clock.start) + " - " + uiTime(clock.finish) + " (up to 60 minutes since tuning; availability varies)"
    if clock.outside then m.message.text += chr(10) + "Position is older than the current range. New seeks use the current range."
    m.message.text += chr(10) + "Rew / FF  Skip " + catchupElapsedText(archiveSkipSeconds()) + " / hold to preview    Play/Pause  Pause    Up  Go Live    Back  Guide"
    if m.scrub <> invalid
        plan = rewindSeekPlan(request.program, request.tuneStart, m.scrub.target, uiNow())
        if plan <> invalid then m.scrub.target = plan.offset
        target = request.program.startsAt + m.scrub.target
        ratio = (target - clock.start) / (uiNow() - clock.start)
        if ratio < 0 then ratio = 0
        if ratio > 1 then ratio = 1
        m.archivePreview.visible = true
        m.archivePreview.translation = [160 + 1596 * ratio, 750]
        m.message.text = "REWIND PREVIEW: " + uiLocalDate(target) + " " + uiTime(target) + chr(10) + "Behind live: " + catchupElapsedText(uiNow() - target) + chr(10) + "Provider availability varies. No seek is sent until you commit." + chr(10) + "Hold Rew / FF  Move preview    OK / Play Seek    Back  Cancel"
    end if
end sub

sub repeatArchiveScrub()
    if m.scrub = invalid or m.session = invalid then return
    if m.scrub.key = "" then return
    m.scrub.held = true
    stepArchiveScrub()
end sub

sub cancelArchiveScrub()
    m.scrub = invalid
    if m.scrubTimer <> invalid then m.scrubTimer.control = "stop"
    if m.archivePreview <> invalid then m.archivePreview.visible = false
end sub

sub commitArchiveScrub()
    if m.scrub = invalid or m.session = invalid then return
    if m.scrub.identity <> m.session.identity
        cancelArchiveScrub()
        return
    end if
    target = m.scrub.target
    cancelArchiveScrub()
    m.top.archiveSeek = target
end sub

sub openArchiveActions()
    if m.session = invalid then return
    if m.session.mode <> "catchup" or m.seekingArchive then return
    cancelArchiveScrub()
    closeArchiveActions()
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Archive controls"
    dialog.message = "Go Live returns to the current broadcast of this channel."
    dialog.buttons = ["Go Live", "Keep watching archive", "Skip interval: " + catchupElapsedText(archiveSkipSeconds())]
    m.archiveDialogKind = "actions"
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
    selection = event.getData()
    kind = m.archiveDialogKind
    closeArchiveActions()
    if kind = "skip"
        choices = [60, 120, 300]
        if selection >= 0 and selection < choices.count()
            m.top.skipSeconds = choices[selection]
            m.top.skipPreference = {account: m.session.account, seconds: choices[selection]}
        end if
        m.top.setFocus(true)
        renderArchiveProgress()
    else if selection = 0
        m.top.goLiveRequested = true
    else if selection = 2
        dialog = CreateObject("roSGNode", "Dialog")
        dialog.title = "Archive skip interval"
        dialog.message = "Used for tap skips and held seek preview. Provider windows use whole minutes."
        dialog.buttons = ["1 minute", "2 minutes", "5 minutes"]
        dialog.observeField("buttonSelected", "onArchiveAction")
        dialog.observeField("wasClosed", "onArchiveActionsClosed")
        m.archiveDialogKind = "skip"
        m.archiveDialog = dialog
        m.top.getScene().dialog = dialog
    else
        m.top.setFocus(true)
    end if
end sub

sub onArchiveActionsClosed(event as object)
    if m.archiveDialog = invalid then return
    if not m.archiveDialog.isSameNode(event.getRoSGNode()) then return
    m.archiveDialog = invalid
    if m.session <> invalid then m.top.setFocus(true)
end sub
