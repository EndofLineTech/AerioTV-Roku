sub main()
    m.top = taskInput()
    loadXtreamVod()
    assertEqual(m.top.result.ok, false, "no category cannot request whole catalog")
    assertEqual(m.requested, invalid, "no request issued")
    assertEqual(m.top.password, "", "password cleared on failure")
    m.top = taskInput()
    m.top.category = "7"
    m.fixture = [{stream_id: 19, name: "Film", category_id: "7", container_extension: "mp4", stream_icon: "https://other.test/private"}]
    loadXtreamVod()
    assertEqual(m.top.result.ok, true, "category page loaded")
    if instr(1, m.requested, "category_id=7") = 0 then stop
    if instr(1, FormatJson(m.top.result), "test-only") > 0 then stop
    m.top = taskInput()
    m.top.category = "7"
    m.fixture = invalid
    m.fakeStatus = 401
    loadXtreamVod()
    assertEqual(m.top.result.relogin, true, "revoked library credentials return explicit sign-in")
    assertEqual(m.top.password, "", "revoked library Task clears credentials")
    if instr(1, FormatJson(m.top.result), "other.test") > 0 then stop
    assertEqual(m.top.password, "", "password cleared on success")
    m.top = taskInput()
    m.top.operation = "categories"
    m.fixture = []
    loadXtreamVod()
    assertEqual(m.top.result.ok, true, "empty category list distinguished from error")
    m.top = taskInput()
    m.top.operation = "categories"
    m.fixture = invalid
    loadXtreamVod()
    assertEqual(m.top.result.ok, false, "network failure")
    if instr(1, FormatJson(m.top.result), "test-only") > 0 then stop
    print "ALL TESTS PASSED"
end sub

function taskInput() as object
    return {baseUrl: "https://example.test", username: "viewer", password: "test-only", accountScope: "xc-slot", kind: "movie", operation: "page", pageNumber: 1, category: "", query: "", seriesId: "", itemId: "", cancelRequested: false}
end function

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    m.requested = url
    m.failure = "Request failed."
    m.httpFailure = invalid
    if m.fakeStatus <> invalid then m.httpFailure = {status: m.fakeStatus}
    return m.fixture
end function

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
