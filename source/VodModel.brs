function vodKindPath(kind as string) as string
    if kind = "movie" then return "movies"
    if kind = "series" then return "series"
    if kind = "episode" then return "episodes"
    return ""
end function

function vodNormalize(raw as dynamic, kind as string) as dynamic
    if type(raw) <> "roAssociativeArray" or vodKindPath(kind) = "" then return invalid
    id = textValue(raw.id)
    uuid = textValue(raw.uuid)
    if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(id) then return invalid
    if not CreateObject("roRegex", "^[A-Za-z0-9-]+$", "").isMatch(uuid) then return invalid
    title = left(textValue(raw.name), 256)
    if title = "" then title = "Untitled"
    description = textValue(raw.description)
    if description = "" then description = textValue(raw.plot)
    logoId = ""
    if type(raw.logo) = "roAssociativeArray" then logoId = textValue(raw.logo.id)
    if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(logoId) then logoId = ""
    item = {id: id, uuid: uuid, kind: kind, key: kind + ":" + uuid, title: title, description: left(description, 2000), year: textValue(raw.year), rating: left(textValue(raw.rating), 20), genre: left(textValue(raw.genre), 160), duration: textValue(raw.duration_secs).toInt(), logoId: logoId, season: textValue(raw.season_number), episode: textValue(raw.episode_number), seriesId: ""}
    if item.duration < 0 then item.duration = 0
    item.streamFormat = vodStreamFormat(textValue(raw.container_extension))
    item.providerId = ""
    item.actors = left(textValue(raw.actors), 500)
    item.director = left(textValue(raw.director), 160)
    item.airDate = left(textValue(raw.air_date), 20)
    item.tmdbId = textValue(raw.tmdb_id)
    if not CreateObject("roRegex", "^[1-9][0-9]*$", "").isMatch(item.tmdbId) then item.tmdbId = ""
    item.trailerId = textValue(raw.youtube_trailer)
    if not CreateObject("roRegex", "^[A-Za-z0-9_-]{11}$", "").isMatch(item.trailerId) then item.trailerId = ""
    if type(raw.m3u_account) = "roAssociativeArray" then item.providerId = textValue(raw.m3u_account.id)
    if type(raw.series) = "roAssociativeArray" then item.seriesId = textValue(raw.series.id)
    item.seriesTmdbId = ""
    if type(raw.series) = "roAssociativeArray" then item.seriesTmdbId = textValue(raw.series.tmdb_id)
    item.seriesTitle = ""
    item.seriesLogoId = ""
    if type(raw.series) = "roAssociativeArray"
        item.seriesTitle = left(textValue(raw.series.name), 120)
        if type(raw.series.logo) = "roAssociativeArray" then item.seriesLogoId = textValue(raw.series.logo.id)
    end if
    if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(item.seriesLogoId) then item.seriesLogoId = ""
    if not CreateObject("roRegex", "^[1-9][0-9]*$", "").isMatch(item.seriesTmdbId) then item.seriesTmdbId = ""
    return item
end function

function vodArtworkUrl(base as string, item as object) as string
    base = normalizeBaseUrl(base)
    path = vodKindPath(item.kind)
    if base = "" or path = "" then return ""
    numeric = CreateObject("roRegex", "^[0-9]+$", "")
    if item.explicitProvider <> true and numeric.isMatch(textValue(item.logoId)) then return base + "/api/vod/vodlogos/" + item.logoId + "/cache/"
    if not numeric.isMatch(textValue(item.id)) then return ""
    uri = base + "/api/vod/" + path + "/" + item.id + "/image/?kind=movie_image"
    if item.explicitProvider = true and numeric.isMatch(textValue(item.providerId)) then uri += "&m3u_account_id=" + item.providerId
    return uri
end function

function vodExternalLinks(item as object) as object
    links = []
    numeric = CreateObject("roRegex", "^[0-9]+$", "")
    id = textValue(item.tmdbId)
    if (item.kind = "movie" or item.kind = "series") and numeric.isMatch(id)
        kind = "movie"
        if item.kind = "series" then kind = "tv"
        links.push("https://www.themoviedb.org/" + kind + "/" + id)
    else if item.kind = "episode"
        seriesId = textValue(item.seriesTmdbId)
        if numeric.isMatch(seriesId) and numeric.isMatch(textValue(item.season)) and numeric.isMatch(textValue(item.episode))
            links.push("https://www.themoviedb.org/tv/" + seriesId + "/season/" + item.season + "/episode/" + item.episode)
        end if
    end if
    trailer = textValue(item.trailerId)
    if CreateObject("roRegex", "^[A-Za-z0-9_-]{11}$", "").isMatch(trailer) then links.push("https://www.youtube.com/watch?v=" + trailer)
    return links
end function

function vodStreamFormat(extension as string) as string
    extension = lcase(extension)
    if extension = "mkv" then return "mkv"
    if extension = "mp4" or extension = "m4v" or extension = "mov" then return "mp4"
    if extension = "ts" or extension = "mpegts" then return "ts"
    return "unknown"
end function

