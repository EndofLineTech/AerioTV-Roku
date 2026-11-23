sub openDvrLibrary()
    if userProfileGateClosed() then return
    if m.page <> "guide" then return
    if m.capabilities.dvr <> "view" and m.capabilities.dvr <> "manage" then return
    if m.serverAccountId = "" or m.guide.config = invalid then return
    stopPlayback()
    m.guide.active = false
    m.guide.visible = false
    m.screen.visible = false
    m.page = "dvr"
    m.dvr.config = userViewEvent({baseUrl: m.baseUrl, apiKey: m.apiKey, accountId: m.serverAccountId, scope: m.accountIdentity, permission: m.capabilities.dvr, channels: m.guide.config.channels}, currentUserSessionId())
    m.dvr.active = true
end sub

sub closeDvrLibrary()
    if m.page <> "dvr" then return
    cancelDvrPlayback()
    m.dvr.active = false
    m.dvr.config = invalid
    m.page = "guide"
    m.guide.visible = true
    m.guide.active = true
    resumePendingVodDeepLink()
end sub

' Two-step Back: the DVR root returns to its tab before the Live TV grid.
sub onDvrBack()
    if m.page <> "dvr" then return
    closeDvrLibrary()
    if m.page = "guide" then m.guide.focusTab = "dvr"
end sub

sub openVodLibrary(kind as string)
    if userProfileGateClosed() then return
    if m.accountPreferences.vodEnabled = false then return
    if kind = "movie" and m.capabilities.movies <> "allowed" then return
    if kind = "series" and m.capabilities.series <> "allowed" then return
    stopPlayback()
    m.guide.active = false
    m.guide.visible = false
    m.screen.visible = false
    m.page = "library"
    m.vod.savedState = vodState(m.accountPreferences.vod)
    m.vod.history = vodHistory(m.accountPreferences.vodRecent)
    m.vod.unsupportedTitles = vodUnsupportedLookup(vodUnsupportedStore(), m.baseUrl)
    bookmark = invalid
    if type(m.accountPreferences.vodBrowse) = "roAssociativeArray" then bookmark = m.accountPreferences.vodBrowse[kind]
    connection = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if connection <> invalid and connection.provider = "xtream"
        m.vod.config = userViewEvent({kind: kind, providerType: "xtream", baseUrl: m.baseUrl, username: m.xcUsername, password: m.xcPassword, accountScope: m.accountIdentity, apiKey: "", accountId: "", bookmark: bookmark, tmdbEnabled: false}, currentUserSessionId())
    else
        m.vod.config = userViewEvent({kind: kind, baseUrl: m.baseUrl, apiKey: m.apiKey, accountId: m.serverAccountId, accountScope: normalizeBaseUrl(m.baseUrl) + "|" + m.serverAccountId, bookmark: bookmark, tmdbKey: m.registry.read("tmdbApiKey"), tmdbEnabled: m.accountPreferences.vodTmdbEnabled = true}, currentUserSessionId())
    end if
    m.vod.active = true
end sub

sub closeVodLibrary()
    restoreSearch = false
    if m.unifiedSearchReturn <> invalid and m.guide.config <> invalid
        restoreSearch = m.unifiedSearchReturn.account = m.accountIdentity and m.unifiedSearchReturn.scope = m.guide.config.scope
    end if
    m.unifiedSearchReturn = invalid
    m.vod.callFunc("saveLibraryBookmark")
    m.vod.callFunc("cancelVod")
    m.vod.active = false
    if m.vod.config <> invalid
        if textValue(m.vod.config.providerType) = "xtream" then m.vod.config = invalid
    end if
    m.page = "guide"
    m.guide.visible = true
    m.guide.active = true
    if restoreSearch then m.guide.callFunc("resumeUnifiedSearch")
    resumePendingVodDeepLink()
end sub

sub onUnifiedSearchVodSelection(event as object)
    if not userEventCurrent(event.getData()) then return
    if not m.guide.isSameNode(event.getRoSGNode()) or m.page <> "guide" then return
    selection = event.getData()
    if type(selection) <> "roAssociativeArray" or m.guide.config = invalid then return
    if textValue(m.guide.config.providerType) <> "dispatcharr" or m.accountPreferences.vodEnabled = false then return
    if selection.scope <> m.guide.config.scope or selection.accountId <> m.serverAccountId then return
    kind = textValue(selection.kind)
    if kind = "movie" and m.capabilities.movies <> "allowed" then return
    if kind = "series" and m.capabilities.series <> "allowed" then return
    if kind <> "movie" and kind <> "series" then return
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(textValue(selection.id)) then return
    m.unifiedSearchReturn = {account: m.accountIdentity, scope: selection.scope}
    openVodLibrary(kind)
    if m.page <> "library"
        m.unifiedSearchReturn = invalid
        return
    end if
    m.vod.searchSelection = {accountScope: normalizeBaseUrl(m.baseUrl) + "|" + m.serverAccountId, kind: kind, id: selection.id, query: selection.query}
end sub

sub onLibraryDestination(event as object)
    if not m.vod.isSameNode(event.getRoSGNode()) or m.page <> "library" then return
    openVodLibrary(event.getData())
end sub

sub onXtreamVodAuthRejected(event as object)
    if not m.vod.isSameNode(event.getRoSGNode()) or m.page <> "library" then return
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid or entry.provider <> "xtream" then return
    requireConnectionRelogin("Xtream credentials were rejected by the provider.")
end sub

