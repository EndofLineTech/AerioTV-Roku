sub init()
    m.canvas = m.top.findNode("canvas")
    m.top.focusable = true
    m.primaryNavigation = m.top.findNode("primaryNavigation")
    m.primaryNavigation.observeField("selection", "onPrimarySelection")
    m.primaryNavigation.observeField("exitRequested", "onPrimaryExit")
    m.primaryNavigation.observeField("active", "onGuideChromeFocus")
    updatePrimaryTabs()
    m.navigator = m.top.findNode("groupNavigator")
    m.navigator.observeField("preview", "onGroupPreview")
    m.navigator.observeField("closed", "onNavigatorClosed")
    m.navigator.observeField("optionsRequested", "handleOptionsShortcut")
    m.navigator.observeField("topRequested", "focusPrimaryNavigation")
    m.navigator.observeField("active", "onGuideChromeFocus")
    m.holdKey = ""
    m.pickerWakeKey = ""
    m.holdTimer = m.top.findNode("holdTimer")
    m.holdTimer.observeField("fire", "repeatGuideHold")
    m.loadDelay = m.top.findNode("loadDelay")
    m.clock = m.top.findNode("clock")
    m.saveDelay = m.top.findNode("saveDelay")
    m.saveDelay.observeField("fire", "savePreferences")
    m.loadDelay.observeField("fire", "loadVisibleWindows")
    m.clock.observeField("fire", "tick")
    m.task = invalid
    m.mappingTask = invalid
    m.cacheClearTask = invalid
    m.mappingState = "idle"
    m.mappingWarning = ""
    m.cacheScope = ""
    m.searchTask = invalid
    m.searchView = m.top.findNode("programSearch")
    m.searchView.observeField("selection", "onProgramSearchSelection")
    m.programQuery = ""
    m.programSearchField = "title"
    m.details = m.top.findNode("programDetails")
    m.details.observeField("action", "onRichDetailAction")
    m.detailDelay = m.top.findNode("detailDelay")
    m.detailDelay.observeField("fire", "loadProgramDetail")
    m.detailTask = invalid
    m.detailCache = {}
    m.detailOrder = []
    m.detailFailures = {}
    m.tmdbTask = invalid
    m.picker = invalid
    m.ready = false
    m.span = 8928 ' 1488 pixels at upstream's 600 pixels/hour.
    m.rowCount = 7
end sub

sub configure()
    m.top.channelFacts = {}
    m.top.catchupPermission = "unknown"
    m.top.moviesPermission = "unknown"
    m.top.seriesPermission = "unknown"
    m.metadataElapsed = CreateObject("roTimespan")
    m.metadataElapsed.mark()
    cancelMetadataLoads()
    suspendGuide()
    m.ready = false
    m.top.playbackChannel = invalid
    m.top.playbackInfo = invalid
    config = m.top.config
    if config = invalid then return
    m.top.vodEnabled = config.preferences.vodEnabled <> false
    m.channels = config.channels
    m.cacheScope = textValue(config.scope)
    m.cacheGeneration = textValue(config.generation)
    m.lineupGeneration = m.cacheGeneration
    m.forceGuideFetch = false
    m.serverGroups = config.groups
    prefs = normalizeAccountPreferences(config.preferences)
    m.settings = prefs.guide
    m.collections = prefs.collections
    m.reminders = prefs.reminders
    m.recent = prefs.recent
    m.groups = organizedGroups(m.serverGroups, m.collections, m.settings, false, m.channels)
    m.base = config.baseUrl
    m.key = config.apiKey
    m.tmdbKey = textValue(config.tmdbKey)
    m.favorites = {}
    m.allowedKeys = guideDictionary()
    m.cache = guideNewCache()
    m.detailCache = {}
    m.detailOrder = []
    m.detailFailures = {}
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
    savedIds = {}
    if type(prefs) = "roAssociativeArray"
        if type(prefs.favoriteIds) = "roArray"
            for each id in prefs.favoriteIds
                savedIds[textValue(id)] = true
            end for
        end if
        for i = 0 to m.groups.count() - 1
            startup = m.settings.startupGroup
            if startup = "last" then startup = prefs.group
            if m.groups[i].id = startup then m.groupIndex = i
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
    loadMappings()
    if m.top.active then onActive()
