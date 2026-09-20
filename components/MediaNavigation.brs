sub openVodLibrary(kind as string)
    if m.accountPreferences.vodEnabled = false then return
    if kind = "movie" and m.capabilities.movies <> "allowed" then return
    if kind = "series" and m.capabilities.series <> "allowed" then return
    stopPlayback()
    m.guide.active = false
    m.guide.visible = false
    m.screen.visible = false
    m.page = "library"
    m.vod.savedState = vodState(m.accountPreferences.vod)
    bookmark = invalid
    if type(m.accountPreferences.vodBrowse) = "roAssociativeArray" then bookmark = m.accountPreferences.vodBrowse[kind]
    m.vod.config = {kind: kind, baseUrl: m.baseUrl, apiKey: m.apiKey, accountId: m.serverAccountId, accountScope: normalizeBaseUrl(m.baseUrl) + "|" + m.serverAccountId, bookmark: bookmark}
    m.vod.active = true
end sub

sub closeVodLibrary()
    m.vod.callFunc("saveLibraryBookmark")
    m.vod.callFunc("cancelVod")
    m.vod.active = false
    m.page = "guide"
    m.guide.visible = true
    m.guide.active = true
end sub

sub onLibraryDestination(event as object)
    if not m.vod.isSameNode(event.getRoSGNode()) or m.page <> "library" then return
    openVodLibrary(event.getData())
end sub

sub onVodBookmark(event as object)
    if not m.vod.isSameNode(event.getRoSGNode()) then return
    value = event.getData()
    if value.scope <> normalizeBaseUrl(m.baseUrl) + "|" + m.serverAccountId then return
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
    if m.settingsHub <> invalid
        if m.settingsHub.active then refreshSettingsHub()
    end if
end sub

sub onVodPlay(event as object)
    if not m.vod.isSameNode(event.getRoSGNode()) or m.page <> "library" then return
    item = event.getData()
    if textValue(item.accountScope) <> normalizeBaseUrl(m.baseUrl) + "|" + m.serverAccountId then return
    saveVodChange(item, {relationId: textValue(item.relationId)})
    identity = "roku_" + CreateObject("roDeviceInfo").getRandomUUID()
    transport = identity
    if m.vodTransport <> invalid
        if m.vodTransport.account = m.accountIdentity and m.vodTransport.key = item.key and m.vodTransport.version = textValue(item.relationId) then transport = m.vodTransport.id
    end if
    m.vodTransport = {account: m.accountIdentity, key: item.key, id: transport, version: textValue(item.relationId)}
    url = vodPlaybackUrl(m.baseUrl, item, transport)
    if url = "" then return
    m.mediaReturn = "library"
    m.mediaItem = item
    recordDiagnostic("vod", 0, "Opening " + item.kind + " using " + item.streamFormat)
    m.mediaIdentity = identity
    m.lastVodWrite = 0
    m.lastVodState = ""
    m.vod.active = false
    m.page = "onDemand"
    m.mediaPlayer.request = {account: m.accountIdentity, identity: identity, key: item.key, mode: "vod", url: url, title: item.title, apiKey: m.apiKey, streamFormat: item.streamFormat, resume: item.resume}
end sub

sub onMediaClosed()
    if m.page <> "onDemand" then return
    m.archiveSeeking = false
    cancelArchiveLoad()
    releaseArchive()
    if m.mediaReturn = "library"
        m.page = "library"
        m.vod.active = true
    else
        m.page = "guide"
        m.guide.visible = true
        m.guide.active = true
    end if
end sub

