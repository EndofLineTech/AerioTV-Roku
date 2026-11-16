' Private native package only: zero HTTP or server mutations from admin Tasks.
function profileAdminRequest(url as string, body = invalid as dynamic, method = "GET" as string) as object
    if m.top.cancelRequested or not requestGateTaskSessionCurrent() then return {ok: false}
    if right(url, 10) = "/users/me/"
        id = m.top.accountId
        username = m.top.username
        if m.key = m.top.baseKey
            id = m.top.baseAccountId
            username = m.top.baseUsername
        end if
        return {ok: true, data: {id: userProfileUserId(id), username: username, user_level: 10}}
    end if
    if right(url, 7) = "/users/"
        key = ""
        if type(m.top.minted) = "roAssociativeArray" then key = m.top.minted.key
        return {ok: true, data: [{id: userProfileUserId(m.top.accountId), username: m.top.username, api_key: "synthetic-caller-key", channel_profiles: []}, {id: 9001, username: "fixture-admin-user", api_key: key}]}
    end if
    if right(url, 10) = "/profiles/" then return {ok: true, data: [{id: 4, name: "Sports"}, {id: 7, name: "Family"}]}
    if method = "POST" and right(url, 10) = "/generate/"
        if body.user_id <> 9001 then return {ok: false}
        return {ok: true, data: {key: "synthetic-minted-key"}}
    end if
    if method = "POST" and right(url, 8) = "/revoke/"
        return {ok: body.user_id = 9001, data: invalid}
    end if
    if method = "PATCH"
        valid = body.channel_profiles.count() = 1 and body.channel_profiles[0] = 4
        return {ok: valid, data: invalid}
    end if
    return {ok: false}
end function
