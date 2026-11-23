sub main()
    m.page = "dvr"
    m.capabilities = {dvr: "view", movies: "denied", series: "denied", level: "viewer"}
    m.guide = {config: {scope: "test-scope"}, visible: false, active: false, setFocus: function(value as boolean) as boolean
        m.focused = value
        return true
    end function}
    m.dvr = {config: {scope: "test-scope", permission: "manage"}, active: true}
    m.vod = {}
    m.accountPreferences = {vodEnabled: true}
    updateLibraryPermissions()
    assertEqual(m.dvr.config.permission, "view", "open DVR loses manage on capability downgrade")
    assertEqual(m.dvr.active, true, "read-only DVR remains open")
    m.capabilities.dvr = "denied"
    updateLibraryPermissions()
    assertEqual(m.dvr.active, false, "DVR closes on permission revocation")
    assertEqual(m.dvr.config, invalid, "revocation discards credential-bearing DVR config")

    m.page = "guide"
    m.capabilities.dvr = "manage"
    m.recordTask = invalid
    m.recordDialog = invalid
    m.recordIntent = invalid
    m.guide.isSameNode = function(node as object) as boolean
        return node.id = "guide"
    end function
    m.guide.callFunc = function(name as string, uuid as string) as object
        return {id: "3", uuid: uuid, name: "Test channel"}
    end function
    m.accountIdentity = "account-one"
    m.accountPreferences.dvrPreRollMinutes = 5
    m.accountPreferences.dvrPostRollMinutes = 10
    future = CreateObject("roDateTime").asSeconds() + 3600
    m.testRequest = {scope: "other-scope", channel: {id: "3", uuid: "channel-3"}, program: {id: "program-1", title: "Test program", startsAt: future, endsAt: future + 3600}}
    onRecordRequested({getRoSGNode: function() as object
        return {id: "guide"}
    end function, getData: function() as object
        return m.testRequest
    end function})
    assertEqual(m.recordIntent, invalid, "stale guide scope cannot start a recording dialog")

    m.recordIntent = {account: "another-account"}
    m.recordChoices = [{action: "confirm"}]
    m.recordDialog = {id: "dialog", close: false, isSameNode: function(node as object) as boolean
        return node.id = "dialog"
    end function}
    onRecordChoice({getRoSGNode: function() as object
        return {id: "dialog"}
    end function, getData: function() as integer
        return 0
    end function})
    assertEqual(m.recordTask, invalid, "stale account cannot submit a recording")
    assertEqual(m.recordDialog.close, false, "stale account remains safely cancellable")
    m.recordSettlementTask = {id: "already-submitted"}
    m.recordIntent = {account: m.accountIdentity}
    m.recordDialog.unobserveField = sub(field as string)
    end sub
    onRecordChoice({getRoSGNode: function() as object
        return {id: "dialog"}
    end function, getData: function() as integer
        return 0
    end function})
    assertEqual(m.recordTask, invalid, "pending outgoing settlement refuses a duplicate record confirmation")
    m.recordIntent = invalid
    m.testRequest.scope = "test-scope"
    onRecordRequested({getRoSGNode: function() as object
        return {id: "guide"}
    end function, getData: function() as object
        return m.testRequest
    end function})
    assertEqual(m.recordIntent, invalid, "guide cannot reopen scheduling while a submitted operation is still settling")
    checkDvrTwoStepBack()
    checkGuideRecordingMarkers()
    print "ALL TESTS PASSED"
end sub

' e3e.29: the Guide's REC markers follow the server DVR list for this account.
sub checkGuideRecordingMarkers()
    m.page = "guide"
    m.capabilities = {dvr: "view"}
    m.serverAccountId = "7"
    m.apiKey = "key"
    m.guide = {recordingState: invalid}
    m.guideRecordingTask = invalid
    future = CreateObject("roDateTime")
    future.fromSeconds(uiNow() + 600)
    later = CreateObject("roDateTime")
    later.fromSeconds(uiNow() + 2400)
    task = {serial: 1, isSameNode: function(other as object) as boolean
        return other.serial = m.serial
    end function, unobserveField: sub(field as string)
    end sub}
    m.guideRecordingTask = task
    rows = [{channelId: "3", startTime: future.toIsoString(), endTime: later.toIsoString(), status: "scheduled", programId: "p"}, {channelId: "3", startTime: future.toIsoString(), endTime: later.toIsoString(), status: "completed"}]
    event = {node: {serial: 1}, data: {ok: true, accountId: "7", recordings: rows}, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return m.data
    end function}
    onGuideRecordings(event)
    assertEqual(m.guideRecordingTask, invalid, "finished marker task is released")
    assertEqual(m.guide.recordingState.count(), 1, "only active recordings reach the Guide")
    assertEqual(m.guide.recordingState[0].status, "scheduled", "scheduled marker")
    m.guideRecordingTask = task
    event.data = {ok: false, accountId: "7", message: "offline"}
    onGuideRecordings(event)
    assertEqual(m.guide.recordingState.count(), 1, "a failed refresh keeps the last markers")
    m.guideRecordingTask = task
    event.data = {ok: true, accountId: "8", recordings: []}
    onGuideRecordings(event)
    assertEqual(m.guide.recordingState.count(), 1, "another account's list is ignored")
    m.guideRecordingTask = {serial: 2, isSameNode: task.isSameNode}
    event.data = {ok: true, accountId: "7", recordings: []}
    onGuideRecordings(event)
    assertEqual(m.guide.recordingState.count(), 1, "a stale task result is ignored")
    m.guideRecordingTask = invalid
    m.capabilities.dvr = "none"
    refreshGuideRecordings()
    assertEqual(m.guide.recordingState.count(), 0, "markers clear without DVR permission")
    m.guide.recordingState = [{status: "scheduled"}]
    clearGuideRecordings()
    assertEqual(m.guide.recordingState.count(), 0, "markers clear on connection change")
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub

' 9jr0: Back from the DVR root returns to the Guide with the DVR tab focused.
sub checkDvrTwoStepBack()
    saved = {page: m.page, dvr: m.dvr, guide: m.guide}
    m.page = "dvr"
    m.dvr = {active: true, config: {}}
    m.guide = {visible: false, active: false, focusTab: ""}
    onDvrBack()
    if m.page <> "guide" or m.guide.active <> true or m.guide.focusTab <> "dvr" then stop
    m.guide.focusTab = ""
    onDvrBack()
    if m.guide.focusTab <> "" then stop ' a stale close cannot refocus the tab row
    m.page = saved.page
    m.dvr = saved.dvr
    m.guide = saved.guide
end sub
