sub init()
    m.canvas = m.top.findNode("canvas")
    m.loadDelay = m.top.findNode("loadDelay")
    m.clock = m.top.findNode("clock")
    m.saveDelay = m.top.findNode("saveDelay")
    m.saveDelay.observeField("fire", "savePreferences")
    m.loadDelay.observeField("fire", "loadVisibleWindows")
    m.clock.observeField("fire", "tick")
    m.task = invalid
    m.searchTask = invalid
    m.searchView = m.top.findNode("programSearch")
    m.searchView.observeField("selection", "onProgramSearchSelection")
    m.programQuery = ""
    m.programSearchField = "title"
    m.picker = invalid
    m.ready = false
    m.span = 8928 ' 1488 pixels at upstream's 600 pixels/hour.
    m.rowCount = 7
end sub

sub configure()
    suspendGuide()
    m.ready = false
    m.top.playbackChannel = invalid
    m.top.playbackInfo = invalid
    config = m.top.config
    if config = invalid then return
    m.channels = config.channels
    m.groups = [{id: "all", name: "All Channels"}, {id: "favorites", name: "Favorites"}]
    for each group in config.groups
        m.groups.push({id: "group:" + group.id, name: group.name})
    end for
    m.base = config.baseUrl
    m.key = config.apiKey
    m.favorites = {}
    m.allowedKeys = guideDictionary()
    m.cache = guideNewCache()
    m.failures = {}
    m.connectionWarning = config.warning
    m.message = ""
    m.query = ""
    m.programQuery = ""
    m.filtered = []
    m.groupIndex = 0
    m.selected = 0
    m.rowStart = 0
    m.anchor = uiNow()
    m.followNow = true
    m.viewStart = (m.anchor \ 1800) * 1800
    m.direction = 1
    prefs = config.preferences
    savedIds = {}
    if type(prefs) = "roAssociativeArray"
        if type(prefs.favoriteIds) = "roArray"
            for each id in prefs.favoriteIds
                savedIds[textValue(id)] = true
            end for
        end if
        for i = 0 to m.groups.count() - 1
            if m.groups[i].id = prefs.group then m.groupIndex = i
        end for
    end if
    for each channel in m.channels
        if savedIds.doesExist(channel.id) then m.favorites[channel.uuid] = true
        m.allowedKeys[channel.uuid] = true
        if channel.epgKey <> "" then m.allowedKeys[channel.epgKey] = true
    end for
    filterLineup()
    if type(prefs) = "roAssociativeArray"
        for i = 0 to m.filtered.count() - 1
            if m.filtered[i].uuid = prefs.lastChannel then m.selected = i
        end for
    end if
    agent = CreateObject("roHttpAgent")
    agent.setCertificatesFile("common:/certs/ca-bundle.crt")
    agent.setHeaders({"X-API-Key": m.key, "Authorization": "ApiKey " + m.key})
    m.canvas.setHttpAgent(agent)
    buildCanvas()
    m.ready = true
    updateMiniLayout()
    if m.top.active then onActive()
end sub

sub buildCanvas()
    m.canvas.removeChildrenIndex(m.canvas.getChildCount(), 0)
    uiLabel(m.canvas, "AerioTV", 96, 62, 400, 64, 46)
    uiLabel(m.canvas, "Live TV", 580, 76, 200, 48, 32, "0x1AC4D8FF")
    uiRect(m.canvas, 580, 129, 112, 3, "0x1AC4D8FF")
    m.heading = uiLabel(m.canvas, "", 1000, 82, 820, 38, 25, "0x9EB5C9FF")
    m.title = uiLabel(m.canvas, "", 96, 150, 1728, 50, 34)
    m.description = uiLabel(m.canvas, "", 96, 205, 1728, 57, 23, "0x9EB5C9FF")
    m.description.wrap = true
    m.dateLabel = uiLabel(m.canvas, "", 96, 270, 235, 30, 22, "0x1AC4D8FF")
    m.ticks = []
    for i = 0 to 4
        m.ticks.push(uiLabel(m.canvas, "", 346 + i * 300, 270, 280, 30, 22, "0x9EB5C9FF"))
    end for
    m.rows = []
    for i = 0 to m.rowCount - 1
        root = m.canvas.createChild("Group")
        root.translation = [96, 306 + i * 96]
        uiRect(root, 0, 0, 239, 95, "0x0D1E35FF")
        number = uiLabel(root, "", 12, 4, 170, 27, 20, "0x1AC4D8FF")
        badge = uiLabel(root, "", 180, 4, 55, 27, 18, "0x1AC4D8FF")
        logo = root.createChild("Poster")
        logo.translation = [12, 33]
        logo.width = 58
        logo.height = 52
        logo.loadWidth = 116
        logo.loadHeight = 104
        logo.loadDisplayMode = "scaleToFit"
        name = uiLabel(root, "", 80, 34, 150, 56, 21)
        name.wrap = true
        m.rows.push({root: root, number: number, badge: badge, logo: logo, name: name, tiles: []})
    end for
    m.nowLine = uiRect(m.canvas, 336, 300, 2, 678, "0x1AC4D8AA")
    m.footer = uiLabel(m.canvas, "", 96, 998, 1728, 36, 22, "0x9EB5C9FF")