sub onVodBookmark(event as object)
    if not m.vod.isSameNode(event.getRoSGNode()) then return
    value = event.getData()
    if not userEventCurrent(value) then return
    scope = normalizeBaseUrl(m.baseUrl) + "|" + m.serverAccountId
    if m.vod.config <> invalid then scope = textValue(m.vod.config.accountScope)
    if value.scope <> scope then return
    if value.kind <> "movie" and value.kind <> "series" then return
    if type(m.accountPreferences.vodBrowse) <> "roAssociativeArray" then m.accountPreferences.vodBrowse = {}
    m.accountPreferences.vodBrowse[value.kind] = {query: left(textValue(value.query), 120), category: left(textValue(value.category), 240), providerId: left(textValue(value.providerId), 20), ordering: left(textValue(value.ordering), 30), page: value.page, index: value.index}
    persistAccountPreferences()
end sub

sub updateLibraryPermissions()
    m.guide.moviesPermission = m.capabilities.movies
    m.guide.seriesPermission = m.capabilities.series
    m.guide.vodEnabled = m.accountPreferences.vodEnabled <> false
    if not m.guide.vodEnabled
        m.guide.moviesPermission = "denied"
        m.guide.seriesPermission = "denied"
    end if
    m.vod.permissions = {movies: m.guide.moviesPermission, series: m.guide.seriesPermission, level: m.capabilities.level}
    if m.page = "dvr"
        if m.capabilities.dvr <> "view" and m.capabilities.dvr <> "manage"
            closeDvrLibrary()
        else
            config = m.dvr.config
            if type(config) = "roAssociativeArray"
                if config.permission <> m.capabilities.dvr
                    updated = {}
                    updated.append(config)
                    updated.permission = m.capabilities.dvr
                    ' DvrView.onDvrConfig drops old dialogs and in-flight operations.
                    m.dvr.config = userViewEvent(updated, currentUserSessionId())
                end if
            end if
        end if
    end if
    if m.settingsHub <> invalid
        if m.settingsHub.active then refreshSettingsHub()
    end if
end sub

sub onVodPlay(event as object)
    if not userEventCurrent(event.getData()) then return
    if not m.vod.isSameNode(event.getRoSGNode()) or m.page <> "library" then return
    started = startVodPlayback(event.getData(), "library")
end sub

function startVodPlayback(item as object, returnPage as string, linkOwner = invalid as dynamic) as boolean
    scope = normalizeBaseUrl(m.baseUrl) + "|" + m.serverAccountId
    connection = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    directXtream = connection <> invalid and connection.provider = "xtream"
    if directXtream then scope = m.accountIdentity
    if textValue(item.accountScope) <> scope then return false
    identity = "roku_" + CreateObject("roDeviceInfo").getRandomUUID()
    transport = identity
    if m.vodTransport <> invalid
        if m.vodTransport.account = m.accountIdentity and m.vodTransport.key = item.key and m.vodTransport.version = textValue(item.relationId) then transport = m.vodTransport.id
    end if
    url = vodPlaybackUrl(m.baseUrl, item, transport)
    if directXtream then url = xtreamVodStreamUrl(m.baseUrl, m.xcUsername, m.xcPassword, item)
    if url = ""
        if directXtream then showNotice("Xtream title format is not supported for this Roku.")
        return false
    end if
    if returnPage = "guide"
        stopPlayback()
        m.guide.active = false
        m.guide.visible = false
        m.screen.visible = false
    end if
    m.vodTransport = {account: m.accountIdentity, key: item.key, id: transport, version: textValue(item.relationId)}
    saveVodChange(item, {relationId: textValue(item.relationId)})
    m.mediaReturn = returnPage
    m.mediaItem = item
    recordDiagnostic("vod", 0, "Opening " + item.kind + " using " + item.streamFormat)
    m.mediaIdentity = identity
    m.lastVodWrite = 0
    m.lastVodState = ""
    m.mediaHistoryRecorded = false
    m.vod.active = false
    m.page = "onDemand"
    providerType = "dispatcharr"
    if directXtream then providerType = "xtream"
    token = ""
    if linkOwner <> invalid then token = textValue(linkOwner.request.coldToken)
    if coldPlaybackCurrent(token)
        m.coldPlayback.phase = "vod-renderer"
        m.coldPlayback.identity = identity
        m.coldPlayback.protection = linkOwner.protection
    else
        token = ""
    end if
    m.mediaPlayer.request = userViewEvent({account: m.accountIdentity, identity: identity, key: item.key, mode: "vod", providerType: providerType, url: url, title: item.title, apiKey: m.apiKey, streamFormat: item.streamFormat, resume: item.resume, coldToken: token}, currentUserSessionId())
    return true
end function

sub onMediaClosed(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) then return
    if not userEventCurrent(event.getData()) then return
    if m.page <> "onDemand" then return
    closed = event.getData()
    if textValue(closed.coldToken) <> "" and closed.identity <> m.mediaIdentity then return
    saveClosingArchiveBookmark()
    m.archiveSeeking = false
    cancelArchiveLoad()
    releaseArchive()
    if m.mediaReturn = "dvr"
        m.dvrPlayback = invalid
        m.page = "dvr"
        m.dvr.active = true
    else if m.mediaReturn = "library"
        m.page = "library"
        m.vod.active = true
    else
        m.page = "guide"
        m.guide.visible = true
        m.guide.active = true
        if textValue(closed.coldToken) <> ""
            settleColdPlayback(closed.coldToken, textValue(closed.coldResult))
            if m.pendingLaunch <> invalid then handlePendingLaunch()
        else
            resumePendingVodDeepLink()
        end if
    end if
