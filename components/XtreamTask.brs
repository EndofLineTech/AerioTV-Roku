sub init()
    m.top.functionName = "loadXtream"
end sub

sub publishXtreamFailure(message as string, relogin = false as boolean)
    m.key = ""
    m.top.username = ""
    m.top.password = ""
    if m.top.cancelRequested <> true then m.top.result = {ok: false, message: message, relogin: relogin}
end sub

sub loadXtream()
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = ""
    username = m.top.username
    password = m.top.password
    if m.base = "" or m.top.connectionId = "" or not xtreamCredentialsValid(username, password)
        publishXtreamFailure("Enter the server URL and session-only Xtream credentials.")
        return
    end if
    m.timeout = 15000
    m.maxResponseBytes = 4194304
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 65000
    m.top.progress = "Verifying Xtream account"
    payload = requestJson(xtreamApiUrl(m.base, username, password))
    rejected = httpAccountRejected(m.httpFailure)
    hasIdentityResponse = payload <> invalid
    account = xtreamAccount(payload)
    payload = invalid ' Server response includes the password; never publish it.
    if not account.ok
        publishXtreamFailure(account.message, rejected or hasIdentityResponse)
        return
    end if
    m.top.progress = "Loading Xtream live categories"
    categories = requestJson(xtreamApiUrl(m.base, username, password, "get_live_categories"))
    if type(categories) <> "roArray"
        publishXtreamFailure("Could not load Xtream live categories. " + m.failure)
        return
    end if
    m.top.progress = "Loading Xtream live channels"
    rows = requestJson(xtreamApiUrl(m.base, username, password, "get_live_streams"))
    result = xtreamLiveLineup(rows, categories, m.base, username, password)
    categories = invalid
    rows = invalid
    if not result.ok
        publishXtreamFailure(result.message)
        return
    end if
    guideUrl = xtreamGuideUrl(m.base, username, password)
    accountScope = metadataCacheDigest("xc|" + m.base + "|" + username + "|" + m.top.connectionId)
    generation = metadataCacheDigest(FormatJson(result.channels))
    m.top.username = ""
    m.top.password = ""
    if m.top.cancelRequested = true then return
    m.top.result = {ok: true, channels: result.channels, groups: result.groups, scope: accountScope, generation: generation, accountId: "xc-" + left(metadataCacheDigest(m.base + "|" + username), 24), guideUrl: guideUrl, apiKey: "", warning: ""}
end sub
