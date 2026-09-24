' Xtream Codes live contract. Authentication payload passwords never cross the
' Task boundary; generated media/guide URLs are volatile session data only.
function xtreamAccount(payload as dynamic) as object
    failed = {ok: false, message: "Xtream account was not authorized."}
    if type(payload) <> "roAssociativeArray" then return failed
    info = payload.user_info
    if type(info) <> "roAssociativeArray" then return failed
    if textValue(info.auth) <> "1" or lcase(textValue(info.status)) <> "active" then return failed
    permitted = false
    if type(info.allowed_output_formats) = "roArray"
        for each format in info.allowed_output_formats
            if format = "ts" then permitted = true
        end for
    end if
    if not permitted then return {ok: false, message: "This Xtream account has no MPEG-TS live output."}
    zone = ""
    if type(payload.server_info) = "roAssociativeArray" then zone = left(textValue(payload.server_info.timezone), 64)
    return {ok: true, timezone: zone, format: "ts"}
end function

function xtreamCredentialsValid(username as string, password as string) as boolean
    if username = "" or password = "" or len(username) > 64 or len(password) > 64 then return false
    safe = CreateObject("roRegex", "^[\x21-\x7E]{1,64}$", "")
    return safe.isMatch(username) and safe.isMatch(password)
end function

function xtreamEscape(value as string) as string
    safe = CreateObject("roRegex", "^[A-Za-z0-9_.~-]$", "")
    digits = "0123456789ABCDEF"
    result = ""
    for i = 1 to len(value)
        byte = asc(mid(value, i, 1))
        if safe.isMatch(mid(value, i, 1))
            result += mid(value, i, 1)
        else
            result += "%" + mid(digits, (byte \ 16) + 1, 1) + mid(digits, (byte mod 16) + 1, 1)
        end if
    end for
    return result
end function

function xtreamApiUrl(base as string, username as string, password as string, action = "" as string) as string
    base = normalizeBaseUrl(base)
    if base = "" or not xtreamCredentialsValid(username, password) then return ""
    url = base + "/player_api.php?username=" + xtreamEscape(username) + "&password=" + xtreamEscape(password)
    if action <> "" then url += "&action=" + xtreamEscape(action)
    return url
end function

function xtreamGuideUrl(base as string, username as string, password as string) as string
    base = normalizeBaseUrl(base)
    if base = "" or not xtreamCredentialsValid(username, password) then return ""
    return base + "/xmltv.php?username=" + xtreamEscape(username) + "&password=" + xtreamEscape(password)
end function

function xtreamLiveUrl(base as string, username as string, password as string, streamId as string) as string
    base = normalizeBaseUrl(base)
    if base = "" or not xtreamCredentialsValid(username, password) then return ""
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(streamId) then return ""
    return base + "/live/" + xtreamEscape(username) + "/" + xtreamEscape(password) + "/" + streamId + ".ts"
end function

function xtreamLiveLineup(rows as dynamic, categories as dynamic, base as string, username as string, password as string) as object
    failure = {ok: false, message: "Xtream live channels are unavailable or invalid."}
    base = normalizeBaseUrl(base)
    if base = "" or not xtreamCredentialsValid(username, password) or type(rows) <> "roArray" then return failure
    if rows.count() > 5000 then return failure
    groups = []
    groupNames = {}
    safeId = CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "")
    if type(categories) = "roArray"
        for each category in categories
            if type(category) = "roAssociativeArray"
                id = textValue(category.category_id)
                name = left(textValue(category.category_name), 80)
                if safeId.isMatch(id) and name <> "" and not groupNames.doesExist(id)
                    groups.push({id: "xc:" + id, name: name})
                    groupNames[id] = true
                end if
            end if
        end for
    end if
    channels = []
    seen = {}
    for each row in rows
        if type(row) <> "roAssociativeArray" then return failure
        id = textValue(row.stream_id)
        name = textValue(row.name)
        if not safeId.isMatch(id) or name = "" then return failure
        if not seen.doesExist(id)
            categoryId = textValue(row.category_id)
            groupId = ""
            if groupNames.doesExist(categoryId) then groupId = "xc:" + categoryId
            number = textValue(row.num)
            if number = "" then number = (channels.count() + 1).toStr()
            uuid = "xc-" + id
            channels.push({id: uuid, uuid: uuid, name: left(name, 120), number: left(number, 12), groupId: groupId, tvgId: left(textValue(row.epg_channel_id), 128), epgId: "", epgKey: left(textValue(row.epg_channel_id), 128), logoId: "", streamId: id})
            seen[id] = true
        end if
    end for
    if channels.count() = 0 then return failure
    return {ok: true, channels: channels, groups: serverGroupOrder(groups)}
end function
