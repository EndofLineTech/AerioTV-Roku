sub init()
    m.top.functionName = "loadXtreamVod"
end sub

sub publishXtreamVod(result as object)
    m.top.username = ""
    m.top.password = ""
    m.key = ""
    if m.top.cancelRequested <> true then m.top.result = result
end sub

sub loadXtreamVod()
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = ""
    username = m.top.username
    password = m.top.password
    if m.base = "" or not xtreamCredentialsValid(username, password) or m.top.accountScope = ""
        publishXtreamVod({ok: false, message: "Sign in to Xtream again to browse this library."})
        return
    end if
    m.timeout = 15000
    m.maxResponseBytes = 4194304
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 30000
    action = ""
    id = ""
    if m.top.kind <> "movie" and m.top.kind <> "series" and m.top.kind <> "episode"
        publishXtreamVod({ok: false, message: "Unsupported Xtream library kind."})
        return
    end if
    if m.top.operation = "categories"
        action = "get_vod_categories"
        if m.top.kind <> "movie" then action = "get_series_categories"
    else if m.top.itemId <> ""
        action = "get_vod_info"
        id = m.top.itemId
        if m.top.kind <> "movie"
            action = "get_series_info"
            if m.top.kind = "episode" then id = m.top.seriesId
        end if
    else if m.top.kind = "episode"
        action = "get_series_info"
        id = m.top.seriesId
    else
        action = "get_vod_streams"
        if m.top.kind = "series" then action = "get_series"
        id = m.top.category
    end if
    url = xtreamVodApiUrl(m.base, username, password, action, id)
    if url = "" or m.top.pageNumber < 1
        publishXtreamVod({ok: false, message: "Choose a valid Xtream category or title first."})
        return
    end if
    data = requestJson(url)
    if data = invalid
        rejected = false
        if type(m.httpFailure) = "roAssociativeArray" then rejected = m.httpFailure.status = 401
        publishXtreamVod({ok: false, relogin: rejected, message: "Could not load Xtream library. " + m.failure})
        return
    end if
    if m.top.operation = "categories"
        result = xtreamVodCategories(data, m.top.pageNumber)
    else if m.top.itemId <> ""
        item = invalid
        if m.top.kind = "episode" then item = xtreamVodEpisode(data, id, m.top.itemId, m.top.accountScope) else item = xtreamVodDetail(data, m.top.kind, id, m.top.accountScope)
        result = {ok: false, message: "This title is no longer available to this account."}
        if item <> invalid then result = {ok: true, item: item}
    else if m.top.kind = "episode"
        result = xtreamVodEpisodes(data, id, m.top.pageNumber, m.top.accountScope)
    else
        result = xtreamVodPage(data, m.top.kind, m.top.pageNumber, m.top.query, id, m.top.accountScope)
    end if
    data = invalid
    publishXtreamVod(result)
end sub
