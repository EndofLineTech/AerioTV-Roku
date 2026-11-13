' Shared avatar identifiers/colors from profile spec 6.6, independent of art.
function userProfileAvatarIcons() as object
    return ["initial", "person", "face", "child", "paw", "cat", "fish", "star", "rocket", "music", "soccer", "gamepad", "movie"]
end function

function userProfileAvatarColors() as object
    return ["teal", "blue", "orange", "ember", "green", "purple", "slate", "sea"]
end function

function userProfileNormalizeAvatar(raw as dynamic) as object
    icon = "initial"
    color = ""
    if type(raw) = "roAssociativeArray"
        if type(raw.icon) = "String" or type(raw.icon) = "roString"
            for each candidate in userProfileAvatarIcons()
                if raw.icon = candidate then icon = candidate
            end for
        end if
        if type(raw.color) = "String" or type(raw.color) = "roString"
            for each candidate in userProfileAvatarColors()
                if raw.color = candidate then color = candidate
            end for
        end if
    end if
    if icon = "initial" and color = "" then return {}
    return {icon: icon, color: color}
end function

function userProfileAvatarInk(color as string) as string
    if color = "teal" or color = "orange" or color = "green" or color = "slate" then return "0B1220"
    return "FFFFFF"
end function

function userProfileTrim(value as string) as string
    return CreateObject("roRegex", "^\s+|\s+$", "").replaceAll(value, "")
end function

function userProfileAvatarInitial(displayName as string, username as string) as string
    value = userProfileTrim(displayName)
    if value = "" then value = userProfileTrim(username)
    if value = "" then return "?"
    if asc(left(value, 1)) < 128 then return ucase(left(value, 1))
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(value)
    count = 2
    if bytes[0] >= 224 then count = 3
    if bytes[0] >= 240 then count = 4
    return ucase(bytes.slice(0, count).toAsciiString())
end function

function userProfileAvatarUnitColor(units as object) as string
    index = 0
    for each unit in units
        index = (index + unit) mod 8
    end for
    return userProfileAvatarColors()[index]
end function

function userProfileAvatarColor(username as string) as string
    value = lcase(userProfileTrim(username))
    units = []
    if CreateObject("roRegex", "^[\x00-\x7F]*$", "").isMatch(value)
        for i = 1 to len(value)
            units.push(asc(mid(value, i, 1)))
        end for
    else
        bytes = CreateObject("roByteArray")
        bytes.fromAsciiString(value)
        i = 0
        while i < bytes.count()
            first = bytes[i]
            codepoint = first
            count = 1
            if first >= 240
                codepoint = first - 240
                count = 4
            else if first >= 224
                codepoint = first - 224
                count = 3
            else if first >= 192
                codepoint = first - 192
                count = 2
            end if
            for offset = 1 to count - 1
                codepoint = codepoint * 64 + bytes[i + offset] - 128
            end for
            if codepoint > 65535
                codepoint -= 65536
                units.push(55296 + int(codepoint / 1024))
                units.push(56320 + (codepoint mod 1024))
            else
                units.push(codepoint)
            end if
            i += count
        end while
    end if
    return userProfileAvatarUnitColor(units)
end function
