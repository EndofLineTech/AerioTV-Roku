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
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
