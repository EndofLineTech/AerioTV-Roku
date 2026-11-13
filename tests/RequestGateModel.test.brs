sub main()
    check(requestGateTicketUrl("https://example.test/path?api_key=must-not-retain", false) = "https://example.test/", "mailbox never retains query/signed URL secrets")
    check(requestGateTicketUrl("https://example.test/api/accounts/users/me/?secret=hidden", true) = "https://example.test/api/accounts/users/me/", "only probe endpoint marker crosses mailbox")
    check(requestGateTicketUrl("https://user:secret@example.test/", false) = "", "userinfo never crosses mailbox")
    check(requestGateProbeIdentityMatches({id: 7}, "7"), "slow probe confirms expected integer account")
    check(requestGateProbeIdentityMatches({id: 7, username: "Alice"}, "7", "alice"), "profile slow probe confirms both saved user ID and case-insensitive username")
    check(not requestGateProbeIdentityMatches({id: 7, username: "Bob"}, "7", "Alice"), "matching integer user ID cannot lift a different profile username's hold")
    check(not requestGateProbeIdentityMatches({id: 7}, "7", "Alice"), "profile slow probe refuses a missing expected username")
    for each user in [{id: 8}, {id: "7"}, {id: 7.0}, {}, invalid]
        check(not requestGateProbeIdentityMatches(user, "7"), "slow probe cannot lift hold for malformed/different identity")
    end for
    check(requestGateServer("HTTPS://Example.Test/api/") = "example.test:443", "server park is host plus effective port")
    check(requestGateServer("https://example.test:443/other") = "example.test:443", "paths/case/default ports share park")
    check(requestGateServer("http://example.test:443/") = "example.test:443", "scheme does not split an identical host/port park")
    check(requestGateServer("https://[2001:DB8::1]/api/") = "[2001:db8::1]:443", "IPv6 server key is unambiguous")
    for each bad in ["", "ftp://example.test", "https://user:password@example.test", "https://example.test:0", "https://example.test:65536"]
        check(requestGateServer(bad) = "", "invalid origin does not acquire a request permit")
    end for
    for each body in ["{" + chr(34) + "detail" + chr(34) + ":" + chr(34) + "Invalid API key" + chr(34) + "}", "{" + chr(34) + "detail" + chr(34) + ":" + chr(34) + "User inactive" + chr(34) + "}"]
        check(requestGateKeyRejected(401, body), "specific Dispatcharr refusal holds key")
        check(not requestGateKeyRejected(403, body), "403 never rejects a key")
    end for
    for each body in ["", "<html>Invalid API key</html>", "{}", "{" + chr(34) + "detail" + chr(34) + ":7}", "{" + chr(34) + "detail" + chr(34) + ":" + chr(34) + "Authentication credentials were not provided." + chr(34) + "}"]
        check(not requestGateKeyRejected(401, body), "generic/proxy/malformed refusal retains credential")
    end for
    a = string(64, "a")
    b = string(64, "b")
    server = "example.test:443"
    state = requestGateDefault()
    check(not requestGatePermit(state, server, "not-a-digest", 1000, false).allowed, "malformed credential context fails closed")
    check(requestGatePermit(state, server, a, 1000, false).allowed, "fresh credential allowed")
    state = requestGateObserve(state, server, a, 401, {}, "{" + chr(34) + "detail" + chr(34) + ":" + chr(34) + "Invalid API key" + chr(34) + "}", 1000)
    check(not requestGatePermit(state, server, a, 1000, false).allowed, "rejected key cannot leave on any path")
    check(requestGatePermit(state, server, b, 1000, false).allowed, "replacement/different credential is not held")
    prompt = requestGatePrompt(state, a)
    check(prompt.show, "first refusal prompts once")
    check(not requestGatePrompt(prompt.state, a).show, "repeated requests never prompt repeatedly")
    check(not requestGatePermit(state, server, a, 1059, true).allowed, "early slow probe refused")
    for each expected in [[1060, 1300], [1300, 1900], [1900, 3700], [3700, 5500]]
        permit = requestGatePermit(state, server, a, expected[0], true)
        check(permit.allowed and permit.probe, "scheduled slow probe admitted")
        state = permit.state
        check(state.keys[a].nextprobe = expected[1], "absolute one/five/fifteen minute then thirty minute schedule")
        check(not requestGatePermit(state, server, a, expected[0] + 1, true).allowed, "never concurrent/repeated probes inside sixty seconds")
    end for
    stale = requestGateObserve(state, server, a, 200, {}, "{}", 4000)
    check(not requestGatePermit(stale, server, a, 4001, false).allowed, "in-flight ordinary success cannot re-lift held key")
    recovered = requestGateObserve(state, server, a, 200, {}, "{}", 4000, true)
    check(requestGatePermit(recovered, server, a, 4001, false).allowed, "successful authorized probe clears its hold")
    parked = requestGateObserve(state, server, b, 429, {}, "", 2000)
    check(not requestGatePermit(parked, server, b, 2059, false).allowed, "missing Retry-After parks sixty seconds")
    check(not requestGatePermit(parked, server, "", 2059, false).allowed, "password/authless paths also share server park")
    check(not requestGatePermit(parked, server, a, 2059, true).allowed, "park blocks even due held-key probes")
    check(requestGatePermit(parked, "other.test:443", b, 2059, false).allowed, "unrelated server is not parked")
    parked = requestGateObserve(state, server, b, 429, {"Retry-After": "999"}, "", 2000)
    check(not requestGatePermit(parked, server, b, 2119, false).allowed and requestGatePermit(parked, server, b, 2120, false).allowed, "server park capped at one hundred twenty seconds")
    expired = requestGateDefault()
    for i = 1 to 32
        expired.servers["old" + i.toStr() + ":443"] = 1
    end for
    fresh = requestGateObserve(expired, server, b, 429, {}, "", 2000)
    check(not fresh.overflow and fresh.servers.count() = 1, "expired parks can be pruned without forgetting a live hold")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
