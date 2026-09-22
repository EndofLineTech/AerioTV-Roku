sub main()
    m.top = {closed: false, setFocus: sub(value as boolean)
        m.focused = value
    end sub}
    m.list = {jumpToItem: -1, setFocus: sub(value as boolean)
        m.focused = value
    end sub}
    m.railItems = settingsHubEntries("", {})
    m.railCells = []
    for each item in m.railItems
        m.railCells.push({ring: {}, fill: {}, label: {}})
    end for
    m.railSelected = 0
    m.railIndex = 0
    m.focusRegion = "rail"
    m.page = "live"
    m.renders = 0
    m.choice = {value: "old"}
    m.stack = [{page: "old"}]
    handleSettingsRailKey("up", true)
    if m.railIndex <> 0 then stop
    handleSettingsRailKey("down", true)
    if m.railIndex <> 1 or m.page <> "live" then stop ' focus does not commit category
    handleSettingsRailKey("right", true)
    if m.page <> "player" or m.focusRegion <> "detail" or not m.list.focused then stop
    if m.stack.count() <> 0 or m.choice <> invalid or m.list.jumpToItem <> 0 then stop
    if handleSettingsRailKey("down", true) then stop ' detail keeps its own input
    focusSettingsRail()
    if m.railIndex <> 1 or not m.top.focused then stop
    handleSettingsRailKey("down", true)
    handleSettingsRailKey("OK", true)
    if m.page <> "remote" or m.renders <> 2 then stop
    focusSettingsRail()
    if handleSettingsRailKey("home", true) or handleSettingsRailKey("options", true) then stop
    handleSettingsRailKey("back", true)
    if not m.top.closed then stop
    before = m.page
    selectSettingsCategory(99)
    if m.page <> before then stop
    print "ALL TESTS PASSED"
end sub

sub renderSettings()
    m.renders++
end sub