end sub

sub onArchiveRequested(event as object)
    if not userEventCurrent(event.getData()) then return
    if not m.guide.isSameNode(event.getRoSGNode()) or m.page <> "guide" then return
    cancelArchiveLoad()
    selected = event.getData()
    if m.guide.config = invalid then return
    if textValue(selected.scope) <> textValue(m.guide.config.scope) then return
    channel = m.guide.callFunc("channelByUuid", selected.channel.uuid)
    if channel = invalid
        clearArchiveBookmark(textValue(selected.channel.uuid), selected.program)
        return
    end if
    connection = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    requestShiftMinutes = 0
    directXtream = false
    if connection <> invalid
        if catchupOffsetSupported(connection.provider) then requestShiftMinutes = catchupOffsetMinutes(connection.catchupOffsetMinutes)
        directXtream = connection.provider = "xtream"
    end if
    days = catchupChannelDays(m.capabilities.catchup, m.channelFacts, channel.id)
    program = selected.program
    restarting = selected.restart = true
    now = uiNow()
    requestedProgram = program
    playhead = 0
    if restarting
        if directXtream
            showNotice("Restart of an in-progress Xtream programme is not available. Choose a completed programme.")
            return
        end if
        requestShiftMinutes = 0 ' Upstream only corrects the completed-program archive path.
        plan = catchupRestartPlan(program, days, now)
        if plan = invalid
            showNotice("Restart is no longer available for this program. Reopen its details.")
            return
        end if
        program = plan.program
        requestedProgram = program
    else if not catchupEligible(program, days, now)
        if m.capabilities.catchup = "denied" or days > 0 then clearArchiveBookmark(channel.uuid, program)
        showNotice("Archive is no longer available for this program. Reopen its details.")
        return
    else
        if catchupRequestWindow(program, days, now, requestShiftMinutes, directXtream) = invalid
            showNotice("The requested archive window is outside provider history. Check the catch-up offset or try again later.")
            return
        end if
        plan = catchupBookmarkPlan(m.accountPreferences.archiveBookmarks, channel.uuid, program, textValue(selected.bookmarkAction), now, directXtream)
        if plan = invalid
            showNotice("The saved position is no longer available. Reopen Program details to play from the beginning.")
            return
        end if
        requestedProgram = plan.program
        playhead = plan.offset
        if directXtream
            archiveRequest = xtreamArchiveRequest(m.baseUrl, m.xcUsername, m.xcPassword, m.xcTimezone, channel, requestedProgram, now, requestShiftMinutes)
            if archiveRequest = invalid
                showNotice("Xtream archive request is not supported for this programme or timezone.")
                return
            end if
        end if
        if selected.bookmarkAction = "startOver"
            if not clearArchiveBookmark(channel.uuid, program) then return
        end if
    end if
    stopPlayback()
    releaseArchive()
    m.archiveContext = {baseUrl: m.baseUrl, apiKey: m.apiKey, account: m.accountIdentity, connectionId: m.selectedConnectionId, channel: channel, program: program, restart: restarting, requestShiftMinutes: requestShiftMinutes, retentionDays: days}
    m.archiveOffset = playhead
    m.archiveStartPaused = false
    m.archiveSeeking = false
    if directXtream
        m.archiveContext.providerType = "xtream"
        m.archiveContext.apiKey = ""
        m.mediaReturn = "guide"
        m.guide.active = false
        m.guide.visible = false
        m.page = "onDemand"
        m.mediaPlayer.skipSeconds = m.devicePreferences.archiveSkipSeconds
        m.mediaPlayer.broadcastInfo = invalid
        openXtreamArchiveMedia(archiveRequest)
        return
    end if
    m.archiveTask = CreateObject("roSGNode", "CatchupTask")
    tagTaskForCurrentUser(m.archiveTask)
    m.archiveTask.baseUrl = m.baseUrl
    m.archiveTask.apiKey = m.apiKey
    m.archiveTask.accountId = m.serverAccountId
    m.archiveTask.channelUuid = channel.uuid
    m.archiveTask.program = requestedProgram
    m.archiveTask.restart = restarting
    m.archiveTask.requestShiftMinutes = requestShiftMinutes
    m.archiveTask.retentionDays = days
    m.archiveTask.observeField("result", "onArchiveCreated")
    m.archiveTask.control = "RUN"
    m.page = "archiveLoading"
    m.guide.active = false
    m.top.setFocus(true)
    if restarting then showNotice("Opening Restart Program... Archive may not yet be available. Back cancels.") else showNotice("Opening archive... Back cancels.")
end sub

sub openXtreamArchiveMedia(archiveRequest as object)
    program = m.archiveContext.program
    identity = CreateObject("roDeviceInfo").getRandomUUID()
    beginArchiveBookmarkPlayback(identity)
    ' UTC whole-minute rounding still affects the playhead after removing the
    ' configured correction; use the same wire window that generated the URL.
    m.archiveContext.bookmarkOffset = archiveRequest.guideStart - program.startsAt
    m.mediaPlayer.request = userViewEvent({account: m.accountIdentity, identity: identity, key: textValue(program.id), mode: "catchup", providerType: "xtream", url: archiveRequest.url, title: program.title, apiKey: "", streamFormat: "ts", programStart: program.startsAt, program: program, offset: m.archiveOffset, startPaused: m.archiveStartPaused, restart: false, rewind: false}, currentUserSessionId())
