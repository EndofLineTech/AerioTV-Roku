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
        publishXtreamFailure("Could not load Xtream live categories. " + m.failure, httpAccountRejected(m.httpFailure))
        return
    end if
    m.top.progress = "Loading Xtream live channels"
    rows = requestJson(xtreamApiUrl(m.base, username, password, "get_live_streams"))
    result = xtreamLiveLineup(rows, categories, m.base, username, password)
    rejected = httpAccountRejected(m.httpFailure)
    categories = invalid
    rows = invalid
    if not result.ok
        publishXtreamFailure(result.message, rejected)
        return
    end if
    m.top.progress = "Checking Xtream movie access"
    movieCategories = requestJson(xtreamApiUrl(m.base, username, password, "get_vod_categories"))
    if type(m.httpFailure) = "roAssociativeArray"
        if m.httpFailure.status = 401
            publishXtreamFailure("Xtream credentials rejected. Sign in again.", true)
            return
        end if
    end if
    movies = type(movieCategories) = "roArray"
    if movies then movies = xtreamVodCategories(movieCategories, 1).ok and movieCategories.count() > 0
    movieCategories = invalid
    m.top.progress = "Checking Xtream series access"
    seriesCategories = requestJson(xtreamApiUrl(m.base, username, password, "get_series_categories"))
    if type(m.httpFailure) = "roAssociativeArray"
        if m.httpFailure.status = 401
            publishXtreamFailure("Xtream credentials rejected. Sign in again.", true)
            return
        end if
    end if
    series = type(seriesCategories) = "roArray"
    if series then series = xtreamVodCategories(seriesCategories, 1).ok and seriesCategories.count() > 0
    seriesCategories = invalid
    guideUrl = xtreamGuideUrl(m.base, username, password)
    accountScope = metadataCacheDigest("xc|" + m.base + "|" + username + "|" + m.top.connectionId)
    generation = metadataCacheDigest(FormatJson(result.channels))
    m.top.username = ""
    m.top.password = ""
    if m.top.cancelRequested = true then return
    m.top.result = {ok: true, channels: result.channels, groups: result.groups, scope: accountScope, generation: generation, accountId: "xc-" + left(metadataCacheDigest(m.base + "|" + username), 24), timezone: account.timezone, movies: movies, series: series, guideUrl: guideUrl, apiKey: "", warning: ""}
end sub
