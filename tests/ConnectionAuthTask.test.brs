sub main()
    for each status in [401, 403, 503]
        m.rejectedStatus = status
        m.calls = 0
        m.top = {baseUrl: "https://example.test", apiKey: "test-only", username: "", password: "", cancelRequested: false}
        loadChannels()
        if m.calls <> 1 or m.top.result.ok <> false then stop
        if m.top.result.relogin <> (status = 401) then stop
        if m.top.apiKey <> "" then stop
    end for
    m.profileMode = true
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", username: "", password: "", cancelRequested: false, profileId: "3"}
    loadChannels()
    if m.calls <> 3 or m.top.result.ok <> false then stop
    if instr(1, m.top.result.message, "Selected channel profile") = 0 then stop
    if m.top.apiKey <> "" then stop
    m.profileMode = false
    m.compatibilityMode = true
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", authMode: "authorization", username: "", password: "", cancelRequested: false, profileId: "3"}
    loadChannels()
    if m.calls <> 4 then stop ' users/me rejected once, then verified once; summary and profile reads once
    if m.requestMode <> "x-api-key" or m.top.result.ok <> false then stop
    if m.top.apiKey <> "" then stop
    m.compatibilityMode = false
    m.passwordMode = true
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "", username: "viewer", password: "test-password", cancelRequested: false, profileId: ""}
    loadChannels()
    if m.top.result.ok <> true or m.top.result.apiKey <> "verified-key" then stop
    if m.top.password <> "" or m.top.apiKey <> "" then stop
    if m.calls <> 4 then stop ' token, verified user, channel summary and groups
    m.passwordMode = false
    m.unionMode = true
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", authMode: "x-api-key", username: "", password: "", cancelRequested: false, profileId: "", channelProfileIds: [3, 5], userAgent: "Synthetic-Agent"}
    loadChannels()
    if m.top.result.ok <> true or m.top.result.channels.count() <> 2 then stop
    if m.top.result.accountUsername <> "viewer" or m.requestUserAgent <> "Synthetic-Agent" then stop
    if m.top.result.verifiedUser.id <> 7 or m.top.result.verifiedUser.user_level <> 1 then stop
    if m.calls <> 4 then stop ' user, summary, profile union and groups
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", authMode: "x-api-key", username: "", password: "", cancelRequested: false, profileId: "", channelProfileIds: [3, 9], userAgent: "Synthetic-Agent"}
    loadChannels()
    if m.top.result.ok <> false or m.top.apiKey <> "" then stop
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", authMode: "x-api-key", username: "", password: "", cancelRequested: false, verifyOnly: true}
    loadChannels()
    if m.calls <> 1 or not m.top.result.ok or m.top.result.phase <> "verified" then stop
    if m.top.result.verifiedUser.id <> 7 or m.top.result.apiKey <> "test-only" then stop
    if m.top.apiKey <> "" or m.top.result.channels <> invalid then stop
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", authMode: "x-api-key", username: "", password: "", cancelRequested: false, expectedUserId: "8", expectedUsername: "viewer"}
    loadChannels()
    if m.calls <> 1 or m.top.result.ok or not m.top.result.identityChanged then stop
    if m.top.apiKey <> "" then stop
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", authMode: "x-api-key", username: "", password: "", cancelRequested: false, expectedUserId: "7", expectedUsername: "another"}
    loadChannels()
    if m.calls <> 1 or m.top.result.ok or not m.top.result.identityChanged then stop
    for each change in ["level", "staff", "superuser", "assignments", "stream-limit", "permissions", "staff-string", "permission-string", "level-float", "bad-props", "bad-assignments", "stream-shape"]
        expected = {id: 7, username: "viewer", user_level: 1}
        actual = {id: 7, username: "viewer", user_level: 1}
        if change = "level" then expected.user_level = 10
        if change = "staff" then actual.is_staff = true
        if change = "superuser" then actual.is_superuser = true
        if change = "assignments" then actual.channel_profiles = [2]
        if change = "stream-limit" then actual.stream_limit = 3
        if change = "permissions" then actual.custom_properties = {vod_movies_enabled: false}
        if change = "staff-string" then actual.is_staff = "false"
        if change = "permission-string" then actual.custom_properties = {vod_movies_enabled: "false"}
        if change = "level-float" then actual.user_level = 1.0
        if change = "bad-props" then actual.custom_properties = "bad"
        if change = "bad-assignments" then actual.channel_profiles = "bad"
        if change = "stream-shape" then actual.stream_limit = {}
        m.fixtureAuthorityUser = actual
        m.calls = 0
        m.cacheReads = 0
        m.cacheWrites = 0
        m.top = {baseUrl: "https://example.test", apiKey: "test-only", authMode: "x-api-key", username: "", password: "", cancelRequested: false, expectedUserId: "7", expectedUsername: "viewer", expectedAuthorizationSignature: dispatcharrAuthorizationSignature(expected), profileId: "", channelProfileIds: []}
        loadChannels()
        check(m.calls = 1 and m.cacheReads = 0 and m.cacheWrites = 0 and m.top.result.ok = false and m.top.result.protectionAuthorityChanged = true, "changed/malformed " + change + " stops after own me, BEFORE any channel/profile/cache acquisition")
        check(m.top.result.relogin <> true and m.top.result.identityChanged <> true and m.top.result.apiKey = invalid and m.top.result.channels = invalid and m.top.apiKey = "" and m.key = "", "authority drift does not reject/return the own key or manufacture a credential/identity recovery result")
    end for
    m.fixtureAuthorityUser = {id: 7, username: "viewer", user_level: 1}
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", authMode: "x-api-key", username: "", password: "", cancelRequested: false, expectedAuthorizationSignature: dispatcharrAuthorizationSignature(m.fixtureAuthorityUser), profileId: "", channelProfileIds: []}
    loadChannels()
    check(m.top.result.ok and m.calls = 3, "same own authority admits the expected full lineup without a second roster or borrowed identity")
    m.cancelAfterMe = true
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "test-only", authMode: "x-api-key", username: "", password: "", cancelRequested: false, expectedAuthorizationSignature: dispatcharrAuthorizationSignature(m.fixtureAuthorityUser), profileId: "", channelProfileIds: []}
    loadChannels()
    check(m.calls = 1 and m.top.result = invalid and m.top.apiKey = "", "cancelled bound admission publishes no authority failure or successful content after own me")
    m.cancelAfterMe = false
    m.fixtureAuthorityUser = invalid
    m.ownSignInMode = true
    for each outcome in ["ok", "rejected", "verify-rejected", "bad-token", "api", "name", "name-no-api"]
        m.loginOutcome = outcome
        m.calls = 0
        m.top = {baseUrl: "https://example.test", apiKey: "", username: "viewer", password: "synthetic-password", cancelRequested: false, ownProfileSignIn: true, expectedUsername: "VIEWER", verifyOnly: true}
        loadChannels()
        if m.top.password <> "" or m.top.apiKey <> "" then stop
        if outcome = "ok"
            if m.calls <> 2 or not m.top.result.ok or m.top.result.verifiedUser.id <> 88 or m.top.result.apiKey <> "verified-own-key" then stop
        else if outcome = "api"
            if m.top.result.ok or m.top.result.apiAccessRequired <> true then stop
            if m.top.result.message <> "This account has no API key yet. Ask your Dispatcharr administrator to turn on API access for it." then stop
        else
            if m.top.result.ok or m.top.result.message <> "Dispatcharr did not accept that username or password." then stop
        end if
    end for
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "", username: "viewer", password: "synthetic-password", cancelRequested: true, ownProfileSignIn: true, expectedUsername: "viewer", verifyOnly: true}
    loadChannels()
    if m.calls <> 0 or m.top.password <> "" or m.top.result <> invalid then stop
    m.calls = 0
    m.top = {baseUrl: "https://example.test", apiKey: "", username: "viewer", password: "synthetic-password", cancelRequested: false, ownProfileSignIn: true, verifyOnly: true}
    loadChannels()
    if m.calls <> 0 or m.top.result.ok or m.top.password <> "" then stop
    print "ALL TESTS PASSED"
