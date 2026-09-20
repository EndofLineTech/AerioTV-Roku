sub main()
    if httpFailure(401, {}, 1000).category <> "authentication" then stop
    if httpFailure(403, {}, 1000).category <> "permission" then stop
    if httpFailure(409, {}, 1000).retryable then stop
    if httpRetryAfter({"Retry-After": "17"}, 1000) <> 17 then stop
    if httpRetryAfter({"retry-after": "-1"}, 1000) <> -1 then stop
    reference = CreateObject("roDateTime")
    reference.fromISO8601String("2015-10-21T07:26:00Z")
    if httpRetryAfter({"Retry-After": "Wed, 21 Oct 2015 07:28:00 GMT"}, reference.asSeconds()) <> 120 then stop
    if httpRetryAfter({"Retry-After": "bad"}, 1000) <> -1 then stop
    resetHttpTest([{status: 429, headers: {"Retry-After": "0"}, body: ""}, {status: 200, body: "{""ok"":true}"}])
    result = requestJson("https://example.test/api")
    if result.ok <> true or m.calls <> 2 then stop
    resetHttpTest([{status: 503, headers: {"Retry-After": "0"}, body: ""}])
    if requestJson("https://example.test/api", {mutation: true}) <> invalid then stop
    if m.calls <> 1 then stop ' never automatically repeat a mutation
    resetHttpTest([{status: 429, headers: {"Retry-After": "3600"}, body: ""}])
    if requestJson("https://example.test/api") <> invalid or m.calls <> 1 then stop
    if m.httpFailure.category <> "rate-limit" then stop
    resetHttpTest([{status: 200, body: "not json"}])
    if requestJson("https://example.test/api") <> invalid then stop
    if m.httpFailure.category <> "invalid-response" then stop
    resetHttpTest([{status: 200, body: "[]"}])
    m.top.cancelRequested = true
    if requestJson("https://example.test/api") <> invalid or m.calls <> 0 then stop
    resetHttpTest([{status: 503, headers: {"Retry-After": "0"}, body: "", cancelNext: true}])
    if requestJson("https://example.test/api") <> invalid or m.calls <> 1 then stop
    if m.httpFailure.category <> "cancelled" then stop
    resetHttpTest([{status: 200, body: "{""results"":[],""next"":""https://example.test/api/list""}"}])
    m.base = "https://example.test"
    if requestPages("/api/list") <> invalid or m.calls <> 1 then stop
    if instr(1, m.failure, "Pagination repeated") = 0 then stop
    print "ALL TESTS PASSED"
end sub

sub resetHttpTest(responses as object)
    m.top = {cancelRequested: false}
    m.responses = responses
    m.calls = 0
    m.timeout = 1000
    m.deadlineMs = invalid
end sub

function httpTransferOnce(url as string, body as dynamic, bearer as string, timeoutMs as integer, maxBytes as integer) as object
    m.calls++
    result = m.responses.shift()
    if result.cancelNext = true then m.top.cancelRequested = true
    if result.headers = invalid then result.headers = {}
    if result.error = invalid then result.error = ""
    return result
end function
