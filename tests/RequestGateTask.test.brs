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
    hash = string(64, "a")
    other = string(64, "b")
    nonce = "00000000-0000-4000-8000-000000000090"
    m.global = {activeusersession: "outgoing-authenticated-session", profileownsigninnonce: nonce, profileownsigninpending: true}
    m.gateState = requestGateObserve(m.gateState, "example.test:443", hash, 401, {}, FormatJson({detail: "Invalid API key"}), 100)
    version = m.gateState.keys[hash].version
    m.gateState = requestGateObserve(m.gateState, "example.test:443", other, 401, {}, FormatJson({detail: "Invalid API key"}), 101)
    m.gateLeases["old-probe"] = {issued: CreateObject("roDateTime").asSeconds(), server: "example.test:443", hash: hash, probe: true}
    m.gateLeases["other-probe"] = {issued: CreateObject("roDateTime").asSeconds(), server: "example.test:443", hash: other, probe: true}
    proof = {id: "own-proof", action: "own-verified", hash: hash, holdVersion: version, credentialNonce: nonce, result: invalid}
    processRequestGateTicket(proof)
    check(proof.result.allowed and not m.gateState.keys.doesExist(hash) and m.gateState.keys.doesExist(other), "broker serializes verified own-credential resolution for only its captured hash")
    check(not m.gateLeases.doesExist("old-probe") and m.gateLeases.doesExist("other-probe"), "old hash transport leases retire so their late reports cannot re-hold or re-lift the recovered key")
    late = {id: "old-probe", action: "observe", status: 401, headers: {}, body: FormatJson({detail: "Invalid API key"}), url: "", result: invalid}
    processRequestGateTicket(late)
    check(not late.result.allowed and not m.gateState.keys.doesExist(hash), "a retired in-flight key report cannot undo verified own credential recovery")
    m.gateState = requestGateObserve(m.gateState, "example.test:443", hash, 401, {}, FormatJson({detail: "Invalid API key"}), 102)
    stale = {id: "stale-proof", action: "own-verified", hash: hash, holdVersion: version, credentialNonce: nonce, result: invalid}
    processRequestGateTicket(stale)
    check(not stale.result.allowed and m.gateState.keys.doesExist(hash), "same-second newer hold refuses an old credential proof even within the same UI nonce")
    m.global.profileownsigninpending = false
    generic = {id: "generic-proof", action: "own-verified", hash: hash, holdVersion: m.gateState.keys[hash].version, credentialNonce: nonce, result: invalid}
    processRequestGateTicket(generic)
    check(not generic.result.allowed and m.gateState.keys.doesExist(hash), "ordinary authenticated Tasks cannot impersonate own-password completion")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
