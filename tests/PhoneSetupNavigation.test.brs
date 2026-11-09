sub main()
    resetImportTest()
    finishPhoneVerification({ok: false})
    check(m.phonePending <> invalid and m.phoneResult = invalid, "verification failure keeps only the prepared candidate for explicit retry")
    check(m.phoneVerifyTask = invalid and m.phoneSetup.retryAvailable, "failed verification detaches task and exposes retry")
    check(m.connectionStore.selected = "old" and m.apiKey = "old-runtime-key" and m.baseUrl = "https://old.example.test", "verification failure cannot switch saved/current runtime")
    before = formatJson(m.connectionStore)
    onPhoneSetupClosed()
    check(m.phonePending = invalid and m.phoneResult = invalid, "cancel drops staged credentials and results")
    check(m.page = "setup" and not m.phoneSetup.active, "cancel returns to originating screen")
    check(formatJson(m.connectionStore) = before and m.apiKey = "old-runtime-key", "cancel never changes roster or runtime credential")
    resetImportTest()
    stale = {getRoSGNode: function() as object
        return {tag: "detached"}
    end function, getData: function() as object
        return {ok: true, channels: [{id: "one"}]}
    end function}
    onPhoneVerified(stale)
    check(m.phoneResult = invalid and m.phoneVerifyTask <> invalid, "late result from a detached verifier is ignored")
    resetImportTest()
    m.phoneMatches = ["old"]
    m.phoneDialogMode = "confirm"
    m.phoneDialog = fakeImportTask()
    choice = {getRoSGNode: function() as object
        return {tag: "current"}
    end function, getData: function() as integer
        return 0 ' Cancel in the duplicate dialog.
    end function}
    onPhoneSetupChoice(choice)
    check(m.phonePending = invalid and m.connectionStore.selected = "old", "duplicate Cancel cannot save a candidate")
    m.phoneOptions = {id: "imported", guideDays: 3, vodEnabled: false}
    applied = takePhoneSetupPreferences({guide: {futureDays: 7}, vodEnabled: true}, {id: "imported"})
    check(applied.guide.futureDays = 3 and not applied.vodEnabled and m.phoneOptions = invalid, "supported options applied exactly once after commit")
    applied.guide.futureDays = 14
    applied.vodEnabled = true
    retained = takePhoneSetupPreferences(applied, {id: "imported"})
    check(retained.guide.futureDays = 14 and retained.vodEnabled, "later reconnect never overwrites the viewer's changed options")
    print "ALL TESTS PASSED"
end sub

sub resetImportTest()
    m.page = "phoneSetup"
    m.phoneOriginPage = "setup"
    m.phoneClock = {control: "start"}
    m.phoneSetup = {active: true, visible: true, setFocus: function(focus as boolean) as boolean
        return true
    end function}
    m.top = {setFocus: function(focus as boolean) as boolean
        return true
    end function}
    m.phoneDialog = invalid
    m.phoneVerifyTask = fakeImportTask()
    m.phonePending = {ok: true, entry: {id: "new", provider: "m3u"}, credential: {apiKey: "fixture-only"}}
    m.phoneResult = invalid
    m.connectionStore = {schema: 1, selected: "old", entries: []}
    m.apiKey = "old-runtime-key"
    m.baseUrl = "https://old.example.test"
end sub

function fakeImportTask() as object
    return {tag: "current", isSameNode: function(node as object) as boolean
        return node.tag = m.tag
    end function, unobserveField: sub(field as string)
    end sub, hasField: function(field as string) as boolean
        return false
    end function}
end function

sub drawSetup()
end sub

sub drawWelcome()
end sub

sub check(condition as boolean, message as string)
    if not condition
        print "FAIL: "; message
        stop
    end if
end sub
