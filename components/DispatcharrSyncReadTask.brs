' Read-only own-user discovery. Not launched by the production UI until roster
' application and PIN/Child policy are ready. Never writes canonical or legacy.
sub init()
    m.top.functionName = "readDispatcharrSync"
end sub

sub readDispatcharrSync()
    m.key = m.top.apiKey
    base = normalizeBaseUrl(m.top.baseUrl)
    result = {ok: false, state: "invalid", key: "", allowWrite: false}
    if base = "" or m.key = "" then finishDispatcharrSyncRead(result) : return
    me = syncReadObject(base + "/api/accounts/users/me/", 65536)
    if not me.ok then finishDispatcharrSyncRead(me) : return
    user = me.data
    if not dispatcharrSyncInteger(user.id) then finishDispatcharrSyncRead(result) : return
    if user.id <= 0 or textValue(user.id) <> m.top.accountId then finishDispatcharrSyncRead(result) : return
    if type(user.username) <> "String" and type(user.username) <> "roString" then finishDispatcharrSyncRead(result) : return
    if user.username = "" or m.top.username = "" then finishDispatcharrSyncRead({ok: false, state: "waiting", allowWrite: false}) : return
    if lcase(user.username) <> lcase(m.top.username) then finishDispatcharrSyncRead(result) : return
    key = dispatcharrSyncUserKey(user.username)
    if key = "" then finishDispatcharrSyncRead({ok: false, state: "waiting", allowWrite: false}) : return
    listing = syncReadObject(base + "/api/accounts/users/me/app-data/", 65536)
    if not listing.ok then finishDispatcharrSyncRead(listing) : return
    plan = dispatcharrSyncReadPlan(key, listing.data)
    if plan.state <> "canonical"
        plan.ok = plan.state = "missing" or plan.state = "legacy"
        finishDispatcharrSyncRead(plan)
        return
    end if
    record = syncReadObject(base + "/api/accounts/users/me/app-data/" + key + "/", 131072)
    record.key = key
    if not record.ok then finishDispatcharrSyncRead(record) : return
    if record.state = "missing" then finishDispatcharrSyncRead(record) : return
    if not dispatcharrSyncInteger(record.data["schemaVersion"]) then finishDispatcharrSyncRead(result) : return
    if record.data["schemaVersion"] > 3
        finishDispatcharrSyncRead({ok: false, state: "newer", key: key, allowWrite: false})
        return
    end if
    if record.data["schemaVersion"] <> 3 or type(record.data["categories"]) <> "roAssociativeArray" then finishDispatcharrSyncRead(result) : return
    ' This is an envelope candidate, not roster acceptance. The strict schema
    ' reader must still validate envelope metadata, category timestamps and rows.
    record.state = "ready"
    finishDispatcharrSyncRead(record)
end sub

function syncReadObject(url as string, maxBytes as integer) as object
    result = {ok: false, state: "unavailable", allowWrite: false}
    if m.top.cancelRequested or not requestGateTaskSessionCurrent() then return result
    response = httpTransferOnce(url, invalid, "", 10000, maxBytes)
    if response.error <> "" then return result
    if m.top.cancelRequested or not requestGateTaskSessionCurrent() then return result
    value = invalid
    if CreateObject("roRegex", "^\s*\{", "").isMatch(response.body) then value = syncReadParse(response.body)
    if response.status = 404 and right(url, 9) <> "app-data/" and right(url, 10) <> "/users/me/"
        if type(value) = "roAssociativeArray"
            if type(value.code) = "String" or type(value.code) = "roString"
                if value.code = "key_not_found" then return {ok: true, state: "missing", allowWrite: false}
            end if
        end if
    end if
    if response.status <> 200 then return result
    if type(value) <> "roAssociativeArray" then return {ok: false, state: "invalid", allowWrite: false}
    return {ok: true, state: "object", data: value, allowWrite: false}
end function

function syncReadParse(text as string) as dynamic
    ' Host interpreter lacks ParseJson's native double-preserving option.
    if m.syncJsonParser <> invalid then return m.syncJsonParser(text)
    return ParseJson(text, "d")
end function

sub finishDispatcharrSyncRead(result as object)
    m.key = ""
    m.top.apiKey = ""
    result.allowWrite = false
    m.top.result = result
end sub
