' Real Dispatcharr users, distinct from server Channel Profile assignments.
' Pure rules: no registry, requests, runtime active scope or UUID generation.
function userProfileLocalId(value as dynamic) as string
    if type(value) <> "String" and type(value) <> "roString" then return ""
    if not CreateObject("roRegex", "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", "").isMatch(value) then return ""
    return lcase(value)
end function

function userProfileKeyPrefix(slotId as string) as string
    if not CreateObject("roRegex", "^[A-Za-z0-9-]{1,40}$", "").isMatch(slotId) then return ""
    return "profKey_" + slotId + "_"
end function

function userProfileKeyName(slotId as string, id as dynamic) as string
    normalized = userProfileLocalId(id)
    prefix = userProfileKeyPrefix(slotId)
    if normalized = "" or prefix = "" then return ""
    return prefix + normalized
end function

' Restrict IDs to exact JSON integers portable across native and peer readers.
' ParseJson chooses Integer/LongInteger without truncating through ToInt().
function userProfileUserId(value as dynamic) as dynamic
    kind = type(value)
    if kind = "String" or kind = "roString"
        if not CreateObject("roRegex", "^[1-9][0-9]{0,15}$", "").isMatch(value) then return invalid
        value = ParseJson(value)
    end if
    if not userProfileInteger(value) then return invalid
    if value <= 0 or value > 9007199254740991& then return invalid
    return value
end function

function userProfileInteger(value as dynamic) as boolean
    kind = type(value)
    return kind = "Integer" or kind = "roInt" or kind = "roInteger" or kind = "LongInteger" or kind = "roLongInteger"
end function

' Only call on a successful /me/ result. Missing/malformed authority is not
' level 10 (nor an implied unlocked Standard account). Optional malformed flags
' do not confer authority. Never feed an imported roster role to this function.
function userProfileVerifiedLevel(user as dynamic) as dynamic
    if type(user) <> "roAssociativeArray" then return invalid
    if not userProfileInteger(user.user_level) then return invalid
    if user.user_level < 0 then return invalid
    level = user.user_level
    if userProfileTrue(user.is_staff) or userProfileTrue(user.is_superuser)
        if level < 10 then level = 10
    end if
    return level
end function

function userProfileResolveRole(level as dynamic, picked as dynamic) as dynamic
    if not userProfileInteger(level) then return invalid
    if level < 0 then return invalid
    if level >= 10 then return "admin"
    if type(picked) = "String" or type(picked) = "roString"
        if picked = "child" then return "child"
    end if
    return "user"
end function

function userProfileFullAccess(role as dynamic) as boolean
    if type(role) <> "String" and type(role) <> "roString" then return false
    return role = "admin" or role = "user"
end function

function userProfileTrue(value as dynamic) as boolean
    if type(value) <> "Boolean" and type(value) <> "roBoolean" then return false
    return value = true
end function

function userProfileFromVerified(slotId as string, id as string, user as dynamic, now as integer) as dynamic
    localId = userProfileLocalId(id)
    level = userProfileVerifiedLevel(user)
    if slotId = "" or localId = "" or level = invalid or now < 0 then return invalid
    userId = userProfileUserId(user.id)
    if userId = invalid then return invalid
    if type(user.username) <> "String" and type(user.username) <> "roString" then return invalid
    if user.username.trim() = "" then return invalid
    return {
        id: localId, playlistId: slotId, userId: userId
        username: user.username, displayName: userProfileDisplayName(user.username), isDefault: true
        role: userProfileResolveRole(level, invalid), userLevel: level
        isStaff: userProfileTrue(user.is_staff), isSuperuser: userProfileTrue(user.is_superuser)
        order: -1, createdAt: now, updatedAt: 0, avatar: {}
        pinType: "none", pinHash: "", pinSalt: ""
    }
end function

' Bound the encoded bytes, not UTF16 length. Exclude the entire last codepoint
' when a UTF8 sequence crosses the limit; never persist an invalid prefix.
function userProfileDisplayName(value as string) as string
    if CreateObject("roRegex", "^[\x00-\x7F]*$", "").isMatch(value) then return left(value, 40)
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(value)
    if bytes.count() <= 40 then return value
    boundary = userProfileUtf8Boundary(bytes, 40)
    return bytes.slice(0, boundary).toAsciiString()
end function

function userProfileUtf8ByteCount(value as string) as integer
    if CreateObject("roRegex", "^[\x00-\x7F]*$", "").isMatch(value) then return len(value)
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(value)
    return bytes.count()
end function

function userProfileUtf8Boundary(bytes as object, limit as integer) as integer
    if bytes.count() <= limit then return bytes.count()
    boundary = limit
    while boundary > 0 and bytes[boundary] >= 128 and bytes[boundary] < 192
        boundary--
    end while
    return boundary
end function

' Stable insertion sort over the small bounded local roster. Explicit positions
' dominate; ties use default, creation time, then original insertion order.
function userProfileSorted(profiles as object) as object
    result = []
    for each profile in profiles
        position = result.count()
        for i = 0 to result.count() - 1
            if userProfileBefore(profile, result[i])
                position = i
                exit for
            end if
        end for
        result.push(copyJson(profile))
        for i = result.count() - 1 to position + 1 step -1
            result[i] = result[i - 1]
        end for
        result[position] = copyJson(profile)
    end for
    return result
end function

function userProfileBefore(a as object, b as object) as boolean
    if a.order >= 0 and b.order < 0 then return true
    if a.order < 0 and b.order >= 0 then return false
    if a.order <> b.order then return a.order < b.order
    if a.isDefault <> b.isDefault then return a.isDefault = true
    if a.createdAt <> b.createdAt then return a.createdAt < b.createdAt
    return false
end function

' Authorization is the caller's gate; only use normalized, bounded records.
' A physical move writes every position but stamps only changed stored orders.
function userProfileMove(profiles as object, id as string, destination as integer, now as integer) as dynamic
    if destination < 0 or destination >= profiles.count() or now <= 0 then return invalid
    ordered = userProfileSorted(profiles)
    source = -1
    for i = 0 to ordered.count() - 1
        if ordered[i].id = id then source = i
    end for
    if source < 0 then return invalid
    if source = destination then return ordered
    chosen = ordered[source]
    if source < destination
        for i = source to destination - 1
            ordered[i] = ordered[i + 1]
        end for
    else
        for i = source to destination + 1 step -1
            ordered[i] = ordered[i - 1]
        end for
    end if
    ordered[destination] = chosen
    for i = 0 to ordered.count() - 1
        if ordered[i].order <> i
            ordered[i].order = i
            ordered[i] = setCanonicalPreference(ordered[i], "updatedAt", now)
        end if
    end for
    return ordered
end function
