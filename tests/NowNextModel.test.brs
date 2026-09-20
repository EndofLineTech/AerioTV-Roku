sub main()
    first = program("First", 100, 200)
    second = program("Second", 200, 300)
    third = program("Third", 300, 400)
    programs = [third, first, second]
    info = selectNowNext(programs, 150)
    assertEqual(info.current.title, "First", "current program in unsorted data")
    assertEqual(info.next.title, "Second", "next program")
    assertEqual(info.nextStartsAt, 200, "next start")
    assertEqual(scheduleProgress(info.current, 150), 0.5, "schedule progress")
    assertEqual(selectNowNext(programs, 200).current.title, "Second", "rollover at exact boundary")
    assertEqual(selectNowNext(programs, 200).next.title, "Third", "next advances at rollover")
    assertEqual(selectNowNext(programs, 400).current, invalid, "expired programs are not current")
    assertEqual(selectNowNext(programs, 400).next, invalid, "no invented upcoming program")
    assertEqual(selectNowNext([], 150).current, invalid, "empty data")
    gap = selectNowNext([first, program("Later", 250, 350)], 225)
    assertEqual(gap.current, invalid, "real EPG gap")
    assertEqual(gap.next.title, "Later", "future program during gap")
    assertEqual(gap.nextStartsAt, 250, "preserve gap until next start")
    overlap = selectNowNext([first, program("Overlap", 150, 250)], 175)
    assertEqual(overlap.current.title, "First", "overlap matches guide's earlier-start priority")
    assertEqual(overlap.nextStartsAt, 200, "overlapping next interval clips to current end")
    assertEqual(selectNowNext([first, first, second], 150).next.title, "Second", "ignore duplicate program")
    assertEqual(scheduleProgress(first, 0), 0, "progress clamps before start")
    assertEqual(scheduleProgress(first, 999), 1, "progress clamps after end")
    assertEqual(scheduleProgress(invalid, 150), 0, "no progress for missing data")
    assertEqual(scheduleProgress(program("Bad", 200, 100), 150), 0, "invalid duration")

    base = guideEpoch("2024-01-01T00:00:00Z")
    windows = playbackWindowStarts(base + 300, [])
    assertEqual(windows.count(), 2, "normal current plus next windows")
    assertEqual(windows[0], base, "current aligned window")
    assertEqual(windows[1], base + 10800, "next aligned window")
    longProgram = program("Long live event", base, base + 36000)
    windows = playbackWindowStarts(base + 300, [longProgram])
    assertEqual(windows.count(), 3, "long event lookahead remains bounded")
    assertEqual(windows[2], base + 32400, "fetch window containing long event end")

    cache = guideNewCache()
    channel = {uuid: "channel", epgKey: "station"}
    guideCachePut(cache, base, {station: [program("Now", base, base + 1800)]}, base)
    guideCachePut(cache, base + 86400, {station: [program("Tomorrow", base + 86400, base + 88200)]}, base)
    snapshot = playbackSnapshot(cache, {}, channel, base + 300)
    assertEqual(snapshot.programs.count(), 1, "future browsing cache is not mistaken for up next")
    assertEqual(snapshot.status, "loading", "missing lookahead window")
    guideCachePut(cache, base + 10800, {}, base + 10)
    assertEqual(playbackSnapshot(cache, {}, channel, base + 100).status, "ready", "empty but loaded window is valid")
    assertEqual(playbackSnapshot(cache, {}, channel, base + 400).status, "stale", "expired cache status")
    assertEqual(playbackSnapshot(cache, {}, channel, base + 100, base + 400).status, "stale", "historical playhead cannot make expired cache fresh")
    failures = {}
    failures[base.toStr()] = base + 1000
    assertEqual(playbackSnapshot(cache, failures, channel, base + 400).status, "unavailable", "failure keeps cached data but surfaces status")
    assertEqual(playbackSnapshot(cache, failures, channel, base + 400).programs.count(), 1, "retain applicable cached information on failure")
    assertEqual(playbackSnapshot(cache, {}, {uuid: "different", epgKey: "other"}, base + 100).programs.count(), 0, "channel isolation")
    dummy = {}
    dummy.channel = [program("Dummy guide", base, base + 1800)]
    guideCachePut(cache, base, dummy, base)
    assertEqual(playbackSnapshot(cache, {}, channel, base + 100).programs[0].title, "Dummy guide", "UUID-keyed dummy mapping")
    print "ALL TESTS PASSED"
end sub

function program(title as string, startsAt as integer, endsAt as integer) as object
    return {id: title, title: title, startsAt: startsAt, endsAt: endsAt, description: "", subtitle: ""}
end function

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
