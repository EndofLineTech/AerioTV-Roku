sub main()
    m.syncJsonParser = function(text as string) as dynamic
        return ParseJson(text)
    end function
    m.fixtureCheckHeader = false
    for each scenario in ["ready", "missing", "identity", "username", "rejected", "newer", "cancelled"]
        m.fixtureScenario = scenario
        m.top = {baseUrl: "https://example.test", apiKey: "synthetic-own", accountId: "7", username: "Alice", cancelRequested: false}
        readDispatcharrSync()
        result = m.top.result
        if scenario = "ready" or scenario = "missing"
            check(result.ok and result.verifiedBaseUrl = "https://example.test" and result.accountId = "7" and result.accountUsername = "Alice", "successful own read publishes its exact identity/address binding")
            check(type(result.verifiedUser) = "roAssociativeArray", "own read exposes its latest verified authority rather than an earlier authentication snapshot")
            check(result.verifiedUser.user_level = 1 and not result.verifiedUser.is_staff and result.verifiedUser.stream_limit = 2 and result.verifiedUser.custom_properties.vod_movies_enabled = false, "latest own permission downgrade is retained for target staging")
            check(result.verifiedUser.api_key = invalid and result.verifiedUser.password = invalid and result.verifiedUser.cookie = invalid and result.verifiedUser.custom_properties.private_token = invalid, "own read never publishes arbitrary me-response credentials in authority metadata")
        else
            check(not result.ok and result.verifiedUser = invalid, "failed or cancelled read cannot donate a previous read's authority")
        end if
        check(result.allowWrite = false and result.apiKey = invalid and result.phase = invalid and m.top.apiKey = "" and m.key = "" and m.syncReadAuthority = invalid, "authority metadata never turns the read into a writer or credential recovery proof")
    end for
    for each mode in ["authorization", "compatible", "invalid-mode", ""]
        m.global = {authHeaderMode: "compatible"}
        m.top = {baseUrl: "https://example.test", apiKey: "synthetic-own", accountId: "7", username: "Alice", authMode: mode, cancelRequested: false}
        m.fixtureScenario = "ready"
        m.fixtureCheckHeader = true
        m.fixtureExpectedHeader = invalid
        if mode <> "" then m.fixtureExpectedHeader = dispatcharrHeaderMode(mode)
        readDispatcharrSync()
        check(m.top.result.ok and m.global.authHeaderMode = "compatible" and m.requestMode = invalid, "target own read uses task-local verified header mode without changing or retaining the outgoing global mode")
    end for
    m.fixtureCheckHeader = false
    for each retired in ["cancelled", "session"]
        m.global = {activeusersession: "new-session", profilegateclosed: false}
        m.top = {apiKey: "synthetic-own", cancelRequested: retired = "cancelled"}
        if retired = "session" then m.top.aeriosession = "old-session"
        m.key = "synthetic-own"
        m.syncReadAuthority = {verifiedUser: {id: 7, username: "Alice"}}
        finishDispatcharrSyncRead({ok: true, state: "ready", data: {private: "old-holder"}})
        check(not m.top.result.ok and m.top.result.verifiedUser = invalid and m.top.result.data = invalid and m.top.apiKey = "" and m.key = "", "final publication rechecks cancellation/session retirement rather than emitting a stale own payload")
    end for
    print "ALL TESTS PASSED"
end sub

function httpTransferOnce(url as string, body as dynamic, bearer as string, timeoutMs as integer, maxBytes as integer, method = "GET" as string, checked = invalid as dynamic) as object
    if method <> "GET" or bearer <> "" or body <> invalid or m.key <> "synthetic-own" then stop
    if m.fixtureCheckHeader then check(m.requestMode = m.fixtureExpectedHeader, "every target read request carries only its task-local header override")
    value = {apps: [{key: "alice.aeriotv", bytes: 50}]}
    if right(url, 10) = "/users/me/"
        value = {id: 7, username: "Alice", user_level: 1, is_staff: false, stream_limit: 2, channel_profiles: [8], custom_properties: {vod_movies_enabled: false, private_token: "private-token"}, api_key: "private-key", password: "private-password", cookie: "private-cookie"}
        if m.fixtureScenario = "identity" then value.id = 8
        if m.fixtureScenario = "username" then value.username = "Other"
        if m.fixtureScenario = "rejected" then return {status: 401, headers: {}, error: "", body: "{}", bytes: 2}
    else if right(url, 9) = "app-data/"
        if m.fixtureScenario = "missing" then value.apps = []
        if m.fixtureScenario = "cancelled" then m.top.cancelRequested = true
    else
        value = {schemaVersion: 3, deviceId: "fixture", platform: "android", appVersion: "1", updatedAt: "2026-11-11T18:00:00Z", categories: {}}
        if m.fixtureScenario = "newer" then value.schemaVersion = 4
    end if
    return {status: 200, headers: {}, error: "", body: FormatJson(value), bytes: 0}
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
