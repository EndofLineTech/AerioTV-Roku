sub init()
    m.index = 0
    m.lastAnnouncedIndex = -1
    m.actions = ["play", "channels", "recent", "minimize", "options", "stop"]
    m.labels = ["Pause", "Channels", "Recent", "Minimize", "Options", "Stop"]
    m.cells = []
    for i = 0 to 5
        x = 540 + i * 140
        fill = uiSurface(m.top, x + 40, 598, 60, 60, 30, "0x263549EE")
        icon = m.top.createChild("Poster")
        icon.translation = [x + 54, 612]
        icon.width = 32
        icon.height = 32
        icon.uri = "pkg:/images/ui-icon-" + m.actions[i] + ".png"
        label = uiLabel(m.top, m.labels[i], x, 661, 140, 28, uiTypeSize("caption"))
        label.horizAlign = "center"
        label.vertAlign = "center"
        m.cells.push({fill: fill, label: label, icon: icon})
    end for
    draw()
end sub

sub onActive()
    if m.top.active
        m.top.visible = true
        m.index = 0
        m.top.setFocus(true)
    end if
    draw()
end sub

sub draw()
    if m.cells = invalid then return
    for i = 0 to m.cells.count() - 1
        cell = m.cells[i]
        focused = m.top.active and i = m.index
        style = uiControlStyle("action", false, focused)
        uiSetColor(cell.fill, style.fill)
        cell.fill.focusScale = style.scale
        uiSetColor(cell.icon, style.ink, "blendColor")
        cell.label.visible = focused
    end for
    if m.top.active and m.index <> m.lastAnnouncedIndex then
        label = m.labels[m.index]
        if m.index = 0 and m.top.paused then label = "Play"
        uiAnnounce(label)
        m.lastAnnouncedIndex = m.index
    end if
    if not m.top.active then m.lastAnnouncedIndex = -1
    m.cells[0].label.text = "Pause"
    m.cells[0].icon.uri = "pkg:/images/ui-icon-pause.png"
    if m.top.paused then m.cells[0].label.text = "Play"
    if m.top.paused then m.cells[0].icon.uri = "pkg:/images/ui-icon-play.png"
end sub

function handlePlayerKey(key as string, press as boolean) as boolean
    return onKeyEvent(key, press)
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.active then return false
    if key = "options" then return false
    if key = "left"
        if m.index > 0 then m.index--
    else if key = "right"
        if m.index < m.cells.count() - 1 then m.index++
    else if key = "OK"
        m.top.action = m.actions[m.index]
    else if key = "play"
        m.top.action = "play"
    else if key = "up"
        m.top.active = false
        m.top.infoFocus = true
    else if key = "back"
        m.top.active = false
        m.top.dismissed = true
    end if
    draw()
    return true
end function
