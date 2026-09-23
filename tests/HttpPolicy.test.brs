sub main()
    if httpFailure(401, {}, 1000).category <> "authentication" then stop
    if httpFailure(403, {}, 1000).category <> "permission" then stop
    if httpFailure(409, {}, 1000).retryable then stop
    tooLarge = httpFailure(0, {}, 1000, "too-large", 8388609, 8388608)
    if tooLarge.category <> "response-too-large" or tooLarge.sizeBucket <> "at-least-8-mib" then stop
    if httpFailure(0, {}, 1000, "memory").category <> "memory-pressure" then stop
    if httpRetryAfter({"Retry-After": "17"}, 1000) <> 17 then stop
    if httpRetryAfter({"retry-after": "-1"}, 1000) <> -1 then stop
    reference = CreateObject("roDateTime")
    reference.fromISO8601String("2015-10-21T07:26:00Z")
    if httpRetryAfter({"Retry-After": "Wed, 21 Oct 2015 07:28:00 GMT"}, reference.asSeconds()) <> 120 then stop
    if httpRetryAfter({"Retry-After": "bad"}, 1000) <> -1 then stop
    resetHttpTest([{status: 429, headers: {"Retry-After": "0"}, body: ""}, {status: 200, body: "{""ok"":true}"}])
    result = requestJson("https://example.test/api")
    if result.ok <> true or m.calls <> 2 then stop
    if m.observedLimit <> 16000000 then stop
    resetHttpTest([{status: 200, body: "[]"}])
    m.maxResponseBytes = 1048576
    if requestJson("https://example.test/api") = invalid then stop
    if m.observedLimit <> 1048576 then stop
    resetHttpTest([{status: 503, headers: {"Retry-After": "0"}, body: ""}])
    if requestJson("https://example.test/api", {mutation: true}) <> invalid then stop
    if m.calls <> 1 then stop ' never automatically repeat a mutation
    resetHttpTest([{status: 503, body: ""}])
    if requestJson("https://example.test/api/1/", invalid, "", "DELETE") <> invalid or m.calls <> 1 then stop
    if m.observedMethod <> "DELETE" then stop
    resetHttpTest([{status: 204, body: ""}])
    if requestJson("https://example.test/api/1/", invalid, "", "DELETE") = invalid then stop
    resetHttpTest([{status: 429, headers: {"Retry-After": "3600"}, body: ""}])
    if requestJson("https://example.test/api") <> invalid or m.calls <> 1 then stop
    if m.httpFailure.category <> "rate-limit" then stop
    resetHttpTest([{status: 200, body: "not json"}])
    if requestJson("https://example.test/api") <> invalid then stop
    if m.httpFailure.category <> "invalid-response" then stop
    resetHttpTest([{status: 200, body: "", error: "too-large", bytes: 16000001}])
    if requestJson("https://example.test/api") <> invalid then stop
    if m.httpFailure.category <> "response-too-large" or m.httpFailure.sizeBucket <> "at-least-16-mb" then stop
    resetHttpTest([{status: 200, body: "", error: "memory"}])
    if requestJson("https://example.test/api") <> invalid then stop
    if m.httpFailure.category <> "memory-pressure" then stop
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
    m.maxResponseBytes = invalid
end sub

function httpTransferOnce(url as string, body as dynamic, bearer as string, timeoutMs as integer, maxBytes as integer, method = "GET" as string) as object
    m.calls++
    m.observedLimit = maxBytes
    m.observedMethod = method
    result = m.responses.shift()
    if result.cancelNext = true then m.top.cancelRequested = true
    if result.headers = invalid then result.headers = {}
    if result.error = invalid then result.error = ""
    if result.bytes = invalid then result.bytes = -1
    return result
end function
