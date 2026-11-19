' Only account-resolved channel or catalog IDs may reach a player.
' URLs, credentials and unknown media types are never interpreted as links.
' Selection suppression is separate from playback validation: even a malformed
' media intent must not insert an optional profile picker before authentication.
function launchRequestHasMediaIntent(raw as dynamic) as boolean
    if type(raw) <> "roAssociativeArray" then return false
    for each key in raw
        if lcase(key) = "contentid" or lcase(key) = "mediatype"
            if GetInterface(raw[key], "ifString") = invalid then return true
            if raw[key] <> "" then return true
        end if
    end for
    return false
end function

' Intent is deliberately looser than validation. An invalid or missing ID
' for a recognized VOD type must not trigger unrelated live autoplay.
function launchRequestHasVodIntent(raw as dynamic) as boolean
    if type(raw) <> "roAssociativeArray" then return false
    for each key in raw
        if lcase(key) = "mediatype" and GetInterface(raw[key], "ifString") <> invalid
            kind = lcase(raw[key])
            if kind = "movie" or kind = "episode" or kind = "series" then return true
        end if
    end for
    return false
end function

function normalizeLaunchRequest(raw as dynamic) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    id = ""
    mediaType = ""
    foundId = false
    foundType = false
    for each key in raw
        if lcase(key) = "contentid"
            if foundId or GetInterface(raw[key], "ifString") = invalid then return invalid
            foundId = true
            id = raw[key]
        else if lcase(key) = "mediatype"
            if foundType or GetInterface(raw[key], "ifString") = invalid then return invalid
            foundType = true
            mediaType = raw[key]
        end if
    end for
    ' Roku documents livefeed, and App Behavior Analysis sends live. Both
    ' address only a current account-authorized channel, never an arbitrary URL.
    mediaType = lcase(mediaType)
    if mediaType = "livefeed" or mediaType = "live"
        if not CreateObject("roRegex", "^[A-Za-z0-9_-]{1,64}$", "").isMatch(id) then return invalid
        return {kind: "live", id: id}
    end if
    if mediaType <> "movie" and mediaType <> "episode" and mediaType <> "series" then return invalid
    if not launchCatalogId(id) then return invalid
    return {kind: mediaType, id: id}
end function

function launchCatalogId(id as string) as boolean
    return CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(id) and not CreateObject("roRegex", "[^0-9]", "").isMatch(id)
end function