end sub

sub buildCanvas()
    m.canvas.removeChildrenIndex(m.canvas.getChildCount(), 0)
    uiLabel(m.canvas, "AerioTV", 96, 62, 400, 64, 46)
    m.liveTitle = uiLabel(m.canvas, "Live TV", 580, 76, 200, 48, 32, "0x1AC4D8FF")
    m.liveUnderline = uiRect(m.canvas, 580, 129, 112, 3, "0x1AC4D8FF")
    m.heading = uiLabel(m.canvas, "", 1000, 82, 820, 38, 25, "0x9EB5C9FF")
    m.title = uiLabel(m.canvas, "", 96, 150, 1728, 50, 34)
    m.description = uiLabel(m.canvas, "", 96, 205, 1728, 57, 23, "0x9EB5C9FF")
    m.description.wrap = true
    m.description.maxLines = 2
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
        name.maxLines = 2
        catchup = root.createChild("Poster")
        catchup.uri = "pkg:/images/catchup-history.png"
        catchup.translation = [12, 4]
        catchup.width = 20
        catchup.height = 20
        catchup.loadDisplayMode = "scaleToFit"
        catchup.visible = false
        m.rows.push({root: root, number: number, badge: badge, catchup: catchup, logo: logo, name: name, tiles: []})
    end for
    m.nowLine = uiRect(m.canvas, 336, 300, 2, 678, "0x1AC4D8AA")
    m.footer = uiRemoteHints(m.canvas, 96, 998, 1728, 36, 22)
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
    m.primaryNavigation.active = false
    cancelGuideHold()
    if m.tmdbTask <> invalid
        m.tmdbTask.unobserveField("result")
        cancelNetworkTask(m.tmdbTask)
        m.tmdbTask = invalid
    end if
    cancelProgramDetail()
    m.details.active = false
    m.navigator.active = false
    cancelProgramSearch()
    m.searchView.active = false
    m.clock.control = "stop"
    m.saveDelay.control = "stop"
    m.loadDelay.control = "stop"
    if m.task <> invalid
        m.task.unobserveField("cached")
        m.task.unobserveField("result")
        cancelNetworkTask(m.task)
        m.task = invalid
    end if
    closePicker()
end sub

sub tick()
    guideCachePrune(m.cache, uiNow())
    if not m.top.active
        if m.top.playbackChannel <> invalid
            publishPlaybackInfo()
            scheduleLoad()
        end if
        return
    end if
    ' Live browsing follows the clock; historical/future browsing stays anchored.
    if m.followNow then m.anchor = uiNow() else m.anchor = guideTimeClamp(m.anchor, uiNow(), m.settings)
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
            m.task.unobserveField("cached")
            m.task.unobserveField("result")
            cancelNetworkTask(m.task)
            m.task = invalid
        end if
    end if
    m.loadDelay.control = "stop"
    m.loadDelay.control = "start"
end sub

