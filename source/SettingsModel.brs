function settingsHubEntries(page as string, model as object) as object
    if settingsHubRestricted(model)
        if not settingsHubPageAllowed(model, page) then page = ""
        if page = "" then return [
            {title: "Live TV", page: "live"}
            {title: "Player", page: "player"}
            {title: "Appearance", page: "appearance"}
            {title: "About", page: "about"}
            {title: "Manage Profiles", page: "manage-profiles"}
        ]
        if page = "manage-profiles" then return [{title: "Manage Profiles", action: "profiles-manage"}]
    end if
    return settingsHubAllEntries(page, model)
end function

function settingsHubRestricted(model as dynamic) as boolean
    if type(model) <> "roAssociativeArray" then return false
    role = model.userRole
    if role = invalid then return false ' Legacy/direct-provider models.
    if type(role) <> "String" and type(role) <> "roString" then return true
    return role <> "admin" and role <> "user"
end function

function settingsHubPageAllowed(model as dynamic, page as string) as boolean
    if not settingsHubRestricted(model) then return true
    for each allowed in ["", "live", "player", "appearance", "about", "whatsNew", "licenses", "manage-profiles"]
        if page = allowed then return true
    end for
    return false
end function

function settingsHubActionAllowed(model as dynamic, action as dynamic) as boolean
    if not settingsHubRestricted(model) then return true
    if model.userRole <> "child" then return false
    if action = invalid then return true ' A setting value, checked separately.
    if type(action) <> "String" and type(action) <> "roString" then return false
    for each allowed in ["profiles-manage", "resetAppearance", "markWhatsNew"]
        if action = allowed then return true
    end for
    return false
end function

