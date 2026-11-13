sub main()
    model = {userRole: "child", movies: "allowed", series: "allowed", dvr: "manage", catchup: "allowed"}
    root = settingsHubEntries("", model)
    check(root.count() = 5 and root[0].page = "live" and root[1].page = "player" and root[2].page = "appearance" and root[3].page = "about" and root[4].page = "manage-profiles", "Child Settings contains only the four permitted pages and protected management footer")
    for each page in ["connection", "movies", "dvr", "general", "remote", "remotePlayer", "remoteGuide", "sync", "developer"]
        check(not settingsHubPageAllowed(model, page) and settingsHubEntries(page, model)[0].page = "live", "hidden Child deep links return to the restricted Settings root")
    end for
    check(not settingsHubChangeAllowed(model, "device", "networkTimeoutSeconds", 30), "forged current-session Child events cannot edit hidden network settings")
    check(not settingsHubChangeAllowed(model, "account", "vodEnabled", true), "Child cannot change library controls despite a permitted server library")
    check(not settingsHubChangeAllowed(model, "account", "dvrPreRollMinutes", 5), "Child cannot change DVR controls despite a manage-capable server account")
    check(not settingsHubChangeAllowed(model, "device", "themePreset", {}), "malformed setting values are denied without comparing objects to primitive choices")
    check(not settingsHubChangeAllowed(model, "device", "themePreset", true) and not settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", "120"), "wrong primitive setting types cannot impersonate permitted values")
    check(settingsHubChangeAllowed(model, "device", "themePreset", "midnight") and settingsHubChangeAllowed(model, "device", "archiveSkipSeconds", 120), "Child keeps its allowed appearance and player controls")
    for each action in ["connection", "setRemoteAction", "resetRemoteMap", "unknown-action"]
        check(not settingsHubActionAllowed(model, action), "Child handler admission rejects hidden action shortcuts")
    end for
    check(settingsHubActionAllowed(model, "profiles-manage") and settingsHubActionAllowed(model, "resetAppearance") and settingsHubActionAllowed(model, invalid), "protected management and allowed setting changes remain usable")
    model.userRole = "restricted"
    check(settingsHubEntries("", model).count() = 5, "unknown scoped identity fails closed to restricted navigation")
    check(not settingsHubActionAllowed(model, "profiles-manage") and not settingsHubChangeAllowed(model, "device", "customAccent", "1AC4D8"), "unknown authority cannot borrow the Child's management or preference permissions")
    model.userRole = "user"
    check(settingsHubEntries("", model)[0].page = "connection" and settingsHubPageAllowed(model, "general"), "Standard keeps the existing full local Settings contract")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