sub loadVisibleWindows()
    if not m.ready then return
    guideCachePrune(m.cache, uiNow())
    if m.mappingState = "loading" then return
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
                m.task.scope = m.cacheScope
                m.task.generation = m.cacheGeneration
                m.task.cacheEpoch = m.global.cacheEpoch
                m.task.bypassCache = m.forceGuideFetch
                m.task.observeField("result", "onWindowLoaded")
                m.task.observeField("cached", "onWindowCached")
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
    m.top.metadataEvent = {ok: result.ok, stage: "window", source: textValue(result.source), elapsedMs: m.metadataElapsed.totalMilliseconds(), message: textValue(result.message)}
    m.task.unobserveField("cached")
    m.task.unobserveField("result")
    m.task = invalid
    if result.ok
        fetched = uiNow()
        if result.fetched <> invalid then fetched = result.fetched
        guideCachePut(m.cache, result.windowStart, result.index, fetched)
        m.forceGuideFetch = false
        print "[guide-cache] source="; result.source; " resident="; m.cache.order.count(); " ms-after-lineup="; m.metadataElapsed.totalMilliseconds()
        changedReminder = false
        for each reminder in m.reminders
            matchedReminder = false
            channel = channelByUuid(reminder.channelUuid)
            if channel <> invalid
                key = guideChannelKey(channel, result.index)
                if result.index.doesExist(key)
                    for each program in result.index[key]
                        if reminder.id = channel.uuid + "|" + program.id
                            matchedReminder = true
                            if reminder.unavailable = true
                                reminder.unavailable = false
                                changedReminder = true
                            end if
                            if reminder.startsAt <> program.startsAt or reminder.endsAt <> program.endsAt or reminder.title <> program.title
                                reminder.startsAt = program.startsAt
                                reminder.endsAt = program.endsAt
                                reminder.title = program.title
                                changedReminder = true
                            end if
                        end if
                    end for
                end if
            end if
            if not matchedReminder and reminder.startsAt >= result.windowStart and reminder.startsAt < result.windowStart + 10800
                if reminder.unavailable <> true
                    reminder.unavailable = true
                    changedReminder = true
                end if
            end if
        end for
        if changedReminder then savePreferences()
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
        return cachedPlaybackInfo(m.top.playbackChannel, playbackClockEpoch()).windows
    end if
    first = guideWindowStart(m.viewStart)
    last = guideWindowStart(m.viewStart + m.span - 1)
    windows = [first]
    if last <> first then windows.push(last)
    adjacent = last + 10800
    if m.direction < 0 then adjacent = first - 10800
    if adjacent >= guideWindowStart(now - m.settings.historyDays * 86400) and adjacent <= guideWindowStart(now + m.settings.futureDays * 86400 - 1) then windows.push(adjacent)
    return windows
end function

function cachedPlaybackInfo(channel as object, now as integer) as object
    if not m.ready or m.mappingState = "loading" then return {channelUuid: channel.uuid, status: "loading", programs: [], windows: []}
    current = channelByUuid(channel.uuid)
    if current <> invalid then channel = current
    return playbackSnapshot(m.cache, m.failures, channel, now, uiNow())
end function

sub publishPlaybackInfo()
    if m.top.playbackChannel = invalid then return
    m.top.playbackInfo = cachedPlaybackInfo(m.top.playbackChannel, playbackClockEpoch())
end sub

function playbackClockEpoch() as integer
    now = uiNow()
    if m.top.playbackEpoch > 0 and m.top.playbackEpoch <= now then return m.top.playbackEpoch
    return now
end function