sub onArchiveRequested(event as object)
    if not m.guide.isSameNode(event.getRoSGNode()) or m.page <> "guide" then return
    cancelArchiveLoad()
    selected = event.getData()
    if m.guide.config = invalid then return
    if textValue(selected.scope) <> textValue(m.guide.config.scope) then return
    channel = m.guide.callFunc("channelByUuid", selected.channel.uuid)
    if channel = invalid then return
    days = catchupChannelDays(m.capabilities.catchup, m.channelFacts, channel.id)
    program = selected.program
    restarting = selected.restart = true
    if restarting
        plan = catchupRestartPlan(program, days, uiNow())
        if plan = invalid
            showNotice("Restart is no longer available for this program. Reopen its details.")
            return
        end if
        program = plan.program
    else if not catchupEligible(program, days, uiNow())
        showNotice("Archive is no longer available for this program. Reopen its details.")
        return
    end if
    stopPlayback()
    m.archiveContext = {baseUrl: m.baseUrl, apiKey: m.apiKey, account: m.accountIdentity, channel: channel, program: program, restart: restarting}
    m.archiveOffset = 0
    m.archiveStartPaused = false
    m.archiveSeeking = false
    m.archiveTask = CreateObject("roSGNode", "CatchupTask")
    m.archiveTask.baseUrl = m.baseUrl
    m.archiveTask.apiKey = m.apiKey
    m.archiveTask.accountId = m.serverAccountId
    m.archiveTask.channelUuid = channel.uuid
    m.archiveTask.program = program
    m.archiveTask.restart = restarting
    m.archiveTask.observeField("result", "onArchiveCreated")
    m.archiveTask.control = "RUN"
    m.page = "archiveLoading"
    m.guide.active = false
    m.top.setFocus(true)
    if restarting then showNotice("Opening Restart Program... Archive may not yet be available. Back cancels.") else showNotice("Opening archive... Back cancels.")
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
            if m.archiveContext.restart = true
                if result.status = 400 or result.status = 404 or result.status = 500 or result.status = 502 or result.status = 503 or result.status = 504 then message = "Archive not yet available. The provider may be delayed or busy. Try again later or choose Watch channel LIVE."
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
    m.archiveServerStart = result.start
    m.archiveSeeking = false
    m.mediaReturn = "guide"
    m.lastArchiveReport = 0
    m.guide.visible = false
    m.page = "onDemand"
    p = m.archiveContext.program
    m.mediaPlayer.skipSeconds = m.devicePreferences.archiveSkipSeconds
    m.mediaPlayer.request = {account: m.accountIdentity, identity: result.sessionId, key: p.id, mode: "catchup", url: result.url, title: p.title, apiKey: m.apiKey, streamFormat: "ts", programStart: p.startsAt, program: p, offset: m.archiveOffset, startPaused: m.archiveStartPaused, restart: m.archiveContext.restart = true}
end sub

sub deleteOwnArchive(id as string, callback = "" as string)
    if m.archiveContext = invalid or id = "" then return
    task = CreateObject("roSGNode", "CatchupTask")
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
    if m.archivePositionTask <> invalid then cancelNetworkTask(m.archivePositionTask)
    m.archivePositionTask = invalid
    if m.archiveSession <> invalid
        deleteOwnArchive(m.archiveSession)
        m.archiveSession = invalid
    end if
    m.archiveContext = invalid
end sub

sub resetMediaNavigation()
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
end sub

sub onMediaProgress(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) then return
    progress = event.getData()
    if progress.account <> m.accountIdentity then return
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
        saveVodChange(m.mediaItem, {position: position, duration: int(progress.duration), watched: finished})
        return
    end if
    if progress.mode = "catchup" and m.archiveSession <> invalid
        if m.archiveSeeking = true then return
        if progress.identity <> m.archiveSession or not mediaNumber(progress.position) then return
        if m.lastArchiveReport > uiNow() - 30 then return
        if m.archivePositionTask <> invalid
            if m.archivePositionTask.state = "run" then return
        end if
        m.lastArchiveReport = uiNow()
        m.archivePositionTask = CreateObject("roSGNode", "CatchupTask")
        m.archivePositionTask.baseUrl = m.archiveContext.baseUrl
        m.archivePositionTask.apiKey = m.archiveContext.apiKey
        m.archivePositionTask.sessionId = m.archiveSession
        m.archivePositionTask.operation = "position"
        m.archivePositionTask.position = progress.position + m.archiveOffset
        m.archivePositionTask.paused = progress.state = "paused"
        m.archivePositionTask.control = "RUN"
    end if
end sub

sub onArchiveSeek(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) or m.page <> "onDemand" then return
    if m.archiveSeeking = true or m.archiveSession = invalid or m.archiveContext = invalid then return
    plan = catchupSeekPlan(m.archiveContext.program, event.getData(), uiNow())
    if plan = invalid then return
    m.archiveSeeking = true
    m.archiveSeekPlan = plan
    state = m.mediaPlayer.callFunc("suspendArchive")
    m.archiveStartPaused = state.paused
    if m.archivePositionTask <> invalid then cancelNetworkTask(m.archivePositionTask)
    m.archivePositionTask = invalid
    deleteOwnArchive(m.archiveSession, "onArchiveSeekReleased")