end sub

sub openLiveRewind()
    if m.page <> "player" or m.playingChannel = invalid or m.liveSession = invalid then return
    if m.video.state <> "playing" and m.video.state <> "paused" then return
    channel = m.guide.callFunc("channelByUuid", m.playingChannel.uuid)
    if channel = invalid then return
    if catchupChannelDays(m.capabilities.catchup, m.channelFacts, channel.id) <= 0
        showNotice("Provider rewind is unavailable on this channel.")
        return
    end if
    now = uiNow()
    tunedAt = m.liveSession.openedAt
    bounds = rewindBounds(tunedAt, now)
    if bounds = invalid
        showNotice("No whole-minute rewind history since this tune yet. Try again shortly.")
        return
    end if
    origin = {id: "rewind-" + channel.uuid, title: channel.name, startsAt: bounds.start, endsAt: now}
    plan = rewindSeekPlan(origin, tunedAt, now - m.devicePreferences.archiveSkipSeconds - origin.startsAt, now)
    paused = m.video.state = "paused"
    stopPlayback()
    cancelArchiveLoad()
    m.archiveContext = {baseUrl: m.baseUrl, apiKey: m.apiKey, account: m.accountIdentity, connectionId: m.selectedConnectionId, channel: channel, program: origin, rewind: true, tuneStart: tunedAt, restart: false}
    m.archiveOffset = plan.offset
    m.archiveStartPaused = paused
    m.archiveSeeking = false
    m.archiveTask = CreateObject("roSGNode", "CatchupTask")
    tagTaskForCurrentUser(m.archiveTask)
    m.archiveTask.baseUrl = m.baseUrl
    m.archiveTask.apiKey = m.apiKey
    m.archiveTask.accountId = m.serverAccountId
    m.archiveTask.channelUuid = channel.uuid
    m.archiveTask.program = plan.program
    m.archiveTask.rewind = true
    m.archiveTask.tuneStart = tunedAt
    m.archiveTask.observeField("result", "onArchiveCreated")
    m.archiveTask.control = "RUN"
    m.page = "archiveLoading"
    m.guide.active = false
    m.top.setFocus(true)
    showNotice("Opening provider rewind... Archive may not yet be available. Back cancels.")
end sub

sub onArchiveCreated(event as object)
    if not isCurrentTaskEvent(event, m.archiveTask) then return
    result = event.getData()
    if result.ok then recordDiagnostic("archive", 0, "Session created") else recordDiagnostic("archive", -1, result.message)
    m.archiveTask.unobserveField("result")
    m.archiveTask = invalid
    if not result.ok
        message = result.message
        if m.archiveContext <> invalid
            if m.archiveContext.restart = true or m.archiveContext.rewind = true
                if result.status = 400 or result.status = 404 or result.status = 500 or result.status = 502 or result.status = 503 or result.status = 504 then message = "Archive not yet available. The provider may be delayed or busy. Try again later or choose Watch channel LIVE."
            else if archiveBookmarkContextCurrent()
                if catchupBookmarkUnavailableStatus(result.archiveStatus)
                    clearArchiveBookmark(m.archiveContext.channel.uuid, m.archiveContext.program)
                end if
            end if
        end if
        m.archiveSeeking = false
        m.mediaPlayer.callFunc("closeMedia")
        m.mediaPlayer.visible = false
        m.page = "guide"
        m.guide.visible = true
        m.guide.active = true
        releaseArchive()
        showNotice(message)
        return
    end if
    m.archiveSession = result.sessionId
    beginArchiveBookmarkPlayback(result.sessionId)
    hideNotice()
    m.archiveServerStart = result.start
    m.archiveWindowRequestedAt = result.requestedAt
    if m.archiveContext.rewind = true then m.archiveOffset = result.requestedStart - m.archiveContext.program.startsAt
    m.archiveSeeking = false
    m.mediaReturn = "guide"
    m.lastArchiveReport = 0
    m.guide.visible = false
    m.page = "onDemand"
    p = m.archiveContext.program
    m.mediaPlayer.skipSeconds = m.devicePreferences.archiveSkipSeconds
    m.mediaPlayer.broadcastInfo = invalid
    if m.archiveContext.rewind = true
        m.guide.playbackEpoch = p.startsAt + m.archiveOffset
        m.guide.playbackChannel = m.archiveContext.channel
    end if
    m.mediaPlayer.request = userViewEvent({account: m.accountIdentity, identity: result.sessionId, key: p.id, mode: "catchup", url: result.url, title: p.title, apiKey: m.apiKey, streamFormat: "ts", programStart: p.startsAt, program: p, offset: m.archiveOffset, startPaused: m.archiveStartPaused, restart: m.archiveContext.restart = true, rewind: m.archiveContext.rewind = true, tuneStart: m.archiveContext.tuneStart}, currentUserSessionId())
end sub

sub deleteOwnArchive(id as string, callback = "" as string)
    if m.archiveContext = invalid or id = "" then return
    task = CreateObject("roSGNode", "CatchupTask")
    if callback <> "" then tagTaskForCurrentUser(task)
    task.baseUrl = m.archiveContext.baseUrl
    task.apiKey = m.archiveContext.apiKey
    task.sessionId = id
    task.operation = "delete"
    if callback <> "" then task.observeField("result", callback)
    m.archiveCleanupTask = task
    task.control = "RUN"
end sub