sub onPlaybackTime()
    if m.ready <> true or m.top.playbackChannel = invalid or m.top.active then return
    window = guideWindowStart(playbackClockEpoch())
    if m.playbackRequestedWindow = window then return
    m.playbackRequestedWindow = window
    scheduleLoad()
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
    programs = guideCachePrograms(m.cache, key, m.viewStart, m.viewStart + m.span)
    for i = 0 to programs.count() - 1
        if m.detailCache.doesExist(programs[i].id) then programs[i] = mergeProgramFacts(programs[i], m.detailCache[programs[i].id])
    end for
    return programs
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
    gridX = 96
    if m.settings.groupLayout = "sidebar" then gridX = 400
    timeX = gridX + 240
    m.span = (1824 - timeX) * 6
    keepAnchorVisible()
    m.detailDelay.control = "stop"
    m.detailDelay.control = "start"
    if m.selected < m.rowStart then m.rowStart = m.selected
    if m.selected >= m.rowStart + m.rowCount then m.rowStart = m.selected - m.rowCount + 1
    now = uiNow()
    groupTitle = m.groups[m.groupIndex].name
    if m.query <> "" then groupTitle = "Search all channels"
    m.heading.text = groupTitle + "  |  " + m.filtered.count().toStr() + " channels  |  " + uiTime(now)
    m.liveTitle.visible = false
    m.liveUnderline.visible = false
    m.heading.visible = m.settings.groupLayout <> "pills"
    if not m.navigator.active then m.navigator.model = {groups: m.groups, layout: m.settings.groupLayout, selected: m.groups[m.groupIndex].id}
    m.dateLabel.text = uiLocalDate(m.viewStart)
    m.dateLabel.translation = [gridX, 270]
    for i = 0 to m.ticks.count() - 1
        m.ticks[i].text = uiTime(m.viewStart + i * 1800)
        tickX = timeX + 10 + i * 300
        m.ticks[i].translation = [tickX, 270]
        m.ticks[i].visible = tickX < 1824
    end for
    for i = 0 to m.rows.count() - 1
        row = m.rows[i]
        row.root.translation = [gridX, 306 + i * 96]
        index = m.rowStart + i
        row.root.visible = index < m.filtered.count()
        if row.root.visible
            channel = m.filtered[index]
            row.uuid = channel.uuid
            row.number.text = channel.number
            row.catchup.visible = catchupChannelDays(m.top.catchupPermission, m.top.channelFacts, channel.id) > 0
            row.number.width = 170
            if row.catchup.visible
                ' Measure the resolved Label font so the icon follows the digits.
                row.number.width = 0
                numberWidth = row.number.localBoundingRect().width
                if numberWidth > 128 then numberWidth = 128
                row.number.width = numberWidth
                row.catchup.translation = [12 + numberWidth + 6, 4]
            end if
            row.name.text = channel.name
            row.badge.text = ""
            if m.favorites.doesExist(channel.uuid) then row.badge.text = "FAV"
            uri = ""
            if channel.logoId <> "" then uri = m.base + "/api/channels/logos/" + channel.logoId + "/cache/"
            if row.logo.uri <> uri then row.logo.uri = uri
            renderCells(row, rowCells(channel), index = m.selected)
        end if
    end for
    x = timeX + (now - m.viewStart) / 6
    m.nowLine.visible = x >= timeX and x < 1824
    if m.nowLine.visible then m.nowLine.translation = [x, 300]
    m.footer.text = guideRemoteHint()
    remote = m.top.remotePreferences
    if type(remote) = "roAssociativeArray"
        m.footer.visible = remote.infoHints <> false
    end if
    if m.query <> "" then m.footer.text = "Search ALL: " + m.query + "    * > Clear search to restore the selected group"
    if m.connectionWarning <> "" then m.footer.text = m.connectionWarning
    if m.message <> "" then m.footer.text = m.message
    for each window in [guideWindowStart(m.viewStart), guideWindowStart(m.viewStart + m.span - 1)]
        if m.cache.entries.doesExist(window.toStr()) and not guideCacheHas(m.cache, window, uiNow())
            m.footer.text = "Cached guide (refresh pending). " + m.footer.text
            exit for
        end if
    end for
    if m.mappingState = "loading" then m.footer.text = "Loading guide mappings... Channels are ready to watch."
    if m.mappingWarning <> "" then m.footer.text = m.mappingWarning
    if m.filtered.count() = 0
        m.title.text = "No matching channels"
        m.description.text = "Use * to choose another group or clear your search."
        return
    end if
    channel = m.filtered[m.selected]
    retention = catchupRetentionLabel(catchupChannelDays(m.top.catchupPermission, m.top.channelFacts, channel.id))
    cell = selectedCell()
    m.title.text = channel.name
    m.description.text = gapText() + "  |  OK to watch live."
    if retention <> "" then m.description.text = retention + " (provider advertised)  |  " + m.description.text
    if cell <> invalid
        if cell.program <> invalid
            program = cell.program
            m.title.text = program.title
            m.description.text = channel.name + "  |  " + uiTime(program.startsAt) + " - " + uiTime(program.endsAt) + "  " + program.description
            if retention <> "" then m.description.text = retention + " (provider advertised)  |  " + m.description.text
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
        title.maxLines = 1
        time = uiLabel(root, "", 14, 55, 70, 29, 20, "0x9EB5C9FF")
        time.vertAlign = "center"
        row.tiles.push({root: root, border: border, fill: fill, title: title, time: time, badges: []})
    end while
    for i = 0 to row.tiles.count() - 1
        tile = row.tiles[i]
        for each badge in tile.badges
            badge.root.visible = false
        end for
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
            tile.time.translation = [14, 55]
            focused = selected and cell.startsAt <= m.anchor and cell.endsAt > m.anchor and not m.primaryNavigation.active and not m.navigator.active and m.picker = invalid and not m.details.active and not m.searchView.active
            inset = 2
            if focused then inset = 4
            tile.fill.translation = [inset, inset]
            fillWidth = width - inset * 2
            if fillWidth < 1 then fillWidth = 1
            tile.fill.width = fillWidth
            tile.fill.height = 95 - inset * 2
            tile.fill.visible = width > inset * 2
            uiSetColor(tile.border, "0x17344AFF")
            uiSetColor(tile.fill, "0x0D1E35FF")
            if focused
                uiSetColor(tile.border, "0xFFFFFFFF")
                uiSetColor(tile.fill, "0x365163FF")
            end if
            tile.title.text = gapText()
            tile.time.text = ""
            if cell.program <> invalid
                if not focused then uiSetColor(tile.fill, programTint(cell.program, m.settings))
                program = cell.program
                tile.title.text = program.title
                tile.time.text = uiTime(program.startsAt) + " - " + uiTime(program.endsAt)
                flags = programFlagPills(program, m.settings, textWidth)
                offset = 0
                for j = 0 to flags.count() - 1
                    flag = flags[j]
                    if j >= tile.badges.count()
                        badgeRoot = tile.root.createChild("Group")
                        surface = uiSurface(badgeRoot, 0, 0, flag.width, 24, 12, flag.color)
                        label = uiLabel(badgeRoot, "", 0, 0, flag.width, 24, 16, "0xFFFFFFFF")
                        label.horizAlign = "center"
                        label.vertAlign = "center"
                        tile.badges.push({root: badgeRoot, surface: surface, label: label})
                    end if
                    badge = tile.badges[j]
                    badge.root.visible = true
                    badge.root.translation = [14 + flag.x, 57]
                    badge.surface.width = flag.width
                    uiSetColor(badge.surface, flag.color)
                    labelBounds = uiFlagLabelBounds(flag.label, flag.width)
                    badge.label.translation = [labelBounds.x, labelBounds.y]
                    badge.label.width = labelBounds.width
                    badge.label.height = labelBounds.height
                    badge.label.text = flag.label
                    offset = flag.x + flag.width + 8
                end for
                remaining = textWidth - offset
                tile.time.visible = remaining >= 100
                if remaining >= 100
                    tile.time.translation = [14 + offset, 55]
                    tile.time.width = remaining
                    episode = programEpisodeText(program, m.settings)
                    if episode <> "" then tile.time.text = episode + " | " + tile.time.text
                end if
                if hasReminder(m.reminders, row.uuid, program.id) then tile.title.text = "REM | " + tile.title.text
            end if
        end if
    end for
