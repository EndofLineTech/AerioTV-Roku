sub main()
    events = diagnosticEvents(invalid, 5000, "secret")
    if events.count() <> 0 then stop
    raw = []
    for i = 0 to 99
        raw.push({time: 4900 + i, stage: "playback", code: -1, message: "https://host/path?token=secret password=other session_id=private bearer fake secret"})
    end for
    events = diagnosticEvents(raw, 5000, "secret")
    if events.count() <> 80 then stop
    json = FormatJson(events)
    if instr(1, json, "secret") > 0 or instr(1, json, "private") > 0 or instr(1, json, "other") > 0 or instr(1, json, "fake") > 0 then stop
    if instr(1, json, "https") > 0 or preferenceByteBudget(json) > 32768 then stop
    if diagnosticEvents(events, 9000, "secret").count() <> 0 then stop
    print "ALL TESTS PASSED"
end sub
