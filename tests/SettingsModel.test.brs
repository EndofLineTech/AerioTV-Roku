sub main()
    model = {device: normalizeDevicePreferences(invalid), guide: normalizeGuideSettings(invalid), vodEnabled: true, startupBehavior: "guide", whatsNewVersion: "", version: "0.3.29", movies: "denied", series: "unknown", catchup: "allowed"}
    root = settingsHubEntries("", model)
    if root.count() <> 6 or root[1].page <> "player" or root[2].page <> "remote" then stop
    general = settingsHubEntries("general", model)
    if general.count() <> 5 then stop
    model.movies = "allowed"
    if settingsHubEntries("general", model).count() <> 7 then stop
    player = settingsHubEntries("player", model)
    if player[0].key <> "archiveSkipSeconds" or player[0].values[0] <> 60 or player[0].values[2] <> 300 then stop
    if not settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", 120) then stop
    if settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", 15) then stop
    if settingsHubChangeAllowed(model, "device", "apiKey", "private") then stop
    if settingsHubChangeAllowed(model, "guide", "historyDays", 365) then stop
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
    if general[general.count() - 1].action <> "about" then stop
    if settingsHubEntries("about", model).count() < 3 then stop
    model.movies = "denied"
    if settingsHubChangeAllowed(model, "account", "vodEnabled", true) then stop
    model.catchup = "denied"
    if settingsHubEntries("player", model).count() <> 2 then stop
    if settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", 120) then stop
    print "ALL TESTS PASSED"
end sub
