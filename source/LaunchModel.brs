' Only opaque, account-resolved channel IDs may reach the live player.
' URLs, credentials and unknown media types are never interpreted as links.
function normalizeLaunchRequest(raw as dynamic) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    id = ""
    mediaType = ""
    for each key in raw
        if lcase(key) = "contentid"
            if GetInterface(raw[key], "ifString") = invalid then return invalid
            id = raw[key]
        else if lcase(key) = "mediatype"
            if GetInterface(raw[key], "ifString") = invalid then return invalid
            mediaType = raw[key]
        end if
    end for
    if mediaType <> "liveFeed" then return invalid
    if not CreateObject("roRegex", "^[A-Za-z0-9_-]{1,64}$", "").isMatch(id) then return invalid
    return {kind: "live", id: id}
end function
