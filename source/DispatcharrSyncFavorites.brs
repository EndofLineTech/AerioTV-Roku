' Pure favorites adapter for the v3 Sync key (e3e.7). Server integer channel
' PKs map to local UUIDs only through the caller's current authorized lineup.
' Mirrors Android DsyncFavorites/DsyncGate: an id or UUID that cannot be
' translated is never deleted on either side. The writer, scheduler and Guide
' apply path call these helpers only while Sync and Favorites are both On.

' Validates a pulled `favorites` category. Order is kept; a repeated id is
' dropped. Malformed shapes are ignored rather than coerced.
function dispatcharrSyncFavoritesRead(category as dynamic) as object
    denied = {ok: false, ids: []}
    if type(category) <> "roAssociativeArray" then return denied
    stamp = category["updatedAt"]
    if type(stamp) <> "String" and type(stamp) <> "roString" then return denied
    if not CreateObject("roRegex", "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", "").isMatch(stamp) then return denied
    data = category["data"]
    if type(data) <> "roAssociativeArray" then return denied
    raw = data["ids"]
    if type(raw) <> "roArray" then return denied
    ids = []
    seen = {}
    for each id in raw
        if not dispatcharrSyncInteger(id) then return denied
        if id < 1 or id > 2147483647 then return denied
        if not seen.doesExist(id.toStr())
            seen[id.toStr()] = true
            ids.push(id)
        end if
    end for
    return {ok: true, ids: ids}
end function

' Row keys merge only when this device has an unsent change; otherwise the
' newer server list is taken as a whole.
function dispatcharrSyncFavoritesOnNewerPull(dirty as boolean) as string
    if dirty then return "merge"
    return "take-remote"
end function

' Clean apply: server order wins. A local favorite whose channel is outside
' this lineup is kept, since this device cannot tell whether it was dropped.
function dispatcharrSyncFavoritesApply(remoteIds as object, localUuids as object, channels as object) as object
    lookup = dispatcharrSyncFavoritesLineup(channels)
    wanted = []
    seen = {}
    for each id in remoteIds
        key = id.toStr()
        if lookup.byId.doesExist(key)
            uuid = lookup.byId[key]
            if not seen.doesExist(uuid)
                seen[uuid] = true
                wanted.push(uuid)
            end if
        end if
    end for
    dropped = []
    for each uuid in localUuids
        if lookup.byUuid.doesExist(uuid)
            if not seen.doesExist(uuid) then dropped.push(uuid)
        else if not seen.doesExist(uuid)
            seen[uuid] = true
            wanted.push(uuid)
        end if
    end for
    return {uuids: wanted, dropped: dropped}
end function

' Dirty merge: local order first, then server channels this device lacks.
' Server ids outside this lineup are returned to carry on the next write.
function dispatcharrSyncFavoritesMerge(localUuids as object, remoteIds as object, channels as object) as object
    lookup = dispatcharrSyncFavoritesLineup(channels)
    result = {uuids: [], carried: []}
    seen = {}
    for each uuid in localUuids
        if not seen.doesExist(uuid)
            seen[uuid] = true
            result.uuids.push(uuid)
        end if
    end for
    for each id in remoteIds
        key = id.toStr()
        if lookup.byId.doesExist(key)
            uuid = lookup.byId[key]
            if not seen.doesExist(uuid)
                seen[uuid] = true
                result.uuids.push(uuid)
            end if
        else
            result.carried.push(id)
        end if
    end for
    return result
end function

' Wire ids for a write: local favorites in order, then server ids this lineup
' cannot translate (kept on the wire), capped at the 1000-id wire limit.
function dispatcharrSyncFavoritesWireIds(localUuids as object, channels as object, remoteIds as object) as object
    translated = dispatcharrSyncChannelIds(localUuids, channels)
    lookup = dispatcharrSyncFavoritesLineup(channels)
    ids = []
    seen = {}
    for each id in translated.ids
        if ids.count() >= 1000 then exit for
        seen[id.toStr()] = true
        ids.push(id)
    end for
    for each id in remoteIds
        if ids.count() >= 1000 then exit for
        key = id.toStr()
        if not lookup.byId.doesExist(key) and not seen.doesExist(key)
            seen[key] = true
            ids.push(id)
        end if
    end for
    return {ids: ids, unresolved: translated.unresolved, complete: translated.complete}
end function

' Rebuilds the category for a write: only `ids` is replaced; unknown data
' members and `extra` round-trip. The pulled category is not mutated.
function dispatcharrSyncFavoritesCategory(previous as dynamic, ids as object, updatedAt as string, deviceId as string) as object
    data = ParseJson("{}")
    extra = invalid
    if type(previous) = "roAssociativeArray"
        if type(previous["data"]) = "roAssociativeArray"
            for each name in previous["data"]
                if name <> "ids" then data[name] = previous["data"][name]
            end for
        end if
        if type(previous["extra"]) = "roAssociativeArray" then extra = previous["extra"]
    end if
    data["ids"] = ids
    ' Exact-case wire members: AA literal keys are lowercased on device.
    category = ParseJson("{}")
    category["updatedAt"] = updatedAt
    category["deviceId"] = deviceId
    category["data"] = data
    if extra <> invalid then category["extra"] = extra
    return category
end function

