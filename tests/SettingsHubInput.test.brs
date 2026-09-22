sub main()
    m.top = {active: true, closed: false, setFocus: sub(value as boolean)
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
    if m.focusRegion <> "rail" or m.railIndex <> 4 or m.top.closed then stop
    if not m.top.focused then stop
    if not handleSettingsKey("back", true) or not m.top.closed then stop
    print "ALL TESTS PASSED"
end sub
