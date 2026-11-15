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
