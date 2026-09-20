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
    print "ALL TESTS PASSED"
end sub