function settingsHubAllEntries(page as string, model as object) as object
    if page = ""
        entries = [{title: "Connection", page: "connection"}, {title: "Live TV", page: "live"}, {title: "Player", page: "player"}]
        if model <> invalid
            if model.movies = "allowed" or model.series = "allowed" then entries.push({title: "Movies & TV Shows", page: "movies"})
            if model.dvr = "manage" then entries.push({title: "DVR", page: "dvr"})
        end if
        entries.append([{title: "Appearance", page: "appearance"}, {title: "General", page: "general"}, {title: "Remote control", page: "remote"}, {title: "About", page: "about"}])
        return entries
    end if
    if page = "profiles-baseline"
        if model = invalid then return []
        if type(model.profilesBaseline) = "Boolean" or type(model.profilesBaseline) = "roBoolean"
            if model.profilesBaseline then return [{title: "Open Profiles", action: "profiles-baseline"}]
        end if
        return []
    end if
    if page = "live" then return [
        {title: "Guide history days", scope: "guide", key: "historyDays", values: guideDayChoices()}
        {title: "Guide future days", scope: "guide", key: "futureDays", values: guideDayChoices()}
        {title: "Channel sort", scope: "guide", key: "channelSort", values: ["number", "name", "id"]}
        {title: "Guide density", scope: "guide", key: "guideDensity", values: ["preview", "basic"]}
        {title: "Guide display scale", scope: "guide", key: "guideDisplayScale", values: [90, 100, 110, 120]}
        {title: "Show channel logos", scope: "guide", key: "showLogos", values: [true, false]}
        {title: "Show channel numbers", scope: "guide", key: "showNumbers", values: [true, false]}
        {title: "Show channel names", scope: "guide", key: "showNames", values: [true, false]}
        {title: "Program subtitles / taller Preview", scope: "guide", key: "showSubtitles", values: [true, false]}
        {title: "Logo Size", scope: "guide", key: "channelLogoSize", values: channelLogoSizeChoices()}
        {title: "Rounded Guide Logos", scope: "guide", key: "roundedGuideLogos", values: [true, false]}
        {title: "Rounded Program Cells", scope: "guide", key: "roundedProgramCells", values: [true, false]}
    ]
    if page = "player"
        entries = []
        if model.catchup = "allowed"
            entries.push({title: "Rewind & archive: Skip Back", scope: "device", key: "archiveSkipBackSeconds", values: skipSecondsChoices()})
            entries.push({title: "Rewind & archive: Skip Forward", scope: "device", key: "archiveSkipForwardSeconds", values: skipSecondsChoices()})
        end if
        if model.dvr = "view" or model.dvr = "manage"
            entries.push({title: "In-progress recordings: Skip Back", scope: "device", key: "recordingSkipBackSeconds", values: skipSecondsChoices()})
            entries.push({title: "In-progress recordings: Skip Forward", scope: "device", key: "recordingSkipForwardSeconds", values: skipSecondsChoices()})
        end if
        entries.push({title: "Audio compatibility (next tune)", scope: "device", key: "audioMode", values: ["auto", "direct", "aac"]})
        entries.push({title: "Dispatcharr live transport (next tune)", scope: "device", key: "liveTransport", values: ["auto", "ts", "hls"]})
        entries.push({title: "Live startup retries (next tune)", scope: "device", key: "liveStartupRetries", values: [0, 1, 2, 3]})
        entries.push({title: "Radio Mode by Default (next tune)", scope: "device", key: "radioDefault", values: [true, false]})
        entries.push({title: "Video scale", scope: "device", key: "videoScale", values: ["fit", "fill", "stretch"]})
        return entries
    end if
    if page = "remote" then return [
        {title: "While watching", page: "remotePlayer"}
        {title: "In the TV Guide", page: "remoteGuide"}
        {title: "Play channels from the Guide in", scope: "device", key: "guideTuneInMini", values: [false, true]}
        {title: "Reset remote controls", action: "resetRemoteMap"}
    ]
    if page = "remotePlayer" then return remoteSlotEntries("player")
    if page = "remoteGuide" then return remoteSlotEntries("guide")
    if page = "movies"
        if model.movies <> "allowed" and model.series <> "allowed" then return []
        return [
            {title: "VOD libraries for this account", scope: "account", key: "vodEnabled", values: [true, false]}
            {title: "Optional TMDB VOD enrichment", scope: "account", key: "vodTmdbEnabled", values: [true, false]}
            {title: "Movies & TV Shows display scale", scope: "device", key: "vodDisplayScale", values: vodDisplayScaleChoices()}
        ]
    end if
    if page = "dvr"
        if model.dvr <> "manage" then return []
        return [
            {title: "DVR start early (minutes)", scope: "account", key: "dvrPreRollMinutes", values: [0, 5, 10, 15, 30]}
            {title: "DVR end late (minutes)", scope: "account", key: "dvrPostRollMinutes", values: [0, 5, 10, 15, 30]}
        ]
    end if
    if page = "appearance" then return [
        {title: "Color theme", scope: "device", key: "themePreset", values: ["aerio", "midnight", "sunset", "forest", "lavender", "monochrome", "light"]}
        {title: "Appearance mode", scope: "device", key: "appearanceMode", values: ["dark", "light"]}
        {title: "True Black Background", scope: "device", key: "trueBlack", values: [true, false]}
        {title: "Custom accent (hex RGB)", action: "customAccent"}
        {title: "Panel style", scope: "device", key: "panelStyle", values: ["translucent", "solid"]}
        {title: "Text size", scope: "device", key: "textSize", values: [90, 100, 110, 120]}
        {title: "Secondary text size", scope: "device", key: "subtextSize", values: [90, 100, 110, 120]}
        {title: "Contrast", scope: "device", key: "contrastMode", values: ["standard", "high"]}
        {title: "Reset appearance", action: "resetAppearance"}
        {title: "Group navigation", scope: "guide", key: "groupLayout", values: ["modal", "pills", "sidebar"]}
        {title: "Pop up info card on channel change", scope: "device", key: "infoOnTune", values: [true, false]}
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
        entries.push({title: "Audio Guide (screen reader)", scope: "device", key: "audioGuide", values: [true, false]})
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
        {title: "Settings: browse categories in the left rail; press Right or OK to edit and Back to return."},
        {title: "Movies & TV Shows and DVR preferences have their own categories when available."},
        {title: "Connection, Appearance, General, Remote control and About remain available on this Roku."},
        {title: "Launch and deep-link support remain in testing; see the GitHub release limits."},
        {title: "Mark this version read", action: "markWhatsNew"}
    ]
    if page = "connection"
        entries = [{title: "Open connection settings (edit / forget / reconnect)", action: "connection"}]
        if model <> invalid
            if type(model.profilesBaseline) = "Boolean" or type(model.profilesBaseline) = "roBoolean"
                if model.profilesBaseline then entries.push({title: "Profiles", page: "profiles"})
            end if
            if model.permissionsAvailable = true then entries.push({title: "Account permissions", page: "permissions"})
        end if
        return entries
    end if
    if page = "permissions" then return permissionsPageEntries(model)
    if page = "profiles"
        entries = []
        if model = invalid then return entries
        if model.profilesBaseline <> true then return entries
        if type(model.profileRows) = "roArray"
            for each profile in model.profileRows
                entries.push({title: profile.title, action: "profile-edit", profileId: profile.id})
            end for
        end if
        entries.push({title: "Add Profile", action: "profiles-add"})
        askTitle = "Ask who is watching at launch: Off"
        if model.profilesAskAtLaunch = true then askTitle = "Ask who is watching at launch: On"
        entries.push({title: askTitle, action: "profiles-ask"})
        return entries
    end if
    return []
