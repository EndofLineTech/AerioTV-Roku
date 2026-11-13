sub main()
    m.top = {close: false, buttonSelected: -1, wasClosed: false}
    m.input = {text: "", maxTextLength: 6}
    check(onKeyEvent("up", true) and m.input.text = "U", "D-pad enters direction without showing its plaintext")
    onKeyEvent("down", true)
    onKeyEvent("left", true)
    onKeyEvent("OK", true)
    check(m.top.buttonSelected = -1, "three directions cannot submit")
    onKeyEvent("right", true)
    check(m.input.text = "UDLR" and m.top.buttonSelected = -1, "minimum length does not auto-submit")
    onKeyEvent("OK", true)
    check(m.top.buttonSelected = 0, "Select explicitly submits")
    m.top.buttonSelected = -1
    onKeyEvent("back", true)
    check(m.input.text = "" and not m.top.wasClosed, "Back first clears entered directions")
    onKeyEvent("back", true)
    check(m.top.wasClosed, "Back on empty developer pad signals protected app exit")
    m.top.wasClosed = false
    for i = 1 to 8
        onKeyEvent("up", true)
    end for
    check(len(m.input.text) = 6, "input stops at bounded six directions")
    onKeyEvent("options", true)
    check(m.top.wasClosed, "Options never opens an unprotected secondary dialog")
    m.top.wasClosed = false
    check(not onKeyEvent("up", false) and len(m.input.text) = 6, "key releases do not create extra entries")
    m.input.text = ""
    m.input.maxTextLength = 4
    for i = 1 to 6
        onKeyEvent("right", true)
    end for
    check(m.input.text = "RRRR", "known local direction length bounds displayed slots and input")
    m.dots = []
    for i = 0 to 5
        m.dots.push({outer: {}, inner: {}})
    end for
    m.input.text = "UD"
    onDirectionText()
    check(m.dots[0].outer.translation[0] = 848 and not m.dots[0].inner.visible and m.dots[2].inner.visible and not m.dots[4].outer.visible, "native shapes mask entries and center known-length dots without unsupported font glyphs")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
