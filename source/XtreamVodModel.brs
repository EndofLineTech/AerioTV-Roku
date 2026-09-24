' Xtream catalogs are unpaged on this provider. Never request all streams:
' select one category, bound the response in the Task, and page the normalized
' rows locally. URLs containing credentials exist only at request/playback time.
function xtreamVodApiUrl(base as string, username as string, password as string, action as string, id = "" as string) as string
    param = ""
    if action = "get_vod_streams" or action = "get_series"
        param = "category_id"
    else if action = "get_vod_info"
        param = "vod_id"
    else if action = "get_series_info"
        param = "series_id"
    else if action <> "get_vod_categories" and action <> "get_series_categories"
        return ""
    end if
    if param <> "" and not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(id) then return ""
    url = xtreamApiUrl(base, username, password, action)
    if url = "" then return ""
    if param <> "" then url += "&" + param + "=" + id
    return url
end function

function xtreamVodCategories(rows as dynamic, page as integer) as object
    result = {ok: false, items: [], total: 0, next: "", message: "Xtream categories unavailable."}
    if type(rows) <> "roArray" or rows.count() > 1600 or page < 1 then return result
    seen = {}
    for each row in rows
        if type(row) <> "roAssociativeArray" then return result
        id = textValue(row.category_id)
        if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(id) then return result
        if not seen.doesExist(id)
            if seen.count() >= (page - 1) * 20 and result.items.count() < 20
                result.items.push({id: id, uuid: "xc-category-" + id, key: "category:xc-" + id, kind: "category", title: left(textValue(row.category_name), 200), value: id, year: "", rating: "", logoId: "", season: "", episode: ""})
            end if
            seen[id] = true
        end if
    end for
    result.total = seen.count()
    if result.total > page * 20 then result.next = "next"
    result.ok = true
    result.message = ""
    return result
end function

function xtreamVodItem(row as dynamic, kind as string, scope as string) as dynamic
    if type(row) <> "roAssociativeArray" or (kind <> "movie" and kind <> "series" and kind <> "episode") then return invalid
    id = textValue(row.stream_id)
    if kind = "series" then id = textValue(row.series_id)
    if kind = "episode" then id = textValue(row.id)
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(id) then return invalid
    name = textValue(row.name)
    if kind = "episode" then name = textValue(row.title)
    info = row.info
    if type(info) <> "roAssociativeArray" then info = {}
    if name = "" then name = textValue(info.name)
    if name = "" then return invalid
    description = textValue(row.plot)
    if description = "" then description = textValue(info.plot)
    if description = "" then description = textValue(info.overview)
    year = textValue(row.year)
    if year = "" then year = textValue(row.releaseDate)
    if year = "" then year = textValue(row.release_date)
    if year = "" then year = textValue(info.releaseDate)
    if CreateObject("roRegex", "^[0-9]{4}", "").isMatch(year) then year = left(year, 4) else year = ""
    raw = {id: id, uuid: "xc-" + kind + "-" + id, name: name, plot: description, year: year, rating: textValue(row.rating), genre: textValue(row.genre), duration_secs: info.duration_secs, container_extension: row.container_extension, season_number: row.season, episode_number: row.episode_num}
    if kind = "episode"
        raw.series = {id: textValue(row.seriesId)}
        raw.season_number = row.season
    end if
    item = vodNormalize(raw, kind)
    if item = invalid then return invalid
    item.accountScope = scope
    item.authorization = scope
    return item
end function

function xtreamVodPage(rows as dynamic, kind as string, page as integer, query as string, category as string, scope as string) as object
    result = {ok: false, items: [], total: 0, next: "", message: "Xtream category unavailable or too large."}
    if type(rows) <> "roArray" or rows.count() > 600 or page < 1 or (kind <> "movie" and kind <> "series") then return result
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(category) then return result
    for each row in rows
        item = xtreamVodItem(row, kind, scope)
        if item = invalid then return result
        declared = textValue(row.category_id)
        if declared <> "" and declared <> category then return result
        if query = "" or instr(1, lcase(item.title), lcase(query)) > 0
            result.total++
            if result.total > (page - 1) * 20 and result.items.count() < 20 then result.items.push(item)
        end if
    end for
    if result.total > page * 20 then result.next = "next"
    result.ok = true
    result.message = ""
    return result
