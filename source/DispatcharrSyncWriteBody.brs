' Structural final gate only: this does NOT authorize a PUT or prove a category
' merge. The future writer must separately bind fresh GET/list/migration evidence,
' own credentials and the actual outgoing session immediately before transport.
function dispatcharrSyncCheckedWriteBody(original as dynamic, candidate as dynamic, rebuilt as dynamic) as object
    denied = {ok: false, allowWrite: false, body: "", reason: "envelope"}
    before = dispatcharrSyncEnvelopeRead(original)
    after = dispatcharrSyncEnvelopeRead(candidate)
    if not before.ok or not after.ok then return denied
    if before.malformedCategories.count() > 0 or after.malformedCategories.count() > 0 then return denied
    if type(rebuilt) <> "roArray" then return denied
    if rebuilt.count() < 1 or rebuilt.count() > 2 then return denied
    ' Only profiles and favorites have typed writers. Unsupported categories
    ' must remain untouched, not claim rebuild ownership.
    owned = {}
    for each name in rebuilt
        if type(name) <> "String" and type(name) <> "roString" then return denied
        if name <> "profiles" and name <> "favorites" then return denied
        if owned.doesExist(name) then return denied
        owned[name] = true
    end for
    denied.reason = "preservation"
    if not dispatcharrSyncWriteIso(candidate["updatedAt"]) then return denied
    if not dispatcharrSyncPreservedMembers(original, candidate, ["deviceId", "platform", "appVersion", "updatedAt", "categories"]) then return denied
    if not dispatcharrSyncPreservedMembers(original["categories"], candidate["categories"], rebuilt) then return denied
    denied.reason = "rebuilt-category"
    if owned.doesExist("profiles")
        category = candidate["categories"]["profiles"]
        if type(category) <> "roAssociativeArray" then return denied
        if not dispatcharrSyncWriteIso(category["updatedAt"]) then return denied
        if not dispatcharrSyncRosterString(category["deviceId"]) then return denied
        if category["deviceId"] <> candidate["deviceId"] then return denied
        if after.profilesState <> "ready" then return denied
        if not dispatcharrSyncWritableProfiles(category["data"]) then return denied
        prior = original["categories"]["profiles"]
        if prior <> invalid
            if not dispatcharrSyncPreservedMembers(prior, category, ["updatedAt", "deviceId", "data"]) then return denied
            if not dispatcharrSyncPreservedMembers(prior["data"], category["data"], ["rows", "removed"]) then return denied
        end if
    end if
    if owned.doesExist("favorites")
        if not dispatcharrSyncRosterString(candidate["deviceId"]) then return denied
        if not dispatcharrSyncFavoritesCategoryWritable(original["categories"]["favorites"], candidate["categories"]["favorites"], candidate["deviceId"]) then return denied
    end if
    denied.reason = "encoding"
    encoded = strictJsonEncode(candidate)
    if not encoded.ok or encoded.text = "" then return denied
    ' Byte budget and the immutable checked string are enforced before posting.
    bytes = dispatcharrSyncWriteByteCount(encoded.text)
    if bytes < 2 then return denied
    if bytes > 131072
        denied.state = "too-large"
        denied.reason = "size"
        return denied
    end if
    denied.reason = "readback"
    parsed = invalid
    if m.syncWriteParser <> invalid
        parsed = m.syncWriteParser(encoded.text)
    else
        parsed = ParseJson(encoded.text, "d")
    end if
    readback = dispatcharrSyncEnvelopeRead(parsed)
    if not readback.ok then return denied
    if readback.malformedCategories.count() > 0 then return denied
    if owned.doesExist("profiles") and readback.profilesState <> "ready" then return denied
    if owned.doesExist("favorites")
        if not dispatcharrSyncFavoritesRead(parsed["categories"]["favorites"]).ok then return denied
    end if
    denied.reason = "roundtrip"
    checked = strictJsonEncode(parsed)
    if not checked.ok then return denied
    if not dispatcharrSyncWireEqual(parsed, candidate) then return denied
    return {ok: true, allowWrite: false, body: encoded.text, bytes: bytes}