sub cancelArchiveLoad()
    if m.archiveTask = invalid then return
    result = m.archiveTask.result
    m.archiveTask.unobserveField("result")
    cancelNetworkTask(m.archiveTask)
    m.archiveTask = invalid
    if type(result) = "roAssociativeArray"
        if result.ok then deleteOwnArchive(result.sessionId)
    end if
end sub

sub releaseArchive()
    if m.archiveContext <> invalid
        if m.archiveContext.rewind = true
            m.guide.playbackEpoch = 0
            m.guide.playbackChannel = invalid
        end if
    end if
    if m.archivePositionTask <> invalid then cancelNetworkTask(m.archivePositionTask)
    m.archivePositionTask = invalid
    if m.archiveSession <> invalid
        deleteOwnArchive(m.archiveSession)
        m.archiveSession = invalid
    end if
    m.archiveContext = invalid
end sub

function archiveBookmarkContextCurrent() as boolean
    context = m.archiveContext
    if context = invalid or m.accountIdentity = "" then return false
    if context.restart = true or context.rewind = true or context.bookmarkUnavailable = true then return false
    return context.account = m.accountIdentity and context.connectionId = m.selectedConnectionId
end function

sub beginArchiveBookmarkPlayback(identity as string)
    if not archiveBookmarkContextCurrent() then return
    m.archiveContext.playbackIdentity = identity
    m.archiveContext.bookmarkOffset = m.archiveOffset
    m.archiveContext.lastBookmarkWrite = 0
    m.archiveContext.lastBookmarkState = ""
end sub

function persistArchiveBookmarks(rows as object) as boolean
    if m.accountIdentity = "" or m.accountPreferences = invalid then return false
    beforePreferences = m.accountPreferences
    before = beforePreferences.archiveBookmarks
    if before = invalid and rows.count() = 0 then return true
    if FormatJson(before) = FormatJson(rows) then return true
    bucket = preferenceScope(m.accountIdentity)
    previous = m.preferenceStore.accounts[bucket]
    m.accountPreferences = setCanonicalPreference(m.accountPreferences, "archiveBookmarks", rows)
    if not persistAccountPreferences()
        m.accountPreferences = beforePreferences
        if previous = invalid
            m.preferenceStore.accounts.delete(bucket)
        else
            m.preferenceStore.accounts[bucket] = previous
        end if
        showNotice("Archive progress could not be saved. The previous bookmark was retained.")
        return false
    end if
    m.guide.archiveBookmarks = rows
    return true
end function

sub reconcileArchiveBookmarks(channels as object, factsAvailable as boolean)
    if m.accountPreferences = invalid or m.accountPreferences.archiveBookmarks = invalid then return
    rows = catchupBookmarkReconcile(m.accountPreferences.archiveBookmarks, channels, m.capabilities.catchup, m.channelFacts, factsAvailable, uiNow())
    persistArchiveBookmarks(rows)
end sub

function clearArchiveBookmark(channelUuid as string, program as dynamic) as boolean
    if type(program) <> "roAssociativeArray" or m.accountPreferences = invalid then return false
    now = uiNow()
    return persistArchiveBookmarks(catchupBookmarkUpdate(m.accountPreferences.archiveBookmarks, channelUuid, program, 0, 0, now))
end function

sub saveClosingArchiveBookmark()
    progress = m.mediaPlayer.progress
    if type(progress) <> "roAssociativeArray" then return
    if progress.closing = true then saveArchiveBookmarkProgress(progress)
end sub

sub saveArchiveBookmarkProgress(progress as dynamic, force = false as boolean)
    if m.page <> "onDemand" or m.archiveSeeking = true or not archiveBookmarkContextCurrent() then return
    if not userEventCurrent(progress) then return
    context = m.archiveContext
    if textValue(context.playbackIdentity) = "" or progress.identity <> context.playbackIdentity then return
    if progress.account <> context.account or progress.mode <> "catchup" then return
    if progress.finished = true
        clearArchiveBookmark(context.channel.uuid, context.program)
        return
    end if
    ' The player only commits native playing/paused samples to progress.position.
    ' A reopen request or failed start cannot replace a previously saved position.
    if not mediaNumber(progress.position) then return
    if progress.position <= 0 then return
    if progress.state <> "playing" and progress.state <> "paused" and progress.closing <> true then return
    if m.capabilities.catchup <> "allowed" then return
    days = catchupChannelDays(m.capabilities.catchup, m.channelFacts, context.channel.id)
    now = uiNow()
    xc = context.providerType = "xtream"
    program = context.program
    if catchupRequestWindow(program, days, now, context.requestShiftMinutes, xc) = invalid then return
    position = int(progress.position + context.bookmarkOffset)
    completed = position >= program.endsAt - program.startsAt
    ' An early sample after a minute-rounded resume can fall below the
    ' bookmark floor; ignore it rather than treating it like a reset.
    if not completed and position < catchupBookmarkMinSeconds() then return
    if not (force or completed or progress.closing = true)
        if progress.state = context.lastBookmarkState and context.lastBookmarkWrite > now - 15 then return
    end if
    context.lastBookmarkState = progress.state
    context.lastBookmarkWrite = now
    if m.guide.callFunc("channelByUuid", context.channel.uuid) = invalid then return
    expiresAt = catchupBookmarkExpiry(program, days, context.requestShiftMinutes, xc)
    if completed then position = 0
    persistArchiveBookmarks(catchupBookmarkUpdate(m.accountPreferences.archiveBookmarks, context.channel.uuid, program, position, expiresAt, now))
