sub init()
    m.ready = false
    m.canvas = m.top.findNode("canvas")
    m.refresh = m.top.findNode("refresh")
    m.refresh.observeField("fire", "requestInfo")
    m.top.visible = false
    m.logoFiles = {}
    m.logoOrder = []
    m.logoBytes = 0
    m.logoFallback = {}
    m.logoTask = invalid
    m.logoCleanupTask = invalid
    m.logoCleanupPaths = []
    m.logoAccepted = {}
    m.logoBatchSequence = 0
    m.logoDelay = m.top.createChild("Timer")
    m.logoDelay.duration = 0.15
    m.logoDelay.observeField("fire", "requestLogos")
end sub

sub configure()
    data = m.top.model
    if data = invalid then return
    m.ready = false
    m.channels = data.channels
    m.logoClock = CreateObject("roTimespan")
    m.logoClock.mark()
    m.logoReported = false
    m.resetFailed = true
    m.groups = data.groups
    m.favorites = data.favorites
    m.recent = data.recent
    m.collections = data.collections
    m.settings = normalizeGuideSettings(data.settings)
    sameConnection = m.base = data.baseUrl and m.key = data.apiKey
    m.base = data.baseUrl
    m.key = data.apiKey
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
    if not sameConnection
        clearLogoCache()
        m.logoPrefix = "tmp:/aeriotv-logos-" + CreateObject("roDeviceInfo").getRandomUUID()
        agent = CreateObject("roHttpAgent")
        agent.setCertificatesFile("common:/certs/ca-bundle.crt")
        agent.setHeaders({"X-API-Key": data.apiKey, "Authorization": "ApiKey " + data.apiKey})
        if m.rows <> invalid
            for each row in m.rows
                row.logo.uri = ""
            end for
        end if
        m.canvas.setHttpAgent(agent)
    end if
    if m.rows = invalid then buildBrowserCanvas()
    m.ready = true
    filterList()
    draw()
end sub

sub buildBrowserCanvas()
    m.backdrop = uiRect(m.canvas, 0, 0, 890, 1080, "0x071426B0")
    m.title = uiLabel(m.canvas, "", 60, 70, 740, 58, 36)
    m.summary = uiLabel(m.canvas, "", 60, 133, 740, 36, 23, "0x1AC4D8FF")
    m.empty = uiLabel(m.canvas, "No channels in this list", 80, 270, 730, 70, 28)
    m.rows = []
    m.groupRows = []
    for i = 0 to 7
        group = m.canvas.createChild("Group")
        group.translation = [40, 202 + i * 84]
        bg = uiRect(group, 0, 0, 295, 78, "0x0D1E3540")
        title = uiLabel(group, "", 14, 16, 267, 58, 23)
        title.wrap = true
        m.groupRows.push({root: group, bg: bg, title: title})
        row = m.canvas.createChild("Group")
        row.translation = [60, 202 + i * 90]
        border = uiRect(row, 0, 0, 760, 84, "0x17344A20")
        fill = uiRect(row, 2, 2, 756, 80, "0x0D1E3530")
        logo = row.createChild("Poster")
        logo.translation = [10, 14]
        logo.width = 76
        logo.height = 54
        logo.loadWidth = 152
        logo.loadHeight = 108
        logo.loadDisplayMode = "scaleToFit"
        logo.observeField("loadStatus", "reportLogoLoad")
        name = uiLabel(row, "", 105, 11, 500, 36, 25)
        nowTitle = uiLabel(row, "", 105, 47, 624, 31, 20, "0x9EB5C9FF")
        watching = uiLabel(row, "", 614, 14, 135, 29, 18, "0x1AC4D8FF")
        m.rows.push({root: row, border: border, fill: fill, logo: logo, name: name, now: nowTitle, watching: watching, uuid: ""})
    end for
    m.hint = uiRemoteHints(m.canvas, 60, 953, 1100, 34, 21)
end sub

sub filterList()
    group = m.groups[m.groupIndex].id
    if m.mode = "recent" then group = "recent"
    m.filtered = organizedChannels(m.channels, group, m.favorites, m.recent, m.collections, m.settings, "")
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
            group.bg.color = "0x0D1E3540"
            if groupStart + i = m.groupIndex then group.bg.color = "0x10344AFF"
            group.title.color = "0xE8F3FAFF"
            if groupStart + i = m.groupIndex and m.focus = "groups" then group.title.color = "0x1AC4D8FF"
        end if
        row = m.rows[i]
        row.root.translation = [x, 202 + i * 90]
        row.root.visible = m.start + i < m.filtered.count()
        row.uuid = ""
        row.logoId = ""
        if row.root.visible
            channel = m.filtered[m.start + i]
            row.logoId = channel.logoId
            row.uuid = channel.uuid
            row.name.text = channel.name
            row.now.text = ""
            row.watching.text = ""
            if channel.uuid = m.top.playingUuid then row.watching.text = "WATCHING"
            uri = ""
            if m.logoFiles.doesExist(channel.logoId)
                uri = m.logoFiles[channel.logoId].uri
                touchLogo(channel.logoId)
            else if m.logoFallback.doesExist(channel.logoId)
                uri = m.base + "/api/channels/logos/" + channel.logoId + "/cache/"
            end if
            if m.resetFailed and row.logo.loadStatus = "failed" then row.logo.uri = ""
            if row.logo.uri <> uri then row.logo.uri = uri
            row.border.color = "0x17344A20"
            row.fill.color = "0x0D1E3530"
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
    m.resetFailed = false
    reportLogoLoad()
    m.logoDelay.control = "stop"
    m.logoDelay.control = "start"
