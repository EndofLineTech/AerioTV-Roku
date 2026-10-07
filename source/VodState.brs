' Compact device-local state, nested under the existing account preference scope.
function vodState(raw as dynamic) as object
    curated = []
    recent = []
    if type(raw) <> "roArray" then return curated
    seen = {}
    for each row in raw
        if type(row) = "roAssociativeArray"
            item = vodNormalize({id: row.id, uuid: row.uuid, name: row.title}, textValue(row.kind))
            if item <> invalid
                if not seen.doesExist(item.key)
                    item.position = 0
                    item.duration = 0
                    if mediaNumber(row.position) then item.position = int(row.position)
                    if mediaNumber(row.duration) then item.duration = int(row.duration)
                    if item.position < 0 or item.position > 864000 then item.position = 0
                    if item.duration < 0 or item.duration > 864000 then item.duration = 0
                    touch = 0
                    if mediaNumber(row.touch) then touch = int(row.touch)
                    if touch < 0 or touch > 999999999 then touch = 0
                    item.watchlist = row.watchlist = true
                    item.favorite = row.favorite = true
                    item.hidden = row.hidden = true
                    item.watched = row.watched = true
                    relation = textValue(row.relationId)
                    if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(relation) then relation = ""
                    availability = textValue(row.availability)
                    if availability <> "missing" and availability <> "denied" and availability <> "available" then availability = "unknown"
                    entry = {id: item.id, uuid: item.uuid, key: item.key, kind: item.kind, title: left(item.title, 120), position: item.position, duration: item.duration, touch: touch, watchlist: item.watchlist, favorite: item.favorite, hidden: item.hidden, watched: item.watched, seriesId: left(textValue(row.seriesId), 20), seriesTitle: left(textValue(row.seriesTitle), 120), authorization: left(textValue(row.authorization), 64), relationId: relation, availability: availability}
                    seen[item.key] = true
                    if vodStatePinned(entry)
                        if curated.count() < 40 then curated.push(entry)
                    else
                        if recent.count() < 20 then recent.push(entry)
                    end if
                    if curated.count() >= 40 and recent.count() >= 20 then exit for
                end if
            end if
        end if
    end for
    for each entry in recent
        curated.push(entry)
    end for
    return curated
end function

function vodStatePinned(entry as object) as boolean
    return entry.watchlist or entry.favorite or entry.hidden or entry.watched
end function

function vodStateEntry(raw as dynamic, item as object) as object
    for each entry in vodState(raw)
        if entry.key = item.key
            if item.authorization <> invalid then entry.authorization = item.authorization
            if item.seriesId <> invalid then entry.seriesId = item.seriesId
            return entry
        end if
    end for
    return {id: item.id, uuid: item.uuid, key: item.key, kind: item.kind, title: left(item.title, 120), position: 0, duration: 0, touch: 0, watchlist: false, favorite: false, hidden: false, watched: false, seriesId: textValue(item.seriesId), authorization: textValue(item.authorization)}
end function

function vodItemHidden(raw as dynamic, item as object) as boolean
    for each entry in vodState(raw)
        if entry.hidden
            if entry.key = item.key then return true
            if item.kind = "episode" and entry.kind = "series" and entry.id = item.seriesId then return true
        end if
    end for
    return false
end function

function vodShelfEntries(raw as dynamic, shelf as string, permissions as object) as object
    result = []
    seenSeries = {}
    for each entry in vodState(raw)
        include = false
        if shelf = "hidden" then include = entry.hidden
        if not vodItemHidden(raw, entry)
            if shelf = "watchlist" then include = entry.watchlist
            if shelf = "favorite" then include = entry.favorite and (entry.kind = "movie" or entry.kind = "series")
            if shelf = "continue" then include = vodResumePosition(entry, entry.duration) > 0
        end if
        if entry.authorization = "" or entry.authorization <> permissions.authorization then include = false
        if entry.availability = "denied" then include = false
        if entry.availability = "missing" and shelf = "continue" then include = false
        if entry.kind = "movie" and permissions.movies <> "allowed" then include = false
        if entry.kind <> "movie" and permissions.series <> "allowed" then include = false
        if include and shelf = "continue" and entry.kind = "episode" and entry.seriesId <> ""
            if seenSeries.doesExist(entry.seriesId) then include = false
            seenSeries[entry.seriesId] = true
        end if
        if include then result.push(entry)
    end for
    return result
end function

' Merge only fresh availability metadata into current state. Never resurrect an
' entry removed while a request was in flight or overwrite progress/curation.
function vodApplyAvailability(raw as dynamic, patches as dynamic) as object
    result = vodState(raw)
    if type(patches) <> "roArray" then return result
    for each entry in result
        for each patch in patches
            if patch.key = entry.key
                entry.availability = textValue(patch.availability)
                entry.authorization = textValue(patch.authorization)
                if textValue(patch.title) <> "" then entry.title = left(patch.title, 120)
                if textValue(patch.seriesTitle) <> "" then entry.seriesTitle = left(patch.seriesTitle, 120)
            end if
        end for
    end for
    return vodState(result)
