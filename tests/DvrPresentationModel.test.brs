sub main()
    now = guideEpoch("2026-09-23T00:00:00Z")
    channel = {id: "3"}
    program = {id: "10", startsAt: now + 100, endsAt: now + 3600}
    if not recordingScheduleEligible("manage", channel, program, now) then stop
    if recordingScheduleEligible("view", channel, program, now) then stop
    if recordingScheduleEligible("manage", {id: "3/4"}, program, now) then stop
    if recordingScheduleEligible("manage", channel, {id: "10", startsAt: now - 3600, endsAt: now - 10}, now) then stop
    upcoming = {id: "1", channelId: "3", title: "Tomorrow", startTime: "2026-09-24T00:00:00Z", status: ""}
    current = {id: "2", channelId: "4", title: "Live recording", startTime: "2026-09-22T23:00:00Z", status: "recording"}
    done = {id: "3", channelId: "5", title: "Finished", startTime: "2026-09-22T20:00:00Z", status: "completed"}
    unknown = {id: "4", channelId: "6", title: "Unknown", startTime: "2026-09-22T18:00:00Z", status: ""}
    rows = [done, upcoming, unknown, current]
    if recordingDisplayStatus(upcoming, now) <> "scheduled" then stop
    if recordingDisplayStatus(unknown, now) <> "unknown" then stop
    if recordingShelfRows(rows, "now", "", now).count() <> 1 then stop
    if recordingShelfRows(rows, "scheduled", "", now)[0].id <> "1" then stop
    recent = recordingShelfRows(rows, "recent", "", now)
    if recent.count() <> 2 or recent[0].id <> "3" then stop
    if recordingShelfRows(rows, "recent", "finished", now).count() <> 1 then stop
    if recordingShelfRows(rows, "recent", "5", now)[0].channelId <> "5" then stop
    if recordingShelfRows(rows, "recent", "sports network", now, {"5": "Sports Network"}).count() <> 1 then stop
    if recordingShelfRows(rows, "recent", "", now, invalid, "title")[0].title <> "Finished" then stop
    rules = [{title: "Baseball", tvgId: "sports", mode: "all", epgSourceId: "1"}]
    library = dvrLibraryRows(rows, rules, "", now)
    if library.count() <> 9 then stop
    if library[0].heading <> "Recording Now" or library[0].itemCount <> 1 then stop
    if library[1].id <> "2" or library[1].displayStatus <> "recording" then stop
    if library[2].heading <> "Scheduled" or library[3].id <> "1" then stop
    if library[4].heading <> "Recent" or library[5].id <> "3" or library[6].id <> "4" then stop
    if library[7].heading <> "Series Rules" or library[8].title <> "Baseball" then stop
    if dvrSelectableIndex(library, 0, 1) <> 1 or dvrSelectableIndex(library, 2, 1) <> 3 then stop
    if dvrSelectableIndex(library, 2, -1) <> 1 or dvrSelectableIndex(library, 7, -1) <> 6 then stop
    if dvrSelectableIndex(library, 8, 1) <> 8 then stop
    filtered = dvrLibraryRows(rows, rules, "baseball", now)
    if filtered.count() <> 2 or filtered[0].heading <> "Series Rules" or filtered[1].title <> "Baseball" then stop
    if dvrLibraryRows(rows, rules, "sports", now)[1].title <> "Baseball" then stop
    if dvrLibraryRows(rows, rules, "missing", now).count() <> 0 then stop
    empty = dvrLibraryRows([], [], "", now)
    if empty.count() <> 4 or empty[0].itemCount <> 0 or empty[3].heading <> "Series Rules" then stop
    if dvrSelectableIndex(empty, 0, 1) <> -1 then stop
    onlyScheduled = dvrLibraryRows([upcoming], [], "", now)
    if dvrSelectableIndex(onlyScheduled, 0, 1) <> 2 then stop
    if dvrSelectableIndex(onlyScheduled, 1, -1) <> 2 then stop
    intent = {channelName: "Test channel", program: {title: "Test program", startsAt: now + 86400, endsAt: now + 90000}}
    padding = {pre: 5, post: 10}
    confirmation = recordingConfirmationText(intent, padding)
    if instr(1, confirmation, "Test channel") = 0 then stop
    if instr(1, confirmation, uiLocalDate(intent.program.startsAt - 300) + " " + uiTime(intent.program.startsAt - 300)) = 0 then stop
    if instr(1, confirmation, uiLocalDate(intent.program.endsAt + 600) + " " + uiTime(intent.program.endsAt + 600)) = 0 then stop
    if instr(1, confirmation, "Start early 5 min; end late 10 min") = 0 then stop
    intent.program.title = string(300, "x")
    if instr(1, recordingConfirmationText(intent, padding), "end late 10 min") = 0 then stop
    finished = {id: "14", status: "completed", fileReady: true, fileFormat: "mkv"}
    plan = recordingPlaybackPlan("https://example.test", finished)
    if plan = invalid or plan.streamFormat <> "mkv" or plan.url <> "https://example.test/api/channels/recordings/14/file/" or plan.growing then stop
    active = {id: "15", status: "recording", hlsReady: true}
    plan = recordingPlaybackPlan("https://example.test", active)
    if plan = invalid or plan.streamFormat <> "hls" or plan.url <> "https://example.test/api/channels/recordings/15/hls/index.m3u8" or not plan.growing then stop
    if recordingPlaybackPlan("https://example.test", {id: "15", status: "recording", hlsReady: false}) <> invalid then stop
    if recordingPlaybackPlan("https://example.test", {id: "1/2", status: "completed", fileReady: true}) <> invalid then stop
    if recordingPlaybackPlan("https://example.test", {id: "16", status: "scheduled", fileReady: true}) <> invalid then stop
    rules = [{title: "Example", tvgId: "foo", description: "Sports"}, {title: "Other", tvgId: "bar", description: "Drama"}]
    if seriesRuleRows(rules, "SPORTS").count() <> 1 then stop
    if seriesRuleRows(rules, "bar")[0].title <> "Other" then stop
    print "ALL TESTS PASSED"
end sub
