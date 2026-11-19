' First stage of the private roster writer. Retain server users absent locally,
' future row tails and tombstones. This is NOT local-row merge or PUT admission.
function dispatcharrSyncRosterWriteBase(data as dynamic, localRemoved as dynamic, now as integer) as object
    denied = {ok: false, allowWrite: false}
    if now <= 0 or type(localRemoved) <> "roArray" then return denied
    decoded = dispatcharrSyncRosterDecode(data)
    if not decoded.ok then return denied
    tombstones = []
    positions = {}
    for each entry in decoded.removed
        if entry.removedAt >= now - 7776000
            row = [entry.username, entry.removedAt]
            if entry.doesExist("userId") then row.push(entry["userId"])
            positions[entry.username] = tombstones.count()
            tombstones.push(row)
        end if
    end for
    for each raw in localRemoved
        entry = dispatcharrSyncRosterRemoved(raw)
        if entry = invalid then return denied
        if raw.count() <> 2 then return denied
        if entry.removedAt >= now - 7776000
            if positions.doesExist(entry.username)
                row = tombstones[positions[entry.username]]
                if entry.removedAt > row[1] then row[1] = entry.removedAt
            else
                positions[entry.username] = tombstones.count()
                tombstones.push([entry.username, entry.removedAt])
            end if
        end if
    end for
    ' Newer rows are intentional re-adds and remove a username's tombstone.
    cleared = {}
    for each row in decoded.rows
        name = lcase(row.username)
        if positions.doesExist(name)
            if row.updatedAt > tombstones[positions[name]][1] then cleared[name] = true
        end if
    end for
    removed = []
    for each row in tombstones
        if not cleared.doesExist(row[0]) then removed.push(row)
    end for
    rows = []
    for each row in decoded.rows
        name = lcase(row.username)
        suppressed = positions.doesExist(name) and not cleared.doesExist(name)
        if not suppressed
            if row.pinAction = "keep" then return denied
            role = row.role
            if role = "" then role = "user"
            order = row.order
            if order < 0 then order = 0
            avatar = {}
            if row.raw.count() > 8
                if type(row.raw[8]) = "roAssociativeArray" then avatar = row.raw[8]
            end if
            outgoing = [row.userId, row.username, userProfileDisplayName(row.displayName), row.pinType, row.pinHash, row.pinSalt, role, row.updatedAt, avatar, order]
            for i = 10 to row.raw.count() - 1
                outgoing.push(row.raw[i])
            end for
            rows.push(outgoing)
        end if
    end for
    return {ok: true, allowWrite: false, rows: rows, removed: removed}
end function

