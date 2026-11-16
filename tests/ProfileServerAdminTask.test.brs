sub main()
    adminTaskFixture()
    runProfileServerAdmin()
    check(m.top.result.ok and m.top.result.users.count() = 1 and m.requests.count() = 3, "list verifies active and base login before requesting users")
    check(m.top.apiKey = "" and m.top.baseKey = "", "task input keys are scrubbed after completion")
    adminTaskFixture()
    m.fixtureBase.user_level = 1
    runProfileServerAdmin()
    check(not m.top.result.ok and m.top.result.manual and m.requests.count() = 2, "nonadmin base falls back without user-list request")
    adminTaskFixture()
    m.fixtureActor.username = "wrong-user"
    runProfileServerAdmin()
    check(not m.top.result.ok and m.requests.count() = 1, "wrong active identity cannot use base admin authority")
    adminTaskFixture()
    m.top.operation = "generate"
    m.top.targetId = "3"
    m.top.targetUsername = "Target"
    runProfileServerAdmin()
    check(m.top.result.ok and m.top.result.key = "new-key" and m.requests.count() = 4, "generation follows fresh dual identity and target list checks")
    last = m.requests[3]
    check(last.body.user_id = 3 and last.key = "active-key" and last.method = "POST", "explicit target generation uses active admin only")
    adminTaskFixture()
    m.top.operation = "generate"
    m.top.targetId = "4"
    m.top.targetUsername = "Target"
    runProfileServerAdmin()
    check(not m.top.result.ok and m.requests.count() = 3, "numeric ID and username must name the same listed user before mutation")
    adminTaskFixture()
    m.fixtureTarget.api_key = "already-present"
    m.top.operation = "generate"
    m.top.targetId = "3"
    m.top.targetUsername = "Target"
    runProfileServerAdmin()
    check(not m.top.result.ok and m.requests.count() = 3, "preexisting key refuses before mutation")
    adminTaskFixture()
    m.fixtureListStatus = 403
    runProfileServerAdmin()
    check(not m.top.result.ok and m.top.result.manual and m.requests.count() = 3, "403 user-list refusal falls back to manual details without attempting mutation")
    adminTaskFixture()
    m.top.operation = "channels"
    m.top.targetId = "3"
    m.top.targetUsername = "Target"
    m.top.confirmed = true
    m.top.channelIds = [4, 7]
    runProfileServerAdmin()
    check(m.top.result.ok and m.requests[3].method = "PATCH" and m.requests[3].body.channel_profiles[1] = 7, "Channel Profiles uses the exact verified user PATCH")
    adminTaskFixture()
    m.fixtureTarget.api_key = "minted-here"
    m.top.minted = {id: 3, username: "Target", key: "minted-here"}
    m.top.operation = "revoke"
    m.top.targetId = "3"
    m.top.targetUsername = "Target"
    m.top.confirmed = true
    runProfileServerAdmin()
    check(m.top.result.ok and m.requests[3].body.user_id = 3 and m.top.minted = invalid, "confirmed same-session revoke explicitly names target and clears its transport proof")
    print "ALL TESTS PASSED"
end sub

sub adminTaskFixture()
    ' Host interpreter lacks Roku's double-preserving parser option.
    m.profileAdminJsonParser = function(text as string) as dynamic
        return ParseJson(text)
    end function
    m.top = {baseUrl: "https://example.test", apiKey: "active-key", baseKey: "base-key", accountId: "2", username: "Actor", baseAccountId: "1", baseUsername: "Base", role: "admin", operation: "list", targetId: "", targetUsername: "", confirmed: false, channelIds: [], minted: invalid, cancelRequested: false}
    m.fixtureActor = {id: 2, username: "Actor", user_level: 10}
    m.fixtureBase = {id: 1, username: "Base", user_level: 10}
    m.fixtureTarget = {id: 3, username: "Target", api_key: ""}
    m.fixtureListStatus = 200
    m.requests = []
end sub

function httpTransferOnce(url as string, body as dynamic, bearer as string, timeoutMs as integer, maxBytes as integer, method = "GET" as string, checkedJson = invalid as dynamic) as object
    m.requests.push({url: url, body: body, key: m.key, method: method})
    data = invalid
    if right(url, 10) = "/users/me/"
        data = m.fixtureActor
        if m.key = "base-key" then data = m.fixtureBase
    else if right(url, 7) = "/users/"
        if m.fixtureListStatus <> 200 then return {status: m.fixtureListStatus, body: "{}", error: ""}
        data = [m.fixtureTarget]
    else if right(url, 10) = "/generate/"
        data = {key: "new-key"}
    else if method = "PATCH" or right(url, 8) = "/revoke/"
        return {status: 204, body: "", error: ""}
    end if
    return {status: 200, body: FormatJson(data), error: ""}
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
