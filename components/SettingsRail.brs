sub buildSettingsRail()
    m.railItems = settingsHubEntries("", m.top.model)
    m.railCells = []
    for i = 0 to m.railItems.count() - 1
        y = 235 + i * 94
        ring = uiSurface(m.top, 96, y, 412, 82, 14, "0x00000000")
        fill = uiSurface(m.top, 98, y + 2, 408, 78, 12, "0x00000000")
        label = uiLabel(m.top, m.railItems[i].title, 122, y + 23, 364, 38, uiTypeSize("section"))
        m.railCells.push({ring: ring, fill: fill, label: label})
    end for
    m.railIndex = 0
    m.railSelected = 0
    m.focusRegion = "rail"
end sub

sub drawSettingsRail()
    if m.railCells = invalid then return
    for i = 0 to m.railCells.count() - 1
        cell = m.railCells[i]
        style = uiControlStyle("row", i = m.railSelected, m.focusRegion = "rail" and i = m.railIndex)
        cell.ring.color = style.ring
        cell.fill.color = style.fill
        cell.label.color = style.ink
        cell.ring.focusScale = style.scale
        cell.fill.focusScale = style.scale
    end for
end sub

sub focusSettingsRail()
    m.focusRegion = "rail"
    m.railIndex = m.railSelected
    m.top.setFocus(true)
    drawSettingsRail()
end sub

sub selectSettingsCategory(index as integer)
    if index < 0 or index >= m.railItems.count() then return
    m.railIndex = index
    m.railSelected = index
    m.page = m.railItems[index].page
    m.choice = invalid
    m.stack = []
    m.focusRegion = "detail"
    renderSettings()
    m.list.jumpToItem = 0
    m.list.setFocus(true)
    drawSettingsRail()
end sub

function handleSettingsRailKey(key as string, press as boolean) as boolean
    if m.focusRegion <> "rail" or not press then return false
    if key = "home" or key = "options" then return false
    if key = "up" and m.railIndex > 0 then m.railIndex--
    if key = "down" and m.railIndex < m.railItems.count() - 1 then m.railIndex++
    if key = "OK" or key = "right"
        selectSettingsCategory(m.railIndex)
        return true
    end if
    if key = "back" then m.top.closed = true
    drawSettingsRail()
    return true
end function
