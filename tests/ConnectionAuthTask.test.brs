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
    print "ALL TESTS PASSED"
end sub

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    m.calls++
    if m.unionMode = true then return {id: 7, username: "viewer", user_level: 1}
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
    return {state: "miss"}
end function

function metadataCacheWrite(scope as string, kind as string, key as string, generation as string, now as integer, payload as dynamic) as boolean
    return true
end function
