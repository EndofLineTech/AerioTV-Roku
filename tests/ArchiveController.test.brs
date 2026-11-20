sub main()
    node = {serial: 1, isSameNode: function(other)
        return m.serial = other.serial
    end function, unobserveField: sub(field)
    end sub}
    m.archiveTask = node
    m.archiveSeeking = true
    m.archiveSession = invalid
    m.archivePositionTask = invalid
    m.archiveContext = {program: {id: "old"}}
    m.mediaPlayer = {visible: true, callFunc: sub(name)
        m.called = name
    end sub}
    m.guide = {visible: false, active: false}
    m.page = "onDemand"
    event = {node: node, getRoSGNode: function()
        return m.node
    end function, getData: function()
        return {ok: false, message: "Creation failed"}
    end function}
    onArchiveCreated(event)
    if m.page <> "guide" or not m.guide.visible or not m.guide.active then stop
    if m.mediaPlayer.visible or m.mediaPlayer.called <> "closeMedia" then stop
    if m.archiveContext <> invalid or m.archiveSeeking then stop
    testArchiveBookmarks()
    testXtreamSlotArchive()
    testDispatcharrBookmarkPlayback()
    print "ALL TESTS PASSED"
end sub

sub testArchiveBookmarks()
    now = 1700000000 \ 1
    program = {id: "unstable", startsAt: now - 7200, endsAt: now - 3600}
    channel = "channel-1"
    expires = catchupBookmarkExpiry(program, 3, -30, false)
    if expires <> program.startsAt - 1800 + 3 * 86400 + 1 then stop
    if catchupBookmarkExpiry(program, 3, 30, true) <> program.startsAt + 3 * 86400 + 1 then stop
    wireStart = program.startsAt - 1800
    wireStart -= wireStart mod 60
    if catchupBookmarkExpiry(program, 3, -30, true) <> wireStart + 3 * 86400 + 1 then stop
    rows = catchupBookmarkUpdate([], channel, program, 127, expires, now)
    if rows.count() <> 1 then stop
    program.id = "different-id"
    program.title = "Metadata changed"
    row = catchupFindBookmark(rows, channel, program, now)
    if row.position <> 127 then stop
    plan = catchupSeekPlan(program, row.position, now)
    if plan.offset <> 120 or plan.program.startsAt <> program.startsAt + 120 then stop
    if catchupFindBookmark(rows, "channel-2", program, now) <> invalid then stop
    otherAiring = {startsAt: program.startsAt + 3600, endsAt: program.endsAt + 3600, id: program.id}
    if catchupFindBookmark(rows, channel, otherAiring, now) <> invalid then stop
    if catchupFindBookmark(rows, channel, program, expires) <> invalid then stop
    if catchupFindBookmark(rows, channel, program, expires - 1) = invalid then stop
    if catchupBookmarkPlan(rows, channel, program, "resume", expires) <> invalid then stop
    lineup = [{uuid: channel, id: "42"}]
    if catchupBookmarkReconcile(rows, lineup, "allowed", {}, true, now).count() <> 0 then stop
    if catchupBookmarkReconcile(rows, lineup, "unknown", {}, false, now).count() <> 1 then stop
    if catchupBookmarkReconcile(rows, lineup, "denied", {}, false, now).count() <> 0 then stop
    if catchupBookmarkReconcile(rows, [], "allowed", {}, false, now).count() <> 0 then stop
    if catchupBookmarkReconcile(rows, lineup, "allowed", {"42": {catchupDays: 3}}, true, expires).count() <> 0 then stop
    if catchupBookmarkUpdate(rows, channel, program, 0, expires, now).count() <> 0 then stop
    for i = 1 to 30
        rows = catchupBookmarkUpdate(rows, "other-" + i.toStr(), program, 127, expires, now)
    end for
    if rows.count() <> 20 or rows[0].channelUuid <> "other-30" or rows[19].channelUuid <> "other-11" then stop
    if catchupBookmarks(FormatJson(rows), now).count() <> 0 then stop
    if catchupBookmarks(ParseJson(FormatJson(rows)), now).count() <> 20 then stop
end sub

