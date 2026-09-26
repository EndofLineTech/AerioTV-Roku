sub init()
    m.top.functionName = "loadShelf"
end sub

sub loadShelf()
    m.base = normalizeBaseUrl(m.top.baseUrl)
    m.key = m.top.apiKey
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.deadlineMs = 30000
    m.timeout = 3000
    m.maxResponseBytes = 1048576
    user = requestJson(m.base + "/api/accounts/users/me/")
    cap = normalizeCapabilities(user, invalid, invalid, CreateObject("roDateTime").asSeconds())
    if cap.accountId <> m.top.accountId
        publishShelf({ok: false, message: "Could not verify saved-library access."})
        return
    end if
    props = user.custom_properties
    if type(props) <> "roAssociativeArray" then props = {}
    auth = metadataCacheDigest(FormatJson({account: cap.accountId, level: cap.level, movies: cap.movies, series: cap.series, hideAdult: props.hide_adult_content}))
    state = vodState(m.top.savedState)
    latestSeries = {}
    if m.top.shelf = "continue"
        for each entry in state
            if entry.kind = "episode" and entry.seriesId <> "" and (entry.watched or vodResumePosition(entry, entry.duration) > 0)
                prior = latestSeries[entry.seriesId]
                if prior = invalid or entry.touch > prior.touch then latestSeries[entry.seriesId] = entry
            end if
        end for
    end if
    patches = []
    items = []
    checked = 0
    for each entry in state
        if m.top.cancelRequested or m.clock.totalMilliseconds() >= 29500 then exit for
        selected = false
        if m.top.shelf = "hidden" then selected = entry.hidden
        if m.top.shelf = "watchlist" then selected = entry.watchlist and not vodItemHidden(state, entry)
        if m.top.shelf = "continue" then selected = vodResumePosition(entry, entry.duration) > 0 and not vodItemHidden(state, entry)
        if selected
            allowed = cap.movies = "allowed"
            if entry.kind <> "movie" then allowed = cap.series = "allowed"
            patch = {key: entry.key, availability: "denied", authorization: auth}
            if allowed
                checked++
                raw = requestJson(m.base + "/api/vod/" + vodKindPath(entry.kind) + "/" + entry.id + "/")
                item = vodNormalize(raw, entry.kind)
                if item <> invalid
                    if item.key = entry.key
                        patch.availability = "available"
                        patch.title = item.title
                        patch.seriesTitle = item.seriesTitle
                        item.authorization = auth
                        item.accountScope = m.base + "|" + cap.accountId
                        item.savedPosition = entry.position
                        items.push(item)
                    else
                        patch.availability = "missing"
                    end if
                else
                    status = 0
                    if type(m.httpFailure) = "roAssociativeArray" then status = m.httpFailure.status
                    if status = 401
                        publishShelf({ok: false, message: "Account verification expired. Reconnect and retry."})
                        return
                    end if
                    if status = 404 and entry.authorization = auth
                        patch.availability = "missing"
                    else if status <> 403 and status <> 404
                        patch.availability = entry.availability
                        patch.authorization = entry.authorization
                    end if
                end if
            end if
            patches.push(patch)
        end if
    end for
    updated = vodApplyAvailability(state, patches)
    permissions = {movies: cap.movies, series: cap.series, authorization: auth}
    visible = []
    for each entry in vodShelfEntries(updated, m.top.shelf, permissions)
        latest = latestSeries[entry.seriesId]
        includeEntry = true
        if m.top.shelf = "continue" and entry.kind = "episode" and latest <> invalid
            if latest.key <> entry.key or latest.watched then includeEntry = false
        end if
        if includeEntry
            found = invalid
            for each item in items
                if item.key = entry.key then found = item
            end for
            if found = invalid
                found = vodNormalize({id: entry.id, uuid: entry.uuid, name: entry.title}, entry.kind)
                found.authorization = auth
                found.accountScope = m.base + "|" + cap.accountId
                found.unavailable = entry.availability = "missing"
                found.metadataPending = entry.availability <> "missing"
            end if
            visible.push(found)
        end if
    end for
    partial = false
    explored = 0
    if m.top.shelf = "continue" and cap.series = "allowed"
        for each entry in state
            if m.top.cancelRequested then exit for
            if m.clock.totalMilliseconds() >= 27000
                partial = true
                exit for
            end if
            if entry.kind = "episode" and entry.watched and entry.seriesId <> ""
                latest = latestSeries[entry.seriesId]
                if latest <> invalid and latest.key = entry.key and not vodItemHidden(state, entry)
                    if explored >= 3
                        partial = true
                        exit for
                    end if
                    explored++
                    m.httpFailure = invalid
                    nextItem = vodShelfNextForSeries(entry, state, auth, cap.accountId)
                    if nextItem = invalid and type(m.httpFailure) = "roAssociativeArray"
                        if m.httpFailure.status = 401
                            publishShelf({ok: false, message: "Account verification expired. Reconnect and retry."})
                            return
                        end if
                    end if
                    if nextItem <> invalid then visible.unshift(nextItem)
                end if
            end if
        end for
    end if
    publishShelf({ok: true, items: visible, total: visible.count(), next: "", patches: patches, authorization: auth, movies: cap.movies, series: cap.series, checked: checked, partial: partial})
end sub

function vodShelfNextForSeries(entry as object, state as object, auth as string, accountId as string) as dynamic
    if entry.authorization <> auth or entry.availability = "denied" or entry.availability = "missing" then return invalid
    anchor = vodNormalize(requestJson(m.base + "/api/vod/episodes/" + entry.id + "/"), "episode")
    if anchor = invalid then return invalid
    if anchor.key <> entry.key or anchor.seriesId <> entry.seriesId then return invalid
    catalog = vodLoadSeriesEpisodes(entry.seriesId, "")
    if not catalog.ok then return invalid
    selection = vodSeriesTarget(catalog.items, state, entry.seriesId, catalog.complete)
    if selection.status <> "next" and selection.status <> "resume" then return invalid
    target = vodNormalize(requestJson(m.base + "/api/vod/episodes/" + selection.item.id + "/"), "episode")
    if target = invalid then return invalid
    if target.key <> selection.item.key or target.seriesId <> entry.seriesId or vodItemHidden(state, target) then return invalid
    target.authorization = auth
    target.accountScope = m.base + "|" + accountId
    target.nextUp = true
    target.savedPosition = selection.position
    return target
end function

sub publishShelf(result as object)
    m.key = ""
    m.top.apiKey = ""
    m.top.savedState = invalid
    if m.top.cancelRequested then return
    m.top.result = result
end sub