end sub

sub onActive()
    if not m.ready then return
    if m.top.active
        m.clock.control = "start"
        drawGuide()
        scheduleLoad()
        m.top.setFocus(true)
    else
        suspendGuide()
        if m.top.playbackChannel <> invalid then onPlaybackChannel()
    end if
end sub

sub suspendGuide()
    cancelProgramSearch()
    m.searchView.active = false
    m.clock.control = "stop"
    m.saveDelay.control = "stop"
    m.loadDelay.control = "stop"
    if m.task <> invalid
        m.task.unobserveField("result")
        m.task.control = "STOP"
        m.task = invalid
    end if
    closePicker()
end sub

sub tick()
    if not m.top.active
        if m.top.playbackChannel <> invalid
            publishPlaybackInfo()
            scheduleLoad()
        end if
        return
    end if
    ' Live browsing follows the clock; historical/future browsing stays anchored.
    if m.followNow then m.anchor = uiNow() else m.anchor = guideClamp(m.anchor, uiNow())
    keepAnchorVisible()
    drawGuide()
    scheduleLoad()
end sub

sub scheduleLoad()
    if not m.ready then return
    if m.task <> invalid
        windows = requestedWindows()
        relevant = false
        needed = false
        for each start in windows
            if start = m.task.windowStart then relevant = true
            if not guideCacheHas(m.cache, start, uiNow()) then needed = true
        end for
        if needed and not relevant
            m.task.unobserveField("result")
            m.task.control = "STOP"
            m.task = invalid
        end if
    end if
    m.loadDelay.control = "stop"
    m.loadDelay.control = "start"
end sub

sub loadVisibleWindows()
    if not m.ready then return
    if not m.top.active and m.top.playbackChannel = invalid then return
    if m.task <> invalid then return
    if m.top.active and m.filtered.count() = 0 then return
    now = uiNow()
    windows = requestedWindows()
    for each start in windows
        if guideCacheHas(m.cache, start, now)
            guideCacheTouch(m.cache, start)
        else
            key = start.toStr()
            retry = true
            if m.failures.doesExist(key) then retry = m.failures[key] <= now
            if retry
                m.task = CreateObject("roSGNode", "GuideTask")
                m.task.baseUrl = m.base
                m.task.apiKey = m.key
                m.task.windowStart = start
                m.task.allowedKeys = m.allowedKeys
                m.task.observeField("result", "onWindowLoaded")
                m.task.control = "RUN"
                if m.top.active then m.footer.text = "Loading guide...  Navigation and live tuning remain available."
                return
            end if
        end if
    end for
end sub

sub onWindowLoaded(event as object)
    if not isCurrentTaskEvent(event, m.task) then return
    result = event.getData()
    m.task.unobserveField("result")
    m.task = invalid
    if result.ok
        guideCachePut(m.cache, result.windowStart, result.index, uiNow())
        m.failures.delete(result.windowStart.toStr())
        m.message = ""
    else
        m.failures[result.windowStart.toStr()] = uiNow() + 60
        if result.windowStart >= guideWindowStart(m.viewStart) and result.windowStart <= guideWindowStart(m.viewStart + m.span - 1)
            m.message = "Guide unavailable: " + result.message + "  * > Refresh guide to retry."
        end if
    end if
    if m.top.active
        drawGuide()
        scheduleLoad()
    else if m.top.playbackChannel <> invalid
        publishPlaybackInfo()
        scheduleLoad()
    end if
end sub

