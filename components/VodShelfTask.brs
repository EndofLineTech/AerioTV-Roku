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
    end for
    publishShelf({ok: true, items: visible, total: visible.count(), next: "", patches: patches, authorization: auth, movies: cap.movies, series: cap.series, checked: checked})
end sub

sub publishShelf(result as object)
    m.key = ""
    m.top.apiKey = ""
    m.top.savedState = invalid
    if m.top.cancelRequested then return
    m.top.result = result
end sub
