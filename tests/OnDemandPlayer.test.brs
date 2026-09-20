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
    print "ALL TESTS PASSED"
end sub
