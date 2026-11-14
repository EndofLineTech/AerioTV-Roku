' Pure provider-model helpers, shared by the network Task and the UI.
function dispatcharrVerifiedAuthority(user as object) as object
    result = {id: user.id, username: user.username, user_level: user.user_level, is_staff: user.is_staff, is_superuser: user.is_superuser, stream_limit: user.stream_limit}
    ids = []
    if type(user.channel_profiles) = "roArray"
        for each id in user.channel_profiles
            ids.push(id)
        end for
    end if
    result["channel_profiles"] = ids
    properties = {}
    if type(user.custom_properties) = "roAssociativeArray"
        for each field in ["dvr_access", "catchup_enabled", "vod_movies_enabled", "vod_series_enabled", "hide_adult_content"]
            if user.custom_properties.doesExist(field) then properties[field] = user.custom_properties[field]
        end for
    end if
    result["custom_properties"] = properties
    return result
end function

function dispatcharrAuthorizationSignature(user as dynamic) as string
    if type(user) <> "roAssociativeArray" then return ""
    ids = []
    if type(user.channel_profiles) = "roArray"
        for each id in user.channel_profiles
            ids.push(textValue(id))
        end for
    end if
    ids.sort()
    properties = user.custom_properties
    if type(properties) <> "roAssociativeArray" then properties = {}
    snapshot = {level: textValue(user.user_level), staff: user.is_staff = true, superuser: user.is_superuser = true, assignments: ids, streamLimit: textValue(user.stream_limit), dvr: textValue(properties.dvr_access), catchup: properties.catchup_enabled <> false, movies: properties.vod_movies_enabled <> false, series: properties.vod_series_enabled <> false, hideAdult: properties.hide_adult_content = true}
    return FormatJson(snapshot)
end function

function textValue(value as dynamic) as string
    if value = invalid then return ""
    if GetInterface(value, "ifString") <> invalid then return value.trim()
    if GetInterface(value, "ifInt") <> invalid then return value.toStr()
    if GetInterface(value, "ifFloat") <> invalid then return value.toStr().trim()
    return ""
end function

' Remote channel artwork is volatile and distinct from authenticated proxy IDs.
' Never insert provider credentials or accept local-file/credentialed URLs.
function channelLogoUrl(value as dynamic) as string
    if type(value) <> "String" and type(value) <> "roString" then return ""
    value = value.trim()
    if len(value) > 4096 then return ""
    if not CreateObject("roRegex", "^https?://[^/?#@\s\\]+([/?][^#\s\\]*)?$", "i").isMatch(value) then return ""
    if CreateObject("roRegex", "[\x00-\x20\x7f]", "").isMatch(value) then return ""
    return value
end function

function channelLogoCacheKeyValid(id as string) as boolean
    return CreateObject("roRegex", "^([1-9][0-9]{0,9}|remote-[A-Za-z0-9-]{1,96})$", "").isMatch(id)
end function

function channelLogoCacheId(channel as object) as string
    id = textValue(channel.logoId)
    if CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(id) then return id
    if channelLogoUrl(channel.logoUrl) = "" then return ""
    uuid = textValue(channel.uuid)
    if not CreateObject("roRegex", "^[A-Za-z0-9-]{1,96}$", "").isMatch(uuid) then return ""
    return "remote-" + uuid
end function

function channelLogoRemoteUrls(channels as object) as object
    urls = {}
    for each channel in channels
        id = channelLogoCacheId(channel)
        if left(id, 7) = "remote-" then urls[id] = channelLogoUrl(channel.logoUrl)
    end for
    return urls
end function

function channelLogoBatchUrls(ids as object, urls as object) as object
    result = {}
    for each id in ids
        if urls.doesExist(id) then result[id] = urls[id]
    end for
    return result
end function

function channelLogoRequest(id as string, urls as dynamic, base as string, key as string, mode as string, userAgent as string) as dynamic
    if not channelLogoCacheKeyValid(id) then return invalid
    if left(id, 7) = "remote-"
        if type(urls) <> "roAssociativeArray" then return invalid
        url = channelLogoUrl(urls[id])
        if url = "" then return invalid
        ' Includes redirects: this transfer has no provider auth/Referer/agent.
        headers = dispatcharrRequestHeaders("", "x-api-key", "")
        headers["Referer"] = "" ' Suppress Roku's automatic redirect referrer.
        return {url: url, headers: headers}
    end if
    base = normalizeBaseUrl(base)
    if base = "" then return invalid
    return {url: base + "/api/channels/logos/" + id + "/cache/", headers: dispatcharrRequestHeaders(key, mode, userAgent)}
end function

' Provider names sometimes include the channel number as a separate heading.
' Only accept an exact delimited prefix, not names such as 24Kitchen or 2400.
function channelHeading(number as string, name as string) as string
    number = number.trim()
    name = name.trim()
    if number = "" then return name
    if name = "" then return number
    if left(name, len(number)) = number
        suffix = mid(name, len(number) + 1)
        if suffix = "" or left(suffix, 1) = "|" or left(suffix, 1) = ":" then return name
        if left(suffix, 2) = " |" or left(suffix, 2) = " :" or left(suffix, 2) = " -" then return name
    end if
    return number + "  " + name
end function

function normalizeBaseUrl(value as string) as string
    value = value.trim()
    pattern = CreateObject("roRegex", "^https?://[^/?#@\s]+(/[^?#\s]*)?$", "i")
    if not pattern.isMatch(value) then return ""
    while right(value, 1) = "/"
        value = left(value, len(value) - 1)
    end while
    return value
