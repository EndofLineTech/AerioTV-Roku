' Pure lifecycle plans. The controller owns authorization, stopping outgoing
' tasks/video, and committing scoped preference cleanup before adopting a plan.
function userProfileNormalizeTombstones(raw as dynamic) as dynamic
    if type(raw) <> "roArray" then return invalid
    if raw.count() > 256 then return invalid
    result = []
    positions = {}
    for each row in raw
        if type(row) <> "roArray" then return invalid
        if row.count() < 2 or row.count() > 3 then return invalid
        if type(row[0]) <> "String" and type(row[0]) <> "roString" then return invalid
        if row[0] = "" or userProfileUtf8ByteCount(row[0]) > 256 then return invalid
        if not userProfileInteger(row[1]) then return invalid
        if row[1] <= 0 then return invalid
        if row.count() = 3
            if not userProfileInteger(row[2]) then return invalid
            if userProfileUserId(row[2]) = invalid then return invalid
        end if
        username = lcase(row[0])
        candidate = [username, row[1]]
        if row.count() = 3 then candidate.push(row[2])
        if positions.doesExist(username)
            index = positions[username]
            if candidate[1] > result[index][1] then result[index] = candidate
        else
            positions[username] = result.count()
            result.push(candidate)
        end if
    end for
    return result
end function

function userProfileTombstones(local as object, remote as object, now as integer) as dynamic
    all = []
    all.append(local)
    all.append(remote)
    union = userProfileNormalizeTombstones(all)
    if union = invalid then return invalid
    result = []
    for each row in union
        if row[1] >= now - 7776000 then result.push(row)
    end for
    return result
end function

function userProfileTombstoneRemoves(tombstones as object, profile as object) as boolean
    if profile.isDefault then return false
    for each row in tombstones
        if row[0] = lcase(profile.username) and row[1] >= profile.updatedAt then return true
    end for
    return false
end function

function userProfileRemovalPlan(store as object, id as string, now as integer, reason as string) as object
    denied = {ok: false, needsDefaultSwitch: false, pushRequired: false}
    if reason <> "normal" and reason <> "undo" and reason <> "pull" then return denied
    cleaned = normalizeUserProfileStore(store, store.playlistId)
    if cleaned.readOnly = true then return denied
    found = invalid
    kept = []
    for each profile in cleaned.profiles
        if profile.id = id
            found = profile
        else
            kept.push(profile)
        end if
    end for
    if found = invalid then return denied
    if found.isDefault then return denied
    if cleaned.active = id
        denied.needsDefaultSwitch = true
        return denied
    end if
    localOnly = reason = "pull" or found.addressHeld
    if reason = "undo" and (found.addOrigin = "roster" or found.addOrigin = "paused") then localOnly = true
    if not localOnly and now <= 0 then return denied
    if not localOnly and now < found.updatedAt
        denied.reason = "clock-not-ready"
        return denied
    end if
    cleaned.profiles = kept
    if not localOnly
        cleaned.removed = userProfileTombstones(cleaned.removed, [[lcase(found.username), now]], now)
        cleaned.pendingRoster = true
    end if
    return {ok: true, needsDefaultSwitch: false, pushRequired: not localOnly, store: cleaned, removedProfile: found}
end function

' Fail-closed interim activation boundary, replaced by the real PIN/picker
' controller only once mrr.8/.9 and the active credential resolver are present.
function userProfileStartupGate(store as object) as object
    if store.readOnly = true then return {allowed: false, reason: "recovery"}
    if store.profiles.count() = 0 then return {allowed: true, reason: ""}
    cleaned = normalizeUserProfileStore(store, store.playlistId)
    if cleaned.readOnly = true then return {allowed: false, reason: "recovery"}
    for each profile in cleaned.profiles
        if profile.id = cleaned.active
            if profile.role = "child" then return {allowed: false, reason: "child"}
            if not profile.isDefault then return {allowed: false, reason: "profileKey"}
            if profile.pinType <> "none" then return {allowed: false, reason: "pin"}
        end if
    end for
    if cleaned.askAtLaunch and cleaned.profiles.count() > 1 then return {allowed: false, reason: "picker"}
    return {allowed: true, reason: ""}
end function