end function

function vodStateUpdate(raw as dynamic, item as object, patch as object) as object
    prior = vodState(raw)
    entry = vodStateEntry(prior, item)
    wasPinned = vodStatePinned(entry)
    newest = 0
    for each saved in prior
        if saved.touch > newest then newest = saved.touch
    end for
    if newest >= 999999999 then newest = 0
    entry.touch = newest + 1
    for each key in ["position", "duration", "watchlist", "favorite", "hidden", "watched", "relationId"]
        if patch.doesExist(key) then entry[key] = patch[key]
    end for
    if vodStatePinned(entry) and not wasPinned
        pins = 0
        for each saved in prior
            if vodStatePinned(saved) then pins++
        end for
        ' A new explicit choice must never evict an older one at capacity.
        if pins >= 40 then return invalid
    end if
    result = [entry]
    for each saved in prior
        if saved.key <> entry.key then result.push(saved)
    end for
    return vodState(result)
end function

' A playback history is separate from curated choices and resume state. Keep only
' bounded identities; saved rows are never trusted as playable without rechecking.
function vodHistory(raw as dynamic) as object
    result = []
    if type(raw) <> "roArray" then return result
    seen = {}
    for each row in raw
        if type(row) = "roAssociativeArray"
            kind = textValue(row.kind)
            if kind = "movie" or kind = "episode"
                item = vodNormalize({id: row.id, uuid: row.uuid, name: row.title}, kind)
                if item <> invalid and not seen.doesExist(item.key)
                    seriesId = textValue(row.seriesId)
                    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(seriesId) then seriesId = ""
                    if kind = "movie" or seriesId <> ""
                        result.push({id: item.id, uuid: item.uuid, key: item.key, kind: kind, title: left(textValue(row.title), 120), seriesId: seriesId, seriesTitle: left(textValue(row.seriesTitle), 120)})
                        seen[item.key] = true
                        if result.count() >= 20 then exit for
                    end if
                end if
            end if
        end if
    end for
    return result
end function

function vodHistoryRecord(raw as dynamic, item as object) as object
    prior = vodHistory(raw)
    if type(item) <> "roAssociativeArray" then return prior
    kind = textValue(item.kind)
    if kind <> "movie" and kind <> "episode" then return prior
    seriesId = textValue(item.seriesId)
    if kind = "episode" and not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(seriesId) then return prior
    selected = vodHistory([{id: item.id, uuid: item.uuid, kind: kind, title: item.title, seriesId: seriesId, seriesTitle: textValue(item.seriesTitle)}])
    if selected.count() = 0 then return prior
    result = selected
    for each entry in prior
        if entry.key <> selected[0].key then result.push(entry)
        if result.count() >= 20 then exit for
    end for
    return result
end function

function vodHistoryRemove(raw as dynamic, key as string) as object
    result = []
    for each entry in vodHistory(raw)
        if entry.key <> key then result.push(entry)
    end for
    return result
end function

function vodResumePosition(entry as object, duration as integer) as integer
    if entry.hidden or entry.watched or entry.position < 30 then return 0
    if duration <= 0 then duration = entry.duration
    if duration <= 0 or entry.position >= duration * 0.95 or duration - entry.position < 30 then return 0
    return entry.position
end function

' Build in ordinary resizable arrays, then assign once to the native Dialog.
' Arrays read back from SceneGraph fields may be non-resizable on the device.
function vodDetailMenu(item as object, entry as object) as object
    actions = ["play"]
    buttons = ["Play from beginning"]
    if item.kind = "series"
        actions = ["episodes"]
        buttons = ["Browse episodes"]
    else if item.streamFormat = "unknown"
        actions = ["mp4", "mkv"]
        buttons = ["Play as MP4", "Play as Matroska"]
    else if vodResumePosition(entry, entry.duration) > 0
        actions.unshift("resume")
        buttons.unshift("Resume")
    end if
    label = "Add to watchlist"
    if entry.watchlist then label = "Remove from To Watch" else label = "Add to To Watch"
    buttons.push(label) : actions.push("watchlist")
    if item.kind = "movie" or item.kind = "series"
        label = "Add to Favorites"
        if entry.favorite then label = "Remove from Favorites"
        buttons.push(label) : actions.push("favorite")
    end if
    label = "Hide title"
    if entry.hidden then label = "Unhide title"
    buttons.push(label) : actions.push("hidden")
    label = "Mark watched / remove progress"
    if entry.watched then label = "Mark unwatched"
    buttons.push(label) : actions.push("watched")
    if vodExternalLinks(item).count() > 0
        buttons.push("External information / trailer links") : actions.push("links")
    end if
    buttons.push("Back") : actions.push("back")
    return {actions: actions, buttons: buttons}
end function