end sub

sub clearLogoCache()
    m.logoDelay.control = "stop"
    if m.logoTask <> invalid
        m.logoTask.unobserveField("asset")
        m.logoTask.unobserveField("result")
        m.logoTask.cancelled = true
        for each id in m.logoTask.ids
            for each ext in [".part", ".jpg", ".png", ".webp"]
                m.logoCleanupPaths.push(m.logoTask.prefix + "-" + id + ext)
            end for
        end for
        m.logoTask = invalid
    end if
    for each id in m.logoFiles
        m.logoCleanupPaths.push(m.logoFiles[id].uri)
    end for
    m.logoFiles = {}
    m.logoOrder = []
    m.logoBytes = 0
    m.logoFallback = {}
    m.logoAccepted = {}
    cleanupLogoFiles()
end sub

sub cleanupLogoFiles()
    if m.logoCleanupTask <> invalid or m.logoCleanupPaths.count() = 0 then return
    m.logoCleanupTask = CreateObject("roSGNode", "LogoCleanupTask")
    m.logoCleanupTask.paths = m.logoCleanupPaths
    m.logoCleanupPaths = []
    m.logoCleanupTask.observeField("done", "onLogoCleanup")
    m.logoCleanupTask.control = "RUN"
end sub

sub onLogoCleanup(event as object)
    if not isCurrentTaskEvent(event, m.logoCleanupTask) then return
    m.logoCleanupTask.unobserveField("done")
    m.logoCleanupTask = invalid
    cleanupLogoFiles()
end sub

sub invalidateLogos()
    clearLogoCache()
    m.logoPrefix = "tmp:/aeriotv-logos-" + CreateObject("roDeviceInfo").getRandomUUID()
    if m.rows <> invalid
        for each row in m.rows
            row.logo.uri = ""
        end for
    end if
    if m.top.active then draw()
end sub

sub touchLogo(id as string)
    order = []
    for each old in m.logoOrder
        if old <> id then order.push(old)
    end for
    order.push(id)
    m.logoOrder = order
end sub

sub requestLogos()
    if not m.top.active or m.logoTask <> invalid then return
    ids = []
    seen = {}
    for each row in m.rows
        id = row.logoId
        if row.root.visible and id <> "" and not m.logoFiles.doesExist(id) and not m.logoFallback.doesExist(id) and not seen.doesExist(id)
            ids.push(id)
            seen[id] = true
        end if
    end for
    if ids.count() = 0 then return
    m.logoAccepted = {}
    m.logoTask = CreateObject("roSGNode", "LogoCacheTask")
    m.logoTask.baseUrl = m.base
    m.logoTask.apiKey = m.key
    m.logoTask.ids = ids
    m.logoBatchSequence++
    m.logoTask.prefix = m.logoPrefix + "-" + m.logoBatchSequence.toStr()
    m.logoTask.observeField("asset", "onLogoAsset")
    m.logoTask.observeField("result", "onLogoBatch")
    m.logoTask.control = "RUN"
end sub

sub storeLogo(asset as object)
    if m.logoAccepted.doesExist(asset.id) then return
    m.logoAccepted[asset.id] = true
    if m.logoFiles.doesExist(asset.id) then return
    m.logoFiles[asset.id] = asset
    m.logoBytes += asset.bytes
    touchLogo(asset.id)
    while m.logoOrder.count() > 32 or m.logoBytes > 16777216
        victim = ""
        for each id in m.logoOrder
            visible = false
            for each row in m.rows
                if row.root.visible and row.logoId = id then visible = true
            end for
            if not visible
                victim = id
                exit for
            end if
        end for
        if victim = "" then exit while ' Eight visible files are individually capped at 2 MiB.
        m.logoBytes -= m.logoFiles[victim].bytes
        m.logoCleanupPaths.push(m.logoFiles[victim].uri)
        m.logoFiles.delete(victim)
        order = []
        for each id in m.logoOrder
            if id <> victim then order.push(id)
        end for
        m.logoOrder = order
    end while
    for each row in m.rows
        if row.root.visible and row.logoId = asset.id then row.logo.uri = asset.uri
    end for
    cleanupLogoFiles()
end sub

sub onLogoAsset(event as object)
    if not isCurrentTaskEvent(event, m.logoTask) then return
    storeLogo(event.getData())
end sub

sub onLogoBatch(event as object)
    if not isCurrentTaskEvent(event, m.logoTask) then return
    result = event.getData()
    m.logoTask.unobserveField("asset")
    m.logoTask.unobserveField("result")
    m.logoTask = invalid
    for each asset in result.assets
        storeLogo(asset)
    end for
    for each id in result.failed
        m.logoFallback[id] = true
    end for
    if m.top.active then draw()
end sub

sub reportLogoLoad()
    if not m.ready or not m.top.active or m.logoReported then return
    loaded = 0
    failed = 0
    for each row in m.rows
        if row.root.visible and row.logoId <> ""
            if row.logo.uri = "" then return
            if row.logo.loadStatus = "ready"
                loaded++
            else if row.logo.loadStatus = "failed"
                failed++
            else
                return
            end if
        end if
    end for
    print "[browser-logos] ready="; loaded; " failed="; failed; " elapsed_ms="; m.logoClock.totalMilliseconds()
    m.logoReported = true
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

sub handleOptionsShortcut()
    onKeyEvent("options", true)
end sub
