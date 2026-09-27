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
    responseLimit = guideMetadataDiagnosticText({stage: "mapping", source: "network", category: "response-too-large", sizeBucket: "at-least-8-mib", message: "Metadata response exceeds this device's safe loading budget."})
    if responseLimit <> "mapping network response-too-large at-least-8-mib Metadata response exceeds this device's safe loading budget." then stop
    restoredLimit = guideMetadataDiagnosticText({stage: "mapping", source: "network", category: "response-too-large", sizeBucket: "at-least-16-mb", message: ""})
    if instr(1, restoredLimit, "at-least-16-mb") = 0 then stop
    memoryPressure = guideMetadataDiagnosticText({stage: "mapping", source: "network", category: "memory-pressure", message: "Device memory pressure stopped the metadata download."})
    if memoryPressure <> "mapping network memory-pressure Device memory pressure stopped the metadata download." then stop
    current = [{time: 4990, scope: "account-A", stage: "playback", code: -3, elapsedMs: 510, message: "private channel secret"}, {time: 4999, scope: "account-B", stage: "vod", code: 403, elapsedMs: 900, message: "other account"}]
    scoped = diagnosticEvents(current, 5000, "secret", "account-A")
    if scoped.count() <> 1 or scoped[0].scope <> "account-A" then stop
    if instr(1, FormatJson(diagnosticConsoleEvents(scoped)), "account-A") > 0 then stop
    if diagnosticEvents(current, 5000, "secret", "account-B").count() <> 1 then stop
    if diagnosticEvents(current, 5000, "secret", "account-C").count() <> 0 then stop
    code = diagnosticSupportCode(current, 5000, "secret", "account-A")
    if code <> "D113-35O2-00AW-Y" then stop ' fixed parity vector for offline decoder
    if len(code) < 8 or len(code) > 120 or left(code, 3) <> "D11" then stop
    if instr(1, code, "secret") > 0 or instr(1, code, "account") > 0 then stop
    if diagnosticSupportCode(current, 5000, "secret", "account-B") = code then stop
    if diagnosticSupportCode(current, 5000, "secret", "account-C") <> "" then stop
    large = []
    for i = 0 to 19
        large.push({time: 4900 + i, scope: "account-A", stage: "guide", code: 500, elapsedMs: 500, message: "private"})
    end for
    code = diagnosticSupportCode(large, 5000, "secret", "account-A")
    if left(code, 3) <> "D18" or len(code) > 120 then stop ' last eight only
    print "ALL TESTS PASSED"
end sub
