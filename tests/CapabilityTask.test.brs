sub main()
    for each mode in ["ready", "missing", "denied", "identity", "rejected401", "rejected403", "unavailable"]
        m.testMode = mode
        m.profileSeenBeforeFacts = false
        m.top = {baseUrl: "https://example.test", apiKey: "test-only", accountId: "one", profileResult: invalid}
        refreshCapabilities()
        if mode = "identity"
            if m.top.profileResult <> invalid or m.top.result.identityChanged <> true then stop
        else if mode = "rejected401" or mode = "rejected403"
            if m.top.profileResult <> invalid or m.top.result.relogin <> true then stop
        else if mode = "unavailable"
            if m.top.profileResult <> invalid or m.top.result.relogin = true then stop
        else
            if not m.profileSeenBeforeFacts then stop
            if mode = "ready"
                if m.top.profileResult.state <> "ready" or m.top.profileResult.profile.id <> "7" then stop
            else if mode = "missing"
                if m.top.profileResult.state <> "unavailable" then stop
            else
                if m.top.profileResult.state <> "error" then stop
            end if
        end if
        if m.top.apiKey <> "" then stop
    end for
    print "ALL TESTS PASSED"
end sub

function requestJson(url as string) as dynamic
    m.failure = ""
    m.httpFailure = invalid
    if instr(1, url, "users/me") > 0
        if m.testMode = "identity" then return {id: "other", user_level: 10}
        if m.testMode = "rejected401" or m.testMode = "rejected403" or m.testMode = "unavailable"
            status = 503
            if m.testMode = "rejected401" then status = 401
            if m.testMode = "rejected403" then status = 403
            m.httpFailure = httpFailure(status, {}, 1000)
            m.failure = m.httpFailure.message
            return invalid
        end if
        return {id: "one", user_level: 10}
    end if
    if instr(1, url, "outputprofiles") > 0
        if m.testMode = "denied"
            m.failure = "HTTP 403"
            return invalid
        end if
        if m.testMode = "missing" then return []
        return [{id: 7, is_active: true, command: "ffmpeg", parameters: "-c:v copy -c:a aac", name: "AAC"}]
    end if
    ' Optional metadata must not delay publishing the playback prerequisite.
    if m.top.profileResult = invalid then stop
    if instr(1, url, "version") > 0 then return {version: "test"}
    return []
end function

function requestPages(path as string) as dynamic
    m.profileSeenBeforeFacts = m.top.profileResult <> invalid
    return []
end function