end sub

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    m.calls++
    if m.ownSignInMode = true
        if instr(1, url, "/api/accounts/token/") > 0
            if body.username <> "viewer" or body.password <> "synthetic-password" then stop
            if m.loginOutcome = "rejected" then return invalid
            if m.loginOutcome = "bad-token" then return {}
            return {access: "synthetic-session-token"}
        end if
        if bearer <> "synthetic-session-token" then stop
        if m.loginOutcome = "verify-rejected" then return invalid
        username = "viewer"
        key = "verified-own-key"
        if m.loginOutcome = "name" then username = "another"
        if m.loginOutcome = "name-no-api" then username = "another"
        if m.loginOutcome = "api" then key = invalid
        if m.loginOutcome = "name-no-api" then key = invalid
        return {id: 88, username: username, user_level: 1, api_key: key}
    end if
    if m.unionMode = true
        if m.cancelAfterMe = true then m.top.cancelRequested = true
        if type(m.fixtureAuthorityUser) = "roAssociativeArray" then return m.fixtureAuthorityUser
        return {id: 7, username: "viewer", user_level: 1}
    end if
    if m.passwordMode = true
        if instr(1, url, "/api/accounts/token/") > 0
            if body.username <> "viewer" or body.password <> "test-password" then stop
            return {access: "session-token"}
        end if
        if bearer <> "session-token" then stop
        return {id: 7, username: "viewer", user_level: 1, api_key: "verified-key"}
    end if
    if m.compatibilityMode = true
        if m.calls = 1
            m.httpFailure = httpFailure(400, {}, 1000)
            m.failure = m.httpFailure.message
            return invalid
        end if
        m.httpFailure = invalid
        m.failure = ""
        return {id: 7}
    end if
    if m.profileMode = true then return {id: 7}
    m.httpFailure = httpFailure(m.rejectedStatus, {}, 1000)
    m.httpFailure.keyRejected = (m.rejectedStatus = 401)
    m.failure = m.httpFailure.message
    return invalid