end sub

sub onArchiveSkipPreference(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) or m.page <> "onDemand" then return
    change = event.getData()
    if change.account <> m.accountIdentity then return
    if change.seconds <> 60 and change.seconds <> 120 and change.seconds <> 300 then return
    m.devicePreferences.archiveSkipSeconds = change.seconds
    persistPreferences()
end sub

sub onArchiveGoLive(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) or m.page <> "onDemand" then return
    if m.archiveContext = invalid or m.archiveSeeking = true then return
    channel = m.guide.callFunc("channelByUuid", m.archiveContext.channel.uuid)
    if not catchupLiveReturnAllowed(m.archiveContext, m.accountIdentity, channel)
        showNotice("This channel is no longer in the authorized lineup. Return to the guide.")
        return
    end if
    ' Release only this archive session; never stop the shared live channel.
    m.mediaPlayer.callFunc("closeMedia")
    cancelArchiveLoad()
    releaseArchive()
    m.page = "guide" ' makes a queued archive-closed event obsolete
    startPlayback(channel, true)
end sub

sub onArchiveSeekReleased(event as object)
    if not isCurrentTaskEvent(event, m.archiveCleanupTask) then return
    m.archiveCleanupTask.unobserveField("result")
    if m.archiveSeeking <> true or m.page <> "onDemand" or m.archiveContext = invalid then return
    result = event.getData()
    if not result.ok
        m.mediaPlayer.callFunc("closeMedia")
        showNotice("Could not release the prior archive session. Return to the guide and retry.")
        return
    end if
    m.archiveSession = invalid
    m.archiveOffset = m.archiveSeekPlan.offset
    m.archiveTask = CreateObject("roSGNode", "CatchupTask")
    m.archiveTask.baseUrl = m.archiveContext.baseUrl
    m.archiveTask.apiKey = m.archiveContext.apiKey
    m.archiveTask.accountId = m.serverAccountId
    m.archiveTask.channelUuid = m.archiveContext.channel.uuid
    m.archiveTask.program = m.archiveSeekPlan.program
    m.archiveTask.restart = m.archiveContext.restart = true
    m.archiveTask.observeField("result", "onArchiveCreated")
    m.archiveTask.control = "RUN"
end sub

sub onVodStateChange(event as object)
    if not m.vod.isSameNode(event.getRoSGNode()) then return
    change = event.getData()
    if textValue(change.scope) <> normalizeBaseUrl(m.baseUrl) + "|" + m.serverAccountId then return
    if textValue(change.removeKey) <> ""
        kept = []
        for each entry in vodState(m.accountPreferences.vod)
            if entry.key <> change.removeKey then kept.push(entry)
        end for
        m.accountPreferences.vod = kept
        persistAccountPreferences()
        m.vod.savedState = kept
        return
    end if
    if change.clearHidden = true
        m.accountPreferences.vod = vodState(m.accountPreferences.vod)
        for each entry in m.accountPreferences.vod
            entry.hidden = false
        end for
        persistAccountPreferences()
        m.vod.savedState = m.accountPreferences.vod
        return
    end if
    saveVodChange(change.item, change.patch)
end sub

sub saveVodChange(item as object, patch as object)
    before = m.accountPreferences.vod
    m.accountPreferences.vod = vodStateUpdate(before, item, patch)
    if not persistAccountPreferences()
        m.accountPreferences.vod = before
        m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
        showNotice("VOD state could not be saved. Existing preferences were retained.")
    end if
    m.vod.savedState = vodState(m.accountPreferences.vod)
end sub

sub onMediaDiagnostic(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) then return
    value = event.getData()
    stage = "vod"
    if value.mode = "catchup" then stage = "archive"
    recordDiagnostic(stage, value.code, value.message)
end sub

sub onMetadataDiagnostic(event as object)
    if not m.guide.isSameNode(event.getRoSGNode()) then return
    value = event.getData()
    code = 0
    if not value.ok then code = -1
    recordDiagnostic("guide", code, value.stage + " " + value.source + " " + value.message, value.elapsedMs)
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
        m.page = "guide"
        m.guide.active = true
        denied = true
    end if
    if denied then showNotice("Account permission changed. Media viewing was closed; reconnect or check permissions.")
end sub
