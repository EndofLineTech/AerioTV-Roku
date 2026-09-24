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
    m.requestMode = dispatcharrHeaderMode(textValue(m.top.authMode))
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
        if type(user) <> "roAssociativeArray" and m.requestMode <> "x-api-key"
            if type(m.httpFailure) = "roAssociativeArray"
                if m.httpFailure.status = 400
                    m.requestMode = "x-api-key"
                    user = requestJson(m.base + "/api/accounts/users/me/")
                end if
            end if
        end if
    end if
    if type(user) <> "roAssociativeArray"
        publishError("Could not verify the Dispatcharr account. " + m.failure, httpAccountRejected(m.httpFailure))
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
    if m.top.profileId <> ""
        m.progressLabel = "Checking permitted channel profile"
        profiles = requestPages("/api/channels/profiles/?page=1&page_size=200")
        narrowed = profileRestrictedLineup(rows, profiles, m.top.profileId)
        profiles = invalid
        if not narrowed.ok
            publishError(narrowed.message)
            return
        end if
        rows = narrowed.channels
    end if
    scope = metadataCacheDigest(m.base + "|" + textValue(user.id) + "|profile:" + m.top.profileId)
    generation = metadataCacheDigest(FormatJson(rows))
    cached = metadataCacheRead(scope, "channels", "summary", generation, CreateObject("roDateTime").asSeconds(), true)
    channels = []
    if cached.state = "fresh" then channels = cached.payload
    seen = {}
    for each raw in rows
        if cached.state = "fresh" then exit for
        channel = normalizeChannel(raw)
        if channel <> invalid
            if not seen.doesExist(channel.uuid)
                channels.push(channel)
                seen[channel.uuid] = true
            end if
        end if
    end for
    if cached.state <> "fresh" then metadataCacheWrite(scope, "channels", "summary", generation, CreateObject("roDateTime").asSeconds(), channels)
    rows = invalid
    warning = ""
    ' EPG mappings hydrate separately after the authorized lineup becomes usable.
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
    m.top.result = {ok: true, channels: channels, groups: serverGroupOrder(groups), warning: warning, apiKey: m.key, accountId: textValue(user.id), profileId: m.top.profileId, authModeUsed: m.requestMode, scope: scope, generation: generation}
    m.key = ""
    m.top.apiKey = ""
end sub

sub publishError(message as string, relogin = false as boolean)
    m.key = ""
    m.top.apiKey = ""
    m.top.password = ""
    if m.top.cancelRequested = true then return
    m.top.result = {ok: false, message: message, relogin: relogin}
end sub
