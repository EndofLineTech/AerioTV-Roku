sub main()
    assertEqual(normalizeBaseUrl(" https://tv.example.test/base/// "), "https://tv.example.test/base", "trim base")
    assertEqual(normalizeBaseUrl("ftp://tv.example.test"), "", "reject scheme")
    assertEqual(normalizeBaseUrl("https://"), "", "reject missing host")
    assertEqual(normalizeBaseUrl("https://user:pass@tv.example.test"), "", "reject embedded credentials")
    assertEqual(normalizeBaseUrl("https://tv.example.test/?key=secret"), "", "reject query")
    assertEqual(trustedPageUrl("https://tv.test", "/api/channels/?page=2"), "https://tv.test/api/channels/?page=2", "relative page")
    assertEqual(trustedPageUrl("https://tv.test", "https://tv.test.evil/api/"), "", "reject cross origin page")
    assertEqual(trustedPageUrl("https://tv.test", "//evil.test/api/"), "", "reject protocol relative page")
    assertEqual(trustedPageUrl("https://tv.test", "http://tv.test/api/"), "", "reject downgrade")
    assertEqual(apiRows({results: [1, 2]}).count(), 2, "paginated list")
    assertEqual(apiRows({data: [1]}).count(), 1, "data wrapper")
    assertEqual(apiRows([1, 2, 3]).count(), 3, "flat list")
    assertEqual(apiRows({detail: "error"}), invalid, "malformed list differs from empty")
    assertEqual(apiRows({results: []}).count(), 0, "empty list")
    channel = normalizeChannel({id: 4, uuid: "abc-123", name: "Local", channel_number: "2.1", channel_group: 9})
    assertEqual(channel.number, "2.1", "decimal channel number")
    assertEqual(channel.groupId, "9", "legacy group key")
    assertEqual(normalizeChannel({id: 4, name: "Missing UUID"}), invalid, "unplayable row")
    assertEqual(normalizeChannel("wrong"), invalid, "bad row")
    channels = [channel, normalizeChannel({id: 5, uuid: "def-456", name: "News", channel_number: 12})]
    assertEqual(filterChannels(channels, "all", {}).count(), 2, "all channels")
    assertEqual(filterChannels(channels, "group:9", {}).count(), 1, "group filter")
    assertEqual(filterChannels(channels, "favorites", {"abc-123": true}).count(), 1, "favorites")
    assertEqual(filterChannels(channels, "favorites", {}).count(), 0, "empty favorites")
    groups = serverGroupOrder([{id: "9", name: "Zulu"}, {id: "1", name: "alpha"}, {id: "4", name: "Sports"}])
    assertEqual(groups[0].name, "alpha", "0.31 server guide name ordering")
    groups = serverGroupOrder([{id: "9", name: "Zulu", order: 0}, {id: "1", name: "alpha", order: 2}])
    assertEqual(groups[0].name, "Zulu", "explicit server rank overrides name")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
