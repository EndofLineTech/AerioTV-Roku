sub init()
    m.index = 0
    m.actions = ["play", "channels", "recent", "minimize", "options", "stop"]
    m.labels = ["Pause", "Channels", "Recent", "Minimize", "Options", "Stop"]
    m.cells = []
    for i = 0 to 5
        x = 864 + i * 160
        border = uiRect(m.top, x, 606, 150, 66, "0x17344AFF")
        fill = uiRect(m.top, x + 3, 609, 144, 60, "0x0D1E35EE")
        label = uiLabel(m.top, m.labels[i], x + 4, 625, 142, 39, 23)
        label.horizAlign = "center"
        m.cells.push({border: border, fill: fill, label: label})
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
        cell.border.color = "0x17344AFF"
        cell.fill.color = "0x0D1E35EE"
        if m.top.active and i = m.index
            cell.border.color = "0x1AC4D8FF"
            cell.fill.color = "0x10344AFF"
        end if
    end for
    m.cells[0].label.text = "Pause"
    if m.top.paused then m.cells[0].label.text = "Play"
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
