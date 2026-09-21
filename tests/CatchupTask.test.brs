sub main()
    resetTask()
    runCatchup()
    if not m.top.result.ok or m.calls.count() <> 1 or m.calls[0].method <> "POST" then stop
    if m.calls[0].body.duration <> 5 or m.top.apiKey <> "" then stop
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
    m.top.program = {startsAt: now - 9000, endsAt: now - 8000}
    m.echoStart = true
    runCatchup()
    if not m.top.result.ok or m.top.result.requestedStart < now - 3600 then stop
    if m.calls[0].body.duration > 60 then stop
    resetTask()
    m.top.rewind = true
    m.top.tuneStart = now - 7200
    m.response.data.start = "1970-01-01T00:00:00Z"
    runCatchup()
    if m.top.result.ok or m.calls.count() <> 2 or m.calls[1].method <> "DELETE" then stop
    print "ALL TESTS PASSED"
end sub

sub resetTask()
    now = CreateObject("roDateTime").asSeconds()
    m.top = {baseUrl: "https://host.test", apiKey: "test-only", operation: "create", cancelRequested: false, accountId: "1", channelUuid: "channel", program: {startsAt: now - 3600, endsAt: now - 3300}}
    m.user = {id: 1}
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