end sub

sub filterLineup()
    previous = ""
    if m.filtered <> invalid
        if m.selected < m.filtered.count() then previous = m.filtered[m.selected].uuid
    end if
    candidates = organizedChannels(m.channels, m.groups[m.groupIndex].id, m.favorites, m.recent, m.collections, m.settings, m.query)
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
    m.top.preferences = {favoriteIds: favoriteIds, lastChannel: uuid, group: m.groups[m.groupIndex].id, guide: m.settings, collections: m.collections, reminders: m.reminders}
end sub

sub keepAnchorVisible()
    if m.anchor < m.viewStart or m.anchor >= m.viewStart + m.span
        m.viewStart = (m.anchor \ 1800) * 1800
    end if
end sub

sub jumpTo(epoch as integer)
    m.followNow = abs(epoch - uiNow()) < 2
    m.anchor = guideTimeClamp(epoch, uiNow(), m.settings)
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
    return {channels: m.channels, groups: m.groups, favorites: m.favorites, collections: m.collections, settings: m.settings, group: m.groups[m.groupIndex].id}
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
    cell = selectedCell()
    if cell <> invalid
        if cell.program <> invalid
            m.detailProgram = cell.program
            m.detailChannel = m.filtered[m.selected]
            updateRichDetails()
            m.details.active = true
            loadProgramDetail()
            return
        end if
    end if
    showGapDetails()