end sub

sub resetMediaNavigation()
    cancelVodDeepLink()
    m.unifiedSearchReturn = invalid
    cancelDvrPlayback()
    if m.settingsHub <> invalid then m.settingsHub.active = false
    m.archiveSeeking = false
    m.vodTransport = invalid
    m.mediaIdentity = ""
    m.mediaItem = invalid
    cancelArchiveLoad()
    releaseArchive()
    m.mediaPlayer.callFunc("closeMedia")
    m.vod.callFunc("cancelVod")
    m.vod.active = false
    m.vod.config = invalid
    m.vod.savedState = []
    m.vod.history = []
end sub

sub onMediaProgress(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) then return
    progress = event.getData()
    if not userEventCurrent(progress) then return
    if progress.account <> m.accountIdentity then return
    if progress.mode = "recording"
        onDvrProgress(progress)
        return
    end if
    if progress.mode = "vod" and m.mediaItem <> invalid
        if progress.identity <> m.mediaIdentity or progress.key <> m.mediaItem.key or not mediaNumber(progress.position) or not mediaNumber(progress.duration) then return
        if progress.duration <= 0 then return
        final = progress.finished or progress.closing = true or progress.state = "stopped"
        if not final and progress.state = m.lastVodState and m.lastVodWrite > uiNow() - 15 then return
        m.lastVodWrite = uiNow()
        m.lastVodState = progress.state
        finished = progress.finished or progress.position >= progress.duration * 0.95
        position = int(progress.position)
        if finished then position = 0
        played = not m.mediaHistoryRecorded and (progress.state = "playing" and progress.position > 0 or progress.finished)
        if progress.state = "playing" and progress.position > 0 then rememberVodUnsupported(progress.identity, false)
        saveVodChange(m.mediaItem, {position: position, duration: int(progress.duration), watched: finished}, played)
        return
    end if
    if progress.mode = "catchup" then saveArchiveBookmarkProgress(progress)
    if progress.mode = "catchup" and m.archiveSession <> invalid
        if m.archiveSeeking = true then return
        if progress.identity <> m.archiveSession or not mediaNumber(progress.position) then return
        reportPosition = progress.position + m.archiveOffset
        if m.archiveContext.rewind = true
            epoch = m.archiveContext.program.startsAt + int(reportPosition)
            m.guide.playbackEpoch = epoch
            snapshot = m.guide.callFunc("cachedPlaybackInfo", m.archiveContext.channel, epoch)
            current = selectNowNext(snapshot.programs, epoch).current
            title = "Program information unavailable for playback time"
            reportPosition = progress.position
            if current <> invalid
                title = current.title
                reportPosition = epoch - current.startsAt
            end if
            m.mediaPlayer.broadcastInfo = {title: title, status: snapshot.status}
        end if
        if m.lastArchiveReport > uiNow() - 30 then return
        if m.archivePositionTask <> invalid
            if m.archivePositionTask.state = "run" then return
        end if
        m.lastArchiveReport = uiNow()
        m.archivePositionTask = CreateObject("roSGNode", "CatchupTask")
        tagTaskForCurrentUser(m.archivePositionTask)
        m.archivePositionTask.baseUrl = m.archiveContext.baseUrl
        m.archivePositionTask.apiKey = m.archiveContext.apiKey
        m.archivePositionTask.sessionId = m.archiveSession
        m.archivePositionTask.operation = "position"
        m.archivePositionTask.position = reportPosition
        m.archivePositionTask.paused = progress.state = "paused"
        m.archivePositionTask.control = "RUN"
    end if
end sub

sub onArchiveSeek(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) or m.page <> "onDemand" then return
    value = event.getData()
    if type(value) = "roAssociativeArray"
        if not userEventCurrent(value) then return
        target = value.target
    else
        if currentUserSessionId() <> "" then return
        target = value
    end if
    if not mediaNumber(target) then return
    if m.archiveContext <> invalid
        if m.archiveContext.account <> m.accountIdentity then return
        if m.archiveContext.connectionId <> m.selectedConnectionId then return
        if m.archiveContext.providerType = "xtream"
            program = m.archiveContext.program
            plan = catchupSeekPlan(program, target, uiNow())
            if plan = invalid then return
            channel = m.guide.callFunc("channelByUuid", m.archiveContext.channel.uuid)
            if channel = invalid then return
            archiveRequest = xtreamArchiveRequest(m.baseUrl, m.xcUsername, m.xcPassword, m.xcTimezone, channel, plan.program, uiNow(), m.archiveContext.requestShiftMinutes)
            if archiveRequest = invalid
                showNotice("Provider archive seek is no longer available. Return to the guide.")
                return
            end if
            ' The suspend event can arrive after the replacement request.
            state = m.mediaPlayer.callFunc("suspendArchive")
            saveArchiveBookmarkProgress(m.mediaPlayer.progress, true)
            m.archiveOffset = plan.offset
            m.archiveStartPaused = state.paused
            openXtreamArchiveMedia(archiveRequest)
            return
        end if
    end if
    if m.archiveSeeking = true or m.archiveSession = invalid or m.archiveContext = invalid then return
    now = uiNow()
    plan = catchupSeekPlan(m.archiveContext.program, target, now)
    if m.archiveContext.rewind = true then plan = rewindSeekPlan(m.archiveContext.program, m.archiveContext.tuneStart, target, now)
    if plan = invalid then return
    shiftMinutes = catchupOffsetMinutes(m.archiveContext.requestShiftMinutes)
    if m.archiveContext.restart <> true and m.archiveContext.rewind <> true
        if catchupRequestWindow(plan.program, m.archiveContext.retentionDays, now, shiftMinutes) = invalid
            showNotice("The requested archive window is outside provider history. Check the catch-up offset or try again later.")
            return
        end if
    end if
    state = m.mediaPlayer.callFunc("suspendArchive")
    saveArchiveBookmarkProgress(m.mediaPlayer.progress, true)
    m.archiveSeeking = true
    m.archiveSeekPlan = plan
    m.archiveStartPaused = state.paused
    if m.archivePositionTask <> invalid then cancelNetworkTask(m.archivePositionTask)
    m.archivePositionTask = invalid
    deleteOwnArchive(m.archiveSession, "onArchiveSeekReleased")
