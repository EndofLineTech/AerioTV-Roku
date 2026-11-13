' Read-only wire decoding. No local profile, role authority, active session or
' credential is changed here. raw retains original unknown fields/row tails.
function dispatcharrSyncRosterDecode(data as dynamic) as object
    invalidResult = {ok: false, rows: [], removed: []}
    if type(data) <> "roAssociativeArray" then return invalidResult
    if type(data["rows"]) <> "roArray" then return invalidResult
    rows = []
    for each raw in data["rows"]
        row = dispatcharrSyncRosterRow(raw)
        if row = invalid then return invalidResult
        existing = -1
        for i = 0 to rows.count() - 1
            if rows[i].userId = row.userId then existing = i
        end for
        if existing >= 0
            if row.updatedAt > rows[existing].updatedAt then rows[existing] = row
        else if rows.count() < 25
            rows.push(row)
        end if
    end for
    removed = []
    positions = {}
    if data.doesExist("removed")
        if type(data["removed"]) <> "roArray" then return invalidResult
        for each raw in data["removed"]
            entry = dispatcharrSyncRosterRemoved(raw)
            if entry <> invalid
                if positions.doesExist(entry.username)
                    existing = positions[entry.username]
                    if entry.removedAt > removed[existing].removedAt then removed[existing] = entry
                else
                    positions[entry.username] = removed.count()
                    removed.push(entry)
                end if
            end if
        end for
    end if
    return {ok: true, rows: rows, removed: removed, raw: data}
end function

function dispatcharrSyncRosterInt32(value as dynamic) as boolean
    if not dispatcharrSyncInteger(value) then return false
    return value >= -2147483648& and value <= 2147483647&
end function

function dispatcharrSyncRosterString(value as dynamic) as boolean
    return type(value) = "String" or type(value) = "roString"
end function

function dispatcharrSyncRosterRow(raw as dynamic) as dynamic
    if type(raw) <> "roArray" then return invalid
    if raw.count() < 2 then return invalid
    if not dispatcharrSyncRosterInt32(raw[0]) or not dispatcharrSyncRosterString(raw[1]) then return invalid
    row = {userId: raw[0], username: raw[1], displayName: "", role: "", updatedAt: 0, order: -1, avatarPresent: false, avatar: {}, pinAction: "clear", pinType: "none", pinHash: "", pinSalt: "", raw: raw}
    if raw.count() > 2
        if dispatcharrSyncRosterString(raw[2]) then row.displayName = raw[2]
    end if
    pinType = "none"
    if raw.count() > 3
        if dispatcharrSyncRosterString(raw[3])
            if raw[3] = "numbers" or raw[3] = "directions" then pinType = raw[3]
        end if
    end if
    if pinType <> "none"
        row.pinAction = "keep"
        if raw.count() > 5
            pin = {pinType: pinType, pinHash: raw[4], pinSalt: raw[5]}
            if userProfilePinRecordValid(pin)
                row.pinAction = "replace"
                row.pinType = pinType
                row.pinHash = lcase(raw[4])
                row.pinSalt = lcase(raw[5])
            end if
        end if
    end if
    if raw.count() > 6
        if dispatcharrSyncRosterString(raw[6])
            if raw[6] = "admin" or raw[6] = "user" or raw[6] = "child" then row.role = raw[6]
        end if
    end if
    if raw.count() > 7
        if dispatcharrSyncInteger(raw[7]) then row.updatedAt = raw[7]
    end if
    if raw.count() > 8
        if raw[8] <> invalid
            row.avatarPresent = true
            row.avatar = userProfileNormalizeAvatar(raw[8])
        end if
    end if
    if raw.count() > 9
        if dispatcharrSyncInteger(raw[9])
            if raw[9] >= 0 then row.order = raw[9]
        end if
    end if
    return row
end function

function dispatcharrSyncRosterRemoved(raw as dynamic) as dynamic
    if type(raw) <> "roArray" then return invalid
    if raw.count() < 2 then return invalid
    if not dispatcharrSyncRosterString(raw[0]) then return invalid
    if raw[0] = "" or not dispatcharrSyncInteger(raw[1]) then return invalid
    if raw[1] <= 0 then return invalid
    result = {username: lcase(raw[0]), removedAt: raw[1]}
    if raw.count() > 2
        if dispatcharrSyncRosterInt32(raw[2])
            if raw[2] > 0 then result["userId"] = raw[2]
        end if
    end if
    return result
end function

' The caller supplies the active locally verified role, never a pulled role.
' Pause is slot-wide and independent of whether held profiles have a key.
function dispatcharrSyncRosterGate(activeRole as dynamic, enabled as dynamic, profiles as dynamic) as object
    denied = {apply: false, suggestions: false, reason: "invalid"}
    if type(enabled) <> "Boolean" and type(enabled) <> "roBoolean" then return denied
    if not enabled then return {apply: false, suggestions: false, reason: "disabled"}
    if not dispatcharrSyncRosterString(activeRole) then return denied
    if activeRole <> "admin" and activeRole <> "user" then return {apply: false, suggestions: false, reason: "restricted"}
    if type(profiles) <> "roArray" then return denied
    if profiles.count() = 0 then return denied
    for each profile in profiles
        if type(profile) <> "roAssociativeArray" then return denied
        if type(profile.addressHeld) <> "Boolean" and type(profile.addressHeld) <> "roBoolean" then return denied
        if profile.addressHeld then return {apply: false, suggestions: false, reason: "address-held"}
    end for
    return {apply: true, suggestions: true, reason: "ready"}
end function
