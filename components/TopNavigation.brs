sub init()
    m.top.focusable = true
    m.items = []
    m.cells = []
    m.index = -1
end sub

sub configureNavigation()
    focused = m.top.selected
    if m.top.active and m.index >= 0 and m.index < m.items.count() then focused = m.items[m.index].id
    m.items = m.top.items
    m.top.removeChildrenIndex(m.top.getChildCount(), 0)
    m.cells = []
    start = 0
    if m.top.availableWidth > 0 then start = uiCenteredStripX(m.items.count(), 200, 12, m.top.availableWidth)
    for i = 0 to m.items.count() - 1
        x = start + i * 212
        bg = uiSurface(m.top, x, 0, 200, 50, 25, "0x00000000")
        fill = uiSurface(m.top, x + 3, 3, 194, 44, 22, "0x00000000")
        icon = m.top.createChild("Poster")
        icon.width = 24
        icon.height = 24
        icon.uri = "pkg:/images/ui-icon-" + m.items[i].id + ".png"
        label = uiLabel(m.top, m.items[i].label, 0, 0, 0, 50, uiTypeSize("button"))
        content = uiPillContent(200, 50, label.localBoundingRect().width, 24)
        icon.translation = [x + content.iconX, content.iconY]
        label.translation = [x + content.textX, 0]
        label.width = content.textWidth
        label.horizAlign = "center"
        label.vertAlign = "center"
        m.cells.push({bg: bg, fill: fill, label: label, icon: icon})
    end for
    m.index = navigationFirst(m.items, focused)
    drawNavigation()
end sub

sub activateNavigation()
    if m.top.active
        m.index = navigationFirst(m.items, m.top.selected)
        if m.index < 0
            m.top.active = false
            m.top.exitRequested = "down"
            return
        end if
        m.top.setFocus(true)
    end if
    drawNavigation()
end sub

sub drawNavigation()
    if m.cells = invalid then return
    for i = 0 to m.cells.count() - 1
        cell = m.cells[i]
        style = uiControlStyle(m.top.style, m.items[i].id = m.top.selected, m.top.active and i = m.index, m.items[i].enabled = true, false)
        uiSetColor(cell.bg, style.ring)
        uiSetColor(cell.fill, style.fill)
        cell.bg.focusScale = style.scale
        cell.fill.focusScale = style.scale
        uiSetColor(cell.label, style.ink)
        uiSetColor(cell.icon, style.ink, "blendColor")
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not m.top.active or not press then return false
    if key = "left" then m.index = navigationMove(m.items, m.index, -1)
    if key = "right" then m.index = navigationMove(m.items, m.index, 1)
    if key = "OK" and m.index >= 0
        choice = m.items[m.index].id
        m.top.active = false
        m.top.selection = choice
        return true
    end if
    if key = "back" or key = "down" or (key = "up" and m.top.allowUp)
        m.top.active = false
        m.top.exitRequested = key
        return true
    end if
    if key = "options"
        m.top.active = false
        return false
    end if
    drawNavigation()
    return true
end function

function handleNavigationKey(key as string, press as boolean) as boolean
    return onKeyEvent(key, press)
end function