end function

' Read decoding intentionally tolerates malformed stamps/order and drops bad
' tombstones. A writer must not re-emit those tolerated inputs unchanged.
function dispatcharrSyncWritableProfiles(data as object) as boolean
    if data["rows"].count() > 25 then return false
    for each row in data["rows"]
        if row.count() > 7
            if not dispatcharrSyncInteger(row[7]) then return false
        end if
        if row.count() > 9
            if row[9] <> invalid
                if not dispatcharrSyncInteger(row[9]) then return false
            end if
        end if
    end for
    if data.doesExist("removed")
        for each row in data["removed"]
            if dispatcharrSyncRosterRemoved(row) = invalid then return false
            if row.count() > 2
                if row[2] <> invalid
                    if not dispatcharrSyncRosterInt32(row[2]) then return false
                    if row[2] <= 0 then return false
                end if
            end if
        end for
    end if
    return true
end function

' Mirrors dispatcharrSyncFavoritesRead, but strictly: a writer never emits
' a duplicate, floating, non-positive or over-cap id it would drop on read.
function dispatcharrSyncFavoritesCategoryWritable(prior as dynamic, category as dynamic, deviceId as string) as boolean
    if type(category) <> "roAssociativeArray" then return false
    if not dispatcharrSyncWriteIso(category["updatedAt"]) then return false
    if not dispatcharrSyncRosterString(category["deviceId"]) then return false
    if deviceId = "" or category["deviceId"] <> deviceId then return false
    if not dispatcharrSyncCategoryValid(category) then return false
    ids = category["data"]["ids"]
    if type(ids) <> "roArray" then return false
    if ids.count() > 1000 then return false
    seen = {}
    for each id in ids
        if not dispatcharrSyncRosterInt32(id) then return false
        if id <= 0 or seen.doesExist(id.toStr()) then return false
        seen[id.toStr()] = true
    end for
    if prior <> invalid
        if type(prior) <> "roAssociativeArray" then return false
        if type(prior["data"]) <> "roAssociativeArray" then return false
        if not dispatcharrSyncPreservedMembers(prior, category, ["updatedAt", "deviceId", "data"]) then return false
        if not dispatcharrSyncPreservedMembers(prior["data"], category["data"], ["ids"]) then return false
    end if
    return true
end function

function dispatcharrSyncWriteIso(value as dynamic) as boolean
    if not dispatcharrSyncRosterString(value) then return false
    if not CreateObject("roRegex", "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", "").isMatch(value) then return false
    return dispatcharrSyncIsoEpoch(value) <> invalid
end function

' Compare exact wire keys and value kinds without copyJson/FormatJson aliases.
function dispatcharrSyncPreservedMembers(before as object, after as object, replaceable as object) as boolean
    for each pair in [[before, after], [after, before]]
        for each key in pair[0]
            replace = false
            for each name in replaceable
                if key = name then replace = true
            end for
            if not replace
                found = false
                for each other in pair[1]
                    if key = other then found = true
                end for
                if not found then return false
                if not dispatcharrSyncWireEqual(pair[0][key], pair[1][key]) then return false
            end if
        end for
    end for
    return true
end function

function dispatcharrSyncWireEqual(leftValue as dynamic, rightValue as dynamic, depth = 0 as integer) as boolean
    if depth > 32 then return false
    leftKind = type(leftValue)
    rightKind = type(rightValue)
    if leftKind = "roArray" or leftKind = "roAssociativeArray"
        if leftKind <> rightKind then return false
        if leftValue.count() <> rightValue.count() then return false
        if leftKind = "roArray"
            for i = 0 to leftValue.count() - 1
                if not dispatcharrSyncWireEqual(leftValue[i], rightValue[i], depth + 1) then return false
            end for
        else
            for each key in leftValue
                found = false
                for each other in rightValue
                    if key = other then found = true
                end for
                if not found then return false
                if not dispatcharrSyncWireEqual(leftValue[key], rightValue[key], depth + 1) then return false
            end for
        end if
        return true
    end if
    a = strictJsonEncode(leftValue)
    b = strictJsonEncode(rightValue)
    if not a.ok or not b.ok then return false
    return a.text = b.text
