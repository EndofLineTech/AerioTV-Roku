sub main()
    model = {device: normalizeDevicePreferences(invalid), guide: normalizeGuideSettings(invalid), vodEnabled: true, startupBehavior: "guide", whatsNewVersion: "", version: "0.3.29", movies: "denied", series: "unknown", catchup: "allowed"}
    root = settingsHubEntries("", model)
    if root.count() <> 7 or root[0].page <> "connection" or root[1].page <> "live" or root[2].page <> "player" or root[6].page <> "about" then stop
    if root[3].page <> "appearance" or root[5].page <> "remote" then stop
    general = settingsHubEntries("general", model)
    if general.count() <> 5 then stop
    model.movies = "allowed"
    root = settingsHubEntries("", model)
    if root.count() <> 8 or root[3].page <> "movies" then stop
    if settingsHubEntries("general", model).count() <> 5 then stop
    if settingsHubEntries("movies", model).count() <> 2 then stop
    model.dvr = "manage"
    root = settingsHubEntries("", model)
    if root.count() <> 9 or root[4].page <> "dvr" then stop
    if settingsHubEntries("dvr", model).count() <> 2 then stop
    if settingsHubEntries("general", model).count() <> 5 then stop
    player = settingsHubEntries("player", model)
    if player[0].key <> "archiveSkipSeconds" or player[0].values[0] <> 60 or player[0].values[2] <> 300 then stop
    if player[2].key <> "liveTransport" or not settingsHubChangeAllowed(model, "device", "liveTransport", "hls") then stop
    if player[3].key <> "liveStartupRetries" or not settingsHubChangeAllowed(model, "device", "liveStartupRetries", 3) then stop
    if not settingsHubChangeAllowed(model, "device", "liveStartupRetries", 0) then stop
    if settingsHubChangeAllowed(model, "device", "liveStartupRetries", 4) then stop
    if settingsValueText(0, "liveStartupRetries") <> "No automatic retries" then stop
    if settingsValueText(3, "liveStartupRetries") <> "3 retries" then stop
    if settingsHubChangeAllowed(model, "device", "liveTransport", "unsupported") then stop
    if not settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", 120) then stop
    if settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", 15) then stop
    if settingsHubChangeAllowed(model, "device", "apiKey", "private") then stop
    theme = normalizeDevicePreferences(invalid)
    theme["themePreset"] = "midnight"
    if normalizeDevicePreferences(theme).themePreset <> "midnight" then stop
    if settingsHubValue({device: theme}, "device", "themePreset") <> "midnight" then stop
    if not settingsHubChangeAllowed(model, "device", "themePreset", "midnight") then stop
    oldDevice = ParseJson("{" + chr(34) + "themePreset" + chr(34) + ":" + chr(34) + "aerio" + chr(34) + "," + chr(34) + "themepreset" + chr(34) + ":" + chr(34) + "aerio" + chr(34) + "}")
    updatedDevice = setCanonicalPreference(oldDevice, "themePreset", "midnight")
    if normalizeDevicePreferences(updatedDevice).themePreset <> "midnight" then stop
    if updatedDevice.keys().count() <> 1 or updatedDevice["themePreset"] <> "midnight" then stop
    accountAlias = ParseJson("{" + chr(34) + "vodEnabled" + chr(34) + ":true," + chr(34) + "vodenabled" + chr(34) + ":true}")
    account = setCanonicalPreference(accountAlias, "vodEnabled", false)
    if account.keys().count() <> 1 or account["vodEnabled"] <> false then stop
    if settingsHubChangeAllowed(model, "guide", "historyDays", 365) then stop
    live = settingsHubEntries("live", model)
    if live[7].key <> "showSubtitles" or live[7].values[0] <> true or live[7].values[1] <> false then stop
    if instr(1, live[7].title, "Preview") = 0 then stop
    remote = settingsHubEntries("remote", model)
    if remote.count() <> 3 or remote[0].page <> "remotePlayer" then stop
    remotePlayer = settingsHubEntries("remotePlayer", model)
    if remotePlayer.count() <> 9 or remotePlayer[0].slot <> "okShort" then stop
    remoteGuide = settingsHubEntries("remoteGuide", model)
    if remoteGuide.count() <> 8 or remoteGuide[0].slot <> "okShort" then stop
    if settingsHubEntries("remotePlayer", model)[0].values[0] <> "toggleInfo" then stop
    if not settingsHubChangeAllowed(model, "account", "startupBehavior", "mini") then stop
    if not settingsHubChangeAllowed(model, "device", "networkTimeoutSeconds", 30) then stop
    general = settingsHubEntries("general", model)
    if general[general.count() - 1].key <> "audioGuide" then stop
    if settingsHubEntries("about", model).count() < 3 then stop
    model.movies = "denied"
    model.series = "denied"
    if settingsHubChangeAllowed(model, "account", "vodEnabled", true) then stop
    if settingsHubChangeAllowed(model, "account", "dvrPreRollMinutes", 5) <> true then stop
    model.dvr = "denied"
    if settingsHubChangeAllowed(model, "account", "dvrPreRollMinutes", 5) then stop
    model.catchup = "denied"
    if settingsHubEntries("player", model).count() <> 4 then stop
    if settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", 120) then stop
    model.catchup = "allowed"
    model.movies = "allowed"
    model.dvr = "manage"
    seen = {}
    for each category in settingsHubEntries("", model)
        for each setting in settingsHubEntries(category.page, model)
            if setting.key <> invalid
                id = setting.scope + ":" + setting.key
                if seen.doesExist(id) then stop ' a setting must have one canonical category
                seen[id] = true
                for each value in setting.values
                    if not settingsHubChangeAllowed(model, setting.scope, setting.key, value) then stop
                end for
            end if
        end for
    end for
    for each required in ["guide:historyDays", "device:audioMode", "account:vodEnabled", "account:dvrPreRollMinutes", "device:textSize", "device:networkTimeoutSeconds"]
        if not seen.doesExist(required) then stop
    end for
    m.devicePreferences = normalizeDevicePreferences(invalid)
    m.preferenceStore = {device: m.devicePreferences}
    m.saveOk = true
    m.applyCount = 0
    custom = setRemoteAction(defaultRemoteMap(), "guide", "replay", "openOptions")
    if not persistRemoteMap(custom) then stop
    if resolveRemoteAction(m.published.remoteMap, "guide", "replay") <> "openOptions" then stop
    if m.applyCount <> 1 then stop
    m.saveOk = false
    if persistRemoteMap(resetRemoteMap()) then stop
    if resolveRemoteAction(m.published.remoteMap, "guide", "replay") <> "openOptions" then stop
    if resolveRemoteAction(m.preferenceStore.device.remoteMap, "guide", "replay") <> "openOptions" then stop
    m.saveOk = true
    if not persistRemoteMap(resetRemoteMap()) then stop
    if resolveRemoteAction(m.published.remoteMap, "guide", "replay") <> "jumpToNow" then stop
    if m.applyCount <> 3 then stop
    print "ALL TESTS PASSED"
end sub

function persistPreferences() as boolean
    m.preferenceStore.device = m.devicePreferences
    return m.saveOk
end function

sub applyDevicePreferences()
    m.published = copyJson(m.devicePreferences)
    m.applyCount++
end sub
