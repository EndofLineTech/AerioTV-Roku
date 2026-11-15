sub main()
    m.input = {focus: 1, count: 3, armed: true, held: false}
    m.holdTimer = {control: "start"}
    m.top = {busy: true, model: {purpose: "launch", back: "exit"}}
    check(onKeyEvent("back", true), "busy picker owns Back")
    check(m.top.intent <> invalid, "busy picker must notify parent rather than swallow Back")
    check(m.top.intent.action = "back" and not m.input.armed and m.holdTimer.control = "stop", "Back cancels hold and lets launch owner exit even while loading")
    m.top.intent = invalid
    check(onKeyEvent("OK", true) and m.top.intent = invalid, "busy picker still refuses a second selection")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
