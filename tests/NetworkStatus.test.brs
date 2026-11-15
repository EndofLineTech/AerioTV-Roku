sub main()
    for each value in [invalid, {}, {generalMemoryLevel: "low"}, {linkStatus: "true"}, {linkStatus: 1}]
        result = networkLinkTransition(false, value)
        check(not result.changed and not result.returned and result.linked = false, "unrelated or malformed device events cannot fabricate network return")
    end for
    result = networkLinkTransition(false, {linkStatus: true})
    check(result.changed and result.returned and result.linked, "only confirmed disconnected-to-connected transition requests sync")
    result = networkLinkTransition(true, {linkStatus: true})
    check(not result.changed and not result.returned, "duplicate online status cannot storm discovery")
    result = networkLinkTransition(true, {linkStatus: false})
    check(result.changed and not result.returned and not result.linked, "link loss is observed without scheduling a request")
    result = networkLinkTransition(invalid, {linkStatus: true})
    check(result.changed and not result.returned, "first online observation is not a fabricated offline-to-online edge")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
