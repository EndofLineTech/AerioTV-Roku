sub main()
    m.global = invalid
    check(requestGateRenderAllowed("https://example.test/a", ""), "standalone fixtures have no mandatory bootstrap")
    m.global = {requestGateRequired: true}
    check(not requestGateRenderAllowed("https://example.test/a", ""), "mandatory app never fails open without broker")
    check(requestGateRenderAllowed("pkg:/images/a.png", "key"), "packaged artwork never needs network permission")
    check(requestGateRenderAllowed("tmp:/cached.png", "key"), "local cached artwork remains usable")
    m.global.requestGate = {ready: true, snapshot: requestGateDefault()}
    check(requestGateRenderAllowed("https://example.test/a", ""), "fresh host admitted")
    state = requestGateDefault()
    state.servers["example.test:443"] = CreateObject("roDateTime").asSeconds() + 60
    m.global.requestGate.snapshot = state
    check(not requestGateRenderAllowed("https://EXAMPLE.TEST:443/art", ""), "park blocks renderer regardless of path")
    check(not requestGateAccessAllowed("https://example.test/api/", ""), "cache authorization cannot bypass host park")
    check(requestGateRenderAllowed("https://other.test/art", ""), "renderer does not park another host")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
