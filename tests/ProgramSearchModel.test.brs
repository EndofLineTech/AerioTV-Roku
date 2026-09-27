sub main()
    now = guideEpoch("2023-11-14T22:13:20Z")
    channels = [{id: "1", uuid: "a", name: "Effective name", number: "10", epgKey: "station"}, {id: "2", uuid: "b", name: "Overridden station", epgKey: "other"}]
    row = {id: 42, title: "News", start_time: now - 100, end_time: now + 100, tvg_id: "station", channels: [{id: 1, name: "Wrong name"}, {id: 2}, {id: 999}]}
    results = programSearchResults([row, row, invalid], channels, now)
    assertEqual(results.items.count(), 1, "deduplicate; restrict to lineup and effective mapping")
    assertEqual(results.items[0].channel.name, "Effective name", "use effective channel metadata")
    assertEqual(programSearchState(results.items[0].program, now), "Now", "current result")
    assertEqual(programSearchState({startsAt: now + 1, endsAt: now + 10}, now), "Upcoming", "future result")
    assertEqual(programSearchState({startsAt: now - 10, endsAt: now}, now), "Past", "half-open boundary")
    assertEqual(programSearchResults([row], [], now).items.count(), 0, "empty account cannot expose results")
    assertEqual(programSearchResults([row], channels, now, 0).truncated, true, "fanout cap explicit")
    second = {id: 43, title: "Later news", start_time: now + 100, end_time: now + 200, tvg_id: "station", channels: [{id: 1}]}
    ordered = programSearchResults([second, row], channels, now)
    assertEqual(ordered.items[0].program.id, "42", "airings sorted chronologically")
    bounded = programSearchResults([row, second], channels, now, 1)
    assertEqual(bounded.items.count(), 1, "bounded retained results")
    assertEqual(bounded.truncated, true, "omitted airing exposed")
    assertEqual(programSearchResults([{}], channels, now).items.count(), 0, "malformed row ignored")
    assertEqual(programSearchResults(invalid, channels, now).items.count(), 0, "missing response handled")
    row.end_time = now - 259200
    row.start_time = row.end_time - 100
    assertEqual(programSearchResults([row], channels, now).items.count(), 0, "history boundary excluded")
    row.start_time = now + 604800
    row.end_time = row.start_time + 100
    assertEqual(programSearchResults([row], channels, now).items.count(), 0, "future boundary excluded")
    assertEqual(programSearchResults([row], channels, now, 200, 3, 30).items.count(), 1, "expanded future range applies to results")
    assertEqual(programSearchParameters("x", "title", 1, now), invalid, "avoid one-character broad query")
    assertEqual(programSearchParameters("news", "url", 1, now), invalid, "whitelist server search field")
    assertEqual(programSearchParameters("news", "title", 0, now), invalid, "reject invalid page")
    params = programSearchParameters(" News & sport ", "description", 2, now)
    assertEqual(params.query, "News & sport", "preserve query for native URL encoding")
    assertEqual(params.page, 2, "explicit page")
    assertEqual(params.pageSize, 50, "bounded page size")
    assertEqual(guideEpoch(params.endAfter), now - 259200, "history overlap query")
    assertEqual(guideEpoch(params.startBefore), now + 604800, "future bound")
    expanded = programSearchParameters("news", "title", 1, now, 30, 30)
    assertEqual(guideEpoch(expanded.endAfter), now - 30 * 86400, "custom history query")
    assertEqual(guideEpoch(expanded.startBefore), now + 30 * 86400, "custom future query")
    assertEqual(unifiedSearchDomains("all", true, true).count(), 3, "one query searches all three permitted domains")
    domains = unifiedSearchDomains("all", false, true)
    assertEqual(domains.count(), 2, "movies permission excludes movie queries")
    assertEqual(domains[0], "epg", "lineup EPG remains in mixed search")
    assertEqual(domains[1], "series", "series permission retains TV search")
    assertEqual(unifiedSearchDomains("movie", false, true).count(), 0, "denied movie scope cannot query catalog")
    assertEqual(unifiedSearchDomains("description", false, false)[0], "epg", "description searches only EPG")
    assertEqual(unifiedSearchDomains("unexpected", true, true).count(), 0, "unknown scope never starts a task")
    epg = [{channel: channels[0], program: {title: "News"}}, {channel: channels[0], program: {title: "Night news"}}]
    movies = [{id: "1", title: "News movie", kind: "movie"}]
    series = [{id: "2", title: "News show", kind: "series"}]
    mixed = unifiedSearchRows(epg, movies, series)
    assertEqual(mixed.count(), 4, "mixed items retain every bounded result")
    assertEqual(mixed[0].program.title, "News", "EPG first in each interleaved row")
    assertEqual(mixed[1].vod.id, "1", "movie visible in first screen")
    assertEqual(mixed[2].vod.id, "2", "series visible in first screen")
    assertEqual(mixed[3].program.title, "Night news", "remaining EPG stays navigable")
    assertEqual(unifiedSearchRows(epg, movies, series, 2).count(), 2, "bounded result list never exceeds Roku limit")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
