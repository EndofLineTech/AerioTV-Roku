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
    m.recordingPanel = uiSurface(m.top, 96, 694, 1728, 318, 20, "0x0A1628EF")
    m.recordingTrack = uiRect(m.top, 128, 933, 1664, 6, "0x294357FF")
    m.recordingFill = uiRect(m.top, 128, 933, 0, 6, "0x1AC4D8FF")
    m.recordingPreview = uiRect(m.top, 128, 927, 4, 18, "0xFFFFFFFF")
    m.recordingMessage = uiLabel(m.top, "", 128, 750, 1664, 174, uiTypeSize("body"))
    m.recordingMessage.wrap = true
    m.recordingPanel.visible = false
    m.recordingTrack.visible = false
    m.recordingFill.visible = false
    m.recordingPreview.visible = false
    m.recordingMessage.visible = false
    m.recordingTimer = m.top.createChild("Timer")
    m.recordingTimer.duration = 8
    m.recordingTimer.observeField("fire", "onRecordingIntroTimeout")
    m.recordingControls = m.top.createChild("PlayerControls")
    m.recordingControls.id = "recordingControls"
    m.recordingControls.context = "recording"
    m.recordingControls.visible = false
    m.recordingControls.observeField("action", "onRecordingControlAction")
    m.recordingControls.observeField("dismissed", "onRecordingControlsDismissed")
    m.recordingControls.observeField("infoFocus", "onRecordingInfoFocus")
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
    hideRecordingOverlay()
    m.message.visible = true
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
    m.handoffCheckRequested = false
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
    content.httpHeaders = mediaPlaybackHeaders(request.apiKey, textValue(m.global.httpUserAgent))
    m.pendingResume = 0
    m.resumeNoticeUntil = 0
    m.resumeTarget = 0
    m.resumeWatch = invalid
    if request.resume <> invalid then m.pendingResume = int(request.resume)
    m.video.content = content
    print "[on-demand] reader="; content.streamFormat; " mode="; request.mode
    appControls = request.mode = "catchup" or (request.mode = "recording" and request.growing = true)
    m.video.enableUI = not appControls
    m.video.enableTrickPlay = not appControls
    m.video.enableLiveAvailabilityWindow = request.mode = "recording" and request.growing = true
    m.video.visible = true
    m.top.visible = true
    m.opening = false
    m.video.control = "play"
    if appControls then m.top.setFocus(true) else m.video.setFocus(true)
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
        if m.session.mode = "recording" and m.top.request.growing = true
            m.message.visible = false
            m.recordingControls.paused = state = "paused"
            if not m.recordingPanel.visible then showRecordingInfo()
        end if
        reportProgress()
    else if state = "error"
        cancelArchiveScrub()
        hideRecordingOverlay()
        m.message.visible = true
        m.mediaFailed = true
        m.top.diagnostic = {mode: m.session.mode, code: m.video.errorCode, message: sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)}
        print "[on-demand] failure code="; m.video.errorCode; " detail="; sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)
        ' Dispatcharr removes a finished recording's HLS directory and redirects
        ' the old playlist URL to an MKV. Ask the scene to verify current status
        ' before changing readers; a redirect is not a valid HLS playlist.
        if m.session.mode = "recording" and m.top.request.growing = true
            m.top.recordingHandoff = {account: m.session.account, identity: m.session.identity, id: m.session.item, position: m.session.position}
        end if
        m.message.text = playbackFailureText(m.video.errorCode, sanitizePlaybackDiagnostic(m.video.errorStr, m.top.request.apiKey)) + chr(10) + "OK Retry    Back Return"
        if m.session.mode = "vod"
            if m.top.request.providerType = "xtream"
                m.message.text += chr(10) + "If this title keeps failing, return to its category or sign in again."
            else
                m.message.text += chr(10) + "If this source keeps failing: Back to the title, then Choose source version (authorized accounts)."
            end if
        end if
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
        hideRecordingOverlay()
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
    if m.session.mode = "recording" and m.top.request.growing = true
        if m.video.state = "playing" or m.video.state = "paused" then renderRecordingProgress()
    end if
    if m.video.state = "buffering"
        ' A live HLS reader may stall at its final segment instead of emitting
        ' an error when its old playlist URL starts redirecting to the MKV.
        ' Check completion once after a sustained near-edge stall; keep the
        ' playing/paused sample, never the speculative buffering playhead.
        if m.session.mode = "recording" and m.top.request.growing = true and m.handoffCheckRequested <> true
            if m.elapsed.totalSeconds() >= 10 and mediaNumber(m.session.position) and mediaNumber(m.session.duration)
                if m.session.duration >= 12 and m.session.position >= m.session.duration - 12
                    m.handoffCheckRequested = true
                    m.top.recordingHandoff = {account: m.session.account, identity: m.session.identity, id: m.session.item, position: m.session.position}
                end if
            end if
        end if
        m.message.text = "Buffering (" + m.elapsed.totalSeconds().toStr() + "s). Back returns."
        if m.session.mode = "recording" and m.top.request.growing = true and m.recordingPanel.visible
            m.recordingMessage.text = "Buffering recording... Back returns to DVR."
        end if
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

