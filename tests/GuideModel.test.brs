sub main()
    base = guideEpoch("2024-01-01T00:00:00Z")
    stationKeys = guideDictionary()
    stationKeys["ABC"] = 1
    stationKeys["abc"] = 2
    assertEqual(stationKeys.count(), 2, "TVG identifiers remain case sensitive")
    assertEqual(guideEpoch("2024-01-01T00:00:00Z"), 1704067200, "UTC time")
    assertEqual(guideEpoch("2024-01-01T02:00:00+02:00"), 1704067200, "positive timezone")
    assertEqual(guideEpoch("2023-12-31T19:00:00-05:00"), 1704067200, "negative timezone")
    assertEqual(guideEpoch("2024-01-01T00:00:00.123Z"), 1704067200, "fractional seconds")
    assertEqual(guideEpoch("2024-03-10T03:30:00-04:00") - guideEpoch("2024-03-10T01:30:00-05:00"), 3600, "DST spring gap")
    assertEqual(guideEpoch("2024-11-03T01:30:00-05:00") - guideEpoch("2024-11-03T01:30:00-04:00"), 3600, "DST repeated hour")
    assertEqual(guideEpoch("not a date"), invalid, "malformed time")
    assertEqual(guideEpoch("2024-01-01T00:00:00"), invalid, "reject ambiguous timezone")
    assertEqual(guideEpoch("2024-02-31T00:00:00Z"), invalid, "reject impossible date")
    assertEqual(guideWindowStart(base - 1), 1704056400, "epoch window edge before midnight")
    assertEqual(guideWindowStart(base), 1704067200, "epoch window exact boundary")
    assertEqual(normalizeProgram({title: "Bad", start_time: "bad"}), invalid, "malformed program")
    assertEqual(normalizeProgram({start_time: 200, end_time: 100}), invalid, "reversed range")

    first = makeProgram("First", 100, 200)
    second = makeProgram("Second", 250, 350)
    cells = guideCells([second, first], 150, 400)
    assertEqual(cells.count(), 4, "clipped programs and real gaps")
    assertEqual(cells[0].startsAt, 150, "clip left")
    assertEqual(cells[0].program.startsAt, 100, "preserve original start")
    assertEqual(cells[1].program, invalid, "gap does not become fake program")
    assertEqual(cells[3].endsAt, 400, "trailing gap")
    assertEqual(guideCellAt(cells, 200).program, invalid, "half-open interval")
    assertEqual(guideCellAt(cells, 250).program.title, "Second", "exact start")
    assertEqual(guideCellAt(cells, 400), invalid, "window boundary")
    assertEqual(guideNavigate(base + 50, {startsAt: base, endsAt: base + 1800}, 1, base), 1704069000, "right lands exactly at next program")
    assertEqual(guideNavigate(base + 50, {startsAt: base, endsAt: base + 1800}, -1, base), 1704067199, "left lands in preceding program")
    assertEqual(guideNavigate(740800, {startsAt: 740800, endsAt: 741000}, -1, 1000000), 740800, "left cannot escape guide history")
    assertEqual(guideCellAt(guideCells([makeProgram("Different length", 100, 350)], 100, 400), 260).program.title, "Different length", "vertical navigation preserves time across different schedules")
    assertEqual(guideCells([], 100, 400).count(), 1, "empty guide still selectable")
    overlap = guideCells([makeProgram("A", 100, 300), makeProgram("B", 200, 350)], 100, 400)
    assertEqual(overlap[1].startsAt, 300, "overlap has nonoverlapping focus regions")
    assertEqual(guideCells([first, first], 100, 200).count(), 1, "duplicate programs")

    cache = guideNewCache()
    guideCachePut(cache, 0, {"station": [first]}, 10, 100)
    guideCachePut(cache, 10800, {}, 11, 100)
    guideCachePut(cache, 21600, {}, 12, 100)
    assertEqual(guideCacheHas(cache, 0, 15), true, "cached window")
    guideCacheTouch(cache, 0)
    guideCachePut(cache, 32400, {}, 13, 100)
    assertEqual(cache.entries.doesExist("10800"), false, "LRU eviction")
    assertEqual(cache.entries.count(), 3, "bounded cache")
    assertEqual(guideCacheHas(cache, 0, 500), false, "cache TTL")
    assertEqual(guideCachePrograms(cache, "station", 0, 1000)[0].title, "First", "stale data available during refresh")
    assertEqual(guideClamp(0, 1000000), 740800, "three days back")
    assertEqual(guideClamp(9999999, 1000000), 1604799, "seven days forward")

    channel = normalizeChannel({id: 1, uuid: "abc", name: "Old", effective_name: "New", channel_number: 3, effective_channel_number: "3.2", epg_data_id: 4, effective_epg_data_id: 9})
    assertEqual(channel.name, "New", "effective channel name")
    assertEqual(channel.number, "3.2", "effective decimal number")
    assertEqual(channel.epgId, "9", "effective EPG assignment")
    bindChannelGuide([channel], [{id: 9, tvg_id: "epg-station"}])
    assertEqual(channel.epgKey, "epg-station", "EPG bridge")
    assertEqual(guideChannelKey(channel, {"abc": []}), "abc", "dummy EPG uses channel UUID")
    bindChannelGuide([channel], [])
    assertEqual(channel.epgKey, "", "unresolved assignment does not attach wrong guide")

    ' Exercise the target lineup size, shared station mappings and bounded windows.
    large = {}
    for channelIndex = 0 to 1399
        key = "station-" + channelIndex.toStr()
        large[key] = []
        for slot = 0 to 5
            large[key].push(makeProgram(key + slot.toStr(), base + slot * 1800, base + 1800 + slot * 1800))
        end for
    end for
    guideCachePut(cache, base, large, 20)
    programs = guideCachePrograms(cache, "station-1399", base, base + 8928)
    assertEqual(programs.count(), 5, "1400-channel lookup restricts visible time")
    cells = guideCells(programs, base, base + 8928)
    assertEqual(cells.count(), 5, "large lineup renders only requested row")
    assertEqual(cells[4].endsAt, 1704076128, "partial last program clipped")
    print "ALL TESTS PASSED"
end sub

function makeProgram(title as string, startsAt as integer, endsAt as integer) as object
    return normalizeProgram({id: title, title: title, start_time: startsAt, end_time: endsAt, tvg_id: "station"})
end function

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
