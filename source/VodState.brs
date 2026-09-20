' Compact device-local state, nested under the existing account preference scope.
function vodState(raw as dynamic) as object
    result = []
    if type(raw) <> "roArray" then return result
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
                    item.watchlist = row.watchlist = true
                    item.hidden = row.hidden = true
                    item.watched = row.watched = true
                    relation = textValue(row.relationId)
                    if not CreateObject("roRegex", "^[0-9]+$", "").isMatch(relation) then relation = ""
                    result.push({id: item.id, uuid: item.uuid, key: item.key, kind: item.kind, title: left(item.title, 120), position: item.position, duration: item.duration, watchlist: item.watchlist, hidden: item.hidden, watched: item.watched, seriesId: left(textValue(row.seriesId), 20), authorization: left(textValue(row.authorization), 64), relationId: relation})
                    seen[item.key] = true
                    if result.count() >= 20 then exit for
                end if
            end if
        end if
    end for
    return result
end function

function vodStateEntry(raw as dynamic, item as object) as object
    for each entry in vodState(raw)
        if entry.key = item.key
            if item.authorization <> invalid then entry.authorization = item.authorization
            if item.seriesId <> invalid then entry.seriesId = item.seriesId
            return entry
        end if
    end for
    return {id: item.id, uuid: item.uuid, key: item.key, kind: item.kind, title: left(item.title, 120), position: 0, duration: 0, watchlist: false, hidden: false, watched: false, seriesId: textValue(item.seriesId), authorization: textValue(item.authorization)}
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
            if shelf = "continue" then include = vodResumePosition(entry, entry.duration) > 0
        end if
        if entry.authorization = "" or entry.authorization <> permissions.authorization then include = false
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

function vodStateUpdate(raw as dynamic, item as object, patch as object) as object
    entry = vodStateEntry(raw, item)
    for each key in ["position", "duration", "watchlist", "hidden", "watched", "relationId"]
        if patch.doesExist(key) then entry[key] = patch[key]
    end for
    result = [entry]
    for each prior in vodState(raw)
        if prior.key <> entry.key then result.push(prior)
    end for
    return vodState(result)
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
    else if vodResumePosition(entry, item.duration) > 0
        actions.unshift("resume")
        buttons.unshift("Resume")
    end if
    label = "Add to watchlist"
    if entry.watchlist then label = "Remove from watchlist"
    buttons.push(label) : actions.push("watchlist")
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