function requestedWindows() as object
    now = uiNow()
    if not m.top.active and m.top.playbackChannel <> invalid
        return cachedPlaybackInfo(m.top.playbackChannel, now).windows
    end if
    first = guideWindowStart(m.viewStart)
    last = guideWindowStart(m.viewStart + m.span - 1)
    windows = [first]
    if last <> first then windows.push(last)
    adjacent = last + 10800
    if m.direction < 0 then adjacent = first - 10800
    if adjacent >= guideWindowStart(now - 259200) and adjacent <= guideWindowStart(now + 604799) then windows.push(adjacent)
    return windows
end function

function cachedPlaybackInfo(channel as object, now as integer) as object
    if not m.ready then return {channelUuid: channel.uuid, status: "loading", programs: [], windows: []}
    return playbackSnapshot(m.cache, m.failures, channel, now)
end function

sub publishPlaybackInfo()
    if m.top.playbackChannel = invalid then return
    m.top.playbackInfo = cachedPlaybackInfo(m.top.playbackChannel, uiNow())
end sub

sub onPlaybackChannel()
    if not m.ready then return
    if m.top.playbackChannel = invalid
        m.top.playbackInfo = invalid
        if not m.top.active then suspendGuide()
        return
    end if
    publishPlaybackInfo()
    m.clock.control = "start"
    scheduleLoad()
end sub

function channelPrograms(channel as object) as object
    key = channel.epgKey
    for each window in m.cache.entries
        index = m.cache.entries[window].index
        if index.doesExist(channel.uuid) then key = channel.uuid
    end for
    return guideCachePrograms(m.cache, key, m.viewStart, m.viewStart + m.span)
end function

function rowCells(channel as object) as object
    return guideCells(channelPrograms(channel), m.viewStart, m.viewStart + m.span)
end function

function selectedCell() as dynamic
    if m.filtered.count() = 0 then return invalid
    return guideCellAt(rowCells(m.filtered[m.selected]), m.anchor)
end function

sub drawGuide()
    if not m.ready then return
    if m.selected < m.rowStart then m.rowStart = m.selected
    if m.selected >= m.rowStart + m.rowCount then m.rowStart = m.selected - m.rowCount + 1
    now = uiNow()
    m.heading.text = m.groups[m.groupIndex].name + "  |  " + m.filtered.count().toStr() + " channels  |  " + uiTime(now)
    m.dateLabel.text = uiLocalDate(m.viewStart)
    for i = 0 to m.ticks.count() - 1
        m.ticks[i].text = uiTime(m.viewStart + i * 1800)
    end for
    for i = 0 to m.rows.count() - 1
        row = m.rows[i]
        index = m.rowStart + i
        row.root.visible = index < m.filtered.count()
        if row.root.visible
            channel = m.filtered[index]
            row.number.text = channel.number
            row.name.text = channel.name
            row.badge.text = ""
            if m.favorites.doesExist(channel.uuid) then row.badge.text = "FAV"
            uri = ""
            if channel.logoId <> "" then uri = m.base + "/api/channels/logos/" + channel.logoId + "/cache/"
            if row.logo.uri <> uri then row.logo.uri = uri
            renderCells(row, rowCells(channel), index = m.selected)
        end if
    end for
    x = 336 + (now - m.viewStart) / 6
    m.nowLine.visible = x >= 336 and x < 1824
    if m.nowLine.visible then m.nowLine.translation = [x, 300]
    m.footer.text = "OK  Watch / Details     *  Options, groups, search, date     Back  Connection"
    if m.top.miniActive then m.footer.text = "OK  Watch / Details     Back or Play  Fullscreen     *  Options / Stop playback"
    if m.query <> "" then m.footer.text = "Search: " + m.query + "    * > Clear search to show all channels"
    if m.connectionWarning <> "" then m.footer.text = m.connectionWarning
    if m.message <> "" then m.footer.text = m.message
    if m.filtered.count() = 0
        m.title.text = "No matching channels"
        m.description.text = "Use * to choose another group or clear your search."
        return
    end if
    channel = m.filtered[m.selected]
    cell = selectedCell()
    m.title.text = channel.name
    m.description.text = gapText() + "  |  OK to watch live."
    if cell <> invalid
        if cell.program <> invalid
            program = cell.program
            m.title.text = program.title
            m.description.text = channel.name + "  |  " + uiTime(program.startsAt) + " - " + uiTime(program.endsAt) + "  " + program.description
        end if
    end if
