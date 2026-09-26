' Task-only, metadata-only episode hydration. An unfetched provider is not an
' empty series. Try at most three distinct providers under the Task deadline.
function vodHydrateEpisodes(seriesId as string, pageUrl as string, providerId as string) as object
    failure = {ok: false, category: "episode-loading", items: [], total: 0, next: "", message: "Episode catalog could not be loaded from the available sources. Refresh to retry."}
    if m.top.cancelRequested then return failure
    root = m.base + "/api/vod/series/" + seriesId
    tried = {}
    attempts = 0
    fetched = false
    if providerId = ""
        info = requestJson(root + "/provider-info/?include_episodes=false")
        attempts++
        if type(info) = "roAssociativeArray"
            fetched = info.episodes_fetched = true
            if type(info.m3u_account) = "roAssociativeArray" then tried[textValue(info.m3u_account.id)] = true
            if not m.top.cancelRequested
                page = vodPage(requestJson(pageUrl), "episode", m.base)
                if page.ok and page.items.count() > 0 then return page
            end if
        end if
    end if
    if m.top.cancelRequested then return failure
    oldLimit = m.maxResponseBytes
    m.maxResponseBytes = 8388608
    variants = apiRows(requestJson(root + "/providers/"))
    m.maxResponseBytes = oldLimit
    if variants <> invalid
        for each variant in variants
            if attempts >= 3 or m.top.cancelRequested then exit for
            if type(variant) = "roAssociativeArray"
                if type(variant.m3u_account) = "roAssociativeArray"
                    account = textValue(variant.m3u_account.id)
                    relation = textValue(variant.id)
                    numeric = CreateObject("roRegex", "^[0-9]+$", "")
                    selected = providerId = "" or providerId = account
                    if selected and numeric.isMatch(account) and numeric.isMatch(relation) and not tried.doesExist(account)
                        tried[account] = true
                        attempts++
                        info = requestJson(root + "/provider-info/?include_episodes=false&relation_id=" + relation)
                        if type(info) = "roAssociativeArray"
                            if info.episodes_fetched = true then fetched = true
                            if not m.top.cancelRequested
                                page = vodPage(requestJson(pageUrl), "episode", m.base)
                                if page.ok and page.items.count() > 0 then return page
                            end if
                        end if
                    end if
                end if
            end if
        end for
    end if
    if not m.top.cancelRequested and fetched
        page = vodPage(requestJson(pageUrl), "episode", m.base)
        if page.ok then return page
    end if
    failure.attempts = attempts
    failure.providerListAvailable = variants <> invalid
    return failure
end function

' Bounded, account-verified caller only. Incomplete catalogs are not mistaken
' for a final episode; at most four pages/80 normalized entries are retained.
function vodLoadSeriesEpisodes(seriesId as string, providerId as string) as object
    failure = {ok: false, complete: false, items: []}
    numeric = CreateObject("roRegex", "^[0-9]+$", "")
    if not numeric.isMatch(seriesId) or m.top.cancelRequested then return failure
    if providerId <> "" and not numeric.isMatch(providerId) then return failure
    items = []
    for page = 1 to 4
        if m.top.cancelRequested or m.clock.totalMilliseconds() > 27000 then return failure
        url = m.base + "/api/vod/episodes/?page_size=20&page=" + page.toStr() + "&ordering=season_number%2Cepisode_number&series=" + seriesId
        if providerId <> "" then url += "&m3u_account=" + providerId
        data = vodPage(requestJson(url), "episode", m.base)
        if page = 1 and data.ok and data.items.count() = 0 then data = vodHydrateEpisodes(seriesId, url, providerId)
        if not data.ok then return failure
        for each item in data.items
            if item.seriesId <> seriesId then return failure
            items.push(item)
        end for
        if data.next = "" then return {ok: true, complete: true, items: items}
    end for
    return {ok: true, complete: false, items: items}
end function