end function

function urlOrigin(value as string) as string
    pattern = CreateObject("roRegex", "^(https?://[^/?#]+)", "i")
    match = pattern.match(value)
    if match.count() < 2 then return ""
    return match[1]
end function

' Pagination must never send the API key to a different host or scheme.
function trustedPageUrl(base as string, nextPage as string) as string
    origin = urlOrigin(base)
    if origin = "" or nextPage = "" then return ""
    if left(nextPage, 2) = "//" then return ""
    if left(nextPage, 1) = "/" then return origin + nextPage
    if left(nextPage, len(origin) + 1) = origin + "/" then return nextPage
    return ""
end function

function apiRows(payload as dynamic) as dynamic
    if type(payload) = "roArray" then return payload
    if type(payload) <> "roAssociativeArray" then return invalid
    if type(payload.results) = "roArray" then return payload.results
    if type(payload.data) = "roArray" then return payload.data
    return invalid
end function

function normalizeChannel(raw as dynamic) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    uuid = textValue(raw.uuid)
    name = textValue(effectiveChannelValue(raw, "name"))
    id = textValue(raw.id)
    safeId = CreateObject("roRegex", "^[A-Za-z0-9-]+$", "")
    if not safeId.isMatch(uuid) or name = "" or id = "" then return invalid
    groupId = textValue(effectiveChannelValue(raw, "channel_group_id"))
    if groupId = "" then groupId = textValue(raw.channel_group)
    return {
        id: id, uuid: uuid, name: name, number: textValue(effectiveChannelValue(raw, "channel_number"))
        groupId: groupId, tvgId: textValue(effectiveChannelValue(raw, "tvg_id"))
        epgId: textValue(effectiveChannelValue(raw, "epg_data_id"))
        epgKey: "", logoId: textValue(effectiveChannelValue(raw, "logo_id"))
    }
end function

function serverGroupOrder(groups as object) as object
    ' 0.31 Guide getGroupOptions sorts provider names (no persisted rank field).
    ' Honor explicit ranks when supplied and keep stable name ties.
    result = []
    for i = 0 to groups.count() - 1
        g = groups[i]
        name = lcase(textValue(g.name))
        rank = textValue(g.order)
        if rank = "" then rank = textValue(g.position)
        key = "1|" + name
        if CreateObject("roRegex", "^[0-9]+$", "").isMatch(rank) then key = "0|" + right("0000000000" + rank, 10) + "|" + name
        result.push({id: textValue(g.id), name: textValue(g.name), sortKey: key + "|" + right("000000" + i.toStr(), 6)})
    end for
    result.sortBy("sortKey")
    return result
end function

function effectiveChannelValue(raw as object, field as string) as dynamic
    if raw.doesExist("effective_" + field) then return raw["effective_" + field]
    return raw[field]
end function

sub bindChannelGuide(channels as object, epgRows as object)
    bridge = {}
    for each row in epgRows
        if type(row) = "roAssociativeArray" then bridge[textValue(row.id)] = textValue(row.tvg_id)
    end for
    for each channel in channels
        channel.epgKey = channel.tvgId
        if channel.epgId <> ""
            ' An explicit assignment is authoritative. Don't attach a different
            ' station's guide when that assignment could not be resolved.
            channel.epgKey = ""
            if bridge.doesExist(channel.epgId) then channel.epgKey = bridge[channel.epgId]
        end if
    end for
end sub

function filterChannels(channels as object, filter as string, favorites as object) as object
    result = []
    for each channel in channels
        include = filter = "all"
        if filter = "favorites" then include = favorites.doesExist(channel.uuid)
        if left(filter, 6) = "group:" then include = channel.groupId = mid(filter, 7)
        if include then result.push(channel)
    end for
    return result
end function

' 0.31 accepts both API-key forms; Bearer is a short-lived JWT and is not
' interchangeable with a remembered Dispatcharr API key.
function dispatcharrHeaderMode(mode as string) as string
    if mode = "compatible" or mode = "authorization" then return mode
    return "x-api-key"
end function

function dispatcharrUserAgent(override as string) as string
    defaultAgent = "AerioTV-Roku/0.3.88"
    if override = "" or len(override) > 80 then return defaultAgent
    if not CreateObject("roRegex", "^[\x20-\x7E]{1,80}$", "").isMatch(override) then return defaultAgent
    return override
end function

function dispatcharrRequestHeaders(key as string, mode as string, userAgent as string) as object
    result = {"User-Agent": dispatcharrUserAgent(userAgent)}
    if key = "" then return result
    mode = dispatcharrHeaderMode(mode)
    if mode <> "authorization" then result["X-API-Key"] = key
    if mode = "compatible" or mode = "authorization" then result.Authorization = "ApiKey " + key
    return result
end function

function dispatcharrHeaderLines(key as string, mode as string, userAgent as string) as object
    fields = dispatcharrRequestHeaders(key, mode, userAgent)
    result = []
    if fields["X-API-Key"] <> invalid then result.push("X-API-Key: " + fields["X-API-Key"])
    if fields.Authorization <> invalid then result.push("Authorization: " + fields.Authorization)
    result.push("User-Agent: " + fields["User-Agent"])
    return result
end function

function dispatcharrConnectionError(message as string, mode as string) as string
    if dispatcharrHeaderMode(mode) <> "x-api-key" and instr(1, message, "HTTP 400") > 0
        return "Server rejected the selected API authorization header on this Roku. In Connection request settings, choose X-API-Key only and retry."
    end if
    return message
end function
