sub main()
    for each phase in ["me", "list", "key", "put"]
        for each status in [401, 403]
            result = dispatcharrSyncFailure(phase, status, "", "")
            expected = "retry"
            if phase = "me" then expected = "authorization-unavailable"
            if phase = "list" or phase = "put" then expected = "signin-required"
            check(not result.ok and result.state = expected and result.phase = phase and result.status = status, "authorization failure classification is endpoint-specific")
        end for
    end for
    for each status in [0, 500, 502, 503]
        check(dispatcharrSyncFailure("put", status, "", "").state = "retry", "network/server failure remains pending with bounded backoff")
    end for
    check(dispatcharrSyncFailure("put", 429, "", "").state = "parked", "429 stays below the sync engine's shared broker park")
    result = dispatcharrSyncFailure("put", 409, "max_apps", "")
    check(result.state = "storage-full" and result.creationBlocked = true, "only typed PUT max_apps latches canonical creation")
    check(dispatcharrSyncFailure("put", 413, "value_too_large", "").state = "too-large", "oversize is retained for safe trimming/local-change handling, never retried immediately")
    check(dispatcharrSyncFailure("put", 409, "different_conflict", "").state = "retry" and dispatcharrSyncFailure("list", 409, "max_apps", "").creationBlocked <> true, "unknown conflict or non-PUT max_apps cannot latch canonical creation")
    result = dispatcharrSyncFailure("list", 401, "Invalid API key", "")
    check(not result.doesExist("apiKey") and not result.doesExist("body") and not result.doesExist("code"), "failure receipt contains only sanitized classification, no credential or arbitrary response body")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
