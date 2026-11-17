' Shared schema 2.1: own verified username, UTF8 bytes, ASCII-only case fold.
' This module has no credentials, registry, HTTP or write capability.
function dispatcharrSyncUserKey(username as string) as string
    if username = "" then return ""
    bytes = []
    if CreateObject("roRegex", "^[\x00-\x7F]*$", "").isMatch(username)
        for i = 1 to len(username)
            bytes.push(asc(mid(username, i, 1)))
        end for
    else
        bytes = CreateObject("roByteArray")
        bytes.fromAsciiString(username)
    end if
    return dispatcharrSyncKeyBytes(bytes)
end function

' Fresh own-list admission only; it does not authorize transport. Older servers
' advertise smaller limits than the current schema reference deployment. Never
' trim an unsupported category to fit. Absent limits use the older safe bounds.
function dispatcharrSyncWriteBudget(listing as dynamic, key as string, bytes as dynamic) as object
    denied = {ok: false, state: "storage-full", phase: "budget", submitted: false}
    if not dispatcharrSyncInteger(bytes) then return denied
    if bytes < 2 or bytes > 131072 then return denied
    plan = dispatcharrSyncReadPlan(key, listing)
    if plan.state <> "canonical" and plan.state <> "missing" then return denied
    valueCap = 32768
    totalCap = 131072
    appsCap = 25
    if listing.doesExist("limits")
        limits = listing["limits"]
        if type(limits) <> "roAssociativeArray" then return denied
        for each name in ["max_value_bytes", "max_total_bytes", "max_apps"]
            if not dispatcharrSyncInteger(limits[name]) then return denied
            if limits[name] < 1 or limits[name] > 2147483647 then return denied
        end for
        valueCap = limits["max_value_bytes"]
        totalCap = limits["max_total_bytes"]
        appsCap = limits["max_apps"]
    end if
    total = 0&
    previous = 0&
    found = false
    for each app in listing["apps"]
        if app["bytes"] > 2147483647 then return denied
        total += app["bytes"]
        if app["key"] = key
            previous = app["bytes"]
            found = true
        end if
    end for
    if listing.doesExist("total_bytes")
        if not dispatcharrSyncInteger(listing["total_bytes"]) then return denied
        if listing["total_bytes"] < total then return denied
        total = listing["total_bytes"]
    end if
    if bytes > valueCap or total - previous + bytes > totalCap then return denied
    if not found and listing["apps"].count() >= appsCap then return denied
    return {ok: true}
end function

function dispatcharrSyncKeyBytes(bytes as object) as string
    if bytes.count() = 0 then return ""
    encoded = ""
    hex = "0123456789abcdef"
    for each byte in bytes
        if not dispatcharrSyncInteger(byte) then return ""
        if byte < 0 or byte > 255 then return ""
        if byte >= 65 and byte <= 90 then byte += 32
        safe = (byte >= 97 and byte <= 122) or (byte >= 48 and byte <= 57) or byte = 95 or byte = 46 or byte = 45
        if safe
            encoded += chr(byte)
        else
            encoded += "-" + mid(hex, int(byte / 16) + 1, 1) + mid(hex, (byte mod 16) + 1, 1)
        end if
        ' Prefix before truncation, including escaped/nonalphanumeric starts.
        if len(encoded) <= 3
            first = asc(left(encoded, 1))
            if not ((first >= 97 and first <= 122) or (first >= 48 and first <= 57)) then encoded = "u" + encoded
        end if
        if len(encoded) >= 46 then return left(encoded, 46) + ".aeriotv"
    end for
    return encoded + ".aeriotv"
end function

function dispatcharrSyncInteger(value as dynamic) as boolean
    kind = type(value)
    return kind = "Integer" or kind = "roInt" or kind = "roInteger" or kind = "LongInteger" or kind = "roLongInteger"
end function

' Discovery is read-only even when no legacy key exists. A future writer must
' separately prove schema/preservation/category merge/readiness conditions.
function dispatcharrSyncReadPlan(key as string, listing as dynamic) as object
    result = {state: "invalid", key: "", legacy: [], allowWrite: false}
    if key = ""
        result.state = "waiting"
        return result
    end if
    if not CreateObject("roRegex", "^[a-z0-9][a-z0-9._-]{0,45}\.aeriotv$", "").isMatch(key) then return result
    if type(listing) <> "roAssociativeArray" then return result
    if type(listing.apps) <> "roArray" then return result
    if listing.apps.count() > 25 then return result
    seen = []
    canonical = false
    legacy = []
    for each row in listing.apps
        if type(row) <> "roAssociativeArray" then return result
        if type(row.key) <> "String" and type(row.key) <> "roString" then return result
        if not CreateObject("roRegex", "^[A-Za-z0-9][A-Za-z0-9._-]{7,63}$", "").isMatch(row.key) then return result
        if not dispatcharrSyncInteger(row.bytes) then return result
        if row.bytes < 0 then return result
        ' Case matters on the server; an array avoids native AA's aliases.
        for each prior in seen
            if prior = row.key then return result
        end for
        seen.push(row.key)
        if row.key = key then canonical = true
        if row.key = "app.molinete.aerio" or left(row.key, 19) = "app.molinete.aerio." then legacy.push(row.key)
    end for
    result.legacy = legacy
    if canonical
        result.state = "canonical"
        result.key = key
    else if legacy.count() > 0
        result.state = "legacy"
    else
        result.state = "missing"
    end if
    return result
end function
