sub main()
    hash = string(64, "a")
    other = string(64, "b")
    nonce = "00000000-0000-4000-8000-000000000090"
    body = FormatJson({detail: "Invalid API key"})
    state = requestGateObserve(requestGateDefault(), "example.test:443", hash, 401, {}, body, 100)
    captured = state.keys[hash].version
    check(captured <> invalid and captured > 0, "each rejected-hash generation has an independent memory-only version")
    state = requestGateObserve(state, "example.test:443", other, 401, {}, body, 101)
    state = requestGateObserve(state, "example.test:443", "", 429, {"Retry-After": "60"}, "", 102)
    before = FormatJson(state)
    accepted = requestGateOwnCredentialVerified(state, hash, captured, nonce, nonce, true)
    check(accepted.ok and not accepted.state.keys.doesExist(hash) and accepted.state.keys.doesExist(other), "current verified own-password proof lifts only the returned key's captured hash hold")
    check(not requestGatePermit(accepted.state, "example.test:443", hash, 103, false).allowed, "own credential proof never clears a server-wide429 park")
    check(FormatJson(state) = before, "verified own-key resolution is a pure plan and cannot mutate the broker's previous state")
    check(not requestGateOwnCredentialVerified(state, hash, captured, nonce, "00000000-0000-4000-8000-000000000091", true).ok, "retired own credential proof cannot lift a hash hold")
    check(not requestGateOwnCredentialVerified(state, hash, captured, nonce, nonce, false).ok, "ordinary authenticated Tasks and switch attempts have no own-password hold exception")
    check(not requestGateOwnCredentialVerified(state, hash, captured + 1, nonce, nonce, true).ok, "a newer rejection generation cannot be cleared by a stale own credential result")
    check(not requestGateOwnCredentialVerified(state, hash, captured, "", "", true).ok, "missing credential lifecycle never authorizes a hold transition")
    reheld = requestGateObserve(accepted.state, "example.test:443", hash, 401, {}, body, 102)
    check(reheld.keys[hash].version > captured and not requestGateOwnCredentialVerified(reheld, hash, captured, nonce, nonce, true).ok, "a re-rejection in the same second still fences an older successful credential callback")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
