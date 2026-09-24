sub main()
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", accountId: "7", profileId: "", authMode: "compatible", cancelRequested: false}
    loadPermittedProfiles()
    if m.calls <> 3 or m.top.result.ok <> true or m.top.result.authModeUsed <> "x-api-key" then stop
    if m.top.result.choices.count() <> 2 or m.top.apiKey <> "" then stop
    print "ALL TESTS PASSED"
end sub

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    m.calls++
    if m.calls = 1
        m.httpFailure = httpFailure(400, {}, 1000)
        m.failure = m.httpFailure.message
        return invalid
    end if
    m.httpFailure = invalid
    return {id: 7}
end function

function requestPages(path as string) as object
    m.calls++
    return [{id: 8, name: "Narrow", channels: [10]}]
end function
