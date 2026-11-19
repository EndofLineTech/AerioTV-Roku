sub main()
    link = normalizeLaunchRequest({contentId: "e8137d65-0e8f-4bd0-9078-2a09dd85b19f", mediaType: "liveFeed"})
    assertEqual(link.kind, "live", "supported live feed")
    assertEqual(link.id, "e8137d65-0e8f-4bd0-9078-2a09dd85b19f", "opaque channel ID retained")
    assertEqual(normalizeLaunchRequest({CONTENTID: "channel_1", MEDIATYPE: "liveFeed"}).id, "channel_1", "parameter keys are case-insensitive")
    assertEqual(normalizeLaunchRequest({contentId: "channel_1", mediaType: "livefeed"}).id, "channel_1", "documented lowercase livefeed is accepted")
    assertEqual(normalizeLaunchRequest({contentId: "channel_1", mediaType: "LIVEFEED"}).kind, "live", "media type value is case-insensitive")
    assertEqual(normalizeLaunchRequest({contentID: "channel_1", mediaType: "live"}).id, "channel_1", "cloud App Behavior Analysis live alias is accepted")
    assertEqual(normalizeLaunchRequest({contentId: "https://provider.invalid/key", mediaType: "liveFeed"}), invalid, "never accept a stream URL")
    assertEqual(normalizeLaunchRequest({contentId: "secret?key=abc", mediaType: "liveFeed"}), invalid, "never accept URL parameters")
    for each kind in ["movie", "episode", "series"]
        link = normalizeLaunchRequest({contentId: "2147483648", mediaType: ucase(kind)})
        assertEqual(link.kind, kind, "supported VOD type")
        assertEqual(link.id, "2147483648", "decimal ID remains a string")
        for each bad in ["0", "001", "12345678901", " 12", "1.2", "1/2", "1?x", "channel_1", chr(10) + "12", "12" + chr(10), 12]
            assertEqual(normalizeLaunchRequest({contentId: bad, mediaType: kind}), invalid, "invalid VOD identifier")
        end for
    end for
    duplicate = {}
    duplicate.setModeCaseSensitive()
    duplicate["contentId"] = "12"
    duplicate["ContentId"] = "13"
    duplicate["mediaType"] = "movie"
    assertEqual(normalizeLaunchRequest(duplicate), invalid, "ambiguous case aliases are rejected")
    assertEqual(normalizeLaunchRequest({contentId: "", mediaType: "liveFeed"}), invalid, "empty ID is not a channel")
    assertEqual(normalizeLaunchRequest({contentId: "channel_1"}), invalid, "both fields are required")
    assertEqual(normalizeLaunchRequest("not an event"), invalid, "invalid event ignored")
    assertEqual(launchRequestHasMediaIntent({contentId: "channel_1", mediaType: "live"}), true, "media intent suppresses optional selection")
    assertEqual(launchRequestHasMediaIntent({contentId: "https://invalid.test", mediaType: "movie"}), true, "unplayable media intent still skips selection, never validation")
    assertEqual(launchRequestHasMediaIntent({CONTENTID: 7}), true, "malformed media intent grants no playback but is not ordinary launch")
    assertEqual(launchRequestHasMediaIntent({contentId: "", mediaType: ""}), false, "empty launch fields are not a media selection")
    assertEqual(launchRequestHasMediaIntent({source: "homescreen"}), false, "ordinary app launch preserves picker")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label
        stop
    end if
end sub
