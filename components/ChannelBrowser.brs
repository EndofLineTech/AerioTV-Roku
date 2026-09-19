sub init()
    m.ready = false
    m.canvas = m.top.findNode("canvas")
    m.refresh = m.top.findNode("refresh")
    m.refresh.observeField("fire", "requestInfo")
    m.top.visible = false
end sub

sub configure()
    data = m.top.model
    if data = invalid then return
    m.ready = false
    m.channels = data.channels
    m.groups = data.groups
    m.favorites = data.favorites
    m.recent = data.recent
    m.base = data.baseUrl
    m.mode = data.mode
    m.groupIndex = 0
    for i = 0 to m.groups.count() - 1
        if m.groups[i].id = data.group then m.groupIndex = i
    end for
    m.groupsOpen = false
    m.focus = "channels"
    m.selected = 0
    m.start = 0
    m.filtered = []
    m.top.nowTitles = {}
    m.canvas.removeChildrenIndex(m.canvas.getChildCount(), 0)
    agent = CreateObject("roHttpAgent")
    agent.setCertificatesFile("common:/certs/ca-bundle.crt")
    agent.setHeaders({"X-API-Key": data.apiKey, "Authorization": "ApiKey " + data.apiKey})
    m.canvas.setHttpAgent(agent)
    m.backdrop = uiRect(m.canvas, 0, 0, 890, 1080, "0x071426ED")
    m.title = uiLabel(m.canvas, "", 60, 70, 740, 58, 36)
    m.summary = uiLabel(m.canvas, "", 60, 133, 740, 36, 23, "0x1AC4D8FF")
    m.empty = uiLabel(m.canvas, "No channels in this list", 80, 270, 730, 70, 28)
    m.rows = []
    m.groupRows = []
    for i = 0 to 7
        group = m.canvas.createChild("Group")
        group.translation = [40, 202 + i * 84]
        bg = uiRect(group, 0, 0, 295, 78, "0x0D1E35FF")
        title = uiLabel(group, "", 14, 16, 267, 58, 23)
        title.wrap = true
        m.groupRows.push({root: group, bg: bg, title: title})
        row = m.canvas.createChild("Group")
        row.translation = [60, 202 + i * 90]
        border = uiRect(row, 0, 0, 760, 84, "0x17344AFF")
        fill = uiRect(row, 2, 2, 756, 80, "0x0D1E35FF")
        logo = row.createChild("Poster")
        logo.translation = [10, 14]
        logo.width = 76
        logo.height = 54
        logo.loadWidth = 152
        logo.loadHeight = 108
        logo.loadDisplayMode = "scaleToFit"
        name = uiLabel(row, "", 105, 11, 500, 36, 25)
        nowTitle = uiLabel(row, "", 105, 47, 624, 31, 20, "0x9EB5C9FF")
        watching = uiLabel(row, "", 614, 14, 135, 29, 18, "0x1AC4D8FF")
        m.rows.push({root: row, border: border, fill: fill, logo: logo, name: name, now: nowTitle, watching: watching, uuid: ""})
    end for
    m.hint = uiLabel(m.canvas, "", 60, 953, 1150, 62, 22, "0x9EB5C9FF")
    m.ready = true
    filterList()
    draw()
end sub

sub filterList()
    group = m.groups[m.groupIndex].id
    if m.mode = "recent" then group = "recent"
    m.filtered = playerBrowserChannels(m.channels, group, m.favorites, m.recent)
    m.selected = 0
    m.start = 0
    for i = 0 to m.filtered.count() - 1
        if m.filtered[i].uuid = m.top.playingUuid then m.selected = i
    end for
end sub

sub onActive()
    m.top.visible = m.top.active
    if m.top.active
        draw()
        m.refresh.control = "start"
        m.top.setFocus(true)
    else
        m.refresh.control = "stop"
    end if
end sub

