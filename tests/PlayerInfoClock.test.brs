sub main()
    m.ready = true
    m.base = ""
    for each key in ["channelName", "logo", "clock", "state", "hint", "title", "description", "times", "progressTrack", "progressFill", "progressText", "nextTitle", "nextTimes", "dataStatus"]
        m[key] = {}
    end for
    programs = [
        {id: "old", title: "Watching old show", startsAt: 1000, endsAt: 1050, subtitle: "", description: "Old description"}
        {id: "new", title: "Currently on air", startsAt: 1050, endsAt: 1200, subtitle: "", description: "New description"}
    ]
    m.top = {visible: true, now: 1100, playbackState: "paused", hint: "", channel: {uuid: "channel", name: "Example", number: "1", logoId: ""}, info: {channelUuid: "channel", status: "ready", programs: programs}, playhead: {known: true, epoch: 1020, delay: 80, delayed: true, estimated: true}}
    renderInfo()
    if m.title.text <> "Watching old show" or m.state.text <> "PAUSED" then stop
    if instr(1, m.progressText.text, "80s behind live") = 0 then stop
    if instr(1, m.progressText.text, "Estimated") = 0 then stop
    if m.nextTitle.text <> "Currently on air" then stop
    m.top.info.status = "stale"
    renderInfo()
    if m.dataStatus.text <> "Cached guide for playback time" then stop
    m.top.info.status = "ready"
    m.top.playbackState = "playing"
    renderInfo()
    if m.state.text <> "DELAYED" or m.title.text <> "Watching old show" then stop
    m.top.playhead = {known: false}
    renderInfo()
    if m.title.text <> "Playback time unavailable" or m.progressTrack.visible then stop
    m.top.playhead = {known: true, epoch: 1100, delay: 0, delayed: false, estimated: true}
    renderInfo()
    if m.title.text <> "Currently on air" or m.state.text <> "LIVE" then stop
    print "ALL TESTS PASSED"
end sub
