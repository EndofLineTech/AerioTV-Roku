function settingsHubEntries(page as string, model as object) as object
    if page = "" then return [{title: "Live TV", page: "live"}, {title: "Player", page: "player"}, {title: "Appearance", page: "appearance"}, {title: "General", page: "general"}, {title: "Connection", page: "connection"}]
    if page = "live" then return [
        {title: "Guide history days", scope: "guide", key: "historyDays", values: [1, 3, 7, 14, 30]}
        {title: "Guide future days", scope: "guide", key: "futureDays", values: [1, 3, 7, 14, 30]}
        {title: "Channel sort", scope: "guide", key: "channelSort", values: ["number", "name", "id"]}
    ]
    if page = "player"
        entries = []
        if model.catchup = "allowed" then entries.push({title: "Archive skip interval", scope: "device", key: "archiveSkipSeconds", values: [60, 120, 300]})
        entries.push({title: "Audio compatibility (next tune)", scope: "device", key: "audioMode", values: ["auto", "direct", "aac"]})
        entries.push({title: "Video scale", scope: "device", key: "videoScale", values: ["fit", "fill", "stretch"]})
        entries.push({title: "Channel Up/Down direction", scope: "device", key: "channelDirection", values: ["apple", "guide"]})
        return entries
    end if
    if page = "appearance" then return [
        {title: "Group navigation", scope: "guide", key: "groupLayout", values: ["modal", "pills", "sidebar"]}
        {title: "Category colors", scope: "guide", key: "categoryColors", values: [true, false]}
    ]
    if page = "general"
        entries = [{title: "Clock format", scope: "device", key: "clockFormat", values: ["system", "12", "24"]}]
        if model.movies = "allowed" or model.series = "allowed" then entries.push({title: "VOD libraries for this account", scope: "account", key: "vodEnabled", values: [true, false]})
        return entries
    end if
    if page = "connection" then return [{title: "Open connection settings (edit / forget / reconnect)", action: "connection"}]
    return []
end function

function settingsHubValue(model as object, scope as string, key as string) as dynamic
    if scope = "account" then return model.vodEnabled
    if type(model[scope]) <> "roAssociativeArray" then return invalid
    return model[scope][lcase(key)]
end function

function settingsHubChangeAllowed(model as object, scope as string, key as string, value as dynamic) as boolean
    for each page in ["live", "player", "appearance", "general"]
        for each entry in settingsHubEntries(page, model)
            if entry.scope = scope and entry.key = key
                for each allowed in entry.values
                    if allowed = value then return true
                end for
            end if
        end for
    end for
    return false
end function

function settingsValueText(value as dynamic, key = "" as string) as string
    if key = "archiveSkipSeconds"
        if value = 60 then return "1 minute"
        if value = 120 then return "2 minutes"
        if value = 300 then return "5 minutes"
    end if
    if key = "channelDirection"
        if value = "apple" then return "Up next / Down previous"
        if value = "guide" then return "Up previous / Down next"
    end if
    if type(value) = "Boolean" or type(value) = "roBoolean"
        if value then return "On" else return "Off"
    end if
    return textValue(value)
end function
