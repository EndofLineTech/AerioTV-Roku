sub main()
    for each status in [401, 403, 503]
        m.rejectedStatus = status
        m.calls = 0
        m.top = {baseUrl: "https://example.test", apiKey: "test-only", username: "", password: "", cancelRequested: false}
        loadChannels()
        if m.calls <> 1 or m.top.result.ok <> false then stop
        if m.top.result.relogin <> (status = 401 or status = 403) then stop
        if m.top.apiKey <> "" then stop
    end for
    m.profileMode = true
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", username: "", password: "", cancelRequested: false, profileId: "3"}
    loadChannels()
    if m.calls <> 3 or m.top.result.ok <> false then stop
    if instr(1, m.top.result.message, "Selected channel profile") = 0 then stop
    if m.top.apiKey <> "" then stop
    print "ALL TESTS PASSED"
end sub

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    m.calls++
    if m.profileMode = true then return {id: 7}
    m.httpFailure = httpFailure(m.rejectedStatus, {}, 1000)
    m.failure = m.httpFailure.message
    return invalid
end function

function requestPages(path as string) as dynamic
    m.calls++
    if instr(1, path, "/channels/summary/") > 0 then return [{id: 10, uuid: "ten", name: "Authorized", channel_number: "1"}]
    m.failure = "Profiles unavailable."
    return invalid
end function
