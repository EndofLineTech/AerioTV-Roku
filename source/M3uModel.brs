' Small URL-based live playlists. Raw feed and stream URLs stay in Task/Scene
' memory for this session and are never written to registry or metadata cache.
function m3uAttribute(line as string, name as string) as string
    quote = chr(34)
    parts = CreateObject("roRegex", "(^|\s)" + name + "=" + quote + "([^" + quote + "]{0,256})" + quote, "").match(line)
    if parts.count() <> 3 then return ""
    return parts[2]
end function

function m3uDisplayName(line as string) as string
    quoted = false
    for i = 1 to len(line)
        character = mid(line, i, 1)
        if character = chr(34) then quoted = not quoted
        if character = "," and not quoted then return mid(line, i + 1).trim()
    end for
    return ""
end function

function m3uStreamUrl(url as string) as string
    url = url.trim()
    if len(url) > 2048 or url = "" then return ""
    if CreateObject("roRegex", "[\x00-\x20]", "").isMatch(url) then return ""
    if not CreateObject("roRegex", "^https?://[^/?#@]+(/[^#]*)?$", "i").isMatch(url) then return ""
    return url
end function

function m3uChannelId(url as string) as string
    parts = CreateObject("roRegex", "/proxy/ts/stream/([A-Za-z0-9-]{16,64})([?]|$)", "").match(url)
    if parts.count() > 1 then return parts[1]
    ' Stable fallback for other HTTP playlists without persisting their URLs.
    first = 7
    second = 11
    for i = 1 to len(url)
        byte = asc(mid(url, i, 1))
        first = (first * 17 + byte) mod 125000003
        second = (second * 3 + byte) mod 700000001
    end for
    return "m3u-" + first.toStr() + "-" + second.toStr()
end function

function m3uParsePlaylist(body as string) as object
    failure = {ok: false, message: "Invalid or oversized M3U playlist."}
    if len(body) > 2097152 or left(body.trim(), 7) <> "#EXTM3U" then return failure
    channels = []
    groups = []
    seenChannels = {}
    seenGroups = {}
    pending = ""
    for each raw in CreateObject("roRegex", "\r?\n", "").split(body)
        line = raw.trim()
        if len(line) > 4096 then return failure
        if left(line, 8) = "#EXTINF:"
            pending = line
        else if line <> "" and left(line, 1) <> "#" and pending <> ""
            url = m3uStreamUrl(line)
            if url = "" then return failure
            name = m3uDisplayName(pending)
            if name = "" then name = m3uAttribute(pending, "tvg-name")
            if name = "" then return failure
            id = m3uChannelId(url)
            if not seenChannels.doesExist(id)
                if channels.count() >= 5000 then return failure
                group = left(m3uAttribute(pending, "group-title"), 80)
                groupId = ""
                if group <> ""
                    groupId = "m3u:" + group
                    if not seenGroups.doesExist(groupId)
                        groups.push({id: groupId, name: group})
                        seenGroups[groupId] = true
                    end if
                end if
                number = m3uAttribute(pending, "tvg-chno")
                if number = "" then number = (channels.count() + 1).toStr()
                channels.push({id: id, uuid: id, name: left(name, 120), number: left(number, 12), groupId: groupId, tvgId: left(m3uAttribute(pending, "tvg-id"), 128), epgId: "", epgKey: left(m3uAttribute(pending, "tvg-id"), 128), logoId: "", streamUrl: url})
                seenChannels[id] = true
            end if
            pending = ""
        end if
    end for
    if channels.count() = 0 then return failure
    return {ok: true, channels: channels, groups: serverGroupOrder(groups)}
end function
