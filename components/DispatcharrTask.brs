sub init()
    m.top.functionName = "loadChannels"
end sub

sub loadChannels()
    m.progressLabel = "Verifying account"
    m.top.progress = m.progressLabel
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 115000
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = m.top.apiKey
    m.failure = ""
    if m.base = ""
        publishError("Enter a valid server URL.")
        return
    end if
    user = invalid
    if m.top.username <> ""
        m.key = ""
        m.top.progress = "Signing in to Dispatcharr"
        token = requestJson(m.base + "/api/accounts/token/", {username: m.top.username, password: m.top.password})
        m.top.password = ""
        if type(token) <> "roAssociativeArray"
            publishError("Could not sign in. " + m.failure)
            return
        end if
        if textValue(token.access) = ""
            publishError("Unexpected login response. Use your Dispatcharr dashboard credentials.")
            return
        end if
        m.top.progress = "Verifying account"
        user = requestJson(m.base + "/api/accounts/users/me/", invalid, token.access)
        token = invalid
        if type(user) = "roAssociativeArray" then m.key = textValue(user.api_key)
    else if m.key <> ""
        user = requestJson(m.base + "/api/accounts/users/me/")
    end if
    if type(user) <> "roAssociativeArray"
        publishError("Could not verify the Dispatcharr account. " + m.failure)
        return
    end if
    if textValue(user.id) = "" or m.key = ""
        publishError("The account needs an API key. Generate one under Dispatcharr > System > Users.")
        return
    end if

    ' 0.31 summary already applies visibility, permissions, profile union and
    ' effective overrides. Avoid duplicating different access rules on Roku.
    m.progressLabel = "Loading channels"
    rows = requestPages("/api/channels/channels/summary/?ordering=channel_number")
    if rows = invalid
        publishError("Could not load channels. " + m.failure)
        return
    end if
    channels = []
    seen = {}
    for each raw in rows
        channel = normalizeChannel(raw)
        if channel <> invalid
            if not seen.doesExist(channel.uuid)
                channels.push(channel)
                seen[channel.uuid] = true
            end if
        end if
    end for
    warning = ""
    m.progressLabel = "Loading guide mappings for " + channels.count().toStr() + " channels"
    epgRows = requestPages("/api/epg/epgdata/?page=1&page_size=500")
    if epgRows = invalid
        epgRows = []
        warning = "Guide channel mappings unavailable. Reconnect to retry."
    end if
    bindChannelGuide(channels, epgRows)
    epgRows = invalid
    groups = []
    usedGroups = {}
    for each channel in channels
        usedGroups[channel.groupId] = true
    end for
    m.progressLabel = "Loading channel groups"
    groupRows = requestPages("/api/channels/groups/?page=1&page_size=200")
    if groupRows <> invalid
        for each row in groupRows
            if type(row) = "roAssociativeArray"
                if usedGroups.doesExist(textValue(row.id)) and textValue(row.name) <> ""
                    groups.push({id: textValue(row.id), name: textValue(row.name), order: row.order, position: row.position})
                end if
            end if
        end for
    else
        warning = warning + " Groups unavailable; All Channels remains accessible."
    end if
    if m.top.cancelRequested = true
        m.key = ""
        m.top.apiKey = ""
        m.top.password = ""
        return
    end if
    m.top.result = {ok: true, channels: channels, groups: serverGroupOrder(groups), warning: warning, apiKey: m.key, accountId: textValue(user.id)}
    m.key = ""
    m.top.apiKey = ""
end sub

sub publishError(message as string)
    m.key = ""
    m.top.apiKey = ""
    m.top.password = ""
    if m.top.cancelRequested = true then return
    m.top.result = {ok: false, message: message}
end sub
