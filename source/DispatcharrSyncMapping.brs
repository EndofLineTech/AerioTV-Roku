' Foundation contract only. These descriptors and lane reads do not admit a
' session, apply preferences, enable a category, or authorize a server write.
function dispatcharrSyncCategoryNames() as object
    return ["favorites", "recents", "progress", "reminders", "watchlist", "hiddenTitles", "hiddenGroups", "groupOrder", "settings", "remoteMap", "radioDefault", "collections", "profiles"]
end function

function dispatcharrSyncCategoryMapping(name as string) as object
    result = {name: name, known: false, mode: "preserve", identity: "opaque", cap: 0, rowTime: "opaque", categoryTime: "iso8601-seconds", localTarget: "", localIdentity: "", memberCap: 0}
    ' wire name, identity, per-category row cap, row-time unit, local carrier,
    ' local identity. Local caps are NOT permission to truncate peer payloads.
    rows = [
        ["favorites", "channel-pk", 1000, "none", "favoriteIds", "channel-uuid"],
        ["recents", "channel-pk", 50, "unix-seconds", "recent", "channel-uuid"],
        ["progress", "vod-pk", 300, "unix-seconds", "vod", "kind+vod-uuid"],
        ["reminders", "channel-pk+start", 200, "unix-seconds", "reminders", "channel-uuid+program-id"],
        ["watchlist", "vod-pk", 500, "unix-seconds", "vod.watchlist", "kind+vod-uuid"],
        ["hiddenTitles", "vod-pk", 500, "unix-seconds", "vod.hidden", "kind+vod-uuid"],
        ["hiddenGroups", "server-group-name", 500, "none", "guide.hiddenGroups", "group-token"],
        ["groupOrder", "server-group-name", 500, "none", "guide.groupSort+groupOrder", "group-token"],
        ["settings", "allowlisted-setting-name", 0, "none", "profileSettings+account", "schema-setting-name"],
        ["remoteMap", "tv-remote-slot", 0, "none", "device-local", "roku-remote-slot"],
        ["radioDefault", "boolean", 0, "none", "unsupported", "none"],
        ["collections", "collection-uuid", 50, "none", "collections", "collection-id+channel-uuid"],
        ["profiles", "server-user-pk+username", 25, "unix-seconds", "userProfilesV1", "local-profile-uuid+username"]
    ]
    for each row in rows
        if row[0] = name
            result.known = true
            result.identity = row[1]
            result.cap = row[2]
            result.rowTime = row[3]
            result.localTarget = row[4]
            result.localIdentity = row[5]
        end if
    end for
    if name = "collections" then result.memberCap = 500
    if name = "profiles" then result.mode = "profile-controller"
    return result
end function

' Roku is a TV. Scope is local, not a wire field. A restored mobile/unknown
' class choice becomes All devices; Off and missing own lane have NO fallback.
' Return the original map: never normalize/serialize doubles or unknown names.
function dispatcharrSyncSettingsLane(data as dynamic, scope as string) as object
    result = {ok: true, enabled: false, present: false, lane: "", values: invalid}
    if scope = "off" then return result
    if type(data) <> "roAssociativeArray" then return {ok: false, enabled: false, present: false, lane: "", values: invalid}
    lane = "v"
    if scope = "tv" then lane = "tv"
    result.enabled = true
    result.lane = lane
    if not data.doesExist(lane) then return result
    if type(data[lane]) <> "roAssociativeArray" then result.ok = false : return result
    result.present = true
    result.values = data[lane]
    return result
end function

' Normalized local catalog IDs may be decimal strings; wire IDs must still be
' emitted as 32-bit JSON integers. This is not a permissive wire decoder.
function dispatcharrSyncLocalServerId(value as dynamic) as dynamic
    kind = type(value)
    if kind = "String" or kind = "roString"
        if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(value) then return invalid
        if len(value) = 10
            if value > "2147483647" then return invalid
        end if
        return value.toInt()
    end if
    if not dispatcharrSyncInteger(value) then return invalid
    if value < 1 or value > 2147483647 then return invalid
    return value
end function

' Caller supplies ONLY its current authorized Dispatcharr channel catalog.
' Never mutate local IDs or infer a PK from channel number/UUID. Incomplete
' translation cannot be used for a destructive full-category replacement.
function dispatcharrSyncChannelIds(localIds as object, channels as object) as object
    byUuid = {}
    ambiguous = {}
    for each channel in channels
        if type(channel) = "roAssociativeArray"
            uuid = channel.uuid
            if type(uuid) = "String" or type(uuid) = "roString"
                if uuid <> ""
                    id = dispatcharrSyncLocalServerId(channel.id)
                    if id = invalid
                        ambiguous[uuid] = true
                    else if byUuid.doesExist(uuid)
                        if byUuid[uuid] <> id then ambiguous[uuid] = true
                    else
                        byUuid[uuid] = id
                    end if
                end if
            end if
        end if
    end for
    result = {ids: [], unresolved: [], complete: true}
    seen = {}
    for each localId in localIds
        id = invalid
        if type(localId) = "String" or type(localId) = "roString"
            if not ambiguous.doesExist(localId)
                if byUuid.doesExist(localId) then id = byUuid[localId]
            end if
        end if
        if id = invalid
            result.unresolved.push(localId)
            result.complete = false
        else if not seen.doesExist(id.toStr())
            result.ids.push(id)
            seen[id.toStr()] = true
        end if
    end for
    return result
end function
