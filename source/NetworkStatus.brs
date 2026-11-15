' Only the typed linkStatus member is observed; unrelated device/memory events
' and arbitrary network details are neither copied to Scene nor logged.
function networkLinkTransition(previous as dynamic, info as dynamic) as object
    result = {changed: false, returned: false, linked: previous}
    if type(info) <> "roAssociativeArray" then return result
    matches = 0
    linked = invalid
    for each key in info
        if lcase(key) = "linkstatus"
            matches++
            linked = info[key]
        end if
    end for
    if matches <> 1 or GetInterface(linked, "ifBoolean") = invalid then return result
    result.linked = linked
    if GetInterface(previous, "ifBoolean") = invalid
        result.changed = true
        return result
    end if
    result.changed = previous <> linked
    result.returned = not previous and linked
    return result
end function
