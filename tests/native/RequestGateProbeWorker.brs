' Native mailbox/concurrency proof only; no HTTP, registry or owner accounts.
sub init()
    m.top.functionName = "runGateWorker"
end sub

sub runGateWorker()
    m.failures = 0
    base = "https://example.test/api/accounts/users/me/"
    operation = m.top.operation
    if operation = "generic"
        permit = requestGateAcquire(base, "synthetic-generic")
        workerCheck(permit.allowed, "generic-first-admit")
        requestGateReport(permit, {status: 401, headers: {}, body: "<html>Invalid API key</html>"})
        permit = requestGateAcquire(base, "synthetic-generic")
        workerCheck(permit.allowed, "generic-401-retained")
        requestGateReport(permit, {status: 403, headers: {}, body: "{" + chr(34) + "detail" + chr(34) + ":" + chr(34) + "Invalid API key" + chr(34) + "}"})
        permit = requestGateAcquire(base, "synthetic-generic")
        workerCheck(permit.allowed, "403-retained")
        requestGateReport(permit, {status: 200, headers: {}, body: ""})
    else if operation = "reject"
        permit = requestGateAcquire(base, "synthetic-held")
        workerCheck(permit.allowed, "held-first-admit")
        workerCheck(httpDispatcharrKeyRejected(401, "{" + chr(34) + "detail" + chr(34) + ":" + chr(34) + "Invalid API key" + chr(34) + "}"), "client-classifies-specific-refusal")
        requestGateReport(permit, {status: 401, headers: {}, body: "{" + chr(34) + "detail" + chr(34) + ":" + chr(34) + "Invalid API key" + chr(34) + "}"})
        workerCheck(permit.ticket.result.allowed = true, "broker-acknowledges-observation")
        denied = requestGateAcquire(base, "synthetic-held")
        workerCheck(not denied.allowed and denied.reason = "rejected-key", "acknowledged-rejection-blocks-next-call")
        fresh = requestGateAcquire(base, "synthetic-replacement")
        workerCheck(fresh.allowed, "replacement-key-not-held")
        requestGateReport(fresh, {status: 200, headers: {}, body: ""})
        prompt = CreateObject("roSGNode", "RequestGateTicket")
        prompt.id = "synthetic-prompt"
        prompt.action = "prompt"
        prompt.hash = requestGateCredentialHash("synthetic-held")
        first = requestGateExchange(requestGateBroker(), prompt)
        second = requestGateExchange(requestGateBroker(), prompt)
        workerCheck(first.show and not second.show, "shared-prompt-once")
    else if operation = "parallel-report"
        key = "synthetic-concurrent-refusal-" + m.top.index.toStr()
        permit = requestGateAcquire(base, key)
        workerCheck(permit.allowed, "concurrent-observation-first-admit")
        requestGateReport(permit, {status: 401, headers: {}, body: "{" + chr(34) + "detail" + chr(34) + ":" + chr(34) + "Invalid API key" + chr(34) + "}"})
        denied = requestGateAcquire(base, key)
        workerCheck(not denied.allowed and denied.reason = "rejected-key", "concurrent-observation-acknowledged-before-next-request")
    else if operation = "parallel-held"
        denied = requestGateAcquire(base, "synthetic-held")
        workerCheck(not denied.allowed and denied.reason = "rejected-key", "concurrent-task-sees-held-key")
    else if operation = "park"
        permit = requestGateAcquire(base, "synthetic-park")
        workerCheck(permit.allowed, "park-first-admit")
        requestGateReport(permit, {status: 429, headers: {"Retry-After": "120"}, body: ""})
        denied = requestGateAcquire(base, "synthetic-other")
        workerCheck(not denied.allowed and denied.reason = "parked", "server-park-crosses-credentials")
        denied = requestGateAcquire(base, "")
        workerCheck(not denied.allowed and denied.reason = "parked", "server-park-crosses-authless-paths")
        denied = requestGateAcquire(base, "synthetic-held", true)
        workerCheck(not denied.allowed and denied.reason = "parked", "server-park-blocks-probes")
        other = requestGateAcquire("https://other.test/api/", "synthetic-other")
        workerCheck(other.allowed, "different-server-not-parked")
        requestGateReport(other, {status: 200, headers: {}, body: ""})
    else if operation = "parallel-park"
        denied = requestGateAcquire("HTTPS://EXAMPLE.TEST:443/other/path", "synthetic-" + m.top.index.toStr())
        workerCheck(not denied.allowed and denied.reason = "parked", "concurrent-task-sees-server-park")
    else if operation = "video-park"
        m.key = "synthetic-video"
        m.timeout = 2000
        workerCheck(requestJson(m.top.fixtureBase + "/video-park") = invalid, "native-video-park-observed")
        workerCheck(m.httpFailure.category = "rate-limit", "native-video-server-park-classified")
        m.key = ""
    else if operation = "direct-bypasses"
        m.base = m.top.fixtureBase
        m.key = "synthetic-transport-replacement"
        workerCheck(not requestGateAccessAllowed(m.base, m.key), "park-blocks-cache-authorization")
        workerCheck(not requestGateAccessAllowed("https://third.test/", "synthetic-held"), "held-key-blocks-cache-on-another-host")
        workerCheck(sessionMutation(m.base + "/blocked-session", "POST", {}).status = 0, "park-blocks-session-mutation")
        workerCheck(requestMappedDetails({"7": true}) = invalid, "park-blocks-parallel-mapping")
        m.key = ""
    else if operation = "transport"
        m.key = "synthetic-transport-held"
        m.timeout = 2000
        fixture = m.top.fixtureBase
        workerCheck(requestJson(fixture + "/generic") = invalid, "real-generic-refused")
        workerCheck(not httpAccountRejected(m.httpFailure), "real-generic-keeps-key")
        workerCheck(requestJson(fixture + "/forbidden") = invalid, "real-403-refused")
        workerCheck(not httpAccountRejected(m.httpFailure), "real-403-keeps-key")
        workerCheck(requestJson(fixture + "/reject") = invalid, "real-rejection-refused")
        workerCheck(httpAccountRejected(m.httpFailure), "real-rejection-classified")
        workerCheck(requestJson(fixture + "/must-not-send") = invalid, "real-held-transport-blocked")
        m.key = "synthetic-transport-replacement"
        workerCheck(requestJson(fixture + "/ok") <> invalid, "real-replacement-transport-admitted")
        workerCheck(requestJson(fixture + "/park") = invalid, "real-429-refused")
        workerCheck(m.httpAttempts = 1, "real-429-no-immediate-retry")
        workerCheck(requestJson(fixture + "/parked-must-not-send") = invalid, "real-server-park-blocks-transport")
        m.key = ""
    else
        workerCheck(false, "unknown-fixture-operation")
    end if
    m.top.result = {ok: m.failures = 0}
end sub

sub workerCheck(ok as boolean, name as string)
    if ok then return
    m.failures++
    print "[request-gate] "; FormatJson({kind: "failure", assertion: name})
end sub
