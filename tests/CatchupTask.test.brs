sub main()
    resetTask()
    runCatchup()
    if not m.top.result.ok or m.calls.count() <> 1 or m.calls[0].method <> "POST" then stop
    if m.calls[0].body.duration <> 5 or m.top.apiKey <> "" then stop
    for each minutes in [45, -45]
        resetTask()
        origin = m.top.program
        m.top.requestShiftMinutes = minutes
        expectedStart = origin.startsAt + minutes * 60
        runCatchup()
        if not m.top.result.ok or guideEpoch(m.calls[0].body.start) <> expectedStart or m.calls[0].body.duration <> 5 then stop
        if m.top.result.requestedStart <> expectedStart or origin.startsAt <> m.top.program.startsAt then stop
        seek = catchupSeekPlan(origin, 123)
        resetTask()
        m.top.program = seek.program
        m.top.requestShiftMinutes = minutes
        runCatchup()
        if not m.top.result.ok or guideEpoch(m.calls[0].body.start) <> expectedStart + 120 or m.calls[0].body.duration <> 3 then stop
    end for
    for each reopening in [false, true]
        resetTask()
        now = nowForTest()
        origin = {startsAt: now - 3830, endsAt: now - 3605}
        m.top.program = origin
        if reopening then m.top.program = catchupSeekPlan(origin, 125).program
        m.top.requestShiftMinutes = 60
        runCatchup()
        if m.top.result.ok or m.calls.count() <> 0
            print "FAIL: Rounded Dispatcharr request crosses live edge; expected no POST. Reopen="; reopening
            stop
        end if
        resetTask()
        now = nowForTest()
        origin = {startsAt: now - 3840, endsAt: now - 3615}
        m.top.program = origin
        expectedDuration = 4
        if reopening
            m.top.program = catchupSeekPlan(origin, 125).program
            expectedDuration = 2
        end if
        m.top.requestShiftMinutes = 60
        expectedStart = m.top.program.startsAt + 3600
        runCatchup()
        if not m.top.result.ok or m.calls.count() <> 1 then stop
        if guideEpoch(m.calls[0].body.start) <> expectedStart or m.calls[0].body.duration <> expectedDuration then stop
    end for
    resetTask()
    m.top.requestShiftMinutes = 60
    now = nowForTest()
    m.top.program = {startsAt: now - 300, endsAt: now - 60}
    runCatchup()
    if m.top.result.ok or m.calls.count() <> 0 then stop
    resetTask()
    m.top.requestShiftMinutes = -60
    m.top.retentionDays = 1
    m.top.program = {startsAt: nowForTest() - 86300, endsAt: nowForTest() - 86000}
    runCatchup()
    if m.top.result.ok or m.calls.count() <> 0 then stop
    resetTask()
    now = nowForTest()
    m.top.restart = true
    m.top.requestShiftMinutes = 60
    m.top.program = {startsAt: now - 120, endsAt: now + 180}
    runCatchup()
    if not m.top.result.ok or guideEpoch(m.calls[0].body.start) <> now - 120 or m.calls[0].body.duration <> 5 then stop
    resetTask()
    m.cancelDuringCreate = true
    runCatchup()
    if m.top.result <> invalid or m.calls.count() <> 2 or m.calls[1].method <> "DELETE" then stop
    resetTask()
    m.response.data.playback_url = "https://untrusted.test/media"
    runCatchup()
    if m.top.result.ok or m.calls.count() <> 2 or m.calls[1].method <> "DELETE" then stop
    resetTask()
    m.user.id = 99
    runCatchup()
    if m.top.result.ok or m.calls.count() <> 0 then stop
    resetTask()
    m.user = invalid
    m.httpFailure = {status: 404}
    runCatchup()
    if m.top.result.ok or m.top.result.status <> 404 or m.top.result.archiveStatus <> invalid or m.calls.count() <> 0 then stop
    resetTask()
    m.response = {status: 404, data: invalid}
    runCatchup()
    if m.top.result.ok or m.top.result.status <> 404 or m.top.result.archiveStatus <> 404 or m.calls.count() <> 1 then stop
    resetTask()
    m.top.operation = "delete"
    m.top.sessionId = "abcdefghijklmnop"
    runCatchup()
    if not m.top.result.ok or m.calls[0].method <> "DELETE" then stop
    resetTask()
    m.top.operation = "position"
    m.top.sessionId = "abcdefghijklmnop"
    m.top.position = 40
    m.top.paused = true
    runCatchup()
    if not m.top.result.ok or m.calls[0].body.position_secs <> 40 or not m.calls[0].body.paused then stop
    resetTask()
    now = CreateObject("roDateTime").asSeconds()
    m.top.rewind = true
    m.top.tuneStart = now - 7200
    m.top.requestShiftMinutes = 45
    m.top.program = {startsAt: now - 9000, endsAt: now - 8000}
    m.echoStart = true
    runCatchup()
    if not m.top.result.ok or m.top.result.requestedStart < now - 3600 or m.top.result.requestedStart >= now then stop
    if m.calls[0].body.duration > 60 then stop
    resetTask()
    m.top.rewind = true
    m.top.tuneStart = now - 7200
    m.response.data.start = "1970-01-01T00:00:00Z"
    runCatchup()
    if m.top.result.ok or m.calls.count() <> 2 or m.calls[1].method <> "DELETE" then stop
    print "ALL TESTS PASSED"
end sub

function nowForTest() as integer
    return CreateObject("roDateTime").asSeconds()
end function

sub resetTask()
    now = CreateObject("roDateTime").asSeconds()
    m.top = {baseUrl: "https://host.test", apiKey: "test-only", operation: "create", cancelRequested: false, accountId: "1", channelUuid: "channel", requestShiftMinutes: 0, retentionDays: 30, program: {startsAt: now - 7200, endsAt: now - 6900}}
    m.user = {id: 1}
    m.httpFailure = invalid
    m.response = {status: 201, data: {session_id: "abcdefghijklmnop", channel_uuid: "channel", expires_at: now + 60, playback_url: "/proxy/catchup/channel?session_id=abcdefghijklmnop"}}
    m.calls = []
    m.cancelDuringCreate = false
    m.echoStart = false
end sub

function requestJson(url)
    return m.user
end function

function sessionMutation(url, method, body = invalid)
    m.calls.push({url: url, method: method, body: body})
    if method = "DELETE" then return {status: 204, data: invalid}
    if instr(1, url, "/position/") > 0 then return {status: 204, data: invalid}
    if m.cancelDuringCreate then m.top.cancelRequested = true
    if m.echoStart then m.response.data.start = body.start
    return m.response
end function
