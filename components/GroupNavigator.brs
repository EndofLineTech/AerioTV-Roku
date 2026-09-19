sub init()
    m.canvas = m.top.createChild("Group")
    m.delay = m.top.findNode("previewDelay")
    m.delay.observeField("fire", "publishPreview")
    m.rows = []
    m.groups = []
    m.index = 0
    m.layout = "modal"
end sub

sub configure()
    if m.top.model = invalid then return
    m.groups = m.top.model.groups
    m.layout = m.top.model.layout
    m.index = 0
    for i = 0 to m.groups.count() - 1
        if m.groups[i].id = m.top.model.selected then m.index = i
    end for
    m.canvas.removeChildrenIndex(m.canvas.getChildCount(), 0)
    m.rows = []
    count = 3
    if m.layout = "sidebar" then count = 7
    for i = 0 to count - 1
        x = 580 + i * 245
        y = 70
        width = 235
        height = 62
        if m.layout = "sidebar"
            x = 96
            y = 306 + i * 96
            width = 330
            height = 94
        end if
        bg = uiRect(m.canvas, x, y, width, height, "0x0D1E35FF")
        label = uiLabel(m.canvas, "", x + 12, y + 16, width - 24, height - 18, 23)
        m.rows.push({bg: bg, label: label})
    end for
    draw()
end sub

sub onActive()
    if m.top.active then m.top.setFocus(true) else m.delay.control = "stop"
    draw()
end sub

sub draw()
    m.top.visible = m.layout = "pills" or (m.layout = "sidebar" and m.top.active)
    first = 0
    if m.index >= m.rows.count() then first = m.index - m.rows.count() + 1
    for i = 0 to m.rows.count() - 1
        row = m.rows[i]
        row.bg.visible = first + i < m.groups.count()
        row.label.visible = row.bg.visible
        if row.bg.visible
            row.label.text = m.groups[first + i].name
            row.bg.color = "0x0D1E35FF"
            row.label.color = "0xE8F3FAFF"
            if first + i = m.index
                row.bg.color = "0x10344AFF"
                row.label.color = "0x1AC4D8FF"
                if m.top.active
                    row.bg.color = "0x1AC4D8FF"
                    row.label.color = "0x0A1628FF"
                end if
            end if
        end if
    end for
end sub

sub publishPreview()
    if m.top.active and m.groups.count() > 0 then m.top.preview = m.groups[m.index].id
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.active then return false
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
