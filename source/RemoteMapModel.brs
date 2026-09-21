function defaultRemoteMap() as object
    return {version: 1, preset: "default", player: {}, guide: {}}
end function

function resetRemoteMap() as object
    return defaultRemoteMap()
end function

function normalizeRemoteMap(raw as dynamic) as object
    result = defaultRemoteMap()
    if type(raw) <> "roAssociativeArray" then return result
    if raw.version <> 1 or remoteMapText(raw.preset) <> "custom" then return result
    result.preset = "custom"
    result.player = normalizeRemoteContext(raw.player, "player")
    result.guide = normalizeRemoteContext(raw.guide, "guide")
    return result
end function

function normalizeRemoteContext(raw as dynamic, context as string) as object
    result = {}
    if type(raw) <> "roAssociativeArray" then return result
    for each slot in raw
        action = remoteMapText(raw[slot])
        if remoteActionAllowed(context, slot, action) then result[slot] = action
    end for
    return result
end function

function resolveRemoteAction(map as object, context as string, slot as string) as string
    if remoteActionChoices(context, slot).count() = 0 then return ""
    normalized = normalizeRemoteMap(map)
    if normalized.preset = "custom" and normalized[context].doesExist(slot) then return normalized[context][slot]
    return defaultRemoteAction(context, slot)
end function

function setRemoteAction(map as object, context as string, slot as string, action as string) as object
    result = normalizeRemoteMap(map)
    if not remoteActionAllowed(context, slot, action) then return result
    result.preset = "custom"
    result[context][slot] = action
    return result
end function

function remoteActionAllowed(context as string, slot as string, action as string) as boolean
    for each allowed in remoteActionChoices(context, slot)
        if action = allowed then return true
    end for
    return false
end function

function remoteActionChoices(context as string, slot as string) as object
    context = lcase(context)
    slot = lcase(slot)
    if context = "player"
        if slot = "okshort" then return ["toggleInfo", "openOptions", "none"]
        if slot = "oklong" then return ["openOptions", "none"]
        if slot = "upshort" or slot = "downshort" or slot = "leftshort" or slot = "rightshort" then return ["channelUp", "channelDown", "recentChannels", "channelList", "lastChannel", "toggleInfo", "minimizeToGuide", "none"]
        if slot = "replay" then return ["recentChannels", "rewindHistory", "none"]
        if slot = "playpause" then return ["playPause", "none"]
        if slot = "rewind" then return ["rewindHistory", "recentChannels", "none"]
    else if context = "guide"
        if slot = "okshort" then return ["activateSelection", "programDetails", "none"]
        if slot = "leftshort" or slot = "rightshort" then return ["navigate", "jumpToNow", "jumpToTop", "openGroups", "openOptions", "none"]
        if slot = "leftlong" then return ["openGroups", "none"]
        if slot = "rewind" or slot = "fastforward" then return ["pageUp", "pageDown", "jumpToNow", "jumpToTop", "none"]
        if slot = "replay" then return ["jumpToNow", "openOptions", "none"]
        if slot = "playpause" then return ["resumePlayer", "none"]
    end if
    return []
end function

function defaultRemoteAction(context as string, slot as string) as string
    context = lcase(context)
    slot = lcase(slot)
    if context = "player"
        if slot = "okshort" then return "toggleInfo"
        if slot = "oklong" then return "openOptions"
        if slot = "upshort" then return "channelUp"
        if slot = "downshort" then return "channelDown"
        if slot = "leftshort" then return "channelList"
        if slot = "rightshort" then return "lastChannel"
        if slot = "replay" then return "recentChannels"
        if slot = "playpause" then return "playPause"
        if slot = "rewind" then return "rewindHistory"
    else if context = "guide"
        if slot = "okshort" then return "activateSelection"
        if slot = "leftshort" or slot = "rightshort" then return "navigate"
        if slot = "leftlong" then return "openGroups"
        if slot = "rewind" then return "pageUp"
        if slot = "fastforward" then return "pageDown"
        if slot = "replay" then return "jumpToNow"
        if slot = "playpause" then return "resumePlayer"
    end if
    return ""
end function

function remoteMapText(value as dynamic) as string
    kind = type(value)
    if kind = "String" or kind = "roString" then return value
    return ""
end function

function remoteActionText(action as string) as string
    labels = {toggleInfo: "Show/hide player info", openOptions: "Open options", channelUp: "Channel up", channelDown: "Channel down", recentChannels: "Recently watched", channelList: "Channel list", lastChannel: "Previous channel", minimizeToGuide: "Return to TV Guide", rewindHistory: "Rewind history", playPause: "Play/Pause", activateSelection: "Play selected channel", programDetails: "Program details", navigate: "Move focus", jumpToNow: "Jump to Now", jumpToTop: "Jump to top channel", openGroups: "Open groups", pageUp: "Page channels up", pageDown: "Page channels down", resumePlayer: "Return to player", none: "Do nothing"}
    if labels.doesExist(action) then return labels[action]
    return action
end function
