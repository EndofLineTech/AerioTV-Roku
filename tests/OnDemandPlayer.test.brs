sub main()
    m.session = mediaSession("account", "session", "vod", "item", 1000)
    mediaObserve(m.session, "playing", 5, 100, invalid)
    m.top = {request: {apiKey: "private"}, setFocus: sub(value)
    end sub}
    m.video = {state: "buffering", position: 60, duration: 100, visible: true, errorCode: -1, errorStr: "HTTP 500 https://host/private"}
    m.elapsed = {totalSeconds: function()
        return 2
    end function, mark: sub()
    end sub}
    m.message = {text: ""}
    m.clock = {control: "start"}
    m.opening = false
    m.finished = false
    m.closing = false
    reportProgress()
    if m.top.progress.position <> 5 then stop
    m.video.state = "error"
    onMediaState()
    if not m.mediaFailed or instr(1, m.message.text, "private") > 0 then stop
    m.video.state = "finished"
    onMediaState()
    if m.session = invalid or m.finished then stop
    m.session = mediaSession("account", "restart-session", "catchup", "program", 1000)
    m.top.request.restart = true
    m.mediaFailed = false
    m.video.state = "finished"
    onMediaState()
    if m.session = invalid or not m.finished then stop
    if m.clock.control <> "stop" or m.video.visible then stop
    if instr(1, m.message.text, "end of the available archive window") = 0 then stop
    m.video.state = "error"
    m.video.errorStr = "HTTP 503"
    onMediaState()
    if instr(1, m.message.text, "Archive not yet available") = 0 then stop
    m.video.errorStr = "HTTP 403"
    onMediaState()
    if instr(1, m.message.text, "Archive not yet available") > 0 then stop
    m.top.request = {account: "account", title: "Example", program: {id: "p", startsAt: 1000, endsAt: 1600}, offset: 0}
    m.top.skipSeconds = 60
    m.top.archiveSeek = invalid
    m.video.state = "playing"
    m.video.position = 70
    m.video.visible = true
    m.session.position = 70
    m.scrub = invalid
    m.scrubTimer = {}
    m.archiveTrack = {}
    m.archiveFill = {}
    m.archivePreview = {}
    handleArchiveKey("fastforward", true)
    if m.top.archiveSeek <> invalid or m.scrub.target <> 120 then stop
    handleArchiveKey("fastforward", false)
    if m.top.archiveSeek <> 120 or m.scrub <> invalid then stop
    m.top.archiveSeek = invalid
    handleArchiveKey("rewind", true)
    repeatArchiveScrub()
    handleArchiveKey("rewind", false)
    if m.top.archiveSeek <> invalid or m.scrub.target <> 0 then stop
    handleArchiveKey("back", true)
    if m.scrub <> invalid or m.top.archiveSeek <> invalid or m.video.state <> "playing" then stop
    handleArchiveKey("fastforward", true)
    repeatArchiveScrub()
    repeatArchiveScrub()
    handleArchiveKey("fastforward", false)
    if m.top.archiveSeek <> invalid or m.scrub.target <> 240 then stop
    handleArchiveKey("OK", true)
    if m.top.archiveSeek <> 240 or m.scrub <> invalid then stop
    m.top.archiveSeek = invalid
    handleArchiveKey("fastforward", true)
    m.session.identity = "replacement"
    handleArchiveKey("fastforward", false)
    if m.top.archiveSeek <> invalid then stop
    m.session = mediaSession("account", "recording-session", "recording", "recording-id", 1000)
    m.top.request = {account: "account", apiKey: "private", title: "Test recording", mode: "recording"}
    m.video = {state: "playing", position: 0, duration: 120, visible: true, seek: 0}
    m.startPaused = false
    m.pendingResume = 80
    onMediaState()
    if m.video.seek <> 80 or m.pendingResume <> 0 then stop
    m.video.position = 81
    reportProgress()
    if m.resumeTarget <> 0 then stop
    m.top.request.growing = true
    m.video.position = 60
    m.video.seek = 0
    m.recordingPanel = {visible: false}
    m.recordingTrack = {visible: false}
    m.recordingFill = {visible: false, width: 0}
    m.recordingPreview = {visible: false, translation: []}
    m.recordingMessage = {text: ""}
    m.recordingControls = {visible: false, active: false, paused: false, setFocus: sub(value as boolean)
    end sub}
    m.recordingTimer = {control: "stop"}
    if not handleArchiveKey("rewind", true) or m.scrub.target <> 30 then stop
    if m.video.seek <> 0 or m.session = invalid then stop ' preview never seeks
    handleArchiveKey("rewind", false)
    if m.video.seek <> 30 or m.scrub <> invalid or m.session = invalid then stop
    m.video.position = 120
    if not handleArchiveKey("fastforward", true) then stop
    handleArchiveKey("fastforward", false)
    if m.video.seek <> 30 then stop ' cannot seek beyond the growing edge
    m.video.position = 60
    if not handleArchiveKey("OK", true) or not m.recordingControls.active then stop
    if m.video.state <> "playing" then stop ' opening controls does not retune or pause
    m.recordingControls.active = false
    m.video.position = 60
    handleArchiveKey("rewind", true)
    repeatArchiveScrub()
    handleArchiveKey("rewind", false)
    if m.scrub = invalid or m.scrub.target <> 0 then stop
    handleArchiveKey("back", true)
    if m.scrub <> invalid or m.video.seek <> 30 or m.session = invalid then stop
    m.video.position = 60
    handleArchiveKey("fastforward", true)
    repeatArchiveScrub()
    handleArchiveKey("fastforward", false)
    if m.scrub = invalid or m.scrub.target <> 114 then stop
    handleArchiveKey("OK", true)
    if m.video.seek <> 114 or m.scrub <> invalid then stop
    onRecordingControlAction({getData: function() as string
        return "play"
    end function})
    if m.video.control <> "pause" or m.session = invalid then stop
    m.video.state = "buffering"
    onRecordingControlAction({getData: function() as string
        return "fastforward"
    end function})
    if m.video.seek <> 114 then stop ' buffering cannot accept another seek
    m.session.position = 115
    m.session.duration = 120
    m.elapsed.totalSeconds = function()
        return 12
    end function
    m.top.recordingHandoff = invalid
    reportProgress()
    if m.top.recordingHandoff = invalid or m.top.recordingHandoff.position <> 115 then stop
    m.top.recordingHandoff = invalid
    reportProgress()
    if m.top.recordingHandoff <> invalid then stop ' one status check per near-edge stall
    m.elapsed.totalSeconds = function()
        return 2
    end function
    m.video.state = "playing"
    m.video.position = 45
    reportProgress()
    m.top.recordingHandoff = invalid
    m.video.state = "error"
    m.video.errorCode = -3
    m.video.errorStr = "reader pick stream error:bad:mpr playlist file is too large"
    onMediaState()
    if m.top.recordingHandoff = invalid then stop
    if m.top.recordingHandoff.account <> "account" or m.top.recordingHandoff.identity <> "recording-session" then stop
    if m.top.recordingHandoff.id <> "recording-id" or m.top.recordingHandoff.position <> 45 then stop
    m.top.request.growing = false
    m.top.recordingHandoff = invalid
    onMediaState()
    if m.top.recordingHandoff <> invalid then stop ' finished-file errors never request an HLS handoff
    if handleArchiveKey("rewind", true) then stop ' completed recording retains native path
    print "ALL TESTS PASSED"
end sub