end sub

sub showGapDetails()
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
    cancelGuideHold()
    closePicker()
    m.pickerKind = kind
    m.pickerItems = items
    m.picker = m.top.createChild("Group")
    uiRect(m.picker, 0, 0, 1920, 1080, "0x000000CC")
    uiSurface(m.picker, 460, 130, 1000, 810, 24, "0x0D1E35F0")
    uiLabel(m.picker, title, 510, 170, 900, 66, 38)
    list = m.picker.createChild("LabelList")
    list.translation = [510, 265]
    list.itemSize = [900, 64]
    list.itemSpacing = [0, 0]
    list.numRows = 8
    list.clippingRect = [0, 0, 900, 512]
    uiSetColor(list, "0xE8F3FAFF")
    uiSetColor(list, "0x0A1629FF", "focusedColor")
    uiSetColor(list, "0x1AC4D8FF", "focusBitmapBlendColor")
    list.focusBitmapUri = "pkg:/images/ui-focus-pill.png"
    content = CreateObject("roSGNode", "ContentNode")
    for each item in items
        child = content.createChild("ContentNode")
        child.title = item.title
    end for
    list.content = content
    list.observeField("itemSelected", "onPickerSelected")
    m.pickerList = list
    hints = uiRemoteHints(m.picker, 510, 866, 900, 36, 21)
    hints.text = "Up/Down  Scroll choices     OK  Select     Back  Close"
    list.setFocus(true)
end sub

sub closePicker()
    m.guideLeftReleasePending = false
    m.pickerList = invalid
    if m.picker <> invalid
        m.top.removeChild(m.picker)
        m.picker = invalid
    end if
end sub

sub openOptions()
    m.navigator.active = false
    items = [
        {title: "Program details", action: "details"}
        {title: "Toggle favorite", action: "favorite"}
        {title: "Channel groups", action: "groups"}
        {title: "Channel groups (list fallback)", action: "groupList"}
        {title: "Group navigation layout", action: "navigationLayout"}
        {title: "Search channels", action: "search"}
        {title: "Search programs / movies / TV", action: "programSearch"}
        {title: "Clear search", action: "clear"}
        {title: "Jump to date and time", action: "date"}
        {title: "Jump to Now", action: "now"}
        {title: "Refresh guide", action: "refresh"}
        {title: "Connection settings", action: "settings"}
        {title: "Diagnostics", action: "diagnostics"}
        {title: "Clock format", action: "clock"}
        {title: "Guide settings", action: "guideSettings"}
        {title: "Settings (Live TV / Player / Appearance / General)", action: "settingsHub"}
        {title: "Manage groups", action: "manageGroups"}
        {title: "Collections", action: "collections"}
        {title: "Favorite ordering", action: "favoriteOrder"}
        {title: "Program reminders", action: "reminders"}
        {title: "Jump to top", action: "top"}
        {title: "Go to channel number", action: "number"}
        {title: "Refresh channel lineup", action: "refreshChannels"}
        {title: "Clear guide/detail cache", action: "clearCache"}
    ]
    if m.top.miniActive
        items.unshift({title: "Stop playback", action: "stopPlayer"})
        if m.top.sleepActive then items.unshift({title: "Cancel sleep timer", action: "cancelSleep"})
        items.unshift({title: "AerioTV player options", action: "optionsPlayer"})
        items.unshift({title: "Return to fullscreen", action: "expandPlayer"})
    end if
    if m.top.moviesPermission = "allowed" then items.push({title: "Movies", action: "movies"})
    if m.top.seriesPermission = "allowed" then items.push({title: "TV Shows", action: "series"})
    label = "Enable VOD libraries for this connection"
    if m.top.vodEnabled then label = "Disable VOD libraries for this connection"
    items.push({title: label, action: "toggleVod"})
    if m.top.pendingTune then items.unshift({title: "Cancel pending channel tune", action: "cancelPendingTune"})
    openPicker("Guide options", items, "options")
end sub

