' The entire app requires the precision-preserving ParseJson option, not just
' sync writes. The Dashboard floor is an additional external release gate.
function userProfileRuntimeSupported(version as dynamic) as boolean
    if type(version) <> "roAssociativeArray" then return false
    parts = []
    for each key in ["major", "minor"]
        value = version[key]
        kind = type(value)
        if kind <> "String" and kind <> "roString" and kind <> "Integer" and kind <> "roInt" and kind <> "roInteger" then return false
        text = value.toStr()
        if not CreateObject("roRegex", "^[0-9]{1,3}$", "").isMatch(text) then return false
        parts.push(val(text))
    end for
    return parts[0] > 14 or (parts[0] = 14 and parts[1] >= 6)
end function