end function

function requestPages(path as string) as dynamic
    m.calls++
    if m.unionMode = true
        if instr(1, path, "/channels/summary/") > 0 then return [{id: 10, uuid: "ten", name: "First", channel_number: "1"}, {id: 11, uuid: "eleven", name: "Second", channel_number: "2"}, {id: 12, uuid: "twelve", name: "Hidden", channel_number: "3"}]
        if instr(1, path, "/channels/profiles/") > 0 then return [{id: 3, channels: [10]}, {id: 5, channels: [11, 99]}]
        if instr(1, path, "/channels/groups/") > 0 then return []
    end if
    if instr(1, path, "/channels/summary/") > 0 then return [{id: 10, uuid: "ten", name: "Authorized", channel_number: "1"}]
    if m.passwordMode = true and instr(1, path, "/channels/groups/") > 0 then return []
    m.failure = "Profiles unavailable."
    return invalid
end function

function metadataCacheDigest(value as string) as string
    return "test-digest"
end function

function metadataCacheRead(scope as string, kind as string, key as string, generation as string, now as integer, authorized as boolean) as object
    if m.cacheReads = invalid then m.cacheReads = 0
    m.cacheReads++
    return {state: "miss"}
end function

function metadataCacheWrite(scope as string, kind as string, key as string, generation as string, now as integer, payload as dynamic) as boolean
    if m.cacheWrites = invalid then m.cacheWrites = 0
    m.cacheWrites++
    return true
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