sub onPickerSelected(event as object)
    if m.pickerList = invalid then return
    if not m.pickerList.isSameNode(event.getRoSGNode()) then return
    if event.getData() < 0 or event.getData() >= m.pickerItems.count() then return
    item = m.pickerItems[event.getData()]
    kind = m.pickerKind
    m.pickerWakeKey = "OK"
    closePicker()
    m.top.setFocus(true)
    if handleGuideSetting(kind, item) then return
    if kind = "programSearchField"
        if item.field = "searchMovies" or item.field = "searchSeries"
            m.top.playerRequest = item.field
            return
        end if
        m.programSearchField = item.field
        editProgramSearch()
        return
    else if kind = "dateCategory"
        if item.action = "now" then jumpTo(uiNow()) else openPicker(item.title, item.days, "date")
        return
    else if kind = "clock"
        m.top.devicePreference = {clockFormat: item.value}
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
        if action = "expandPlayer" or action = "stopPlayer" or action = "optionsPlayer" or action = "cancelSleep" or action = "cancelPendingTune"
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
        else if action = "navigationLayout"
            openNavigationLayout()
            return
        else if action = "groups" or action = "groupList"
            if action = "groups" and m.settings.groupLayout <> "modal"
                m.navigator.active = true
                return
            end if
            items = []
            for i = 0 to m.groups.count() - 1
                items.push({title: m.groups[i].name, index: i})
            end for
            openPicker("Channel groups", items, "groups")
            return
        else if action = "programSearch"
            scopes = [{title: "Program title", field: "title"}, {title: "Program description", field: "description"}]
            if m.top.vodEnabled
                if m.top.moviesPermission = "allowed" then scopes.push({title: "Movies", field: "searchMovies"})
                if m.top.seriesPermission = "allowed" then scopes.push({title: "TV Shows", field: "searchSeries"})
            end if
            openPicker("Search in", scopes, "programSearchField")
            return
        else if action = "guideSettings" or action = "manageGroups" or action = "collections" or action = "favoriteOrder" or action = "reminders"
            openGuideSetting(action)
            return
        else if action = "top"
            m.selected = 0
            m.rowStart = 0
        else if action = "number"
            openGuideKeyboard("number", "Channel number in current list (decimals allowed)", "")
            return
        else if action = "refreshChannels"
            m.top.playerRequest = "refreshChannels"
            return
        else if action = "movies" or action = "series" or action = "diagnostics" or action = "toggleVod" or action = "settingsHub"
            m.top.playerRequest = action
            return
        else if action = "clearCache"
            cancelProgramDetail()
            m.cache = guideNewCache()
            m.detailCache = {}
            m.detailOrder = []
            m.detailFailures = {}
            m.failures = {}
            clearStoredGuideCache()
        else if action = "clock"
            openPicker("Clock format", [{title: "System", value: "system"}, {title: "12-hour", value: "12"}, {title: "24-hour", value: "24"}], "clock")
            return
        else if action = "search"
            dialog = CreateObject("roSGNode", "KeyboardDialog")
            dialog.title = "Search ALL authorized channels by name or number"
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
            clearStoredGuideCache()
            cancelProgramDetail()
            m.detailCache = {}
            m.detailOrder = []
            m.detailFailures = {}
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
        m.message = ""
        filterLineup()
        drawGuide()
        scheduleLoad()
    end if
    dialog.close = true
end sub

sub cancelProgramSearch()
    if m.searchTask <> invalid
        m.searchTask.unobserveField("result")
        cancelNetworkTask(m.searchTask)
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
    m.searchTask.historyDays = m.settings.historyDays
    m.searchTask.futureDays = m.settings.futureDays
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
            m.query = ""
            allFound = false
            for i = 0 to m.groups.count() - 1
                if m.groups[i].id = "all"
                    m.groupIndex = i
                    allFound = true
                end if
            end for
            if not allFound then m.query = target.name
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
    start = ((now - m.settings.historyDays * 86400) \ 1800) * 1800 + 1800
    for epoch = start to now + m.settings.futureDays * 86400 - 1 step 1800
        date = uiLocalDate(epoch)
        if date <> lastDate
            dates.push({title: date, times: []})
            lastDate = date
        end if
        dates[dates.count() - 1].times.push({title: uiTime(epoch) + "  (" + uiTime(epoch, false) + " UTC)", epoch: epoch})
    end for
    today = []
    future = []
    past = []
    for each day in dates
        if day.title = uiLocalDate(now)
            today.push(day)
        else if day.title > uiLocalDate(now)
            future.push(day)
        else
            past.unshift(day)
        end if
    end for
    openPicker("Jump to date", [{title: "Jump to Now", action: "now"}, {title: "Today", days: today}, {title: "Upcoming", days: future}, {title: "Previous", days: past}], "dateCategory")