sub hideRecordingOverlay()
    if m.recordingTimer <> invalid then m.recordingTimer.control = "stop"
    if m.recordingControls <> invalid
        m.recordingControls.active = false
        m.recordingControls.visible = false
    end if
    if m.recordingPanel <> invalid then m.recordingPanel.visible = false
    if m.recordingTrack <> invalid then m.recordingTrack.visible = false
    if m.recordingFill <> invalid then m.recordingFill.visible = false
    if m.recordingPreview <> invalid then m.recordingPreview.visible = false
    if m.recordingMessage <> invalid then m.recordingMessage.visible = false
    if m.message <> invalid then m.message.visible = true
end sub

sub showRecordingInfo()
    if m.session = invalid then return
    if m.session.mode <> "recording" or m.top.request.growing <> true then return
    m.recordingPanel.visible = true
    m.recordingMessage.visible = true
    m.recordingControls.visible = true
    m.message.visible = false
    if not m.recordingControls.active
        m.recordingTimer.control = "stop"
        m.recordingTimer.control = "start"
    end if
    renderRecordingProgress()
end sub

sub enterRecordingControls()
    showRecordingInfo()
    m.recordingTimer.control = "stop"
    m.recordingControls.active = true
    m.recordingControls.setFocus(true)
end sub

sub onRecordingIntroTimeout()
    if m.recordingControls.active or m.scrub <> invalid then return
    hideRecordingOverlay()
    if m.session <> invalid then m.top.setFocus(true)
end sub

sub onRecordingControlsDismissed()
    cancelArchiveScrub()
    hideRecordingOverlay()
    if m.session <> invalid then m.top.setFocus(true)
end sub

sub onRecordingInfoFocus()
    if m.session = invalid then return
    m.recordingControls.active = false
    showRecordingInfo()
    m.recordingTimer.control = "stop"
    m.top.setFocus(true)
end sub

sub onRecordingControlAction(event as object)
    if m.session = invalid or m.session.mode <> "recording" or m.top.request.growing <> true then return
    action = event.getData()
    if action = "play"
        if m.scrub <> invalid
            commitRecordingScrub()
            return
        end if
        if m.video.state = "paused" then m.video.control = "resume" else if m.video.state = "playing" then m.video.control = "pause"
    else if action = "rewind" or action = "fastforward"
        if m.video.state <> "playing" and m.video.state <> "paused"
            m.recordingMessage.text = "Wait for recording playback before seeking."
            return
        end if
        direction = 1
        if action = "rewind" then direction = -1
        plan = recordingSeekTarget(m.video.position, m.video.duration, direction, 30, true)
        if plan = invalid
            m.recordingMessage.text = "Seek range unavailable. Playback continues."
        else if plan.moved
            print "[recording-controls] seek="; plan.position
            m.video.seek = plan.position
        else
            m.recordingMessage.text = "Already at the available recording limit."
        end if
    else if action = "stop"
        closeMedia() ' Stops this viewer, never the server's recording.
    end if
end sub

sub renderRecordingProgress()
    if m.session = invalid or not m.recordingPanel.visible then return
    if m.session.mode <> "recording" or m.top.request.growing <> true then return
    m.recordingControls.paused = m.video.state = "paused"
    duration = m.video.duration
    position = m.video.position
    if not mediaNumber(duration) or not mediaNumber(position) or duration < 12 or position < 0
        m.recordingTrack.visible = false
        m.recordingFill.visible = false
        m.recordingMessage.text = "RECORDING: " + left(m.top.request.title, 100) + chr(10) + "Seek range unavailable. Play/Pause still works; Back returns to DVR."
        return
    end if
    m.recordingTrack.visible = true
    m.recordingFill.visible = true
    fraction = position / duration
    if fraction < 0 then fraction = 0
    if fraction > 1 then fraction = 1
    m.recordingFill.width = 1664 * fraction
    stateLabel = "RECORDING NOW"
    if m.video.state = "paused" then stateLabel += " (paused)"
    m.recordingMessage.text = stateLabel + ": " + left(m.top.request.title, 100) + chr(10)
    m.recordingMessage.text += "Position " + catchupElapsedText(int(position)) + " / " + catchupElapsedText(int(duration)) + " (growing file)" + chr(10)
    m.recordingMessage.text += "Rew / FF  30s / hold to preview    OK  Controls    Back  DVR"
    if m.scrub <> invalid
        m.recordingPreview.visible = true
        preview = m.scrub.target / duration
        if preview < 0 then preview = 0
        if preview > 1 then preview = 1
        m.recordingPreview.translation = [128 + 1660 * preview, 927]
        m.recordingMessage.text = "RECORDING SEEK PREVIEW: " + catchupElapsedText(m.scrub.target) + " / " + catchupElapsedText(int(duration)) + chr(10) + "Preview only; no seek until confirmed." + chr(10) + "Rew / FF  Move    OK / Play  Seek    Back  Cancel"
    end if