end function

function dispatcharrSyncWriteByteCount(value as string) as integer
    if CreateObject("roRegex", "^[\x00-\x7F]*$", "").isMatch(value) then return len(value)
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(value)
    return bytes.count()
end function

' Existing canonical-key preparation only. No absent-key creation, legacy
' migration or session/credential authority is inferred from this pure result.
' A favorites plan, when supplied, is rebuilt in the same checked body.
function dispatcharrSyncPrepareProfilesWrite(original as dynamic, store as object, enabled as boolean, now as integer, acknowledgedStamp as dynamic, deviceId as string, appVersion as string, favorites = invalid as dynamic) as object
    denied = {ok: false, allowWrite: false, body: "", reason: "invalid"}
    read = dispatcharrSyncEnvelopeRead(original)
    if not read.ok then return denied
    if read.malformedCategories.count() > 0 or deviceId = "" or appVersion = "" or now <= 0 then return denied
    data = {rows: []}
    categoryStamp = 0&
    if read.profilesState = "ready"
        data = original["categories"]["profiles"]["data"]
        categoryStamp = dispatcharrSyncIsoEpoch(original["categories"]["profiles"]["updatedAt"])
    end if
    plan = dispatcharrSyncProfilesWritePlan(store, data, enabled, now, acknowledgedStamp, categoryStamp)
    if not plan.ok then return plan
    favoritesPlan = invalid
    if favorites <> invalid
        favoritesPlan = dispatcharrSyncFavoritesWritePlan(original, favorites)
        if not favoritesPlan.ok then return denied
    end if
    staged = dispatcharrSyncWriteCandidate(original, now, deviceId, appVersion)
    if not staged.ok then return denied
    candidate = staged.candidate
    category = candidate["categories"]["profiles"]
    if category = invalid then category = ParseJson("{}")
    category["data"] = plan.data
    category["updatedAt"] = staged.stamp
    category["deviceId"] = deviceId
    candidate["categories"]["profiles"] = category
    rebuilt = ["profiles"]
    if favoritesPlan <> invalid and favoritesPlan.needsLocalCommit <> true
        candidate["categories"]["favorites"] = dispatcharrSyncFavoritesCategory(favoritesPlan.previous, favoritesPlan.ids, staged.stamp, deviceId)
        rebuilt.push("favorites")
    end if
    checked = dispatcharrSyncCheckedWriteBody(original, candidate, rebuilt)
    if not checked.ok then return checked
    checked.rebuilt = rebuilt
    checked.stamp = dispatcharrSyncIsoEpoch(staged.stamp)
    checked.localPlan = plan.localPlan
    checked.maximumSentStamp = plan.maximumSentStamp
    checked.unchanged = false
    if read.profilesState = "ready" then checked.unchanged = dispatcharrSyncWireEqual(original["categories"]["profiles"]["data"], plan.data)
    if favoritesPlan <> invalid then checked.unchanged = checked.unchanged and favoritesPlan.unchanged = true
    cleaned = normalizeUserProfileStore(store, store.playlistId)
    checked.needsLocalCommit = FormatJson(cleaned) <> FormatJson(plan.localPlan.store)
    if favoritesPlan <> invalid and favoritesPlan.needsLocalCommit = true then checked.needsLocalCommit = true
    return checked
end function