sub draw()
    if not m.ready then return
    m.title.text = "Channels"
    if m.mode = "recent" then m.title.text = "Recently Watched"
    m.summary.text = m.groups[m.groupIndex].name + "  |  " + m.filtered.count().toStr() + " channels"
    if m.mode = "recent" then m.summary.text = "Most recent first  |  " + m.filtered.count().toStr() + " channels"
    x = 60
    m.backdrop.width = 890
    if m.groupsOpen
        x = 370
        m.backdrop.width = 1190
    end if
    m.empty.translation = [x + 20, 270]
    m.empty.visible = m.filtered.count() = 0
    if m.selected < m.start then m.start = m.selected
    if m.selected >= m.start + 8 then m.start = m.selected - 7
    groupStart = 0
    if m.groupIndex > 7 then groupStart = m.groupIndex - 7
    for i = 0 to 7
        group = m.groupRows[i]
        group.root.visible = m.groupsOpen and groupStart + i < m.groups.count()
        if group.root.visible
            group.title.text = m.groups[groupStart + i].name
            group.bg.color = "0x0D1E35FF"
            if groupStart + i = m.groupIndex then group.bg.color = "0x10344AFF"
            group.title.color = "0xE8F3FAFF"
            if groupStart + i = m.groupIndex and m.focus = "groups" then group.title.color = "0x1AC4D8FF"
        end if
        row = m.rows[i]
        row.root.translation = [x, 202 + i * 90]
        row.root.visible = m.start + i < m.filtered.count()
        row.uuid = ""
        if row.root.visible
            channel = m.filtered[m.start + i]
            row.uuid = channel.uuid
            row.name.text = channel.name
            row.now.text = ""
            row.watching.text = ""
            if channel.uuid = m.top.playingUuid then row.watching.text = "WATCHING"
            uri = ""
            if channel.logoId <> "" then uri = m.base + "/api/channels/logos/" + channel.logoId + "/cache/"
            if row.logo.uri <> uri then row.logo.uri = uri
            row.border.color = "0x17344AFF"
            row.fill.color = "0x0D1E35FF"
            if m.focus = "channels" and m.start + i = m.selected
                row.border.color = "0x1AC4D8FF"
                row.fill.color = "0x10344AFF"
            end if
        end if
    end for
    m.hint.text = "OK  Watch    Left  Groups    Back  Close"
    if m.groupsOpen then m.hint.text = "Up/Down  Browse    Right  Channels    Back  Close groups"
    if m.mode = "recent" then m.hint.text = "OK  Watch    Back  Close"
    updateTitles()
    requestInfo()
end sub

sub requestInfo()
    if not m.ready or not m.top.active then return
    visible = []
    for i = m.start to m.filtered.count() - 1
        if i >= m.start + 8 then exit for
        visible.push(m.filtered[i])
    end for
    m.top.infoRequest = visible
end sub

sub updateTitles()
    if not m.ready then return
    titles = m.top.nowTitles
    if titles = invalid then return
    for each row in m.rows
        if row.uuid <> "" and titles.doesExist(row.uuid) then row.now.text = titles[row.uuid]
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.active then return false
    if key = "back" or key = "options"
        if m.groupsOpen
            m.groupsOpen = false
            m.focus = "channels"
            draw()
        else
            m.top.active = false
            m.top.closed = true
        end if
        return true
    end if
    if key = "left" and m.mode <> "recent"
        m.groupsOpen = true
        m.focus = "groups"
    else if key = "right"
        m.focus = "channels"
    else if key = "up" or key = "down"
        delta = 1
        if key = "up" then delta = -1
        if m.focus = "groups"
            target = m.groupIndex + delta
            if target >= 0 and target < m.groups.count()
                m.groupIndex = target
                filterList()
            end if
        else
            target = m.selected + delta
            if target >= 0 and target < m.filtered.count() then m.selected = target
        end if
    else if key = "OK"
        if m.focus = "groups"
            m.focus = "channels"
        else if m.filtered.count() > 0
            m.top.channelSelected = m.filtered[m.selected]
            return true
        end if
    else
        return true
    end if
    draw()
    return true
end function
