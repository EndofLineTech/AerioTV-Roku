sub init()
    m.top.visible = false
    uiRect(m.top, 0, 0, 1920, 1080, "0x0A1628FF")
    uiLabel(m.top, "Program search", 96, 76, 1180, 58, 40)
    m.heading = uiLabel(m.top, "", 96, 151, 1180, 44, 28, "0x1AC4D8FF")
    m.detail = uiLabel(m.top, "", 96, 207, 1180, 96, 23, "0x9EB5C9FF")
    m.detail.wrap = true
    m.rows = []
    for i = 0 to 5
        root = m.top.createChild("Group")
        root.translation = [96, 320 + i * 104]
        background = uiRect(root, 0, 0, 1728, 98, "0x0D1E35FF")
        title = uiLabel(root, "", 22, 12, 1684, 38, 27)
        subtitle = uiLabel(root, "", 22, 55, 1684, 32, 22, "0x9EB5C9FF")
        m.rows.push({root: root, background: background, title: title, subtitle: subtitle})
    end for
    m.footer = uiLabel(m.top, "", 96, 980, 1728, 58, 22, "0x9EB5C9FF")
    m.footer.wrap = true
    m.entries = []
    m.index = 0
    m.clock = m.top.createChild("Timer")
    m.clock.duration = 30
    m.clock.repeat = true
    m.clock.observeField("fire", "render")
end sub

sub setModel()
    model = m.top.model
    if model = invalid then return
    m.index = 0
    m.entries = []
    m.entries.append(model.items)
    if not model.loading
        if model.hasNext then m.entries.push({title: "Next results page", action: "next"})
        if model.page > 1 then m.entries.push({title: "Previous results page", action: "previous"})
        m.entries.push({title: "Retry / refresh this page", action: "retry"})
    end if
    m.entries.push({title: "Edit search", action: "edit"})
    m.entries.push({title: "Back to guide", action: "close"})
    m.heading.text = model.searchField + ": " + model.query
    render()
end sub

sub onActive()
    m.top.visible = m.top.active
    if m.top.active
        m.top.setFocus(true)
        m.clock.control = "start"
    else
        m.clock.control = "stop"
    end if
end sub

sub render()
    if m.entries.count() = 0 then return
    model = m.top.model
    first = (m.index \ 6) * 6
    for i = 0 to 5
        row = m.rows[i]
        at = first + i
        row.root.visible = at < m.entries.count()
        if row.root.visible
            entry = m.entries[at]
            row.background.color = "0x0D1E35FF"
            row.title.color = "0xE8F3FAFF"
            row.subtitle.color = "0x9EB5C9FF"
            if at = m.index
                row.background.color = "0x1AC4D8FF"
                row.title.color = "0x0A1628FF"
                row.subtitle.color = "0x0A1628FF"
            end if
            row.subtitle.text = ""
            if entry.program <> invalid
                p = entry.program
                row.title.text = p.title
                row.subtitle.text = entry.channel.number + "  " + entry.channel.name + "  |  " + programSearchState(p, uiNow()) + "  |  " + uiLocalDate(p.startsAt) + " " + uiTime(p.startsAt) + " - " + uiTime(p.endsAt)
            else
                row.title.text = entry.title
            end if
        end if
    end for
    m.detail.text = model.message
    selected = m.entries[m.index]
    if selected.program <> invalid then m.detail.text = selected.program.description
    m.footer.text = "Page " + model.page.toStr() + "  |  Past 3d / Next 7d  |  OK: Guide  |  *: Edit  |  Back: Close"
    if model.truncated = true
        m.footer.text += chr(10) + "Page limited to 200 airings. Narrow the search to see omitted matches."
    else
        m.footer.text += chr(10) + "Your lineup only. Opening an outside-filter result clears channel filters."
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.active then return false
    if key = "back"
        m.top.selection = {action: "close"}
    else if key = "options"
        m.top.selection = {action: "edit"}
    else if key = "up"
        if m.index > 0 then m.index--
        render()
    else if key = "down"
        if m.index < m.entries.count() - 1 then m.index++
        render()
    else if key = "OK"
        m.top.selection = m.entries[m.index]
    end if
    return true
end function
