sub main()
    m.session = mediaSession("account", "session", "vod", "item", 1000)
    mediaObserve(m.session, "playing", 5, 100, invalid)
    m.top = {request: {apiKey: "private"}, setFocus: sub(value)
    end sub}
    m.video = {state: "buffering", position: 60, duration: 100, visible: true, errorCode: -1, errorStr: "HTTP 500 https://host/private"}
    m.elapsed = {totalSeconds: function()
        return 2
    end function}
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
    print "ALL TESTS PASSED"
end sub
