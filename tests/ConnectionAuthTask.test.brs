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
    print "ALL TESTS PASSED"
end sub

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    m.calls++
    m.httpFailure = httpFailure(m.rejectedStatus, {}, 1000)
    m.failure = m.httpFailure.message
    return invalid
end function
