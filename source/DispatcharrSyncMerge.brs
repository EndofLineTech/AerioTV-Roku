' Pure local roster plan. The controller must authenticate/retire an active
' tombstoned profile before committing cleanup; this module never sends HTTP.
function dispatcharrSyncRosterMerge(store as object, decoded as object, enabled as boolean, now as integer) as object
    denied = {ok: false, applied: false, removed: [], suggestions: [], needsDefaultSwitch: false}
    cleaned = normalizeUserProfileStore(store, store.playlistId)
    if cleaned.readOnly = true or decoded.ok <> true or now <= 0 then return denied
    activeRole = ""
    defaultId = ""
    for each profile in cleaned.profiles
        if profile.id = cleaned.active then activeRole = profile.role
        if profile.isDefault then defaultId = profile.id
    end for
    gate = dispatcharrSyncRosterGate(activeRole, enabled, cleaned.profiles)
    result = {ok: true, applied: false, store: cleaned, removed: [], suggestions: [], needsDefaultSwitch: false}
    if not gate.apply then return result
    tombstones = {}
    for each row in cleaned.removed
        if row[1] >= now - 7776000 then tombstones[lcase(row[0])] = row[1]
    end for
    remoteRemoved = {}
    for each row in decoded.removed
        name = row.username
        if row.removedAt >= now - 7776000
            remoteRemoved[name] = row.removedAt
            if not tombstones.doesExist(name) or row.removedAt > tombstones[name] then tombstones[name] = row.removedAt
        end if
    end for
    remoteRows = {}
    ambiguous = {}
    for each row in decoded.rows
        name = lcase(row.username)
        if remoteRows.doesExist(name) then ambiguous[name] = true
        remoteRows[name] = row
        if tombstones.doesExist(name)
            if row.updatedAt > tombstones[name] then tombstones.delete(name)
        end if
    end for
    ' A local username must never inherit two different users' PIN/role rows.
    if ambiguous.count() > 0 then return denied
    retained = []
    known = {}
    for each profile in cleaned.profiles
        name = lcase(profile.username)
        known[name] = true
        stamp = profile.updatedAt
        if remoteRows.doesExist(name)
            row = remoteRows[name]
            if row.userId > 0 and row.userId <> profile.userId then return denied
            if row.updatedAt > stamp then stamp = row.updatedAt
        end if
        if tombstones.doesExist(name) and not profile.isDefault and tombstones[name] >= stamp
            result.removed.push(profile)
            if profile.id = cleaned.active
                result.needsDefaultSwitch = true
                cleaned.active = defaultId
            end if
        else
            if remoteRows.doesExist(name)
                row = remoteRows[name]
                if not tombstones.doesExist(name)
                    if dispatcharrSyncShouldRepairProfile(profile, row) then cleaned.pendingRoster = true
                    profile = dispatcharrSyncMergeProfile(profile, row, now)
                end if
            else if profile.addOrigin = "paused"
                profile = setCanonicalPreference(profile, "addOrigin", "plain")
            end if
            retained.push(profile)
        end if
    end for
    cleaned.profiles = retained
    localRemoved = []
    for each row in cleaned.removed
        name = lcase(row[0])
        keep = row[1] >= now - 7776000
        if not tombstones.doesExist(name) then keep = false
        if remoteRemoved.doesExist(name)
            if remoteRemoved[name] >= row[1] then keep = false
        end if
        if keep then localRemoved.push(row)
    end for
    cleaned.removed = localRemoved
    for each row in decoded.rows
        name = lcase(row.username)
        if row.userId > 0 and row.username <> "" and not known.doesExist(name) and not tombstones.doesExist(name) then result.suggestions.push(row)
    end for
    validated = normalizeUserProfileStore(cleaned, cleaned.playlistId)
    if validated.readOnly = true then return denied
    result.store = validated
    result.applied = true
    return result
end function

function dispatcharrSyncProfileStripped(name as string, username as string, avatar as object) as boolean
    return (name.trim() = "" or lcase(name) = lcase(username)) and userProfileNormalizeAvatar(avatar).count() = 0
end function

function dispatcharrSyncMergeProfile(profile as object, row as object, now as integer) as object
    localStripped = dispatcharrSyncProfileStripped(profile.displayName, profile.username, profile.avatar)
    remoteStripped = dispatcharrSyncProfileStripped(row.displayName, row.username, row.avatar)
    if dispatcharrSyncShouldRepairProfile(profile, row)
        return setCanonicalPreference(profile, "updatedAt", now)
    end if
    settlement = profile.addOrigin = "paused"
    full = row.updatedAt > profile.updatedAt or (localStripped and not remoteStripped and profile.updatedAt >= row.updatedAt) or settlement
    result = copyJson(profile)
    if full
        if row.displayName.trim() <> "" then result = setCanonicalPreference(result, "displayName", userProfileDisplayName(row.displayName))
        if row.role <> "" then result = setCanonicalPreference(result, "role", userProfileResolveRole(profile.userLevel, row.role))
        if row.avatarPresent then result = setCanonicalPreference(result, "avatar", row.avatar)
        if row.order >= 0 then result = setCanonicalPreference(result, "order", row.order)
        if row.pinAction <> "keep"
            result = setCanonicalPreference(result, "pinType", row.pinType)
            result = setCanonicalPreference(result, "pinHash", row.pinHash)
            result = setCanonicalPreference(result, "pinSalt", row.pinSalt)
        end if
        stamp = row.updatedAt
        if settlement and stamp = 0 then stamp = now
        result = setCanonicalPreference(result, "updatedAt", stamp)
    end if
    if not remoteStripped
        if not profile.displayNameClaimed and row.displayName.trim() <> "" then result = setCanonicalPreference(result, "displayName", userProfileDisplayName(row.displayName))
        if not profile.avatarClaimed and row.avatarPresent then result = setCanonicalPreference(result, "avatar", row.avatar)
    end if
    if settlement then result = setCanonicalPreference(result, "addOrigin", "roster")
    return result
end function

function dispatcharrSyncShouldRepairProfile(profile as object, row as object) as boolean
    if profile.addOrigin = "paused" then return false
    return not dispatcharrSyncProfileStripped(profile.displayName, profile.username, profile.avatar) and dispatcharrSyncProfileStripped(row.displayName, row.username, row.avatar) and row.updatedAt >= profile.updatedAt and row.updatedAt <= profile.updatedAt + 600
end function
