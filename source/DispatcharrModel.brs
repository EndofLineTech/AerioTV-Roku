' Pure provider-model helpers, shared by the network Task and the UI.
function textValue(value as dynamic) as string
    if value = invalid then return ""
    if GetInterface(value, "ifString") <> invalid then return value.trim()
    if GetInterface(value, "ifInt") <> invalid then return value.toStr()
    if GetInterface(value, "ifFloat") <> invalid then return value.toStr().trim()
    return ""
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
    pattern = CreateObject("roRegex", "^(https?://[^/]+)", "i")
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
