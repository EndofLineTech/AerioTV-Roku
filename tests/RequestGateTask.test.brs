sub main()
    m.top = {}
    m.gateState = requestGateDefault()
    m.gateLeases = {}
    ticket = {id: "lease-a", action: "acquire", url: "https://example.test/path", hash: "", probe: false, result: invalid}
    processRequestGateTicket(ticket)
    check(ticket.result.allowed and m.gateLeases.count() = 1, "fresh immutable wire acquires one lease")
    ticket.result.completedOnce = true
    processRequestGateTicket(ticket)
    check(ticket.result.completedOnce = true and m.gateLeases.count() = 1, "re-notified completed wire is never processed or answered again")
    report = {id: "lease-a", action: "observe", status: 200, headers: {}, body: "", url: "", result: invalid}
    processRequestGateTicket(report)
    check(report.result.allowed and m.gateLeases.count() = 0, "fresh observation wire may finish same lease")
    report.result.completedOnce = true
    processRequestGateTicket(report)
    check(report.result.completedOnce = true, "duplicate nested-node notification cannot create a response feedback loop")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