end sub

function gapText() as string
    first = guideWindowStart(m.viewStart)
    last = guideWindowStart(m.viewStart + m.span - 1)
    for start = first to last step 10800
        if m.failures.doesExist(start.toStr()) then return "Guide unavailable"
        if not m.cache.entries.doesExist(start.toStr()) then return "Loading guide..."
    end for
    return "No guide information"
end function

sub renderCells(row as object, cells as object, selected as boolean)
    ' Bound node count even if a malformed source produces sub-minute schedules.
    if cells.count() > 128
        cells = [{startsAt: m.viewStart, endsAt: m.viewStart + m.span, program: invalid}]
        m.message = "This schedule is too dense to display. Live tuning is available."
    end if
    while row.tiles.count() < cells.count()
        root = row.root.createChild("Group")
        border = uiRect(root, 0, 0, 100, 95, "0x17344AFF")
        fill = uiRect(root, 2, 2, 96, 91, "0x0D1E35FF")
        title = uiLabel(root, "", 14, 14, 70, 37, 25)
        time = uiLabel(root, "", 14, 55, 70, 29, 20, "0x9EB5C9FF")
        row.tiles.push({root: root, border: border, fill: fill, title: title, time: time})
    end while
    for i = 0 to row.tiles.count() - 1
        tile = row.tiles[i]
        tile.root.visible = i < cells.count()
        if tile.root.visible
            cell = cells[i]
            width = (cell.endsAt - cell.startsAt) / 6 - 1
            if width < 1 then width = 1
            tile.root.translation = [240 + (cell.startsAt - m.viewStart) / 6, 0]
            tile.border.width = width
            fillWidth = width - 4
            if fillWidth < 1 then fillWidth = 1
            tile.fill.width = fillWidth
            tile.fill.visible = width > 4
            tile.title.visible = width > 40
            tile.time.visible = width > 180
            textWidth = width - 28
            if textWidth < 1 then textWidth = 1
            tile.title.width = textWidth
            tile.time.width = textWidth
            focused = selected and cell.startsAt <= m.anchor and cell.endsAt > m.anchor
            tile.border.color = "0x17344AFF"
            tile.fill.color = "0x0D1E35FF"
            if focused
                tile.border.color = "0x1AC4D8FF"
                tile.fill.color = "0x10344AFF"
            end if
            tile.title.text = gapText()
            tile.time.text = ""
            if cell.program <> invalid
                program = cell.program
                tile.title.text = program.title
                tile.time.text = uiTime(program.startsAt) + " - " + uiTime(program.endsAt)
            end if
        end if
    end for
end sub

sub filterLineup()
    previous = ""
    if m.filtered <> invalid
        if m.selected < m.filtered.count() then previous = m.filtered[m.selected].uuid
    end if
    candidates = filterChannels(m.channels, m.groups[m.groupIndex].id, m.favorites)
    m.filtered = []
    m.selected = 0
    m.rowStart = 0
    for each channel in candidates
        if m.query = "" or instr(1, lcase(channel.name + " " + channel.number), lcase(m.query)) > 0
            if channel.uuid = previous then m.selected = m.filtered.count()
            m.filtered.push(channel)
        end if
    end for
end sub

sub savePreferences()
    favoriteIds = []
    for each channel in m.channels
        if m.favorites.doesExist(channel.uuid) then favoriteIds.push(channel.id)
    end for
    uuid = ""
    if m.filtered.count() > 0 then uuid = m.filtered[m.selected].uuid
    m.top.preferences = {favoriteIds: favoriteIds, lastChannel: uuid, group: m.groups[m.groupIndex].id}
end sub

sub keepAnchorVisible()
    if m.anchor < m.viewStart or m.anchor >= m.viewStart + m.span
        m.viewStart = (m.anchor \ 1800) * 1800
    end if
end sub

sub jumpTo(epoch as integer)
    m.followNow = abs(epoch - uiNow()) < 2
    m.anchor = guideClamp(epoch, uiNow())
    m.viewStart = (m.anchor \ 1800) * 1800
    drawGuide()
    scheduleLoad()
end sub

sub watchLive()
    if m.filtered.count() = 0 then return
    savePreferences()
    m.top.watchChannel = m.filtered[m.selected]
end sub