function dispatcharrSyncFavoritesLineup(channels as object) as object
    lookup = {byId: {}, byUuid: {}}
    for each channel in channels
        if type(channel) = "roAssociativeArray"
            uuid = channel.uuid
            id = dispatcharrSyncLocalServerId(channel.id)
            if (type(uuid) = "String" or type(uuid) = "roString") and uuid <> "" and id <> invalid
                lookup.byId[id.toStr()] = uuid
                lookup.byUuid[uuid] = id
            end if
        end if
    end for
    return lookup
end function

' Local favoriteIds hold lineup channel ids (text). The adapter works in
' UUIDs, so an id outside this lineup becomes an opaque "#id" entry: it can
' never match a lineup UUID and is therefore always kept.
function dispatcharrSyncFavoritesLocalEntries(favoriteIds as dynamic, channels as object) as object
    byId = {}
    byId.setModeCaseSensitive()
    for each channel in channels
        if type(channel) = "roAssociativeArray"
            id = textValue(channel.id)
            uuid = textValue(channel.uuid)
            if id <> "" and uuid <> "" and not byId.doesExist(id) then byId[id] = uuid
        end if
    end for
    entries = []
    for each id in compactIds(favoriteIds, 2000)
        if byId.doesExist(id)
            entries.push(byId[id])
        else
            entries.push("#" + id)
        end if
    end for
    return entries
end function

function dispatcharrSyncFavoritesLocalIds(entries as object, channels as object) as object
    byUuid = {}
    byUuid.setModeCaseSensitive()
    for each channel in channels
        if type(channel) = "roAssociativeArray"
            id = textValue(channel.id)
            uuid = textValue(channel.uuid)
            if id <> "" and uuid <> "" and not byUuid.doesExist(uuid) then byUuid[uuid] = id
        end if
    end for
    ids = []
    for each entry in entries
        if left(entry, 1) = "#"
            ids.push(mid(entry, 2))
        else if byUuid.doesExist(entry)
            ids.push(byUuid[entry])
        end if
    end for
    return compactIds(ids, 2000)
end function

' Profile-owned sync record inside the account preferences. It is local
' bookkeeping, never a wire field or a device-wide choice.
function dispatcharrSyncFavoritesState(preferences as dynamic) as object
    state = {known: false, pending: false, acknowledgedAt: 0}
    if type(preferences) <> "roAssociativeArray" then return state
    record = preferences["dispatcharrSyncFavorites"]
    if type(record) <> "roAssociativeArray" then return state
    state.known = true
    if type(record["pending"]) = "Boolean" or type(record["pending"]) = "roBoolean" then state.pending = record["pending"]
    stamp = record["acknowledgedAt"]
    if dispatcharrSyncInteger(stamp)
        if stamp > 0 then state.acknowledgedAt = stamp
    end if
    return state
end function

function dispatcharrSyncFavoritesWithState(preferences as object, pending as boolean, acknowledgedAt as dynamic) as object
    record = ParseJson("{}")
    record["pending"] = pending
    record["acknowledgedAt"] = acknowledgedAt
    return setCanonicalPreference(preferences, "dispatcharrSyncFavorites", record)
end function

' Ordered local favorites as one comparable value for write acknowledgement.
function dispatcharrSyncFavoritesIntent(preferences as dynamic) as string
    ids = []
    if type(preferences) = "roAssociativeArray" then ids = compactIds(preferences.favoriteIds, 2000)
    return FormatJson(ids)
end function

' A newer pulled category is taken whole when clean, merged when this profile
' has an unsent change (or has never synced local favorites). The applied
' server stamp becomes the acknowledged stamp. No lineup means no decision.
function dispatcharrSyncFavoritesPullPlan(preferences as object, category as dynamic, channels as object) as object
    result = {applied: false, changed: false, preferences: preferences}
    if type(channels) <> "roArray" then return result
    if channels.count() = 0 then return result
    read = dispatcharrSyncFavoritesRead(category)
    if not read.ok then return result
    stamp = dispatcharrSyncIsoEpoch(category["updatedAt"])
    if stamp = invalid then return result
    state = dispatcharrSyncFavoritesState(preferences)
    if stamp <= state.acknowledgedAt then return result
    current = compactIds(preferences.favoriteIds, 2000)
    dirty = state.pending or (not state.known and current.count() > 0)
    local = dispatcharrSyncFavoritesLocalEntries(current, channels)
    entries = invalid
    if dispatcharrSyncFavoritesOnNewerPull(dirty) = "merge"
        entries = dispatcharrSyncFavoritesMerge(local, read.ids, channels).uuids
    else
        entries = dispatcharrSyncFavoritesApply(read.ids, local, channels).uuids
    end if
    ids = dispatcharrSyncFavoritesLocalIds(entries, channels)
    staged = setCanonicalPreference(preferences, "favoriteIds", ids)
    result.applied = true
    result.changed = FormatJson(ids) <> FormatJson(current)
    result.preferences = dispatcharrSyncFavoritesWithState(staged, dirty, stamp)
    return result
end function

' Only the exact written favorites clear pending; the stamp is monotonic.
function dispatcharrSyncFavoritesAcknowledge(preferences as object, intent as string, stamp as dynamic) as object
    state = dispatcharrSyncFavoritesState(preferences)
    acknowledged = state.acknowledgedAt
    if dispatcharrSyncInteger(stamp)
        if stamp > acknowledged then acknowledged = stamp
    end if
    pending = state.pending
    if intent <> "" and intent = dispatcharrSyncFavoritesIntent(preferences) then pending = false
    return dispatcharrSyncFavoritesWithState(preferences, pending, acknowledged)
end function