end sub

sub onArchiveSkipPreference(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) or m.page <> "onDemand" then return
    change = event.getData()
    if not userEventCurrent(change) then return
    if change.account <> m.accountIdentity then return
    if change.seconds <> 60 and change.seconds <> 120 and change.seconds <> 300 then return
    m.devicePreferences.archiveSkipSeconds = change.seconds
    persistPreferences()
end sub

sub onArchiveGoLive(event as object)
    if not userEventCurrent(event.getData()) then return
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) or m.page <> "onDemand" then return
    if m.archiveContext = invalid or m.archiveSeeking = true then return
    channel = m.guide.callFunc("channelByUuid", m.archiveContext.channel.uuid)
    if not catchupLiveReturnAllowed(m.archiveContext, m.accountIdentity, channel)
        showNotice("This channel is no longer in the authorized lineup. Return to the guide.")
        return
    end if
    ' Release only this archive session; never stop the shared live channel.
    tunedAt = 0
    if m.archiveContext.rewind = true then tunedAt = m.archiveContext.tuneStart
    m.mediaPlayer.callFunc("closeMedia")
    saveClosingArchiveBookmark()
    cancelArchiveLoad()
    releaseArchive()
    m.page = "guide" ' makes a queued archive-closed event obsolete
    startPlayback(channel, true, false, false, tunedAt)
end sub

sub onArchiveSeekReleased(event as object)
    if not isCurrentTaskEvent(event, m.archiveCleanupTask) then return
    m.archiveCleanupTask.unobserveField("result")
    if m.archiveSeeking <> true or m.page <> "onDemand" or m.archiveContext = invalid then return
    if m.archiveContext.account <> m.accountIdentity or m.archiveContext.connectionId <> m.selectedConnectionId then return
    result = event.getData()
    if not result.ok
        m.mediaPlayer.callFunc("closeMedia")
        showNotice("Could not release the prior archive session. Return to the guide and retry.")
        return
    end if
    m.archiveSession = invalid
    m.archiveOffset = m.archiveSeekPlan.offset
    m.archiveTask = CreateObject("roSGNode", "CatchupTask")
    tagTaskForCurrentUser(m.archiveTask)
    m.archiveTask.baseUrl = m.archiveContext.baseUrl
    m.archiveTask.apiKey = m.archiveContext.apiKey
    m.archiveTask.accountId = m.serverAccountId
    m.archiveTask.channelUuid = m.archiveContext.channel.uuid
    m.archiveTask.program = m.archiveSeekPlan.program
    m.archiveTask.restart = m.archiveContext.restart = true
    m.archiveTask.rewind = m.archiveContext.rewind = true
    if m.archiveContext.requestShiftMinutes <> invalid then m.archiveTask.requestShiftMinutes = m.archiveContext.requestShiftMinutes
    if m.archiveContext.retentionDays <> invalid then m.archiveTask.retentionDays = m.archiveContext.retentionDays
    if m.archiveContext.rewind = true then m.archiveTask.tuneStart = m.archiveContext.tuneStart
    m.archiveTask.observeField("result", "onArchiveCreated")
    m.archiveTask.control = "RUN"
end sub

sub onVodStateChange(event as object)
    if not m.vod.isSameNode(event.getRoSGNode()) then return
    change = event.getData()
    if not userEventCurrent(change) then return
    scope = normalizeBaseUrl(m.baseUrl) + "|" + m.serverAccountId
    if m.vod.config <> invalid then scope = textValue(m.vod.config.accountScope)
    if textValue(change.scope) <> scope then return
    if change.clearHistory = true or textValue(change.removeHistoryKey) <> ""
        before = m.accountPreferences.vodRecent
        if change.clearHistory = true then m.accountPreferences.vodRecent = [] else m.accountPreferences.vodRecent = vodHistoryRemove(before, change.removeHistoryKey)
        if not persistAccountPreferences()
            m.accountPreferences.vodRecent = before
            m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
            showNotice("Recently Watched could not be saved. Retry from Library options.")
        end if
        m.vod.history = vodHistory(m.accountPreferences.vodRecent)
        return
    end if
    if type(change.availability) = "roArray"
        before = m.accountPreferences.vod
        m.accountPreferences.vod = vodApplyAvailability(before, change.availability)
        if not persistAccountPreferences()
            m.accountPreferences.vod = before
            m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
            showNotice("Saved-library verification could not be saved. Refresh to retry.")
        end if
        m.vod.savedState = vodState(m.accountPreferences.vod)
        return
    end if
    if textValue(change.removeKey) <> ""
        before = m.accountPreferences.vod
        kept = []
        for each entry in vodState(before)
            if entry.key <> change.removeKey then kept.push(entry)
        end for
        m.accountPreferences.vod = kept
        if not persistAccountPreferences()
            m.accountPreferences.vod = before
            m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
        end if
        m.vod.savedState = vodState(m.accountPreferences.vod)
        return
    end if
    if change.clearHidden = true
        before = m.accountPreferences.vod
        m.accountPreferences.vod = vodState(before)
        for each entry in m.accountPreferences.vod
            entry.hidden = false
        end for
        if not persistAccountPreferences()
            m.accountPreferences.vod = before
            m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
        end if
        m.vod.savedState = vodState(m.accountPreferences.vod)
        return
    end if
    saveVodChange(change.item, change.patch)