' Favorites-only preparation: profiles and every other category round-trip.
function dispatcharrSyncPrepareFavoritesWrite(original as dynamic, favorites as dynamic, now as integer, deviceId as string, appVersion as string) as object
    denied = {ok: false, allowWrite: false, body: "", reason: "invalid"}
    read = dispatcharrSyncEnvelopeRead(original)
    if not read.ok then return denied
    if read.malformedCategories.count() > 0 or deviceId = "" or appVersion = "" or now <= 0 then return denied
    plan = dispatcharrSyncFavoritesWritePlan(original, favorites)
    if not plan.ok then return denied
    if plan.needsLocalCommit = true then return {ok: true, allowWrite: false, body: "", needsLocalCommit: true, unchanged: false, rebuilt: []}
    staged = dispatcharrSyncWriteCandidate(original, now, deviceId, appVersion)
    if not staged.ok then return denied
    candidate = staged.candidate
    candidate["categories"]["favorites"] = dispatcharrSyncFavoritesCategory(plan.previous, plan.ids, staged.stamp, deviceId)
    checked = dispatcharrSyncCheckedWriteBody(original, candidate, ["favorites"])
    if not checked.ok then return checked
    checked.rebuilt = ["favorites"]
    checked.stamp = dispatcharrSyncIsoEpoch(staged.stamp)
    checked.needsLocalCommit = false
    checked.unchanged = plan.unchanged = true
    return checked
end function

' Precision clone of the fresh value plus writer envelope metadata only.
function dispatcharrSyncWriteCandidate(original as dynamic, now as integer, deviceId as string, appVersion as string) as object
    denied = {ok: false}
    encoded = strictJsonEncode(original)
    if not encoded.ok then return denied
    candidate = invalid
    if m.syncWriteParser <> invalid
        candidate = m.syncWriteParser(encoded.text)
    else
        candidate = ParseJson(encoded.text, "d")
    end if
    if not dispatcharrSyncWireEqual(original, candidate) then return denied
    clock = CreateObject("roDateTime")
    clock.fromSeconds(now)
    stamp = left(clock.toISOString(), 19) + "Z"
    if not dispatcharrSyncWriteIso(stamp) then return denied
    candidate["updatedAt"] = stamp
    candidate["deviceId"] = deviceId
    candidate["platform"] = "roku"
    candidate["appVersion"] = appVersion
    return {ok: true, candidate: candidate, stamp: stamp}
end function

' Plans the favorites ids for a write against the freshly read category.
' A newer server list whose lineup channels are missing locally must first
' be merged locally (needsLocalCommit) so a PUT can never drop them.
function dispatcharrSyncFavoritesWritePlan(original as dynamic, favorites as dynamic) as object
    denied = {ok: false, reason: "favorites"}
    if type(favorites) <> "roAssociativeArray" or type(original) <> "roAssociativeArray" then return denied
    channels = favorites.channels
    if type(channels) <> "roArray" then return denied
    if channels.count() = 0 then return denied
    if type(original["categories"]) <> "roAssociativeArray" then return denied
    prior = invalid
    remote = []
    stamp = 0
    if original["categories"].doesExist("favorites")
        prior = original["categories"]["favorites"]
        read = dispatcharrSyncFavoritesRead(prior)
        if not read.ok then return denied
        remote = read.ids
        stamp = dispatcharrSyncIsoEpoch(prior["updatedAt"])
    end if
    acknowledged = 0
    if dispatcharrSyncInteger(favorites.acknowledgedAt) then acknowledged = favorites.acknowledgedAt
    local = dispatcharrSyncFavoritesLocalEntries(favorites.ids, channels)
    if prior <> invalid and stamp > acknowledged
        merged = dispatcharrSyncFavoritesMerge(local, remote, channels)
        if FormatJson(merged.uuids) <> FormatJson(local) then return {ok: true, needsLocalCommit: true, unchanged: false, ids: [], previous: prior}
    end if
    wire = dispatcharrSyncFavoritesWireIds(local, channels, remote)
    unchanged = false
    if prior <> invalid then unchanged = dispatcharrSyncWireEqual(prior["data"]["ids"], wire.ids)
    return {ok: true, needsLocalCommit: false, unchanged: unchanged, ids: wire.ids, previous: prior}
end function