end function

function remoteSlotEntries(context as string) as object
    slots = []
    if context = "player" then slots = ["okShort", "okLong", "upShort", "downShort", "leftShort", "rightShort", "replay", "playPause", "rewind"]
    if context = "guide" then slots = ["okShort", "leftShort", "leftLong", "rightShort", "rewind", "fastForward", "replay", "playPause", "backShort"]
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
    if slot = "backShort" then return "Back"
    if slot = "fastForward" then return "Fast Forward"
    if slot = "rewind" then return "Rewind"
    return slot
end function

function settingsHubValue(model as object, scope as string, key as string) as dynamic
    if scope = "account" then return model[lcase(key)]
    if type(model[scope]) <> "roAssociativeArray" then return invalid
    values = model[scope]
    if values.doesExist(lcase(key)) then return values[lcase(key)]
    return values[key]
end function

function settingsHubChangeAllowed(model as object, scope as string, key as string, value as dynamic) as boolean
    valueType = type(value)
    primitive = false
    for each allowedType in ["String", "roString", "Boolean", "roBoolean", "Integer", "roInt", "roInteger", "LongInteger", "roLongInteger", "Float", "roFloat", "Double", "roDouble"]
        if valueType = allowedType then primitive = true
    end for
    if not primitive then return false
    if settingsHubRestricted(model)
        if model.userRole <> "child" then return false
    end if
    if scope = "device" and key = "customAccent"
        if GetInterface(value, "ifString") = invalid then return false
        return value = "" or CreateObject("roRegex", "^[0-9A-Fa-f]{6}$", "").isMatch(value)
    end if
    for each page in ["live", "player", "movies", "dvr", "appearance", "general", "remote"]
        for each entry in settingsHubEntries(page, model)
            if entry.scope = scope and entry.key = key
                for each allowed in entry.values
                    sameKind = GetInterface(allowed, "ifString") <> invalid and GetInterface(value, "ifString") <> invalid
                    if (type(allowed) = "Boolean" or type(allowed) = "roBoolean") and (valueType = "Boolean" or valueType = "roBoolean") then sameKind = true
                    numericTypes = ["Integer", "roInt", "roInteger", "LongInteger", "roLongInteger", "Float", "roFloat", "Double", "roDouble"]
                    allowedNumeric = false
                    valueNumeric = false
                    for each numericType in numericTypes
                        if type(allowed) = numericType then allowedNumeric = true
                        if valueType = numericType then valueNumeric = true
                    end for
                    if allowedNumeric and valueNumeric then sameKind = true
                    if sameKind
                        if allowed = value then return true
                    end if
                end for
            end if
        end for
    end for
    return false