function vodVersionPage(payload as dynamic, page as integer) as object
    result = {ok: false, items: [], total: 0, next: "", message: "Source versions unavailable."}
    rows = apiRows(payload)
    if rows = invalid then return result
    result.total = rows.count()
    offset = (page - 1) * 20
    for i = offset to rows.count() - 1
        if result.items.count() >= 20 then exit for
        row = rows[i]
        if type(row) <> "roAssociativeArray" then return result
        if type(row.m3u_account) <> "roAssociativeArray" then return result
        id = textValue(row.id)
        providerId = textValue(row.m3u_account.id)
        numeric = CreateObject("roRegex", "^[0-9]+$", "")
        if not numeric.isMatch(id) or not numeric.isMatch(providerId) then return result
        result.items.push({id: id, providerId: providerId, uuid: "version-" + id, key: "version:" + id, kind: "version", title: left(textValue(row.m3u_account.name), 120) + " — version " + id, year: "", rating: "", logoId: "", season: "", episode: ""})
    end for
    if rows.count() > offset + 20 then result.next = "next"
    result.ok = true
    result.message = ""
    return result
end function

function vodPage(payload as dynamic, kind as string, base as string, limit = 20 as integer) as object
    result = {ok: false, items: [], total: 0, next: "", message: "Unexpected catalog response."}
    if type(payload) <> "roAssociativeArray" then return result
    if type(payload.results) <> "roArray" then return result
    if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(textValue(payload.count)) then return result
    if payload.results.count() > limit then return result
    for each row in payload.results
        item = vodNormalize(row, kind)
        if item <> invalid then result.items.push(item)
    end for
    if result.items.count() <> payload.results.count() then return result
    nextPage = textValue(payload.next)
    if nextPage <> ""
        result.next = trustedPageUrl(base, nextPage)
        if result.next = "" then return result
    end if
    result.total = textValue(payload.count).toInt()
    result.ok = true
    result.message = ""
    return result
end function

function vodVisualTile(index as integer, focused as integer, total as integer, compact as boolean) as object
    row = index \ 5
    first = focused \ 5 - 1
    if first < 0 then first = 0
    lastFirst = (total + 4) \ 5 - 2
    if lastFirst < 0 then lastFirst = 0
    if first > lastFirst then first = lastFirst
    if compact then return {x: 96 + (index mod 5) * 348, y: 220 + row * 150, visible: index < total}
    return {x: 96 + (index mod 5) * 348, y: 210 + (row - first) * 380, visible: index < total and row >= first and row < first + 2}
end function

function vodEnabledProviders(rows as object) as object
    enabled = {}
    for each row in rows
        if type(row) = "roAssociativeArray"
            if row.is_active = true and row.enable_vod = true
                id = textValue(row.id)
                if CreateObject("roRegex", "^[0-9]+$", "").isMatch(id) then enabled[id] = true
            end if
        end if
    end for
    return enabled
end function

function vodEnabledCategories(rows as object, providers as object, categoryType as string, providerId = "" as string) as object
    visible = []
    for each row in rows
        if type(row) = "roAssociativeArray"
            if row.category_type = categoryType and type(row.m3u_accounts) = "roArray"
                for each relation in row.m3u_accounts
                    if type(relation) = "roAssociativeArray"
                        id = textValue(relation.m3u_account)
                        if relation.enabled = true and providers.doesExist(id) and (providerId = "" or providerId = id)
                            visible.push({id: row.id, name: row.name})
                            exit for
                        end if
                    end if
                end for
            end if
        end if
    end for
    return visible
end function

function vodCategoryPage(payload as dynamic, page as integer, base as string) as object
    result = {ok: false, items: [], total: 0, next: "", categories: true, message: "Categories unavailable; use title search."}
    rows = apiRows(payload)
    if rows = invalid then return result
    offset = 0
    result.total = rows.count()
    if type(payload) = "roAssociativeArray"
        if rows.count() > 20 then return result
        result.total = textValue(payload.count).toInt()
        if textValue(payload.next) <> ""
            result.next = trustedPageUrl(base, textValue(payload.next))
            if result.next = "" then return result
        end if
    else
        offset = (page - 1) * 20
        if rows.count() > offset + 20 then result.next = "next"
    end if
    for i = offset to rows.count() - 1
        if result.items.count() >= 20 then exit for
        raw = rows[i]
        if type(raw) <> "roAssociativeArray" then return result
        id = textValue(raw.id)
        if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(id) then return result
        result.items.push({id: id, uuid: "category-" + id, key: "category:" + id, kind: "category", title: left(textValue(raw.name), 200), value: textValue(raw.name), year: "", rating: "", logoId: "", season: "", episode: ""})
    end for
    result.ok = true
    result.message = ""
    return result
end function

function vodPlaybackUrl(base as string, item as object, sessionId as string) as string
    if item.kind <> "movie" and item.kind <> "episode" then return ""
    if not CreateObject("roRegex", "^[A-Za-z0-9-]+$", "").isMatch(item.uuid) then return ""
    if not CreateObject("roRegex", "^[A-Za-z0-9_-]+$", "").isMatch(sessionId) then return ""
    base = normalizeBaseUrl(base)
    if base = "" then return ""
    url = base + "/proxy/vod/" + item.kind + "/" + item.uuid + "/" + sessionId
    provider = textValue(item.providerId)
    if item.explicitProvider = true and CreateObject("roRegex", "^[0-9]+$", "").isMatch(provider) then url += "?m3u_account_id=" + provider
    return url
end function
