sub main()
    m.phoneSetupRecentDraws = invalid
    check(phoneSetupAcceptDeviceDraw(string(64, "a"), 0) = invalid and phoneSetupAcceptDeviceDraw(string(64, "a"), 33) = invalid, "invalid draw sizes are refused")
    check(phoneSetupAcceptDeviceDraw(invalid, 32) = invalid and phoneSetupAcceptDeviceDraw(7, 32) = invalid, "unavailable or malformed platform digest is refused")
    check(phoneSetupAcceptDeviceDraw("short", 32) = invalid and phoneSetupAcceptDeviceDraw(string(64, "z"), 32) = invalid, "digest must be exactly32 hex bytes")
    first = phoneSetupAcceptDeviceDraw(string(64, "A"), 32)
    check(first = string(64, "a"), "accepted device digest is canonical and complete")
    check(phoneSetupAcceptDeviceDraw(string(64, "a"), 4) = invalid, "repeated device draw fails closed across requested sizes")
    m.phoneSetupRecentDraws = invalid
    for i = 1 to 8
        sample = phoneSetupAcceptDeviceDraw("0" + i.toStr() + string(62, "a"), 4)
        check(type(sample) = "String" and len(sample) = 8, "fresh device draw yields exactly4 hex bytes")
    end for
    check(phoneSetupAcceptDeviceDraw("01" + string(62, "a"), 32) = invalid, "nonadjacent recent draw reuse is refused")
    check(m.phoneSetupRecentDraws.count() = 8, "invalid/reused draw does not advance history")
    m.phoneSetupRecentDraws = invalid
    for i = 1 to 40
        sample = phoneSetupAcceptDeviceDraw(right("00" + i.toStr(), 2) + string(62, "a"), 4)
        check(type(sample) = "String", "fresh draws remain usable beyond the bounded history")
    end for
    check(m.phoneSetupRecentDraws.count() = 32, "secret-digest history remains bounded in Task memory")
    m.phoneSetupRecentDraws = invalid
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
