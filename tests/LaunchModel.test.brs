sub main()
    link = normalizeLaunchRequest({contentId: "e8137d65-0e8f-4bd0-9078-2a09dd85b19f", mediaType: "liveFeed"})
    assertEqual(link.kind, "live", "supported live feed")
    assertEqual(link.id, "e8137d65-0e8f-4bd0-9078-2a09dd85b19f", "opaque channel ID retained")
    assertEqual(normalizeLaunchRequest({CONTENTID: "channel_1", MEDIATYPE: "liveFeed"}).id, "channel_1", "parameter keys are case-insensitive")
    assertEqual(normalizeLaunchRequest({contentId: "https://provider.invalid/key", mediaType: "liveFeed"}), invalid, "never accept a stream URL")
    assertEqual(normalizeLaunchRequest({contentId: "secret?key=abc", mediaType: "liveFeed"}), invalid, "never accept URL parameters")
    assertEqual(normalizeLaunchRequest({contentId: "channel_1", mediaType: "movie"}), invalid, "unsupported VOD must not start live video")
    assertEqual(normalizeLaunchRequest({contentId: "", mediaType: "liveFeed"}), invalid, "empty ID is not a channel")
    assertEqual(normalizeLaunchRequest({contentId: "channel_1"}), invalid, "both fields are required")
    assertEqual(normalizeLaunchRequest("not an event"), invalid, "invalid event ignored")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label
        stop
    end if
end sub