end function

function settingsValueText(value as dynamic, key = "" as string) as string
    if key = "channelLogoSize"
        value = normalizeChannelLogoSize(value)
        if value = 25 then return "2.5%"
        return (value \ 10).toStr() + "%"
    end if
    if key = "liveStartupRetries"
        if value = 0 then return "No automatic retries"
        if value = 1 then return "1 retry"
        return value.toStr() + " retries"
    end if
    if key = "liveTransport"
        if value = "auto" then return "Automatic (MPEG-TS)"
        if value = "hls" then return "HLS (test server)"
        return "MPEG-TS"
    end if
    if key = "textSize" or key = "subtextSize" or key = "vodDisplayScale" or key = "guideDisplayScale" then return value.toStr() + "%"
    if key = "themePreset"
        names = {aerio: "AerioTV", midnight: "Midnight", sunset: "Sunset", forest: "Forest", lavender: "Lavender", monochrome: "Monochrome", light: "Neutral"}
        if names.doesExist(textValue(value)) then return names[value]
    end if
    if key = "appearanceMode"
        if value = "light" then return "Light" else return "Dark"
    end if
    if key = "archiveSkipBackSeconds" or key = "archiveSkipForwardSeconds" or key = "recordingSkipBackSeconds" or key = "recordingSkipForwardSeconds"
        return skipChoiceText(value)
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
    if key = "guideTuneInMini"
        if value = true then return "Mini-player (OK again for full screen)"
        return "Full screen"
    end if
    if key = "startupBehavior"
        if value = "mini" then return "Resume last channel in mini-player"
        return "Guide (no autoplay)"
    end if
    if type(value) = "Boolean" or type(value) = "roBoolean"
        if value then return "On" else return "Off"
    end if
    return textValue(value)
end function

' Read-only Dispatcharr permission facts for the active account (e3e.32).
function permissionsPageEntries(model as object) as object
    if model = invalid or model.permissionsAvailable <> true then return []
    level = model.capabilityLevel
    role = "Unknown"
    if type(level) = "Integer" or type(level) = "roInt" or type(level) = "roInteger"
        if level >= 10
            role = "Administrator"
        else if level >= 1
            role = "Standard user"
        else if level = 0
            role = "Streamer"
        end if
    end if
    dvr = {manage: "Manage recordings", view: "View recordings", none: "No access"}
    dvrText = "Unknown"
    if dvr.doesExist(textValue(model.dvr)) then dvrText = dvr[textValue(model.dvr)]
    checked = "Not yet"
    fetchedAt = model.capabilityFetchedAt
    if (type(fetchedAt) = "Integer" or type(fetchedAt) = "roInt" or type(fetchedAt) = "roInteger") and fetchedAt > 0
        minutes = (model.now - fetchedAt) \ 60
        if minutes < 1
            checked = "Just now"
        else if minutes = 1
            checked = "1 minute ago"
        else
            checked = minutes.toStr() + " minutes ago"
        end if
    end if
    entries = [{title: "Role: " + role}, {title: "Movies: " + permissionText(model.movies)}, {title: "TV Shows: " + permissionText(model.series)}, {title: "Catch-up: " + permissionText(model.catchup)}, {title: "DVR: " + dvrText}]
    if textValue(model.serverVersion) <> "" then entries.push({title: "Server: Dispatcharr " + textValue(model.serverVersion)})
    entries.push({title: "Last checked: " + checked})
    entries.push({title: "Refresh permissions", action: "refreshPermissions"})
    return entries
end function

function permissionText(value as dynamic) as string
    if value = "allowed" then return "Allowed"
    if value = "denied" then return "Not allowed"
    return "Unknown"
end function