function adjacentPlayingChannel(currentUuid as string, direction as integer) as dynamic
    if not m.ready then return invalid
    ' Keep the same group/search/favorites order the viewer entered playback from.
    ' Previewing a held key does not move guide focus until a tune is committed.
    return adjacentLiveChannel(m.filtered, currentUuid, direction)
end function

sub selectPlayingChannel(uuid as string)
    if not m.ready then return
    for i = 0 to m.filtered.count() - 1
        if m.filtered[i].uuid = uuid
            m.selected = i
            savePreferences()
            return
        end if
    end for
end sub

function channelByUuid(uuid as string) as dynamic
    for each channel in m.channels
        if channel.uuid = uuid then return channel
    end for
    return invalid
end function

function playerBrowserData() as object
    return {channels: m.channels, groups: m.groups, favorites: m.favorites, group: m.groups[m.groupIndex].id}
end function

function browserNowTitles(channels as object) as object
    titles = {}
    for each channel in channels
        snapshot = cachedPlaybackInfo(channel, uiNow())
        info = selectNowNext(snapshot.programs, uiNow())
        title = "No current program listed"
        if snapshot.status = "loading" then title = "Loading program information..."
        if snapshot.status = "unavailable" then title = "Program information unavailable"
        if info.current <> invalid
            title = info.current.title
            if snapshot.status = "stale" or snapshot.status = "unavailable" then title += " (cached)"
        end if
        titles[channel.uuid] = title
    end for
    return titles
end function

sub updateMiniLayout()
    if not m.ready then return
    m.title.width = 1728
    m.description.width = 1728
    m.heading.width = 820
    if m.top.miniActive
        m.title.width = 1180
        m.description.width = 1180
        m.heading.width = 330
    end if
end sub