end sub

sub closeMedia()
    cancelArchiveScrub()
    hideRecordingOverlay()
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
    growing = m.session.mode = "recording" and m.top.request.growing = true
    if (m.session.mode = "catchup" or growing) and (key = "rewind" or key = "fastforward")
        if press
            if growing then beginRecordingScrub(key) else beginArchiveScrub(key)
        else if m.scrub <> invalid
            if m.scrub.key = key
                m.scrub.key = ""
                m.scrubTimer.control = "stop"
                if not m.scrub.held
                    if growing then commitRecordingScrub() else commitArchiveScrub()
                end if
            end if
        end if
        return true
    end if
    if not press then return false
    if m.scrub <> invalid
        if key = "OK" or key = "play"
            if growing then commitRecordingScrub() else commitArchiveScrub()
        else if key = "back"
            cancelArchiveScrub()
            if growing then renderRecordingProgress() else renderArchiveProgress()
        else if key = "up"
            cancelArchiveScrub()
            if growing then enterRecordingControls() else openArchiveActions()
        end if
        return true
    end if
    if key = "back"
        if growing and m.recordingPanel.visible
            hideRecordingOverlay()
            m.top.setFocus(true)
            return true
        end if
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
    if growing
        if key = "OK" or key = "up" or key = "down"
            enterRecordingControls()
            return true
        end if
        if key = "play"
            if m.video.state = "paused" then m.video.control = "resume" else if m.video.state = "playing" then m.video.control = "pause"
            showRecordingInfo()
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

sub beginRecordingScrub(key as string)
    if m.video.state <> "playing" and m.video.state <> "paused" then return
    if m.scrub <> invalid
        if m.scrub.key = key then return
    else
        if not mediaNumber(m.video.position) or not mediaNumber(m.video.duration)
            showRecordingInfo()
            m.recordingMessage.text = "Seek range unavailable. Playback continues."
            return
        end if
        m.scrub = {identity: m.session.identity, origin: int(m.video.position), target: int(m.video.position), held: false, key: ""}
    end if
    m.scrub.key = key
    showRecordingInfo()
    stepRecordingScrub()
    if m.scrub = invalid then return
    m.scrubTimer.control = "stop"
    m.scrubTimer.control = "start"
end sub

sub stepRecordingScrub()
    if m.scrub = invalid then return
    direction = 1
    if m.scrub.key = "rewind" then direction = -1
    plan = recordingSeekTarget(m.scrub.target, m.video.duration, direction, 30, true)
    if plan = invalid
        cancelArchiveScrub()
        m.recordingMessage.text = "Seek range unavailable. Playback continues."
        return
    end if
    if not plan.moved
        cancelArchiveScrub()
        m.recordingMessage.text = "Already at the available recording limit."
        return
    end if
    m.scrub.target = plan.position
    renderRecordingProgress()
end sub

sub commitRecordingScrub()
    if m.scrub = invalid or m.session = invalid then return
    target = m.scrub.target
    valid = m.scrub.identity = m.session.identity and target <> m.scrub.origin
    if not mediaNumber(m.video.duration) then valid = false
    if valid then valid = target >= 0 and target <= int(m.video.duration) - 6
    if valid then valid = m.video.state = "playing" or m.video.state = "paused"
    cancelArchiveScrub()
    if valid
        print "[recording-controls] seek="; target
        m.video.seek = target
        m.recordingMessage.text = "Seeking within the available recording window..."
    else
        m.recordingMessage.text = "Seek range changed. Playback continues at the current position."
    end if
end sub

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
    if m.session.mode = "recording" and m.top.request.growing = true then stepRecordingScrub() else stepArchiveScrub()
end sub

sub cancelArchiveScrub()
    m.scrub = invalid
    if m.scrubTimer <> invalid then m.scrubTimer.control = "stop"
    if m.archivePreview <> invalid then m.archivePreview.visible = false
    if m.recordingPreview <> invalid then m.recordingPreview.visible = false
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
