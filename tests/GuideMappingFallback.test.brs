sub main()
    channel = {tvgId: "direct-guide-id", epgId: "mapped-id"}
    assertEqual(guideMappingKey(channel, {ok: false}), "direct-guide-id", "mapping failure preserves direct guide ID")
    assertEqual(guideMappingKey(channel, {ok: true, links: {"mapped-id": "mapped-guide-id"}}), "mapped-guide-id", "successful mapping overrides direct guide ID")
    assertEqual(guideMappingKey({tvgId: "direct-guide-id", epgId: "mapped-id"}, {ok: true, links: {}}), "direct-guide-id", "missing mapped row preserves direct guide ID")
    assertEqual(guideMappingKey({tvgId: "", epgId: "mapped-id"}, {ok: false}), "", "missing direct guide ID remains unavailable")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
