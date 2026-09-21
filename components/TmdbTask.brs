sub init()
    m.top.functionName = "loadTmdb"
end sub

sub loadTmdb()
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = m.top.apiKey
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 30000
    m.timeout = 5000
    m.maxResponseBytes = 1048576
    if m.encoder = invalid then m.encoder = CreateObject("roUrlTransfer")
    item = m.top.item
    if type(item) <> "roAssociativeArray" then publishTmdb({ok: false}) : return
    failure = {ok: false, key: item.key, message: "Optional TMDB metadata unavailable; provider information remains usable."}
    if not m.top.enabled or not CreateObject("roRegex", "^[A-Fa-f0-9]{32}$", "").isMatch(m.top.tmdbKey)
        publishTmdb(failure)
        return
    end if
    user = requestJson(m.base + "/api/accounts/users/me/")
    cap = normalizeCapabilities(user, invalid, invalid, CreateObject("roDateTime").asSeconds())
    permitted = cap.movies
    if item.kind <> "movie" then permitted = cap.series
    if cap.accountId <> m.top.accountId or permitted <> "allowed"
        publishTmdb(failure)
        return
    end if
    props = user.custom_properties
    if type(props) <> "roAssociativeArray" then props = {}
    m.authorization = metadataCacheDigest(FormatJson({account: cap.accountId, level: cap.level, movies: cap.movies, series: cap.series, hideAdult: props.hide_adult_content}))
    if m.authorization <> textValue(item.authorization)
        publishTmdb(failure)
        return
    end if
    if vodKindPath(item.kind) = "" or not CreateObject("roRegex", "^[0-9]+$", "").isMatch(textValue(item.id))
        publishTmdb(failure)
        return
    end if
    fresh = vodNormalize(requestJson(m.base + "/api/vod/" + vodKindPath(item.kind) + "/" + item.id + "/"), item.kind)
    if fresh = invalid then publishTmdb(failure) : return
    if fresh.key <> item.key then publishTmdb(failure) : return
    if fresh.tmdbId = "" then fresh.tmdbId = textValue(item.tmdbId)
    if item.kind = "episode" and fresh.seriesTmdbId = "" and fresh.seriesId <> ""
        series = vodNormalize(requestJson(m.base + "/api/vod/series/" + fresh.seriesId + "/"), "series")
        if series <> invalid then fresh.seriesTmdbId = series.tmdbId
    end if
    m.cap = cap
    m.hideAdult = props.hide_adult_content = true and cap.level < 10
    scope = metadataCacheDigest(m.base + "|" + cap.accountId)
    generation = m.authorization + "|tmdb-en-v2|" + metadataCacheDigest(FormatJson({id: fresh.tmdbId, title: fresh.title, year: fresh.year, series: fresh.seriesTmdbId, season: fresh.season, episode: fresh.episode}))
    now = CreateObject("roDateTime").asSeconds()
    key = "tmdb:" + item.key
    cached = metadataCacheRead(scope, "vod", key, generation, now, true)
    metadata = invalid
    if cached.state = "fresh" then metadata = cached.payload
    if metadata = invalid
        path = tmdbItemPath(fresh)
        if path = "" then publishTmdb(failure) : return
        metadata = tmdbMetadata(tmdbGet(path + "?append_to_response=credits,videos&language=en-US"), item.kind)
        if metadata = invalid then publishTmdb(failure) : return
        if m.hideAdult and metadata.adult then publishTmdb(failure) : return
        if fresh.seriesTmdbId <> "" then metadata.seriesTmdbId = fresh.seriesTmdbId
        metadataCacheWrite(scope, "vod", key, generation, now, metadata)
    end if
    if m.top.operation = "details"
        publishTmdb({ok: true, key: item.key, metadata: metadata})
    else
        publishTmdb(tmdbDiscovery(fresh, metadata))
    end if
end sub

function tmdbGet(path as string) as dynamic
    if left(path, 1) <> "/" or instr(1, path, "://") > 0 then return invalid
    savedKey = m.key
    m.key = "" ' Dispatcharr authentication must never reach TMDB.
    separator = "?"
    if instr(1, path, "?") > 0 then separator = "&"
    result = requestJson("https://api.themoviedb.org/3" + path + separator + "api_key=" + m.encoder.escape(m.top.tmdbKey))
    m.key = savedKey
    return result
end function

function tmdbItemPath(item as object) as string
    numeric = CreateObject("roRegex", "^[1-9][0-9]*$", "")
    if item.kind = "episode"
        if not numeric.isMatch(item.seriesTmdbId) or not CreateObject("roRegex", "^[0-9]+$", "").isMatch(item.season) or not numeric.isMatch(item.episode) then return ""
        return "/tv/" + item.seriesTmdbId + "/season/" + item.season + "/episode/" + item.episode
    end if
    kind = "movie"
    if item.kind = "series" then kind = "tv"
    id = item.tmdbId
    if not numeric.isMatch(id)
        url = "/search/" + kind + "?language=en-US&include_adult=false&query=" + m.encoder.escape(item.title)
        if CreateObject("roRegex", "^[0-9]{4}$", "").isMatch(item.year)
            field = "primary_release_year"
            if kind = "tv" then field = "first_air_date_year"
            url += "&" + field + "=" + item.year
        end if
        id = tmdbSelectMatch(apiRows(tmdbGet(url)), item)
    end if
    if id = "" then return ""
    return "/" + kind + "/" + id
