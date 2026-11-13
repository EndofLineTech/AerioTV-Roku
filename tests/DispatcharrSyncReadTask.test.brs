sub main()
    m.syncJsonParser = function(text as string) as dynamic
        return ParseJson(text)
    end function
    for each scenario in ["canonical", "legacy", "missing", "key-missing", "forbidden", "unsupported", "proxy404", "identity", "username", "empty-username", "malformed", "newer", "park"]
        m.scenario = scenario
        m.calls = []
        m.top = {baseUrl: "https://example.test", apiKey: "synthetic-own", accountId: "7", username: "Alice", cancelRequested: false}
        readDispatcharrSync()
        if m.top.apiKey <> "" or m.key <> "" then stop
        for each path in m.calls
            if instr(1, path, "/users/7/") > 0 or instr(1, path, "app.molinete") > 0 then stop
        end for
        if scenario = "canonical"
            if m.top.result.state <> "ready" or m.top.result.key <> "alice.aeriotv" or m.calls.count() <> 3 then stop
        else if scenario = "key-missing" or scenario = "missing"
            if m.top.result.state <> "missing" then stop
        else if scenario = "newer"
            if m.top.result.state <> "newer" then stop
        else if scenario = "legacy"
            if m.top.result.state <> "legacy" or m.calls.count() <> 2 then stop
        else
            if m.top.result.ok then stop
        end if
        if m.top.result.allowWrite <> false then stop
        if scenario = "identity" or scenario = "username"
            if m.calls.count() <> 1 then stop
        end if
        if scenario = "empty-username" and m.top.result.state <> "waiting" then stop
    end for
    print "ALL TESTS PASSED"
end sub

function httpTransferOnce(url as string, body as dynamic, bearer as string, timeoutMs as integer, maxBytes as integer, method = "GET" as string, checked = invalid as dynamic) as object
    if method <> "GET" or bearer <> "" or body <> invalid or m.key <> "synthetic-own" then stop
    m.calls.push(url)
    response = {status: 200, headers: {}, error: "", body: "", bytes: 0}
    if right(url, 10) = "/users/me/"
        response.body = FormatJson({id: 7, username: "Alice"})
        if m.scenario = "identity" then response.body = FormatJson({id: 8, username: "Alice"})
        if m.scenario = "username" then response.body = FormatJson({id: 7, username: "Other"})
        if m.scenario = "empty-username" then response.body = FormatJson({id: 7, username: ""})
    else if right(url, 9) = "app-data/"
        response.body = FormatJson({apps: [{key: "alice.aeriotv", bytes: 50}]})
        if m.scenario = "legacy" then response.body = FormatJson({apps: [{key: "app.molinete.aerio", bytes: 50}]})
        if m.scenario = "missing" then response.body = FormatJson({apps: []})
        if m.scenario = "forbidden" then response.status = 403
        if m.scenario = "unsupported" then response.status = 404
        if m.scenario = "park" then response.status = 429
    else
        response.body = "{""schemaVersion"":3,""deviceId"":""fixture"",""platform"":""android"",""appVersion"":""1"",""updatedAt"":""2026-11-11T18:00:00Z"",""categories"":{}}"
        if m.scenario = "newer" then response.body = "{""schemaVersion"":4}"
        if m.scenario = "key-missing"
            response.status = 404
            response.body = FormatJson({code: "key_not_found"})
        end if
        if m.scenario = "proxy404"
            response.status = 404
            response.body = "<html>not found</html>"
        end if
        if m.scenario = "malformed" then response.body = "[]"
    end if
    return response
end function
