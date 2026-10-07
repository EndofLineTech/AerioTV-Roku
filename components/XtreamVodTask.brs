sub init()
    m.top.functionName = "loadXtreamVod"
end sub

sub publishXtreamVod(result as object)
    if type(result.item) = "roAssociativeArray"
        if result.item.accountScope = m.top.accountScope then result.item.authorization = m.scopeAuth
    end if
    if type(result.items) = "roArray"
        for each item in result.items
            if type(item) = "roAssociativeArray"
                if item.accountScope = m.top.accountScope then item.authorization = m.scopeAuth
            end if
        end for
    end if
    m.top.username = ""
    m.top.password = ""
    m.top.savedState = invalid
    m.top.history = invalid
    m.key = ""
    if m.top.cancelRequested <> true then m.top.result = result
end sub

sub loadXtreamVod()
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = ""
    m.scopeAuth = ""
    username = m.top.username
    password = m.top.password
    if m.base = "" or not xtreamCredentialsValid(username, password) or m.top.accountScope = ""
        publishXtreamVod({ok: false, message: "Sign in to Xtream again to browse this library."})
        return
    end if
    m.scopeAuth = metadataCacheDigest("xc-vod|" + m.top.accountScope)
    m.timeout = 15000
    m.maxResponseBytes = 4194304
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 30000
    if m.top.operation = "shelf"
        loadXtreamSavedShelf(username, password)
        return
    end if
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

sub loadXtreamSavedShelf(username as string, password as string)
    shelf = m.top.shelf
    state = vodState(m.top.savedState)
    entries = []
    if shelf = "recent"
        entries = vodHistory(m.top.history)
    else if shelf = "watchlist" or shelf = "favorite"
        entries = vodShelfEntries(state, shelf, {movies: "allowed", series: "allowed", authorization: m.scopeAuth})
    else
        publishXtreamVod({ok: false, message: "Unsupported saved library."})
        return
    end if
    m.timeout = 3000
    items = []
    partial = false
    for each entry in entries
        if m.top.cancelRequested then exit for
        if m.clock.totalMilliseconds() >= 27000
            partial = true
            exit for
        end if
        if not vodItemHidden(state, entry)
            kind = entry.kind
            id = entry.id
            action = "get_vod_info"
            if kind <> "movie"
                action = "get_series_info"
                if kind = "episode" then id = entry.seriesId
            end if
            url = xtreamVodApiUrl(m.base, username, password, action, id)
            if url <> ""
                m.httpFailure = invalid
                raw = requestJson(url)
                if raw = invalid
                    status = 0
                    if type(m.httpFailure) = "roAssociativeArray" then status = m.httpFailure.status
                    if status = 401
                        publishXtreamVod({ok: false, relogin: true, message: "Sign in to Xtream again to browse saved titles."})
                        return
                    end if
                    if status <> 404 and status <> 403 then partial = true
                else
                    item = invalid
                    if kind = "episode" then item = xtreamVodEpisode(raw, id, entry.id, m.top.accountScope) else item = xtreamVodDetail(raw, kind, id, m.top.accountScope)
                    if item <> invalid
                        if item.key = entry.key and item.id = entry.id and (kind <> "episode" or item.seriesId = entry.seriesId)
                            items.push(item)
                        end if
                    end if
                end if
            end if
        end if
    end for
    publishXtreamVod({ok: true, items: items, total: items.count(), next: "", patches: [], partial: partial})
end sub
