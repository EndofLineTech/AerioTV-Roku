sub seedUiAuditSettings(page as string)
    m.page = page
    m.choice = invalid
    m.stack = []
    renderSettings()
    m.focusRegion = "detail"
    m.list.jumpToItem = 0
    m.list.setFocus(true)
    drawSettingsRail()
end sub