' Pure local/server merge plan, still no credential/session/transport authority.
' The caller MUST commit localPlan (including protection imports) and any actual
' retirement before HTTP. A cleanup-required result may not be sent as a roster.
function dispatcharrSyncProfilesWritePlan(store as object, data as dynamic, enabled as boolean, now as integer, acknowledgedStamp as dynamic, serverCategoryStamp as dynamic) as object
    denied = {ok: false, allowWrite: false, reason: "invalid"}
    if store.retirementPending = true then return denied
    if not dispatcharrSyncInteger(acknowledgedStamp) or not dispatcharrSyncInteger(serverCategoryStamp) then return denied
    if acknowledgedStamp < 0 or serverCategoryStamp < 0 then return denied
    decoded = dispatcharrSyncRosterDecode(data)
    if not decoded.ok then return denied
    merged = dispatcharrSyncRosterMerge(store, decoded, enabled, now)
    if not merged.ok or not merged.applied then return denied
    if merged.removed.count() > 0
        return {ok: false, allowWrite: false, reason: "cleanup-required", localPlan: merged}
    end if
    for each profile in merged.store.profiles
        if profile.id = merged.store.active
            if profile.role <> "admin" and profile.role <> "user"
                return {ok: false, allowWrite: false, reason: "protection-changed", localPlan: merged}
            end if
        end if
    end for
    base = dispatcharrSyncRosterWriteBase(data, store.removed, now)
    if not base.ok then return denied
    rows = base.rows
    tombstones = base.removed
    newestRemote = 0&
    newestLocal = 0&
    for each row in decoded.rows
        if row.updatedAt > newestRemote then newestRemote = row.updatedAt
    end for
    for each profile in merged.store.profiles
        if profile.updatedAt > newestLocal then newestLocal = profile.updatedAt
    end for
    maxSentStamp = 0&
    localProfiles = userProfileSorted(merged.store.profiles)
    for localIndex = 0 to localProfiles.count() - 1
        profile = localProfiles[localIndex]
        remote = invalid
        for each row in decoded.rows
            if row.userId = profile.userId
                if lcase(row.username) <> lcase(profile.username) then return denied
                remote = row
            end if
        end for
        stamp = profile.updatedAt
        if stamp = 0 and remote <> invalid then stamp = remote.updatedAt
        covered = false
        for each tombstone in tombstones
            if tombstone[0] = lcase(profile.username) and tombstone[1] >= stamp then covered = true
        end for
        ' Default is never removed locally, but an unstamped default is not an
        ' intentional re-add and cannot erase another device's removal intent.
        if not covered
            stale = false
            if remote = invalid and decoded.rows.count() > 0 and acknowledgedStamp > 0
                if profile.updatedAt <= acknowledgedStamp
                    stale = profile.updatedAt < serverCategoryStamp or newestLocal < newestRemote - 7776000
                end if
            end if
            if not stale
                if stamp = 0 and remote = invalid then stamp = now
                role = profile.role
                if role <> "admin" and role <> "user" and role <> "child" then role = "user"
                outgoing = [profile.userId, profile.username, userProfileDisplayName(profile.displayName), profile.pinType, profile.pinHash, profile.pinSalt, role, stamp, profile.avatar, localIndex]
                if remote <> invalid
                    avatar = invalid
                    if not profile.avatarClaimed and remote.raw.count() > 8 and not dispatcharrSyncProfileStripped(remote.displayName, remote.username, remote.avatar)
                        if type(remote.raw[8]) = "roAssociativeArray" then outgoing[8] = remote.raw[8]
                    end if
                    if dispatcharrSyncKeepFreshRosterPresentation(store.profiles, profile, remote, now)
                        outgoing[2] = userProfileDisplayName(remote.displayName)
                        if remote.raw.count() > 8 then avatar = remote.raw[8]
                        if type(avatar) = "roAssociativeArray" then outgoing[8] = avatar
                        if remote.order >= 0 then outgoing[9] = remote.order
                    end if
                    for i = 10 to remote.raw.count() - 1
                        outgoing.push(remote.raw[i])
                    end for
                end if
                at = -1
                for i = 0 to rows.count() - 1
                    if rows[i][0] = profile.userId then at = i
                end for
                if at >= 0
                    rows[at] = outgoing
                else
                    if rows.count() >= 25 then return denied
                    rows.push(outgoing)
                end if
                kept = []
                for each tombstone in tombstones
                    if tombstone[0] <> lcase(profile.username) or tombstone[1] >= stamp then kept.push(tombstone)
                end for
                tombstones = kept
                if stamp > maxSentStamp then maxSentStamp = stamp
            end if
        end if
    end for
    output = ParseJson("{}")
    for each field in data
        output[field] = data[field]
    end for
    output["rows"] = rows
    output["removed"] = tombstones
    return {ok: true, allowWrite: false, data: output, localPlan: merged, maximumSentStamp: maxSentStamp}
end function

function dispatcharrSyncKeepFreshRosterPresentation(previous as object, profile as object, remote as object, now as integer) as boolean
    if profile.addOrigin <> "roster" or profile.createdAt <= 0 or now < profile.createdAt or now > profile.createdAt + 60 then return false
    if dispatcharrSyncProfileStripped(remote.displayName, remote.username, remote.avatar) then return false
    for each old in previous
        if old.id = profile.id
            if dispatcharrSyncProfileStripped(old.displayName, old.username, old.avatar) then return true
            ' A fresh read can settle and persist the rescue before the next
            ' GET/PUT. Keep the peer order on that retry, but never override
            ' a subsequent explicit local move or presentation edit.
            if old.updatedAt <> remote.updatedAt or old.order <> remote.order then return false
            return old.displayName = userProfileDisplayName(remote.displayName) and FormatJson(old.avatar) = FormatJson(remote.avatar)
        end if
    end for
    return false
end function
