sub main()
    model = {device: normalizeDevicePreferences(invalid), guide: normalizeGuideSettings(invalid), vodEnabled: true, startupBehavior: "guide", whatsNewVersion: "", version: "0.3.29", movies: "denied", series: "unknown", catchup: "allowed"}
    root = settingsHubEntries("", model)
    if root.count() <> 5 or root[1].page <> "player" then stop
    general = settingsHubEntries("general", model)
    if general.count() <> 6 then stop
    model.movies = "allowed"
    if settingsHubEntries("general", model).count() <> 8 then stop
    player = settingsHubEntries("player", model)
    if player[0].key <> "archiveSkipSeconds" or player[0].values[0] <> 60 or player[0].values[2] <> 300 then stop
    if not settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", 120) then stop
    if settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", 15) then stop
    if settingsHubChangeAllowed(model, "device", "apiKey", "private") then stop
    if settingsHubChangeAllowed(model, "guide", "historyDays", 365) then stop
    if not settingsHubChangeAllowed(model, "device", "playerReplayAction", "rewind") then stop
    if settingsHubChangeAllowed(model, "device", "playerReplayAction", "play") then stop
    if not settingsHubChangeAllowed(model, "account", "startupBehavior", "mini") then stop
    if not settingsHubChangeAllowed(model, "device", "networkTimeoutSeconds", 30) then stop
    general = settingsHubEntries("general", model)
    if general[general.count() - 1].action <> "about" then stop
    if settingsHubEntries("about", model).count() < 3 then stop
    model.movies = "denied"
    if settingsHubChangeAllowed(model, "account", "vodEnabled", true) then stop
    model.catchup = "denied"
    if settingsHubEntries("player", model).count() <> 4 then stop
    if settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", 120) then stop
    print "ALL TESTS PASSED"
end sub