end sub

sub moveGuideTime(key as string)
    m.followNow = false
    m.direction = 1
    if key = "left" then m.direction = -1
    cell = selectedCell()
    if cell <> invalid
        target = cell.endsAt
        if m.direction < 0 then target = cell.startsAt - 1
        m.anchor = guideTimeClamp(target, uiNow(), m.settings)
        keepAnchorVisible()
    end if
end sub

sub activateGuideSelection()
    cell = selectedCell()
    now = uiNow()
    if cell <> invalid and cell.program <> invalid
        if cell.program.startsAt > now or cell.program.endsAt <= now
            showDetails()
            return
        end if
    end if
    watchLive()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if key = "home" then return false
    if not m.top.active then return false
    ' The committing LabelList OK must not tune the grid after closing a picker.
    if m.pickerWakeKey = key
        if not press then m.pickerWakeKey = ""
        return true
    end if
    if handleGuideHeldKey(key, press) then return true
    if not press then return false
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
        if m.top.pendingTune = true
            m.top.playerRequest = "cancelPendingTune"
            return true
        end if
        if m.top.miniActive
            m.top.playerRequest = "expandPlayer"
            return true
        end if
        savePreferences()
        m.top.exitRequested = true
        return true
    end if
    if key = "play" and m.top.miniActive
        return handleGuideMappedKey(key)
    end if
    if key = "up" and m.selected = 0 and m.settings.groupLayout <> "modal"
        m.navigator.active = true
        return true
    end if
    if key = "up" and (m.selected = 0 or m.filtered.count() = 0)
        focusPrimaryNavigation()
        return true
    end if
    if m.filtered.count() = 0 then return true
    if handleGuideMappedKey(key) then return true
    if len(key) = 1 and instr(1, "0123456789", key) > 0
        openGuideKeyboard("number", "Channel number in current list", key)
        return true
    else if key = "up"
        if m.selected > 0 then m.selected--
        beginGuideHold(key)
    else if key = "down"
        if m.selected < m.filtered.count() - 1 then m.selected++
        beginGuideHold(key)
    else
        return false
    end if
    drawGuide()
    scheduleLoad()
    m.saveDelay.control = "stop"
    m.saveDelay.control = "start"
    return true
end function

sub updatePrimaryTabs()
    if m.primaryNavigation = invalid then return
    enabled = m.top.moviesPermission = "allowed" or m.top.seriesPermission = "allowed"
    items = [{id: "live", label: "Live TV", enabled: true}, {id: "vod", label: "VOD", enabled: enabled}, {id: "settings", label: "Settings", enabled: true}]
    if FormatJson(m.primaryNavigation.items) <> FormatJson(items) then m.primaryNavigation.items = items
end sub

sub onGuideChromeFocus()
    if m.ready = true and m.top.active then drawGuide()
end sub

sub focusPrimaryNavigation()
    if not m.top.active then return
    cancelGuideHold()
    m.navigator.active = false
    m.primaryNavigation.active = true
end sub

sub onPrimarySelection(event as object)
    m.top.setFocus(true)
    if event.getData() = "vod"
        m.top.playerRequest = "vodHome"
    else if event.getData() = "settings"
        m.top.playerRequest = "settingsHub"
    else
        m.top.setFocus(true)
    end if
end sub

sub onPrimaryExit(event as object)
    if event.getData() = "down" and m.settings.groupLayout = "pills" then m.navigator.active = true else m.top.setFocus(true)
end sub
