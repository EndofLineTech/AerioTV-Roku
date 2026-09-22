function settingsHubEntries(page as string, model as object) as object
    if page = "" then return [{title: "Live TV", page: "live"}, {title: "Player", page: "player"}, {title: "Remote control", page: "remote"}, {title: "Appearance", page: "appearance"}, {title: "General", page: "general"}, {title: "Connection", page: "connection"}]
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
        return entries
    end if
    if page = "remote" then return [
        {title: "While watching", page: "remotePlayer"}
        {title: "In the TV Guide", page: "remoteGuide"}
        {title: "Reset remote controls", action: "resetRemoteMap"}
    ]
    if page = "remotePlayer" then return remoteSlotEntries("player")
    if page = "remoteGuide" then return remoteSlotEntries("guide")
    if page = "appearance" then return [
        {title: "Group navigation", scope: "guide", key: "groupLayout", values: ["modal", "pills", "sidebar"]}
        {title: "Category colors", scope: "guide", key: "categoryColors", values: [true, false]}
        {title: "Show player logo", scope: "device", key: "infoLogo", values: [true, false]}
        {title: "Show player channel", scope: "device", key: "infoChannel", values: [true, false]}
        {title: "Show player title", scope: "device", key: "infoTitle", values: [true, false]}
        {title: "Show player time and progress", scope: "device", key: "infoTime", values: [true, false]}
        {title: "Show player description", scope: "device", key: "infoDescription", values: [true, false]}
        {title: "Show player next program", scope: "device", key: "infoNext", values: [true, false]}
        {title: "Show player remote hints", scope: "device", key: "infoHints", values: [true, false]}
    ]
    if page = "general"
        entries = [{title: "Clock format", scope: "device", key: "clockFormat", values: ["system", "12", "24"]}]
        entries.push({title: "Startup behavior", scope: "account", key: "startupBehavior", values: ["guide", "mini"]})
        entries.push({title: "Network request timeout", scope: "device", key: "networkTimeoutSeconds", values: [10, 20, 30]})
        entries.push({title: "Active session refresh", scope: "device", key: "refreshSeconds", values: [120, 300, 600]})
        if model.movies = "allowed" or model.series = "allowed"
            entries.push({title: "VOD libraries for this account", scope: "account", key: "vodEnabled", values: [true, false]})
            entries.push({title: "Optional TMDB VOD enrichment", scope: "account", key: "vodTmdbEnabled", values: [true, false]})
        end if
        entries.push({title: "About, licenses and What's New", action: "about"})
        return entries
    end if
    if page = "about" then return [
        {title: "AerioTV Roku " + model.version},
        {title: "Independent Roku client for Dispatcharr"},
        {title: "License notices and third-party attribution", action: "licenses"},
        {title: "What's New", action: "whatsNew"}
    ]
    if page = "whatsNew" then return [
        {title: "Version " + model.version},
        {title: "TV styling: pill navigation, rounded controls and a poster-led library."},
        {title: "Settings now has a category rail and detail pane."},
        {title: "Development visual refresh; see the GitHub releases page for published builds."},
        {title: "Mark this version read", action: "markWhatsNew"}
    ]
    if page = "connection" then return [{title: "Open connection settings (edit / forget / reconnect)", action: "connection"}]
    return []
end function

function remoteSlotEntries(context as string) as object
    slots = []
    if context = "player" then slots = ["okShort", "okLong", "upShort", "downShort", "leftShort", "rightShort", "replay", "playPause", "rewind"]
    if context = "guide" then slots = ["okShort", "leftShort", "leftLong", "rightShort", "rewind", "fastForward", "replay", "playPause"]
    entries = []
    for each slot in slots
        entries.push({title: remoteSlotTitle(slot), action: "remoteSlot", context: context, slot: slot, values: remoteActionChoices(context, slot)})
    end for
    return entries
end function

function remoteSlotTitle(slot as string) as string
    if slot = "okShort" then return "OK"
    if slot = "okLong" then return "OK (hold)"
    if slot = "upShort" then return "Up"
    if slot = "downShort" then return "Down"
    if slot = "leftShort" then return "Left"
    if slot = "leftLong" then return "Left (hold)"
    if slot = "rightShort" then return "Right"
    if slot = "replay" then return "Replay"
    if slot = "playPause" then return "Play/Pause"
    if slot = "fastForward" then return "Fast Forward"
    if slot = "rewind" then return "Rewind"
    return slot
end function

function settingsHubValue(model as object, scope as string, key as string) as dynamic
    if scope = "account" then return model[lcase(key)]
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
    if key = "guideReplayAction"
        if value = "now" then return "Jump to Now"
        return "Open guide options"
    end if
    if key = "playerReplayAction"
        if value = "recent" then return "Open Recent"
        return "Open rewind history"
    end if
    if key = "networkTimeoutSeconds" then return value.toStr() + " seconds"
    if key = "refreshSeconds" then return (value \ 60).toStr() + " minutes"
    if key = "startupBehavior"
        if value = "mini" then return "Resume last channel in mini-player"
        return "Guide (no autoplay)"
    end if
    if type(value) = "Boolean" or type(value) = "roBoolean"
        if value then return "On" else return "Off"
    end if
    return textValue(value)
end function
