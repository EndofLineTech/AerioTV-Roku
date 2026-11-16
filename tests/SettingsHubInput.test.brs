sub main()
    m.top = {active: true, closed: false, setFocus: sub(value as boolean)
        m.focused = value
    end sub}
    m.list = {setFocus: sub(value as boolean)
        m.focused = value
    end sub}
    m.page = "about"
    m.items = [{title: "Version 0.3.38"}, {title: "License text"}]
    m.choice = invalid
    m.stack = []
    m.railCells = []
    m.railIndex = 0
    m.railSelected = 4
    m.focusRegion = "detail"
    selectSetting(0)
    selectSetting(1)
    if m.choice <> invalid or m.stack.count() <> 0 then stop
    if not handleSettingsKey("back", true) then stop
    if m.focusRegion <> "rail" or m.railIndex <> 4 or m.top.closed or m.list.focused then stop
    if not m.top.focused then stop
    if not handleSettingsKey("back", true) or not m.top.closed then stop
    m.top.model = {account: "example-account"}
    m.items = [{title: "Open Profiles", action: "profiles-baseline"}]
    m.userSessionId = "example-baseline-session"
    selectSetting(0)
    if m.top.selection.action <> "profiles-baseline" or m.top.selection.account <> "example-account" then stop
    if m.top.selection.aeriosession <> m.userSessionId or m.choice <> invalid or m.stack.count() <> 0 then stop
    m.items = [{title: "Example", action: "profile-edit", profileId: "local-profile"}]
    selectSetting(0)
    if m.top.selection.profileId <> "local-profile" or m.top.selection.action <> "profile-edit" then stop
    print "ALL TESTS PASSED"
end sub
