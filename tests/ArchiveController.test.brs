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
    testXtreamSlotArchive()
    print "ALL TESTS PASSED"
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
    m.capabilities = {catchup: "allowed"}
    m.channelFacts = {"xc-19": {catchupDays: 3}}
    m.xcUsername = "viewer"
    m.xcPassword = "fixture"
    m.xcTimezone = "UTC"
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
    program = {id: "test", title: "Test", startsAt: uiNow() - 7200, endsAt: uiNow() - 3700}
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
    seekEvent = {node: m.mediaPlayer, value: {target: 125}, getData: archiveEvent.getData, getRoSGNode: archiveEvent.getRoSGNode}
    m.selectedConnectionId = "other"
    onArchiveSeek(seekEvent)
    if m.mediaPlayer.request.url <> expected then stop
    m.selectedConnectionId = "playlist"
    plan = catchupSeekPlan(program, 125, uiNow())
    onArchiveSeek(seekEvent)
    expected = xtreamArchiveUrl(m.baseUrl, m.xcUsername, m.xcPassword, m.xcTimezone, m.archiveContext.channel, plan.program, uiNow(), 30)
    if m.mediaPlayer.request.url <> expected or m.mediaPlayer.request.program.startsAt <> program.startsAt or m.mediaPlayer.request.offset <> 120 then stop
end sub

sub stopPlayback()
end sub

sub recordDiagnostic(stage, code, message)
end sub

sub showNotice(message)
    m.notice = message
end sub
