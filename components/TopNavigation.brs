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
    for i = 0 to m.items.count() - 1
        x = i * 212
        bg = uiRect(m.top, x, 0, 200, 50, "0x0D1E35FF")
        label = uiLabel(m.top, m.items[i].label, x + 10, 9, 180, 36, 28)
        label.horizAlign = "center"
        underline = uiRect(m.top, x + 12, 48, 176, 3, "0x1AC4D8FF")
        m.cells.push({bg: bg, label: label, underline: underline})
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
        cell.bg.color = "0x0D1E35FF"
        cell.label.color = "0xE8F3FAFF"
        if m.items[i].enabled <> true then cell.label.color = "0x627384FF"
        cell.underline.visible = m.items[i].id = m.top.selected
        if m.top.active and i = m.index
            cell.bg.color = "0x1AC4D8FF"
            cell.label.color = "0x0A1628FF"
        end if
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
