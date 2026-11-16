' Bounded administration only; each operation verifies both current /me proofs.
' Never retry a mutation or expose response/error bodies in UI or diagnostics.
sub init()
    m.top.functionName = "runProfileServerAdmin"
end sub

sub runProfileServerAdmin()
    result = {ok: false, manual: true, reason: "Only a Dispatcharr admin can manage server users."}
    m.key = m.top.apiKey
    base = normalizeBaseUrl(m.top.baseUrl)
    if base = "" or textValue(m.key) = "" or textValue(m.top.baseKey) = "" then finishProfileServerAdmin(result) : return
    actor = profileAdminRequest(base + "/api/accounts/users/me/")
    if not actor.ok then finishProfileServerAdmin(result) : return
    if not profileAdminIdentity(actor.data, m.top.accountId, m.top.username) then finishProfileServerAdmin(result) : return
    m.key = m.top.baseKey
    login = profileAdminRequest(base + "/api/accounts/users/me/")
    m.key = m.top.apiKey
    if not login.ok then finishProfileServerAdmin(result) : return
    if not profileAdminIdentity(login.data, m.top.baseAccountId, m.top.baseUsername) then finishProfileServerAdmin(result) : return
    if not userProfileServerAdminAllowed(login.data, actor.data, m.top.role) then finishProfileServerAdmin(result) : return
    listing = profileAdminList(base, "/api/accounts/users/")
    if not listing.ok then finishProfileServerAdmin({ok: false, manual: true, reason: "Could not list Dispatcharr users. Enter details instead."}) : return
    users = listing.data
    if type(users) = "roAssociativeArray" then users = users.results
    if type(users) <> "roArray" then finishProfileServerAdmin(result) : return
    if users.count() > 512 then finishProfileServerAdmin({ok: false, manual: true, reason: "Server user list is too large. Enter details instead."}) : return
    if m.top.operation = "list"
        finishProfileServerAdmin({ok: true, users: users})
        return
    end if
    target = invalid
    for each user in users
        if profileAdminIdentity(user, m.top.targetId, m.top.targetUsername) then target = user
    end for
    if target = invalid then finishProfileServerAdmin({ok: false, reason: "User changed. Reopen this profile."}) : return
    if m.top.operation = "generate" or m.top.operation = "revoke"
        if target.id = login.data.id then finishProfileServerAdmin({ok: false, reason: "The base login's API key cannot be changed here."}) : return
    end if
    if m.top.operation = "choices"
        choices = profileAdminList(base, "/api/channels/profiles/")
        if not choices.ok then finishProfileServerAdmin({ok: false, reason: "Could not load Channel Profiles."}) : return
        rows = choices.data
        if type(rows) = "roAssociativeArray" then rows = rows.results
        if type(rows) <> "roArray" then finishProfileServerAdmin(result) : return
        finishProfileServerAdmin({ok: true, target: target, choices: rows})
        return
    end if
    plan = userProfileServerAdminMutation(m.top.operation, target, actor.data, m.top.minted, m.top.channelIds, m.top.confirmed)
    if not plan.ok then finishProfileServerAdmin({ok: false, reason: "User access changed. No server change was made."}) : return
    response = profileAdminRequest(base + plan.path, plan.body, plan.method)
    if not response.ok then finishProfileServerAdmin({ok: false, reason: "Could not save server user access."}) : return
    if m.top.operation = "generate"
        key = ""
        if type(response.data) = "roAssociativeArray"
            key = textValue(response.data.key)
            if key = "" then key = textValue(response.data.api_key)
            if key = "" and type(response.data.user) = "roAssociativeArray" then key = textValue(response.data.user.api_key)
        end if
        if key = "" then finishProfileServerAdmin({ok: false, reason: "Could not enable API access."}) : return
        finishProfileServerAdmin({ok: true, id: target.id, username: target.username, key: key})
    else
        finishProfileServerAdmin({ok: true, id: target.id, username: target.username})
    end if
end sub

function profileAdminIdentity(user as dynamic, id as string, username as string) as boolean
    if type(user) <> "roAssociativeArray" then return false
    if userProfileUserId(user.id) = invalid or id = "" or username = "" then return false
    return textValue(user.id) = id and lcase(textValue(user.username)) = lcase(username)
end function

function profileAdminRequest(url as string, body = invalid as dynamic, method = "GET" as string) as object
    denied = {ok: false}
    if m.top.cancelRequested or not requestGateTaskSessionCurrent() then return denied
    response = httpTransferOnce(url, body, "", 10000, 1048576, method)
    if m.top.cancelRequested or not requestGateTaskSessionCurrent() then return denied
    if response.error <> "" or response.status < 200 or response.status >= 300 then return denied
    value = invalid
    if response.body <> ""
        if m.profileAdminJsonParser <> invalid
            value = m.profileAdminJsonParser(response.body)
        else
            value = ParseJson(response.body, "d")
        end if
        if value = invalid then return denied
    end if
    return {ok: true, data: value}
end function

function profileAdminList(base as string, path as string) as object
    url = base + path
    rows = []
    for page = 0 to 15
        response = profileAdminRequest(url)
        if not response.ok then return {ok: false}
        batch = response.data
        nextUrl = ""
        if type(batch) = "roAssociativeArray"
            nextUrl = textValue(batch.next)
            batch = batch.results
        end if
        if type(batch) <> "roArray" then return {ok: false}
        if rows.count() + batch.count() > 512 then return {ok: false}
        for each row in batch
            rows.push(row)
        end for
        if nextUrl = "" then return {ok: true, data: rows}
        if left(nextUrl, 1) = "/" then nextUrl = base + nextUrl
        ' Follow only this endpoint's query pagination, never another host/path.
        if left(nextUrl, len(base + path) + 1) <> base + path + "?" then return {ok: false}
        if nextUrl = url then return {ok: false}
        url = nextUrl
    end for
    return {ok: false}
end function

sub finishProfileServerAdmin(result as object)
    if m.top.cancelRequested or not requestGateTaskSessionCurrent() then result = {ok: false, reason: "Server action cancelled."}
    m.key = ""
    m.top.apiKey = ""
    m.top.baseKey = ""
    m.top.minted = invalid
    m.top.result = result
end sub