end function

function xtreamVodDetail(payload as dynamic, kind as string, id as string, scope as string) as dynamic
    if type(payload) <> "roAssociativeArray" then return invalid
    info = payload.info
    if type(info) <> "roAssociativeArray" then return invalid
    raw = payload.movie_data
    if kind = "series" then raw = info
    if type(raw) <> "roAssociativeArray" then return invalid
    if kind = "movie"
        raw = {stream_id: raw.stream_id, name: info.name, plot: info.plot, genre: info.genre, rating: info.rating, releaseDate: info.releaseDate, container_extension: raw.container_extension}
    else if kind = "series" and textValue(raw.series_id) = ""
        raw = {series_id: id, name: info.name, plot: info.plot, genre: info.genre, rating: info.rating, releaseDate: info.releaseDate}
    end if
    item = xtreamVodItem(raw, kind, scope)
    if item = invalid or item.id <> id then return invalid
    if textValue(info.plot) <> "" then item.description = left(textValue(info.plot), 2000)
    if textValue(info.genre) <> "" then item.genre = left(textValue(info.genre), 160)
    if textValue(info.duration_secs) <> "" then item.duration = textValue(info.duration_secs).toInt()
    if item.duration < 0 then item.duration = 0
    return item
end function

function xtreamVodEpisodes(payload as dynamic, seriesId as string, page as integer, scope as string) as object
    result = {ok: false, items: [], total: 0, next: "", message: "Xtream episodes unavailable or too large."}
    if type(payload) <> "roAssociativeArray" or type(payload.episodes) <> "roAssociativeArray" or page < 1 then return result
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(seriesId) then return result
    for each seasonKey in payload.episodes
        if not CreateObject("roRegex", "^(0|[1-9][0-9]{0,2})$", "").isMatch(seasonKey) then return result
        if seasonKey.toInt() > 100 then return result
    end for
    ' Numeric season order is stable regardless of associative-array key order.
    for season = 0 to 100
        list = payload.episodes[season.toStr()]
        if list <> invalid
            if type(list) <> "roArray" then return result
            for each raw in list
                if type(raw) <> "roAssociativeArray" then return result
                row = {id: raw.id, title: raw.title, info: raw.info, container_extension: raw.container_extension, episode_num: raw.episode_num, season: season.toStr(), seriesId: seriesId}
                item = xtreamVodItem(row, "episode", scope)
                if item = invalid then return result
                result.total++
                if result.total > 600 then return result
                if result.total > (page - 1) * 20 and result.items.count() < 20 then result.items.push(item)
            end for
        end if
    end for
    if result.total > page * 20 then result.next = "next"
    result.ok = true
    result.message = ""
    return result
end function

function xtreamVodEpisode(payload as dynamic, seriesId as string, episodeId as string, scope as string) as dynamic
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(episodeId) then return invalid
    for page = 1 to 31
        result = xtreamVodEpisodes(payload, seriesId, page, scope)
        if not result.ok then return invalid
        for each item in result.items
            if item.id = episodeId then return item
        end for
        if result.next = "" then exit for
    end for
    return invalid
end function

function xtreamVodStreamUrl(base as string, username as string, password as string, item as object) as string
    base = normalizeBaseUrl(base)
    if base = "" or not xtreamCredentialsValid(username, password) then return ""
    id = textValue(item.id)
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(id) then return ""
    kind = textValue(item.kind)
    if kind = "episode" then kind = "series"
    if kind <> "movie" and kind <> "series" then return ""
    format = textValue(item.streamFormat)
    if format <> "mp4" and format <> "mkv" and format <> "ts" then return ""
    return base + "/" + kind + "/" + xtreamEscape(username) + "/" + xtreamEscape(password) + "/" + id + "." + format
end function
