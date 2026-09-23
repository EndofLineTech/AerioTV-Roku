sub main()
    m.top = {cancelRequested: false}
    m.responses = []
    m.calls = []
    now = CreateObject("roDateTime").asSeconds()
    program = {id: "epg-5", title: "Show", startsAt: now + 3600, endsAt: now + 7200}
    if scheduleRecording("https://host.test", "key", "3/x", program, 5, 10).ok then stop
    if m.calls.count() <> 0 then stop
    if scheduleRecording("https://host.test", "key", "3", program, -1, 10).ok then stop
    if m.calls.count() <> 0 then stop
    if recordingEpochValid("2026-09-22T12:00:00Z") then stop
    if not recordingEpochValid(program.startsAt) then stop
    if cancelRecording("https://host.test", "key", "9999999999").ok or m.calls.count() <> 0 then stop

    m.responses = [[], {id: 7, channel: 3, start_time: recordingTime(program.startsAt - 300), end_time: recordingTime(program.endsAt + 600), custom_properties: {status: "scheduled"}}]
    result = scheduleRecording("https://host.test", "key", "3", program, 5, 10)
    if not result.ok or result.recording.id <> "7" or m.calls.count() <> 2 then stop
    if m.calls[0].url <> "https://host.test/api/channels/recordings/" or m.calls[1].body.channel <> 3 then stop
    if m.calls[1].body.start_time <> recordingTime(program.startsAt - 300) then stop
    if m.calls[1].body.end_time <> recordingTime(program.endsAt + 600) then stop
    if m.calls[1].body.custom_properties.roku_program_id <> "epg-5" then stop
    if m.calls[1].body.custom_properties.program <> invalid then stop

    m.calls = []
    m.responses = [[{id: 7, channel: 3, start_time: "different", end_time: "different", custom_properties: {status: "scheduled", roku_program_id: "epg-5"}}]]
    result = scheduleRecording("https://host.test", "key", "3", program, 5, 10)
    if result.ok or result.category <> "duplicate" or m.calls.count() <> 1 then stop
    m.calls = []
    m.responses = [[{id: 11, channel: 3, start_time: recordingTime(program.startsAt - 300), end_time: recordingTime(program.endsAt + 600), custom_properties: {status: "scheduled"}}]]
    if scheduleRecording("https://host.test", "key", "3", program, 5, 10).category <> "duplicate" or m.calls.count() <> 1 then stop

    m.calls = []
    m.responses = invalid
    m.failure = "Server returned HTTP 403."
    m.httpFailure = {category: "permission"}
    if scheduleRecording("https://host.test", "key", "3", program, 0, 0).category <> "permission" then stop
    if m.calls.count() <> 1 then stop

    m.calls = []
    m.responses = [[{id: 8, channel: 3, custom_properties: {status: "scheduled"}}, {id: 9, channel: 3, custom_properties: {status: "completed"}}]]
    rows = listRecordings("https://host.test", "key", "scheduled")
    if not rows.ok or rows.recordings.count() <> 1 or rows.recordings[0].id <> "8" then stop
    external = normalizeRecording({id: 12, channel: 3, custom_properties: {status: "recording", program: {id: "42", title: "Created elsewhere", description: "Facts"}}})
    if external.title <> "Created elsewhere" or external.programId <> "42" or external.status <> "recording" then stop
    if normalizeRecording({id: 13, channel: 3, custom_properties: {}}).title <> "Recording 13" then stop
    available = normalizeRecording({id: 14, channel: 3, custom_properties: {status: "completed", file_path: "/data/recordings/test.mkv"}})
    if available.fileFormat <> "mkv" or available.fileReady <> true then stop
    if available.filePath <> invalid then stop
    growing = normalizeRecording({id: 15, channel: 3, custom_properties: {status: "recording", _hls_dir: "/data/recordings/hls"}})
    if growing.hlsReady <> true or growing.fileReady = true then stop
    processed = normalizeRecording({id: 16, channel: 3, custom_properties: {status: "completed", comskip: {status: "skipped", reason: "comskip_not_installed"}}})
    if processed.comskipStatus <> "skipped" or processed.comskipReason <> "comskip_not_installed" then stop
    if normalizeRecording({id: 17, channel: 3, custom_properties: {comskip: {status: "error", reason: "/server/private/file"}}}).comskipReason <> "" then stop
    if normalizeRecording({id: 18, channel: 3, custom_properties: {comskip: {status: "completed", mode: "mark"}}}).comskipMode <> "mark" then stop
    if normalizeRecording({id: 19, channel: 3, custom_properties: {comskip: {status: "completed", segments_kept: 2}}}).comskipMode <> "remove" then stop
    m.calls = []
    m.responses = [{id: 8, channel: 3, start_time: recordingTime(now + 3600), custom_properties: {status: "scheduled"}}, {}]
    if not cancelRecording("https://host.test", "key", "8").ok or m.calls[0].method <> "GET" or m.calls[1].method <> "DELETE" then stop
    if cancelRecording("https://host.test", "key", "8/9").ok or m.calls.count() <> 2 then stop
    for each state in ["completed", "recording", "stopped"]
        m.calls = []
        m.responses = [{id: 8, channel: 3, start_time: recordingTime(now + 3600), custom_properties: {status: state}}]
        if cancelRecording("https://host.test", "key", "8").category <> "state" or m.calls.count() <> 1 then stop
    end for
    m.calls = []
    m.responses = [{id: 8, channel: 3, start_time: recordingTime(now - 120), custom_properties: {status: "scheduled"}}]
    if cancelRecording("https://host.test", "key", "8").category <> "state" or m.calls.count() <> 1 then stop
    m.calls = []
    m.responses = [{id: 8, channel: 3, custom_properties: {status: "recording"}}, {success: true, status: "stopped"}]
    if not stopRecording("https://host.test", "key", "8").ok or m.calls[1].method <> "POST" then stop
    m.calls = []
    m.responses = [{id: 8, channel: 3, custom_properties: {status: "completed"}}, {}]
    if not deleteFinishedRecording("https://host.test", "key", "8").ok or m.calls[1].method <> "DELETE" then stop
    m.calls = []
    m.responses = [{id: 8, channel: 3, custom_properties: {status: "recording"}}]
    if deleteFinishedRecording("https://host.test", "key", "8").category <> "state" or m.calls.count() <> 1 then stop
    m.calls = []
    m.responses = [{id: 8, channel: 3, custom_properties: {status: "completed"}}, {success: true, queued: true}]
    if not queueRecordingComskip("https://host.test", "key", "8").ok or m.calls[1].method <> "POST" then stop
    draft = {title: "Test show", mode: "new", titleMode: "exact", tvgId: "channel.test", channelId: "3", description: "", descriptionMode: "contains"}
    m.calls = []
    m.responses = [{matches: [{title: "Test show", start_time: "2026-09-23T12:00:00Z"}], total: 1, epg_found: true}]
    preview = previewSeriesRule("https://host.test", "key", draft)
    if not preview.ok or preview.total <> 1 or m.calls[0].body.mode <> "new" or m.calls[0].body.tvg_id <> "channel.test" then stop
    m.calls = []
    m.responses = [{rules: [{tvg_id: "channel.test", title: "Test show", mode: "all"}]}]
    if createSeriesRule("https://host.test", "key", draft).category <> "duplicate" or m.calls.count() <> 1 then stop
    m.calls = []
    m.responses = [{rules: []}, {success: true, rules: [{tvg_id: "channel.test", title: "Test show", mode: "new"}]}, {success: true, created: 1}]
    saved = createSeriesRule("https://host.test", "key", draft)
    if not saved.ok or m.calls.count() <> 3 or m.calls[1].method <> "POST" or m.calls[2].url <> "https://host.test/api/channels/series-rules/evaluate/" then stop
    m.calls = []
    m.responses = [{rules: [{tvg_id: "channel.test", title: "Test show", mode: "new"}]}, {success: true, rules: [], removed: 1}]
    removed = deleteSeriesRule("https://host.test", "key", draft)
    if not removed.ok or m.calls[1].method <> "DELETE" or instr(1, m.calls[1].url, "title=Test%20show") = 0 then stop
    m.calls = []
    m.responses = [{rules: [{tvg_id: "channel.test", title: "Test show", mode: "new"}, {tvg_id: "channel.test", title: "Test show", mode: "all", epg_source_id: 21}]}]
    if deleteSeriesRule("https://host.test", "key", draft).category <> "state" or m.calls.count() <> 1 then stop
    print "ALL TESTS PASSED"
end sub

function requestPages(path as string) as dynamic
    m.calls.push({url: m.base + path, method: "GET"})
    if m.responses = invalid then return invalid
    return m.responses.shift()
end function

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    m.calls.push({url: url, body: body, method: method})
    if m.responses = invalid then return invalid
    return m.responses.shift()
end function
