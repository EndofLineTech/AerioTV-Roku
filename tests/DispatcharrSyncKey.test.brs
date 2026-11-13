sub main()
    for each vector in [["alice", "alice.aeriotv"], ["ADMIN", "admin.aeriotv"], ["john.doe-1_x", "john.doe-1_x.aeriotv"], ["a@b.com", "a-40b.com.aeriotv"], ["first+tag", "first-2btag.aeriotv"], ["Kids Room", "kids-20room.aeriotv"], ["_admin", "u_admin.aeriotv"], [string(60, "a"), string(46, "a") + ".aeriotv"], ["", ""]]
        check(dispatcharrSyncUserKey(vector[0]) = vector[1], "peer canonical ASCII key vector")
    end for
    check(dispatcharrSyncKeyBytes([74, 111, 115, 195, 169]) = "jos-c3-a9.aeriotv", "peer UTF8 Jose vector")
    check(dispatcharrSyncKeyBytes([240, 159, 152, 128]) = "u-f0-9f-98-80.aeriotv", "emoji uses UTF8 not UTF16 or Unicode case folding")
    check(dispatcharrSyncUserKey(string(44, "a") + "@") = string(44, "a") + "-4.aeriotv", "46-character cut intentionally splits byte escape")
    check(dispatcharrSyncUserKey(" A ") = "u-20a-20.aeriotv", "username is not trimmed or normalized beyond wire algorithm")
    check(dispatcharrSyncKeyBytes([256]) = "" and dispatcharrSyncKeyBytes([-1]) = "", "invalid byte vector refuses")
    current = {apps: [{key: "alice.aeriotv", bytes: 99}, {key: "app.molinete.aerio", bytes: 100}]}
    plan = dispatcharrSyncReadPlan("alice.aeriotv", current)
    check(plan.state = "canonical" and plan.key = "alice.aeriotv" and not plan.allowWrite, "current key takes precedence, read-only never enables writes")
    plan = dispatcharrSyncReadPlan("alice.aeriotv", {apps: [{key: "app.molinete.aerio", bytes: 99}, {key: "app.molinete.aerio.favorites", bytes: 50}, {key: "other.app", bytes: 10}]})
    check(plan.state = "legacy" and plan.legacy.count() = 2 and plan.key = "" and not plan.allowWrite, "legacy absence blocks empty canonical creation, preserves all migration sources")
    plan = dispatcharrSyncReadPlan("alice.aeriotv", {apps: []})
    check(plan.state = "missing" and not plan.allowWrite, "absent record does not auto-create sync data")
    for each malformed in [invalid, [], {}, {apps: "bad"}, {apps: [{key: "bad/key", bytes: 1}]}, {apps: [{key: "alice.aeriotv", bytes: -1}]}, {apps: [{key: "alice.aeriotv", bytes: "99"}]}, {apps: [{key: "alice.aeriotv", bytes: 1}, {key: "alice.aeriotv", bytes: 2}]}]
        check(dispatcharrSyncReadPlan("alice.aeriotv", malformed).state = "invalid", "malformed discovery cannot authorize read or write")
    end for
    check(dispatcharrSyncReadPlan("", current).state = "waiting", "empty verified username waits")
    check(dispatcharrSyncReadPlan("app.molinete.aerio", current).state = "invalid", "caller cannot select a legacy write key")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
