sub buildSettingsRail()
    m.railItems = settingsHubEntries("", invalid)
    m.railCells = []
    ' Reserve cells for every capability-gated category. Refresh their text
    ' and visibility on render rather than growing the SceneGraph each visit.
    for i = 0 to 8
        y = 211 + i * 78
        fill = uiSurface(m.top, 98, y + 2, 408, 70, 35, "0x00000000")
        icon = m.top.createChild("Poster")
        icon.translation = [122, y + 25]
        icon.width = 24
        icon.height = 24
        label = uiButtonLabel(m.top, "", 98, y + 2, 408, 70, uiTypeSize("section"))
        m.railCells.push({fill: fill, icon: icon, label: label})
    end for
    m.railIndex = 0
    m.railSelected = 0
    m.focusRegion = "rail"
end sub

sub drawSettingsRail()
    if m.railCells = invalid then return
    ' The detail list keeps its remembered row when focus is in the rail.
    ' Hide that stale focus wash until the user enters the detail pane.
    if m.list <> invalid
        tint = "0x00000000"
        if m.focusRegion = "detail" then tint = "0x365163FF"
        uiSetColor(m.list, tint, "focusBitmapBlendColor")
    end if
    for i = 0 to m.railCells.count() - 1
        cell = m.railCells[i]
        visible = i < m.railItems.count()
        cell.fill.visible = visible
        cell.icon.visible = visible
        cell.label.visible = visible
        if visible
            item = m.railItems[i]
            icons = {connection: "channels", live: "live", player: "play", movies: "vod", dvr: "recent", appearance: "categories", general: "settings", remote: "options", about: "settings"}
            cell.icon.uri = "pkg:/images/ui-icon-" + icons[item.page] + ".png"
            cell.label.text = item.title
            cell.label.width = 0
            content = uiPillContent(408, 70, cell.label.localBoundingRect().width, 24)
            cell.icon.translation = [98 + content.iconX, cell.fill.translation[1] + content.iconY]
            cell.label.translation = [98 + content.textX, cell.fill.translation[1]]
            cell.label.width = content.textWidth
            style = uiControlStyle("row", i = m.railSelected, m.focusRegion = "rail" and i = m.railIndex, true, false)
            uiSetColor(cell.fill, style.fill)
            uiSetColor(cell.icon, style.ink, "blendColor")
            uiSetColor(cell.label, style.ink)
        end if
    end for
end sub

sub focusSettingsRail()
    m.focusRegion = "rail"
    m.railIndex = m.railSelected
    m.list.setFocus(false)
    m.top.setFocus(true)
    drawSettingsRail()
    if m.railItems <> invalid then uiAnnounce(m.railItems[m.railIndex].title)
end sub

sub selectSettingsCategory(index as integer)
    if index < 0 or index >= m.railItems.count() then return
    previewSettingsCategory(index)
    m.focusRegion = "detail"
    m.list.jumpToItem = 0
    m.list.setFocus(true)
    drawSettingsRail()
end sub

sub previewSettingsCategory(index as integer)
    if index < 0 or index >= m.railItems.count() then return
    m.railIndex = index
    if m.railSelected = index then return
    m.railSelected = index
    m.page = m.railItems[index].page
    m.choice = invalid
    m.stack = []
    renderSettings()
end sub

function handleSettingsRailKey(key as string, press as boolean) as boolean
    if m.focusRegion <> "rail" or not press then return false
    if key = "home" or key = "options" then return false
    previous = m.railIndex
    if key = "up" and m.railIndex > 0 then previewSettingsCategory(m.railIndex - 1)
    if key = "down" and m.railIndex < m.railItems.count() - 1 then previewSettingsCategory(m.railIndex + 1)
    if m.railIndex <> previous then uiAnnounce(m.railItems[m.railIndex].title)
    if key = "OK" or key = "right"
        selectSettingsCategory(m.railIndex)
        return true
    end if
    if key = "back" then m.top.closed = true
    drawSettingsRail()
    return true
end function