sub showDetails()
    if m.filtered.count() = 0 then return
    channel = m.filtered[m.selected]
    cell = selectedCell()
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = channel.name
    dialog.message = gapText()
    if cell <> invalid
        if cell.program <> invalid
            program = cell.program
            dialog.title = program.title
            dialog.message = channel.name + chr(10) + uiLocalDate(program.startsAt) + "  " + uiTime(program.startsAt) + " - " + uiTime(program.endsAt) + chr(10) + program.subtitle + chr(10) + program.description
        end if
    end if
    dialog.buttons = ["Watch channel live", "Close"]
    dialog.observeField("buttonSelected", "onDetailsButton")
    dialog.observeField("wasClosed", "onDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onDetailsButton(event as object)
    dialog = event.getRoSGNode()
    dialog.close = true
    if event.getData() = 0 then watchLive()
end sub

sub onDialogClosed()
    if not m.top.active then return
    if m.searchView.active then m.searchView.setFocus(true) else m.top.setFocus(true)
end sub

sub openPicker(title as string, items as object, kind as string)
    closePicker()
    m.pickerKind = kind
    m.pickerItems = items
    m.picker = m.top.createChild("Group")
    uiRect(m.picker, 0, 0, 1920, 1080, "0x000000CC")
    uiRect(m.picker, 460, 130, 1000, 810, "0x0D1E35FF")
    uiLabel(m.picker, title, 510, 170, 900, 66, 38)
    list = m.picker.createChild("LabelList")
    list.translation = [510, 265]
    list.itemSize = [900, 64]
    list.numRows = 9
    list.color = "0xE8F3FAFF"
    list.focusedColor = "0x0A1628FF"
    list.focusBitmapBlendColor = "0x1AC4D8FF"
    content = CreateObject("roSGNode", "ContentNode")
    for each item in items
        child = content.createChild("ContentNode")
        child.title = item.title
    end for
    list.content = content
    list.observeField("itemSelected", "onPickerSelected")
    list.setFocus(true)
end sub

sub closePicker()
    if m.picker <> invalid
        m.top.removeChild(m.picker)
        m.picker = invalid
    end if
end sub

sub openOptions()
    items = [
        {title: "Program details", action: "details"}
        {title: "Toggle favorite", action: "favorite"}
        {title: "Channel groups", action: "groups"}
        {title: "Search channels", action: "search"}
        {title: "Search programs", action: "programSearch"}
        {title: "Clear search", action: "clear"}
        {title: "Jump to date and time", action: "date"}
        {title: "Jump to Now", action: "now"}
        {title: "Refresh guide", action: "refresh"}
        {title: "Connection settings", action: "settings"}
    ]
    if m.top.miniActive
        items.unshift({title: "Stop playback", action: "stopPlayer"})
        items.unshift({title: "Return to fullscreen", action: "expandPlayer"})
    end if
    openPicker("Guide options", items, "options")
end sub

sub onPickerSelected(event as object)
    item = m.pickerItems[event.getData()]
    kind = m.pickerKind
    closePicker()
    m.top.setFocus(true)
    if kind = "programSearchField"
        m.programSearchField = item.field
        editProgramSearch()
        return
    else if kind = "groups"
        m.groupIndex = item.index
        filterLineup()
        savePreferences()
    else if kind = "date"
        openPicker(item.title + " — local time (UTC reference)", item.times, "time")
        return
    else if kind = "time"
        jumpTo(item.epoch)
        return
    else
        action = item.action
        if action = "expandPlayer" or action = "stopPlayer"
            m.top.playerRequest = action
            return
        else if action = "details"
            showDetails()
            return
        else if action = "favorite"
            if m.filtered.count() > 0
                uuid = m.filtered[m.selected].uuid
                if m.favorites.doesExist(uuid) then m.favorites.delete(uuid) else m.favorites[uuid] = true
                filterLineup()
                savePreferences()
            end if
        else if action = "groups"
            items = []
            for i = 0 to m.groups.count() - 1
                items.push({title: m.groups[i].name, index: i})
            end for
            openPicker("Channel groups", items, "groups")
            return
        else if action = "programSearch"
            openPicker("Search programs by", [{title: "Title", field: "title"}, {title: "Description", field: "description"}], "programSearchField")
            return
        else if action = "search"
            dialog = CreateObject("roSGNode", "KeyboardDialog")
            dialog.title = "Search channel name or number"
            dialog.text = m.query
            dialog.buttons = ["Search", "Cancel"]
            dialog.observeField("buttonSelected", "onSearch")
            dialog.observeField("wasClosed", "onDialogClosed")
            m.top.getScene().dialog = dialog
            return
        else if action = "clear"
            m.query = ""
            filterLineup()
        else if action = "date"
            openDatePicker()
            return
        else if action = "now"
            jumpTo(uiNow())
            return
        else if action = "refresh"
            for each key in m.cache.entries
                m.cache.entries[key].expiresAt = 0
            end for
            m.failures = {}
            m.message = ""
        else if action = "settings"
            savePreferences()
            m.top.exitRequested = true
            return
        end if
    end if
    drawGuide()
    scheduleLoad()
end sub

sub onSearch(event as object)
    dialog = event.getRoSGNode()
    if event.getData() = 0
        m.query = dialog.text.trim()
        filterLineup()
        drawGuide()
        scheduleLoad()
    end if
    dialog.close = true
end sub

sub cancelProgramSearch()
    if m.searchTask <> invalid
        m.searchTask.unobserveField("result")
        m.searchTask.control = "STOP"
        m.searchTask = invalid
    end if
end sub

sub editProgramSearch()
    cancelProgramSearch()
    m.searchView.active = false
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.title = "Program " + m.programSearchField + " (2-120 characters; AND/OR supported)"
    dialog.text = m.programQuery
    dialog.buttons = ["Search", "Cancel"]
    dialog.observeField("buttonSelected", "onProgramSearchKeyboard")
    dialog.observeField("wasClosed", "onDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onProgramSearchKeyboard(event as object)
    dialog = event.getRoSGNode()
    submitted = event.getData() = 0
    if submitted then m.programQuery = left(dialog.text.trim(), 120)
    dialog.close = true
    if submitted and m.top.active
        m.programSearchPage = 1
        m.programSearchNow = uiNow()
        loadProgramSearch()
    end if
end sub

sub loadProgramSearch()
    cancelProgramSearch()
    model = {items: [], query: m.programQuery, searchField: m.programSearchField, page: m.programSearchPage, hasNext: false, loading: true, message: "Searching server-indexed programs... Back cancels. Quoted phrases and AND/OR are supported."}
    m.searchView.model = model
    m.searchView.active = true
    m.searchTask = CreateObject("roSGNode", "ProgramSearchTask")
    m.searchTask.baseUrl = m.base
    m.searchTask.apiKey = m.key
    m.searchTask.query = m.programQuery
    m.searchTask.searchField = m.programSearchField
    m.searchTask.page = m.programSearchPage
    m.searchTask.now = m.programSearchNow
    m.searchTask.channels = m.channels
    m.searchTask.observeField("result", "onProgramSearchResult")
    m.searchTask.control = "RUN"
end sub

sub onProgramSearchResult(event as object)
    if not isCurrentTaskEvent(event, m.searchTask) then return
    result = event.getData()
    m.searchTask.unobserveField("result")
    m.searchTask = invalid
    if not m.top.active or not m.searchView.active then return
    message = result.message
    if result.ok
        message = "Server-indexed programs only; unindexed or overridden EPG assignments may be absent."
        if result.items.count() = 0 then message = "No matching programs for your lineup on this page. Try another page or edit the search."
        if result.truncated then message = "First 200 channel airings on this page shown. Narrow the search for additional matches."
    end if
    m.searchView.model = {items: result.items, query: m.programQuery, searchField: m.programSearchField, page: m.programSearchPage, hasNext: result.hasNext, truncated: result.truncated, loading: false, message: message}
end sub

sub onProgramSearchSelection(event as object)
    item = event.getData()
    if not m.top.active then return
    if item.program <> invalid
        target = channelByUuid(item.channel.uuid)
        if target = invalid then return
        found = false
        for each channel in m.filtered
            if channel.uuid = target.uuid then found = true
        end for
        if not found
            m.groupIndex = 0
            m.query = ""
            filterLineup()
        end if
        selectPlayingChannel(target.uuid)
        cancelProgramSearch()
        m.searchView.active = false
        m.top.setFocus(true)
        anchor = item.program.startsAt
        if item.program.startsAt <= uiNow() and item.program.endsAt > uiNow() then anchor = uiNow()
        jumpTo(anchor)
    else if item.action = "close"
        cancelProgramSearch()
        m.searchView.active = false
        m.top.setFocus(true)
    else if item.action = "edit"
        editProgramSearch()
    else
        if item.action = "next" then m.programSearchPage++
        if item.action = "previous" and m.programSearchPage > 1 then m.programSearchPage--
        loadProgramSearch()
    end if
end sub

sub openDatePicker()
    ' Build local days from actual instants. Repeated DST hours remain distinct
    ' and missing DST hours aren't offered; the UTC reference disambiguates them.
    now = uiNow()
    dates = []
    lastDate = ""
    start = ((now - 259200) \ 1800) * 1800 + 1800
    for epoch = start to now + 604799 step 1800
        date = uiLocalDate(epoch)
        if date <> lastDate
            dates.push({title: date, times: []})
            lastDate = date
        end if
        dates[dates.count() - 1].times.push({title: uiTime(epoch) + "  (" + uiTime(epoch, false) + " UTC)", epoch: epoch})
    end for
    openPicker("Jump to date", dates, "date")
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.active then return false
    if m.picker <> invalid
        if key = "back" or key = "options"
            closePicker()
            m.top.setFocus(true)
        end if
        return true
    end if
    if key = "options"
        openOptions()
        return true
    else if key = "back"
        if m.top.miniActive
            m.top.playerRequest = "expandPlayer"
            return true
        end if
        savePreferences()
        m.top.exitRequested = true
        return true
    end if
    if key = "play" and m.top.miniActive
        m.top.playerRequest = "expandPlayer"
        return true
    end if
    if m.filtered.count() = 0 then return true
    if key = "up"
        if m.selected > 0 then m.selected--
    else if key = "down"
        if m.selected < m.filtered.count() - 1 then m.selected++
    else if key = "left" or key = "right"
        m.followNow = false
        m.direction = 1
        if key = "left" then m.direction = -1
        cell = selectedCell()
        if cell <> invalid
            m.anchor = guideNavigate(m.anchor, cell, m.direction, uiNow())
            keepAnchorVisible()
        end if
    else if key = "OK"
        cell = selectedCell()
        now = uiNow()
        if cell <> invalid
            if cell.program <> invalid
                if cell.program.startsAt > now or cell.program.endsAt <= now
                    showDetails()
                    return true
                end if
            end if
        end if
        watchLive()
        return true
    else if key = "replay"
        jumpTo(uiNow())
        return true
    else
        return false
    end if
    drawGuide()
    scheduleLoad()
    m.saveDelay.control = "stop"
    m.saveDelay.control = "start"
    return true
end function