end function

function tmdbDiscovery(item as object, metadata as object) as object
    result = {ok: true, key: item.key, items: [], total: 0, next: "", message: "", discovery: true}
    if m.top.pageNumber < 1 or m.top.pageNumber > 1000 then return {ok: false, key: item.key, message: "Invalid discovery page."}
    if m.top.operation = "people"
        first = (m.top.pageNumber - 1) * 20
        for i = first to metadata.people.count() - 1
            if result.items.count() >= 20 then exit for
            person = metadata.people[i]
            result.items.push({id: person.id, uuid: "person-" + person.id, key: "person:" + person.id, kind: "person", title: person.name, year: "", rating: person.role, logoId: "", tmdbPosterPath: person.posterPath})
        end for
        result.total = metadata.people.count()
        if first + 20 < result.total then result.next = "next"
        return result
    end if
    references = []
    first = 0
    externalNext = false
    if m.top.operation = "person"
        if not CreateObject("roRegex", "^[1-9][0-9]*$", "").isMatch(m.top.personId) then return {ok: false, key: item.key, message: "Invalid person identifier."}
        raw = tmdbGet("/person/" + m.top.personId + "/combined_credits?language=en-US")
        if type(raw) <> "roAssociativeArray" then return {ok: false, key: item.key, message: "Person credits unavailable."}
        references = tmdbReferences(raw.cast, "", 200)
        referenceKeys = {}
        for each ref in references
            referenceKeys[ref.kind + ":" + ref.id] = true
        end for
        for each ref in tmdbReferences(raw.crew, "", 200)
            if references.count() >= 200 then exit for
            if not referenceKeys.doesExist(ref.kind + ":" + ref.id)
                referenceKeys[ref.kind + ":" + ref.id] = true
                references.push(ref)
            end if
        end for
        first = (m.top.pageNumber - 1) * 10
    else if m.top.operation = "related"
        kind = "movie"
        id = metadata.id
        if item.kind <> "movie" then kind = "tv"
        if item.kind = "episode" then id = item.seriesTmdbId
        externalPage = ((m.top.pageNumber - 1) \ 2) + 1
        raw = tmdbGet("/" + kind + "/" + id + "/recommendations?language=en-US&page=" + externalPage.toStr())
        if type(raw) <> "roAssociativeArray" then return {ok: false, key: item.key, message: "Related titles unavailable."}
        referenceKind = item.kind
        if referenceKind = "episode" then referenceKind = "series"
        references = tmdbReferences(raw.results, referenceKind, 20)
        first = ((m.top.pageNumber - 1) mod 2) * 10
        if mediaNumber(raw.total_pages) then externalNext = externalPage < raw.total_pages
    else
        return {ok: false, key: item.key, message: "Unsupported discovery operation."}
    end if
    checked = 0
    seen = {}
    for i = first to references.count() - 1
        if checked >= 10 or m.top.cancelRequested then exit for
        if m.clock.totalMilliseconds() >= m.deadlineMs - 500 then exit for
        ref = references[i]
        permitted = m.cap.movies
        if ref.kind = "series" then permitted = m.cap.series
        checked++
        if permitted = "allowed"
            url = m.base + "/api/vod/" + vodKindPath(ref.kind) + "/?page_size=20&name=" + m.encoder.escape(ref.title)
            if CreateObject("roRegex", "^[0-9]{4}$", "").isMatch(ref.year) then url += "&year=" + ref.year
            page = vodPage(requestJson(url), ref.kind, m.base)
            if page.ok
                matches = []
                for each candidate in page.items
                    if tmdbCatalogMatch(candidate, ref) then matches.push(candidate)
                end for
                if matches.count() = 1
                    candidate = matches[0]
                    if not vodItemHidden(m.top.savedState, candidate) and not seen.doesExist(candidate.key)
                        seen[candidate.key] = true
                        candidate.authorization = m.authorization
                        candidate.accountScope = m.base + "|" + m.cap.accountId
                        result.items.push(candidate)
                    end if
                end if
            end if
        end if
    end for
    if first + 10 < references.count() or externalNext then result.next = "next"
    result.total = result.items.count()
    result.message = result.items.count().toStr() + " permitted catalog matches from " + checked.toStr() + " suggestions checked. Unmatched/hidden titles are not playable."
    expected = references.count() - first
    if expected > 10 then expected = 10
    if checked < expected then result.message += " Lookup budget reached; Refresh retries this page."
    if m.top.operation = "person" then result.message += " First 200 combined credits only."
    return result
end function

sub publishTmdb(result as object)
    m.key = ""
    m.top.apiKey = ""
    m.top.tmdbKey = ""
    m.top.item = invalid
    m.top.savedState = invalid
    if m.top.cancelRequested then return
    m.top.result = result
end sub
