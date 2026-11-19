sub main()
    resetImportTest()
    m.phonePending.phoneProfilesRequired = true
    startPhoneVerification()
    check(m.phonePending = invalid and m.phoneVerifyTask = invalid, "lost profile verification cannot retry as an unprotected ordinary connection")
    resetImportTest()
    m.phonePending.phoneProfilesRequired = true
    m.phoneResult = {apiKey: "verified-default-key"}
    commitPhoneSetup("add")
    check(m.phonePending = invalid and m.connectionStore.selected = "old", "missing profile lifecycle refuses commit before saving a default key")
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
    m.phoneOptions = {id: "imported", guideDays: 2, vodEnabled: false}
    unchanged = takePhoneSetupPreferences({guide: {futureDays: 7}, vodEnabled: true}, {id: "other"})
    check(unchanged.guide.futureDays = 7 and unchanged.vodEnabled and m.phoneOptions <> invalid, "another slot cannot consume the pending import settings")
    applied = takePhoneSetupPreferences({guide: {futureDays: 7}, vodEnabled: true}, {id: "imported"})
    check(applied.guide.futureDays = 2 and applied.guide.historyDays = 2 and not applied.vodEnabled and m.phoneOptions = invalid, "imported options applied exactly once after commit")
    applied.guide.futureDays = 6
    applied.vodEnabled = true
    retained = takePhoneSetupPreferences(normalizeAccountPreferences(ParseJson(FormatJson(applied))), {id: "imported"})
    check(retained.guide.futureDays = 6 and retained.guide.historyDays = 2 and retained.vodEnabled, "later reconnect reloads the viewer's changed options")
    checkPhoneReopenAfterPinAdmission()
    print "ALL TESTS PASSED"
end sub

sub checkPhoneReopenAfterPinAdmission()
    resetImportTest()
    m.page = "setup"
    m.busy = false
    m.phoneSetup.active = false
    entry = {id: "old", name: "Saved", provider: "dispatcharr", url: "https://old.example.test"}
    m.connectionStore.entries = [entry]
    m.selectedConnectionId = "old"
    profile = userProfileFromVerified("old", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Owner", user_level: 1}, 1)
    profile.isDefault = true
    profile.pinType = "numbers"
    profile.pinSalt = "00112233445566778899aabbccddeeff"
    profile.pinHash = "1234567890123456789012345678901234567890123456789012345678901234"
    store = defaultUserProfileStore("old")
    store.profiles = [profile]
    store.active = profile.id
    m.registry = {store: store, exists: function(key as string) as boolean
        return key = "userProfilesV1_old"
    end function, read: function(key as string) as string
        if key = "userProfilesV1_old" then return FormatJson(m.store)
        return ""
    end function}
    scope = userProfileSessionScope(entry, profile.id, 7, "current", "00000000-0000-4000-8000-000000000002")
    m.activeUserScope = scope
    m.global = {activeusersession: scope.sessionId, profilegateclosed: false, profileswitchpending: false}
    m.profileUnlockGrant = invalid
    m.phoneSetupPinAdmission = {scope: scope, pin: {slot: "old", id: profile.id, pinType: profile.pinType, pinHash: profile.pinHash, pinSalt: profile.pinSalt}}
    check(selectedUserProfileGate().reason = "pin", "ordinary startup gate has no reusable raw PIN grant")
    openPhoneSetup()
    check(m.phoneSetup.active and m.page = "phoneSetup", "an already PIN-admitted holder can reopen its receiver")
    m.page = "setup"
    m.phoneSetup.active = false
    m.global.activeusersession = "00000000-0000-4000-8000-000000000003"
    openPhoneSetup()
    check(not m.phoneSetup.active, "session change cannot reuse phone setup admission")
    m.global.activeusersession = scope.sessionId
    m.registry.store.profiles[0].pinHash = "2345678901234567890123456789012345678901234567890123456789012345"
    openPhoneSetup()
    check(not m.phoneSetup.active, "changed saved PIN cannot reuse phone setup admission")
end sub

sub cancelProfileTask()
end sub

sub cancelCapabilityRefresh()
end sub

sub showNotice(message as string)
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
