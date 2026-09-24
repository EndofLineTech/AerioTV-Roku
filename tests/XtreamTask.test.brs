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
    m.fakeStatus = 0
    m.top = {baseUrl: "https://example.test", username: "viewer", password: "private-test-only", connectionId: "xc-test", cancelRequested: false}
    loadXtream()
    if not m.top.result.ok then print "XC SUCCESS missing" : stop
    if not m.top.result.movies then print "XC MOVIES missing" : stop
    if m.top.result.series then print "XC SERIES unexpected" : stop
    if m.top.result.timezone <> "UTC" then print "XC ZONE missing" : stop
    if m.top.password <> "" then print "XC PASSWORD retained" : stop
    safe = {}
    safe.append(m.top.result)
    safe.delete("guideUrl") ' Live XMLTV URL is volatile and necessarily contains XC credentials.
    if instr(1, FormatJson(safe), "private-test-only") > 0 then print "XC PASSWORD published outside volatile guide URL" : stop
    m.denyAction = "get_live_streams"
    m.top = {baseUrl: "https://example.test", username: "viewer", password: "private-test-only", connectionId: "xc-test", cancelRequested: false}
    loadXtream()
    if m.top.result.relogin <> true or m.top.password <> "" then print "XC revoked during lineup should require sign-in" : stop
    m.denyAction = "get_vod_categories"
    m.top = {baseUrl: "https://example.test", username: "viewer", password: "private-test-only", connectionId: "xc-test", cancelRequested: false}
    loadXtream()
    if m.top.result.relogin <> true or m.top.password <> "" then print "XC revoked during optional metadata should require sign-in" : stop
    print "ALL TESTS PASSED"
end sub

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    if m.fakeStatus = 0
        m.httpFailure = invalid
        if m.denyAction <> invalid
            if instr(1, url, m.denyAction) > 0
                m.httpFailure = httpFailure(401, {}, 1000)
                m.failure = m.httpFailure.message
                return invalid
            end if
        end if
        if instr(1, url, "get_live_categories") > 0 then return [{category_id: 7, category_name: "TV"}]
        if instr(1, url, "get_live_streams") > 0 then return [{stream_id: 12, category_id: "7", name: "Test live"}]
        if instr(1, url, "get_vod_categories") > 0 then return [{category_id: 3, category_name: "Films"}]
        if instr(1, url, "get_series_categories") > 0 then return []
        return {user_info: {auth: 1, status: "Active", allowed_output_formats: ["ts"], password: "private-test-only"}, server_info: {timezone: "UTC"}}
    end if
    m.httpFailure = httpFailure(m.fakeStatus, {}, 1000)
    m.failure = m.httpFailure.message
    return invalid
end function

function metadataCacheDigest(value as string) as string
    return "test-digest"
end function
