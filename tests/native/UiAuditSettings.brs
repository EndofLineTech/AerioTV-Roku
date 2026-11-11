sub seedUiAuditSettings(page as string)
    route = page
    if route = "choice" or route = "reset" then page = "appearance"
    if route = "remote-player" or route = "remote-guide" then page = "remote"
    m.page = page
    for i = 0 to m.railItems.count() - 1
        if m.railItems[i].page = page
            m.railSelected = i
            m.railIndex = i
        end if
    end for
    m.choice = invalid
    m.stack = []
    renderSettings()
    m.focusRegion = "detail"
    m.list.jumpToItem = 0
    m.list.setFocus(true)
    drawSettingsRail()
    if route = "choice" or route = "remote-player" then selectSetting(0)
    if route = "remote-guide" then selectSetting(1)
    if route = "reset"
        for i = 0 to m.items.count() - 1
            if m.items[i].action = "resetAppearance"
                selectSetting(i)
                exit for
            end if
        end for
    end if
end sub
