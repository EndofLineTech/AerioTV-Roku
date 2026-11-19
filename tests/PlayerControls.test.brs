sub main()
    ' Exercise the component's native key handler with focus owned by the
    ' controls, including when focus is on a button other than Play.
    m.top = {active: true, context: "live", paused: true, action: ""}
    m.index = 2
    m.lastAnnouncedIndex = 2
    m.actions = ["play", "channels", "recent"]
    if not onKeyEvent("playonly", true) then stop
    if m.top.action <> "playonly"
        print "FAIL: focused Resume did not emit its own action"
        stop
    end if
    if m.index <> 2 then stop
    m.top.action = ""
    if onKeyEvent("playonly", false) or m.top.action <> "" then stop
    if not onKeyEvent("play", true) or m.top.action <> "play" then stop
    if not onKeyEvent("OK", true) or m.top.action <> "recent" then stop
    if onKeyEvent("options", true) then stop
    m.top.context = "recording"
    if not onKeyEvent("rewind", true) or m.top.action <> "rewind" then stop
    m.top.action = ""
    if not onKeyEvent("playonly", true) or m.top.action <> "" then stop
    m.top.active = false
    if onKeyEvent("playonly", true) then stop
    print "ALL TESTS PASSED"
end sub
