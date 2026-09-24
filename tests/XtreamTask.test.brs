sub main()
    m.top = {baseUrl: "https://example.test", username: "viewer", password: "private-test-only", connectionId: "xc-test", cancelRequested: false}
    m.fakeStatus = 401
    loadXtream()
    if m.top.result.relogin <> true or m.top.password <> "" or m.top.username <> "" then stop
    if instr(1, FormatJson(m.top.result), "private-test-only") > 0 then stop
    m.top = {baseUrl: "https://example.test", username: "viewer", password: "private-test-only", connectionId: "xc-test", cancelRequested: false}
    m.fakeStatus = 503
    loadXtream()
    if m.top.result.relogin = true or m.top.password <> "" then stop
    print "ALL TESTS PASSED"
end sub

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    m.httpFailure = httpFailure(m.fakeStatus, {}, 1000)
    m.failure = m.httpFailure.message
    return invalid
end function
