sub main()
    hash = string(64, "a")
    m.top = {aeriosession: "retired-session", baseUrl: "https://example.test", action: "schedule", scheduleSubmitted: true, cancelRequested: false, subtype: function() as string
        return "DvrRecordingTask"
    end function}
    m.global = {activeusersession: "new-session", profilegateclosed: true, requestGateRequired: true, requestGate: {ready: true, snapshot: requestGateDefault()}}
    permit = {allowed: true, probe: false, submittedSchedule: true, submittedScheduleUrl: "https://example.test/api/channels/recordings/", ticket: {url: requestGateTicketUrl("https://example.test/api/channels/recordings/", false), hash: hash}}
    check(requestGatePermitActive(permit), "an already submitted schedule may receive its bounded response after auth retirement")
    check(not requestGateAcquire(permit.ticket.url, "old-key").allowed, "settlement never admits another request with retired authentication")
    permit.submittedSchedule = false
    check(not requestGatePermitActive(permit), "ordinary requests receive no closed-gate exception")
    permit.submittedSchedule = true
    permit.submittedScheduleUrl = "https://example.test/api/accounts/users/me/"
    check(not requestGatePermitActive(permit), "even recording Tasks cannot continue an old GET or another endpoint")
    permit.submittedScheduleUrl = "https://example.test/api/channels/recordings/"
    m.top.action = "list"
    check(not requestGatePermitActive(permit), "only record-once submission can retain response observation")
    m.top.action = "schedule"
    m.top.scheduleSubmitted = false
    check(not requestGatePermitActive(permit), "an unsubmitted schedule cannot inherit the response-only allowance")
    m.top.scheduleSubmitted = true
    m.top.subtype = function() as string
        return "DispatcharrTask"
    end function
    check(not requestGatePermitActive(permit), "other Tasks cannot impersonate submitted recording settlement")
    m.top.subtype = function() as string
        return "DvrRecordingTask"
    end function
    permit.submittedScheduleUrl = "https://other.test/api/channels/recordings/"
    check(not requestGatePermitActive(permit), "a different server cannot reuse a submitted recording lease")
    permit.submittedScheduleUrl = "https://example.test/api/channels/recordings/"
    m.global.requestGate.snapshot.keys[hash] = {version: 1}
    check(not requestGatePermitActive(permit), "submitted response wait never ignores a rejected-key hold")
    m.global.requestGate.snapshot.keys = {}
    m.global.requestGate.snapshot.servers["example.test:443"] = CreateObject("roDateTime").asSeconds() + 60
    check(not requestGatePermitActive(permit), "submitted response wait never ignores a server park")
    m.global.requestGate.snapshot.servers = {}
    m.top.cancelRequested = true
    check(not requestGatePermitActive(permit), "explicit cancellation still stops response observation")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