end sub

sub saveVodChange(item as object, patch as object, played = false as boolean)
    before = m.accountPreferences.vod
    beforeHistory = m.accountPreferences.vodRecent
    updated = vodStateUpdate(before, item, patch)
    if updated = invalid
        notice = "Saved titles are full (40). Remove a To Watch, Favorite, Hidden or Watched choice before adding another."
        if played
            m.accountPreferences.vodRecent = vodHistoryRecord(beforeHistory, item)
            if persistAccountPreferences()
                m.mediaHistoryRecorded = true
            else
                m.accountPreferences.vodRecent = beforeHistory
                m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
                notice += " Recently Watched could not be saved."
            end if
            m.vod.history = vodHistory(m.accountPreferences.vodRecent)
        end if
        showNotice(notice)
        m.vod.savedState = vodState(before)
        return
    end if
    m.accountPreferences.vod = updated
    if played then m.accountPreferences.vodRecent = vodHistoryRecord(beforeHistory, item)
    if not persistAccountPreferences()
        m.accountPreferences.vod = before
        m.accountPreferences.vodRecent = beforeHistory
        m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
        showNotice("VOD state could not be saved. Existing preferences were retained.")
    else if played
        m.mediaHistoryRecorded = true
    end if
    m.vod.savedState = vodState(m.accountPreferences.vod)
    m.vod.history = vodHistory(m.accountPreferences.vodRecent)
end sub

sub onMediaDiagnostic(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) then return
    if not userEventCurrent(event.getData()) then return
    value = event.getData()
    stage = "vod"
    if value.mode = "catchup"
        stage = "archive"
        if m.page = "onDemand" and m.archiveSeeking <> true and archiveBookmarkContextCurrent()
            if value.account = m.accountIdentity and value.identity = m.archiveContext.playbackIdentity
                if catchupBookmarkUnavailableMediaError(textValue(value.message))
                    m.archiveContext.bookmarkUnavailable = true
                    clearArchiveBookmark(m.archiveContext.channel.uuid, m.archiveContext.program)
                end if
            end if
        end if
    end if
    if value.mode = "vod" and nativeUnsupportedFormat(value.code, textValue(value.message)) then rememberVodUnsupported(value.identity, true)
    recordDiagnostic(stage, value.code, value.message)
end sub

function vodUnsupportedStore() as object
    if m.vodUnsupported = invalid then m.vodUnsupported = loadVodUnsupported(m.registry)
    return m.vodUnsupported
end function

' Mark on a native format refusal; clear once the same title actually plays.
sub rememberVodUnsupported(identity as string, unsupported as boolean)
    item = m.mediaItem
    if item = invalid or identity = "" or identity <> m.mediaIdentity then return
    store = vodUnsupportedStore()
    if vodUnsupportedMarked(store, m.baseUrl, textValue(item.uuid)) = unsupported then return
    if unsupported
        store = markVodUnsupported(store, m.baseUrl, textValue(item.uuid))
    else
        store = clearVodUnsupported(store, m.baseUrl, textValue(item.uuid))
    end if
    m.vodUnsupported = store
    ' Recovery mode blocks runtime registry writes; keep the session copy.
    if m.userProfileRecoveryRequired <> true then saveVodUnsupported(m.registry, store)
    m.vod.unsupportedTitles = vodUnsupportedLookup(store, m.baseUrl)
end sub

sub onMetadataDiagnostic(event as object)
    if not m.guide.isSameNode(event.getRoSGNode()) then return
    value = event.getData()
    code = 0
    if not value.ok then code = -1
    recordDiagnostic("guide", code, guideMetadataDiagnosticText(value), value.elapsedMs)
end sub

sub enforceMediaCapabilities()
    denied = false
    if m.page = "library"
        status = m.vod.callFunc("libraryStatus")
        if status.kind = "movie" then denied = m.capabilities.movies = "denied" else denied = m.capabilities.series = "denied"
        if denied
            closeVodLibrary()
            m.vod.config = invalid
        end if
    else if m.page = "onDemand"
        request = m.mediaPlayer.request
        if request <> invalid
            if request.mode = "catchup"
                denied = m.capabilities.catchup = "denied"
            else if m.mediaItem <> invalid
                if m.mediaItem.kind = "movie" then denied = m.capabilities.movies = "denied" else denied = m.capabilities.series = "denied"
            end if
        end if
        if denied
            m.mediaReturn = "guide"
            m.mediaPlayer.callFunc("closeMedia")
            m.vod.config = invalid
        end if
    else if m.page = "archiveLoading" and m.capabilities.catchup = "denied"
        cancelArchiveLoad()
        releaseArchive()
        m.page = "guide"
        m.guide.active = true
        denied = true
    end if
    if denied then showNotice("Account permission changed. Media viewing was closed; reconnect or check permissions.")
end sub
