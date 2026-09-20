sub init()
    m.top.functionName = "loadVod"
end sub

sub loadVod()
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = m.top.apiKey
    m.timeout = 15000
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 30000
    m.maxResponseBytes = 1048576
    user = requestJson(m.base + "/api/accounts/users/me/")
    if type(user) <> "roAssociativeArray"
        publishVod({ok: false, category: "network", message: "Could not verify account. " + m.failure})
        return
    end if
    cap = normalizeCapabilities(user, invalid, invalid, CreateObject("roDateTime").asSeconds())
    props = user.custom_properties
    if type(props) <> "roAssociativeArray" then props = {}
    authorization = metadataCacheDigest(FormatJson({account: cap.accountId, level: cap.level, movies: cap.movies, series: cap.series, hideAdult: props.hide_adult_content}))
    if m.top.operation = "authorize" and cap.accountId <> "" and cap.accountId = m.top.accountId
        publishVod({ok: true, authorization: authorization, authorizedShelf: true, movies: cap.movies, series: cap.series})
        return
    end if
    permitted = cap.movies
    if m.top.kind <> "movie" then permitted = cap.series
    if cap.accountId <> m.top.accountId or permitted <> "allowed"
        publishVod({ok: false, message: "This account cannot access this catalog.", category: "permission"})
        return
    end if
    path = vodKindPath(m.top.kind)
    if path = "" or m.top.pageNumber < 1
        publishVod({ok: false, message: "Invalid catalog request."})
        return
    end if
    if m.top.operation = "categories" or m.top.operation = "providers"
        categoryType = "movie"
        if m.top.kind <> "movie" then categoryType = "series"
        path = "/api/vod/categories/?category_type=" + categoryType
        if m.top.operation = "providers"
            if cap.level < 10
                publishVod({ok: false, message: "Provider listing requires an authorized admin account."})
                return
            end if
            path = "/api/m3u/accounts/?is_active=true"
        end if
        payload = requestJson(m.base + path + "&page_size=20&page=" + m.top.pageNumber.toStr())
        result = vodCategoryPage(payload, m.top.pageNumber, m.base)
        if payload = invalid then result.message = m.failure
        publishVod(result)
        return
    end if
    url = m.base + "/api/vod/" + path + "/"
    if m.top.itemId <> ""
        if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(m.top.itemId)
            publishVod({ok: false, message: "Invalid title identifier."})
            return
        end if
        raw = requestJson(url + m.top.itemId + "/")
        item = vodNormalize(raw, m.top.kind)
        if item <> invalid
            if m.top.kind = "movie"
                info = requestJson(url + m.top.itemId + "/provider-info/")
                enhanced = vodNormalize(info, "movie")
                if enhanced <> invalid
                    if enhanced.uuid = item.uuid
                        enhanced.logoId = item.logoId
                        item = enhanced
                    end if
                end if
            else if m.top.kind = "series"
                requestJson(url + m.top.itemId + "/provider-info/?include_episodes=false")
            else if item.seriesId <> ""
                info = requestJson(m.base + "/api/vod/series/" + item.seriesId + "/provider-info/?include_episodes=true")
                if type(info) = "roAssociativeArray"
                    if type(info.episodes) = "roAssociativeArray"
                        for each season in info.episodes
                            if type(info.episodes[season]) = "roArray"
                                for each episode in info.episodes[season]
                                    if textValue(episode.id) = item.id
                                        item.streamFormat = vodStreamFormat(textValue(episode.container_extension))
                                        if type(info.m3u_account) = "roAssociativeArray" then item.providerId = textValue(info.m3u_account.id)
                                    end if
                                end for
                            end if
                        end for
                    end if
                end if
            end if
        end if
        if item = invalid
            publishVod({ok: false, message: "Title unavailable. " + m.failure})
        else
            item.authorization = authorization
            item.accountScope = m.base + "|" + cap.accountId
            publishVod({ok: true, item: item})
        end if
        return
    end if
    order = "name"
    for each allowed in ["name", "-name", "year", "-year", "-created_at"]
        if m.top.ordering = allowed then order = allowed
    end for
    if m.top.kind = "episode" then order = "season_number,episode_number"
    encoder = CreateObject("roUrlTransfer")
    url += "?page_size=20&page=" + m.top.pageNumber.toStr() + "&ordering=" + encoder.escape(order)
    searchKey = "search"
    if m.top.titleOnly then searchKey = "name"
    if m.top.query <> "" then url += "&" + searchKey + "=" + encoder.escape(left(m.top.query, 120))
    if m.top.category <> "" then url += "&category=" + encoder.escape(m.top.category)
    if CreateObject("roRegex", "^[0-9]+$", "").isMatch(m.top.providerId) then url += "&m3u_account=" + m.top.providerId
    if CreateObject("roRegex", "^[0-9]{4}$", "").isMatch(m.top.year) then url += "&year=" + m.top.year
    if m.top.seriesId <> ""
        if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(m.top.seriesId)
            publishVod({ok: false, message: "Invalid series identifier."})
            return
        end if
        url += "&series=" + m.top.seriesId
    end if
    scope = metadataCacheDigest(m.base + "|" + cap.accountId)
    generation = authorization
    cacheKey = mid(url, len(m.base) + 1)
    now = CreateObject("roDateTime").asSeconds()
    if not m.top.bypassCache
        cached = metadataCacheRead(scope, "vod", cacheKey, generation, now, true)
        if cached.state = "fresh"
            data = cached.payload
            nextPage = ""
            if data.hasNext then nextPage = "next"
            publishVod({ok: true, items: data.items, total: data.total, next: nextPage, source: "cache"})
            return
        end if
    end if
    data = requestJson(url)
    result = vodPage(data, m.top.kind, m.base)
    if type(m.httpFailure) = "roAssociativeArray" then result.status = m.httpFailure.status
    if result.ok
        for each item in result.items
            item.authorization = authorization
        end for
    end if
    if data = invalid then result.message = m.failure
    if result.ok then metadataCacheWrite(scope, "vod", cacheKey, generation, now, {items: result.items, total: result.total, hasNext: result.next <> ""})
    result.source = "network"
    publishVod(result)
end sub

sub publishVod(result as object)
    m.key = ""
    m.top.apiKey = ""
    if m.top.cancelRequested then return
    m.top.result = result
end sub