sub testXtreamSlotArchive()
    m.page = "guide"
    m.guide = {
        scope: "playlist", config: {scope: "playlist"}, active: true, visible: true
        isSameNode: function(other)
            return other.scope = m.scope
        end function
        callFunc: function(name, uuid)
            return {uuid: uuid, id: "xc-19", streamId: "19", archiveDays: 3}
        end function
    }
    m.connectionStore = {entries: [{id: "other", provider: "xtream", catchupOffsetMinutes: -45}, {id: "playlist", provider: "xtream", catchupOffsetMinutes: 30}]}
    m.selectedConnectionId = "playlist"
    m.baseUrl = "https://example.test"
    m.accountIdentity = "account"
    m.accountPreferences = {}
    m.preferenceStore = defaultPreferenceStore()
    m.registry = {
        data: "", failWrite: false
        read: function(key as string) as string
            return m.data
        end function
        write: function(key as string, bytes as string) as boolean
            if m.failWrite then return false
            m.data = bytes
            return true
        end function
        flush: function() as boolean
            return true
        end function
    }
    m.capabilities = {catchup: "allowed"}
    m.channelFacts = {"xc-19": {catchupDays: 3}}
    m.xcUsername = "viewer"
    m.xcPassword = "fixture"
    m.xcTimezone = "UTC"
    m.xcLiveFormat = "m3u8" ' Live advertisement must not change the supported completed archive route.
    m.devicePreferences = {archiveSkipSeconds: 60}
    m.mediaPlayer = {
        owner: "media"
        isSameNode: function(other)
            return m.owner = other.owner
        end function
        callFunc: function(name)
            return {paused: false}
        end function
    }
    ' Use a non-minute airing so an artificial stream-relative position
    ' exposes the difference between the requested and actual start.
    startAt = (uiNow() \ 60) * 60 - 7200 + 43
    program = {id: "test", title: "Test", startsAt: startAt, endsAt: startAt + 3500}
    archiveEvent = {node: m.guide, value: {scope: "playlist", channel: {uuid: "xc-19"}, program: program}}
    archiveEvent.getData = function()
        return m.value
    end function
    archiveEvent.getRoSGNode = function()
        return m.node
    end function
    onArchiveRequested(archiveEvent)
    expected = xtreamArchiveUrl(m.baseUrl, m.xcUsername, m.xcPassword, m.xcTimezone, m.archiveContext.channel, program, uiNow(), 30)
    if m.mediaPlayer.request.url <> expected or m.mediaPlayer.request.programStart <> program.startsAt then stop
    if right(m.mediaPlayer.request.url, 3) <> ".ts" or m.mediaPlayer.request.streamFormat <> "ts" then stop

    ' The first resume minute begins at 0:17 for this :43 airing. Going
    ' Back after six native seconds must not erase the saved 1:03 bookmark.
    early = {node: m.mediaPlayer, value: {mode: "catchup", account: "account", identity: m.mediaPlayer.request.identity, position: 106, state: "playing"}, getData: archiveEvent.getData, getRoSGNode: archiveEvent.getRoSGNode}
    onMediaProgress(early)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()).position <> 63 then stop
    m.page = "guide"
    archiveEvent.value.bookmarkAction = "resume"
    onArchiveRequested(archiveEvent)
    if m.archiveContext.bookmarkOffset <> 17 then stop
    beforeBack = m.registry.data
    early.value.identity = m.mediaPlayer.request.identity
    early.value.position = 6
    early.value.state = "stopped"
    early.value.closing = true
    m.mediaPlayer.progress = early.value
    onMediaClosed(early)
    if m.page <> "guide" or m.registry.data <> beforeBack
        print "FAIL: early Back after rounded Resume should preserve the stored bookmark"
        stop
    end if
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()).position <> 63 then stop
    archiveEvent.value.bookmarkAction = "startOver"
    onArchiveRequested(archiveEvent)
    if m.mediaPlayer.request.offset <> 0 then stop
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()) <> invalid then stop
    archiveEvent.value.delete("bookmarkAction")
    m.mediaPlayer.progress = invalid

    seekEvent = {node: m.mediaPlayer, value: {target: 125}, getData: archiveEvent.getData, getRoSGNode: archiveEvent.getRoSGNode}
    m.selectedConnectionId = "other"
    onArchiveSeek(seekEvent)
    if m.mediaPlayer.request.url <> expected then stop
    m.selectedConnectionId = "playlist"
    plan = catchupSeekPlan(program, 125, uiNow())
    onArchiveSeek(seekEvent)
    expected = xtreamArchiveUrl(m.baseUrl, m.xcUsername, m.xcPassword, m.xcTimezone, m.archiveContext.channel, plan.program, uiNow(), 30)
    if m.mediaPlayer.request.url <> expected or m.mediaPlayer.request.program.startsAt <> program.startsAt or m.mediaPlayer.request.offset <> 120 then stop
    if right(m.mediaPlayer.request.url, 3) <> ".ts" or m.mediaPlayer.request.streamFormat <> "ts" then stop

    ' Late samples, a buffering seek target, and samples from another account/slot.
    progress = {node: m.mediaPlayer, value: {mode: "catchup", account: "account", identity: "stale", position: 99, state: "playing"}, getData: archiveEvent.getData, getRoSGNode: archiveEvent.getRoSGNode}
    onMediaProgress(progress)
    progress.value.identity = m.mediaPlayer.request.identity
    progress.value.state = "buffering"
    onMediaProgress(progress)
    progress.value.state = "playing"
    m.selectedConnectionId = "other"
    onMediaProgress(progress)
    m.selectedConnectionId = "playlist"
    progress.value.account = "other"
    onMediaProgress(progress)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()) <> invalid then stop
    progress.value.account = "account"
    onMediaProgress(progress)
    row = catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow())
    if row.position <> 176 then stop
    progress.value.position = 111
    progress.value.state = "stopped"
    progress.value.closing = true
    onMediaProgress(progress)
    row = catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow())
    if row.position <> 188 then stop
    if instr(1, m.registry.data, "/timeshift/") <> 0 or instr(1, m.registry.data, "fixture") <> 0 then stop

    ' Simulate relaunch from the serialized account bucket and refreshed EPG IDs.
    m.preferenceStore = loadPreferenceStore(m.registry)
    m.accountPreferences = accountPreferences(m.preferenceStore, "account")
    if accountPreferences(m.preferenceStore, "other").archiveBookmarks <> invalid then stop
    program.id = "reloaded"
    archiveEvent.value.program = program
    archiveEvent.value.bookmarkAction = "resume"
    m.connectionStore.entries[1].catchupOffsetMinutes = -30
    m.page = "guide"
    onArchiveRequested(archiveEvent)
    plan = catchupSeekPlan(program, 188, uiNow())
    expected = xtreamArchiveUrl(m.baseUrl, m.xcUsername, m.xcPassword, m.xcTimezone, m.archiveContext.channel, plan.program, uiNow(), -30)
    if m.mediaPlayer.request.offset <> 180 or m.mediaPlayer.request.url <> expected then stop
    if m.mediaPlayer.request.programStart <> program.startsAt then stop
    progress.value.identity = m.mediaPlayer.request.identity
    progress.value.position = 66
    progress.value.state = "playing"
    progress.value.closing = false
    onMediaProgress(progress)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()).position <> 203 then stop

    ' A new reader can reach native EOF without reporting a playhead.
    m.page = "guide"
    onArchiveRequested(archiveEvent)
    plan = catchupBookmarkPlan(m.accountPreferences.archiveBookmarks, "xc-19", program, "resume", uiNow(), true)
    if plan.resumePosition <> 197 or m.mediaPlayer.request.offset <> 240 then stop
    progress.value.identity = m.mediaPlayer.request.identity
    progress.value.position = invalid
    progress.value.state = "finished"
    progress.value.finished = true
    progress.value.closing = true
    onMediaProgress(progress)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()) <> invalid then stop
    m.page = "guide"
    onArchiveRequested(archiveEvent)
    if m.page <> "guide" then stop
    progress.value.position = 120
    progress.value.state = "playing"
    progress.value.finished = false
    progress.value.closing = false
    archiveEvent.value.bookmarkAction = "catchup"
    onArchiveRequested(archiveEvent)
    progress.value.identity = m.mediaPlayer.request.identity
    onMediaProgress(progress)

    archiveEvent.value.bookmarkAction = "startOver"
    m.page = "guide"
    m.registry.failWrite = true
    onArchiveRequested(archiveEvent)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()) = invalid then stop
    if m.page <> "guide" then stop
    m.registry.failWrite = false
    m.page = "guide"
    onArchiveRequested(archiveEvent)
    if m.mediaPlayer.request.offset <> 0 then stop
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()) <> invalid then stop
    progress.value.identity = m.mediaPlayer.request.identity
    progress.value.state = "playing"
    progress.value.closing = false
    onMediaProgress(progress)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()) = invalid then stop
    progress.value.state = "finished"
    progress.value.finished = true
    progress.value.closing = true
    onMediaProgress(progress)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()) <> invalid then stop

    ' Explicit 404 from the current native reader clears; an interruption
    ' or old stream's diagnostic does not.
    progress.value.finished = false
    progress.value.state = "paused"
    progress.value.closing = false
    onMediaProgress(progress)
    diagnostic = {node: m.mediaPlayer, value: {mode: "catchup", account: "account", identity: "old", code: -5, message: "HTTP response code 404"}, getData: archiveEvent.getData, getRoSGNode: archiveEvent.getRoSGNode}
    onMediaDiagnostic(diagnostic)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()) = invalid then stop
    diagnostic.value.identity = m.mediaPlayer.request.identity
    diagnostic.value.message = "Playback interrupted"
    onMediaDiagnostic(diagnostic)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()) = invalid then stop
    diagnostic.value.message = "HTTP response code 404"
    onMediaDiagnostic(diagnostic)
    progress.value.closing = true
    onMediaProgress(progress)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "xc-19", program, uiNow()) <> invalid then stop
