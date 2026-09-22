sub init()
    m.canvas = m.top.createChild("Group")
    m.delay = m.top.findNode("previewDelay")
    m.delay.observeField("fire", "publishPreview")
    m.rows = []
    m.caption = invalid
    m.groups = []
    m.index = 0
    m.layout = "modal"
end sub

sub configure()
    applyPresentation(m.top.model)
end sub

sub applyPresentation(model as dynamic)
    if model = invalid then return
    m.groups = model.groups
    m.layout = model.layout
    m.index = 0
    for i = 0 to m.groups.count() - 1
        if m.groups[i].id = model.selected then m.index = i
    end for
    m.canvas.removeChildrenIndex(m.canvas.getChildCount(), 0)
    m.caption = invalid
    m.rows = []
    count = 5
    if m.layout = "sidebar" then count = 7
    for i = 0 to count - 1
        x = 580 + i * 245
        y = 98
        width = 235
        height = 40
        if m.layout = "sidebar"
            x = 96
            y = 306 + i * 96
            width = 280
            height = 94
        end if
        radius = height / 2
        if m.layout = "sidebar" then radius = 14
        bg = uiSurface(m.canvas, x, y, width, height, radius, "0x00000000")
        fill = uiSurface(m.canvas, x + 3, y + 3, width - 6, height - 6, radius - 3, "0x263549FF")
        label = uiLabel(m.canvas, "", x + 12, y, width - 24, height, 23)
        label.vertAlign = "center"
        if m.layout = "pills" then label.horizAlign = "center"
        m.rows.push({bg: bg, fill: fill, label: label})
    end for
    if m.layout = "sidebar" then uiLabel(m.canvas, "Groups", 96, 270, 280, 32, 22, "0x1AC4D8FF")
    if m.layout = "pills" then m.caption = uiLabel(m.canvas, "", 580, 73, 1215, 24, 18, "0x1AC4D8FF")
    draw()
end sub

sub onActive()
    if m.top.active then m.top.setFocus(true) else m.delay.control = "stop"
    draw()
end sub

sub draw()
    m.top.visible = m.layout = "pills" or m.layout = "sidebar"
    first = 0
    if m.index >= m.rows.count() then first = m.index - m.rows.count() + 1
    if m.caption <> invalid
        last = first + m.rows.count()
        if last > m.groups.count() then last = m.groups.count()
        m.caption.text = "CHANNEL GROUPS   <   " + (first + 1).toStr() + "-" + last.toStr() + " of " + m.groups.count().toStr() + "   >"
    end if
    for i = 0 to m.rows.count() - 1
        row = m.rows[i]
        row.bg.visible = first + i < m.groups.count()
        row.fill.visible = row.bg.visible
        row.label.visible = row.bg.visible
        if row.bg.visible
            row.label.text = m.groups[first + i].name
            style = uiControlStyle("choice", first + i = m.index, m.top.active and first + i = m.index)
            row.bg.color = style.ring
            row.fill.color = style.fill
            row.label.color = style.ink
            row.bg.focusScale = style.scale
            row.fill.focusScale = style.scale
        end if
    end for
end sub

sub publishPreview()
    if m.top.active and m.groups.count() > 0 then m.top.preview = m.groups[m.index].id
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.active then return false
    if (key = "up" and (m.layout = "pills" or m.index = 0)) or (key = "left" and m.layout = "sidebar")
        m.delay.control = "stop"
        m.top.active = false
        m.top.topRequested = true
        return true
    end if
    if key = "options"
        m.delay.control = "stop"
        m.top.active = false
        m.top.optionsRequested = true
        return true
    end if
    if key = "back" or key = "OK" or (m.layout = "pills" and key = "down") or (m.layout = "sidebar" and key = "right")
        if key <> "back" then publishPreview()
        m.top.active = false
        m.top.closed = true
        return true
    end if
    delta = 0
    if m.layout = "pills"
        if key = "left" then delta = -1
        if key = "right" then delta = 1
    else
        if key = "up" then delta = -1
        if key = "down" then delta = 1
    end if
    target = m.index + delta
    if target >= 0 and target < m.groups.count()
        m.index = target
        draw()
        m.delay.control = "stop"
        m.delay.control = "start"
    end if
    return true
end function
