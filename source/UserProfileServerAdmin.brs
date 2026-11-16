' Live /me proofs only. Local roster roles never confer server authority.
function userProfileServerAdminAllowed(base as dynamic, actor as dynamic, role as string) as boolean
    if role <> "admin" and role <> "user" then return false
    for each user in [base, actor]
        if type(user) <> "roAssociativeArray" then return false
        if userProfileUserId(user.id) = invalid or textValue(user.username) = "" then return false
        level = userProfileVerifiedLevel(user)
        if level = invalid then return false
        if level < 10 then return false
    end for
    return true
end function

function userProfileServerAdminCandidates(users as object, local as object, suggestions as object) as object
    excluded = {}
    for each rows in [local, suggestions]
        for each row in rows
            excluded[lcase(textValue(row.username))] = true
        end for
    end for
    result = []
    for each user in users
        if type(user) = "roAssociativeArray"
            name = lcase(textValue(user.username))
            if userProfileUserId(user.id) <> invalid and name <> "" and not excluded.doesExist(name)
                result.push(user)
                excluded[name] = true
            end if
        end if
    end for
    return result
end function

' Transport must independently verify both admins and reload this exact target.
' Minted proof is memory-only and belongs to the current UI/session lifecycle.
function userProfileServerAdminMutation(operation as string, target as object, actor as object, minted as dynamic, ids as dynamic, confirmed as boolean) as object
    denied = {ok: false}
    id = userProfileUserId(target.id)
    if id = invalid or textValue(target.username) = "" then return denied
    if operation = "channels"
        if not confirmed or type(ids) <> "roArray" then return denied
        cleaned = []
        for each value in ids
            if not userProfileInteger(value) then return denied
            if value <= 0 then return denied
            if cleaned.count() >= 256 then return denied
            found = false
            for each existing in cleaned
                if existing = value then found = true
            end for
            if not found then cleaned.push(value)
        end for
        return {ok: true, method: "PATCH", path: "/api/accounts/users/" + id.toStr() + "/", body: {channel_profiles: cleaned}}
    end if
    if id = actor.id or lcase(target.username) = lcase(textValue(actor.username)) then return denied
    ' Omission is not proof of a missing key (e.g. a restricted serializer).
    if not target.doesExist("api_key") then return denied
    if target.api_key <> invalid
        if type(target.api_key) <> "String" and type(target.api_key) <> "roString" then return denied
    end if
    if operation = "generate"
        if textValue(target.api_key) <> "" then return denied
    else if operation = "revoke"
        if not confirmed or type(minted) <> "roAssociativeArray" then return denied
        if minted.id <> id or lcase(textValue(minted.username)) <> lcase(target.username) then return denied
        if textValue(minted.key) = "" or minted.key <> textValue(target.api_key) then return denied
    else
        return denied
    end if
    return {ok: true, method: "POST", path: "/api/accounts/api-keys/" + operation + "/", body: {user_id: id}}
end function