end sub

sub testDispatcharrBookmarkPlayback()
    m.channelFacts = {"d-1": {catchupDays: 3}}
    m.guide.callFunc = function(name, uuid)
        return {uuid: uuid, id: "d-1"}
    end function
    m.apiKey = "fixture"
    now = uiNow()
    program = {id: "epg", title: "Fixture", startsAt: now - 5600, endsAt: now - 2000}
    rows = catchupBookmarkUpdate([], "dispatch-uuid", program, 189, now + 86400, now)
    plan = catchupBookmarkPlan(rows, "dispatch-uuid", program, "resume", now)
    window = catchupRequestWindow(plan.program, 3, now, -30)
    if window.start <> program.startsAt + 180 - 1800 or window.duration <> 57 then stop

    ' The controller sees a synthetic Task result, not a provider connection.
    m.archiveOffset = plan.offset
    m.archiveContext = {account: "account", connectionId: "playlist", requestShiftMinutes: -30, retentionDays: 3, program: program, channel: {id: "d-1", uuid: "dispatch-uuid"}}
    m.archiveStartPaused = false
    m.archiveTask = {isSameNode: function(other)
        return true
    end function, unobserveField: sub(field)
    end sub}
    event = {node: m.archiveTask, value: {ok: true, sessionId: "dispatcharr-native", url: "https://example.test/archive", requestedAt: now}, getData: function()
        return m.value
    end function, getRoSGNode: function()
        return m.node
    end function}
    onArchiveCreated(event)
    if m.mediaPlayer.request.programStart <> program.startsAt or m.mediaPlayer.request.offset <> 180 then stop
    ' Keep the pre-existing server-reporting branch throttled for this host test.
    m.lastArchiveReport = now
    progress = {node: m.mediaPlayer, value: {mode: "catchup", account: "account", identity: "dispatcharr-native", position: 67, state: "playing"}, getData: event.getData, getRoSGNode: event.getRoSGNode}
    m.global = {activeusersession: "new-profile-session"}
    progress.value.aeriosession = "retired-profile-session"
    onMediaProgress(progress)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "dispatch-uuid", program, now) <> invalid then stop
    progress.value.aeriosession = "new-profile-session"
    onMediaProgress(progress)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "dispatch-uuid", program, now).position <> 247 then stop
    progress.value.position = 83
    progress.value.closing = true
    progress.value.state = "stopped"
    m.mediaPlayer.progress = progress.value
    m.archiveSession = invalid ' don't invoke network cleanup in the host simulation
    closeEvent = {node: m.mediaPlayer, value: {aeriosession: "new-profile-session"}, getData: event.getData, getRoSGNode: event.getRoSGNode}
    onMediaClosed(closeEvent)
    if catchupFindBookmark(m.accountPreferences.archiveBookmarks, "dispatch-uuid", program, now).position <> 263 then stop
    if m.page <> "guide" or not m.guide.active or not m.guide.visible then stop

    ' HTTP 404 from /me is not evidence that this archive is gone.
    for each archiveStatus in [invalid, 404]
        m.page = "archiveLoading"
        m.archiveContext = {account: "account", connectionId: "playlist", program: program, channel: {id: "d-1", uuid: "dispatch-uuid"}}
        m.archiveTask = {aeriosession: "new-profile-session", isSameNode: function(other)
            return true
        end function, unobserveField: sub(field)
        end sub}
        event.node = m.archiveTask
        event.value = {ok: false, status: 404, archiveStatus: archiveStatus, message: "HTTP 404"}
        onArchiveCreated(event)
        row = catchupFindBookmark(m.accountPreferences.archiveBookmarks, "dispatch-uuid", program, now)
        if archiveStatus = invalid and row = invalid then stop
        if archiveStatus = 404 and row <> invalid then stop
    end for
end sub

sub stopPlayback()
end sub

sub recordDiagnostic(stage, code, message)
end sub

sub showNotice(message)
    m.notice = message
end sub

function persistAccountPreferences()
    m.preferenceStore.accounts[preferenceScope(m.accountIdentity)] = m.accountPreferences
    return savePreferenceStore(m.registry, m.preferenceStore)
end function

sub hideNotice()
end sub
