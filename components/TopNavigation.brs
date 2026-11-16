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
    width = m.top.pillWidth
    gap = m.top.pillGap
    if m.top.availableWidth > 0 then start = uiCenteredStripX(m.items.count(), width, gap, m.top.availableWidth)
    for i = 0 to m.items.count() - 1
        x = start + i * (width + gap)
        bg = uiSurface(m.top, x, 0, width, 50, 25, "0x00000000")
        fill = uiSurface(m.top, x + 3, 3, width - 6, 44, 22, "0x00000000")
        ' Overlap the rounded caps with the center while scaling between pills.
        bg.cornerOverlap = 2
        fill.cornerOverlap = 2
        icon = m.top.createChild("Poster")
        icon.width = 24
        icon.height = 24
        iconName = m.items[i].id
        if iconName = "dvr" then iconName = "recent"
        if iconName = "profiles" then iconName = "settings"
        favoriteIcon = invalid
        if iconName = "favorite"
            icon.visible = false
            favoriteIcon = uiLabel(m.top, "★", 0, 0, 24, 50, m.top.labelFontSize)
            favoriteIcon.horizAlign = "center"
            favoriteIcon.vertAlign = "center"
        else
            icon.uri = "pkg:/images/ui-icon-" + iconName + ".png"
        end if
        label = uiLabel(m.top, m.items[i].label, 0, 0, 0, 50, m.top.labelFontSize)
        content = uiPillContent(width, 50, label.localBoundingRect().width, 24)
        if width < 200
            ' Compact library tabs keep full, centered names at large text sizes.
            icon.visible = false
            if favoriteIcon <> invalid then favoriteIcon.visible = false
            content = uiPillContent(width, 50, 0, 0)
        end if
        icon.translation = [x + content.iconX, content.iconY]
        avatar = invalid
        mark = invalid
        if type(m.items[i].avatarInitial) = "String" or type(m.items[i].avatarInitial) = "roString"
            icon.visible = false
            avatar = uiSurface(m.top, x + content.iconX, content.iconY, 24, 24, 12, m.items[i].avatarFill)
            mark = uiLabel(m.top, m.items[i].avatarInitial, x + content.iconX, content.iconY, 24, 24, 18, m.items[i].avatarInk)
            mark.horizAlign = "center"
            mark.vertAlign = "center"
            if m.items[i].avatarUri <> "" and m.items[i].avatarUri <> invalid
                mark.visible = false
                avatarPoster = m.top.createChild("Poster")
                avatarPoster.uri = m.items[i].avatarUri
                avatarPoster.width = 20
                avatarPoster.height = 20
                avatarPoster.translation = [x + content.iconX + 2, content.iconY + 2]
                avatarPoster.blendColor = m.items[i].avatarInk
            end if
        end if
        if favoriteIcon <> invalid then favoriteIcon.translation = [x + content.iconX, 0]
        uiCenterLabel(label, x + content.textX, 0, content.textWidth, 50)
        m.cells.push({bg: bg, fill: fill, label: label, icon: icon, favoriteIcon: favoriteIcon, avatar: avatar, avatarMark: mark})
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
        ' An invisible border still composites dark edge pixels on Roku while
        ' the two surfaces animate independently. Do not draw it when clear.
        cell.bg.visible = style.ring <> "0x00000000"
        uiSetColor(cell.bg, style.ring)
        uiSetColor(cell.fill, style.fill)
        cell.bg.focusScale = style.scale
        cell.fill.focusScale = style.scale
        uiSetColor(cell.label, style.ink)
        uiSetColor(cell.icon, style.ink, "blendColor")
        if cell.favoriteIcon <> invalid then uiSetColor(cell.favoriteIcon, style.ink)
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
