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
    checkPhoneSetupBackAfterPartialSave()
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

sub checkPhoneSetupBackAfterPartialSave()
    resetImportTest()
    ' Failed phase two has discarded the transient context, but the successful
    ' first Flush left a selected fenced slot in the durable registry.
    m.phoneOriginPage = "welcome"
    m.phoneProfileImport = invalid
    m.phoneRecoveryRequired = true
    entry = normalizeConnectionEntry({id: "new", name: "Imported", provider: "dispatcharr", url: "https://new.example.test", remember: true})
    values = {connectionsV1: FormatJson({schema: 1, selected: entry.id, entries: [entry]})}
    values[userProfileImportKey(entry.id)] = "fixture-journal"
    m.registry = {values: values, read: function(key as string) as string
        return textValue(m.values[key])
    end function, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function}
    m.recoverySlot = ""
    onPhoneSetupClosed()
    check(m.recoverySlot = entry.id and m.connectionStore.selected = entry.id and m.apiKey = "", "Back after a failed profile save retires old runtime and offers recovery for the durable fenced slot")
    check(m.registry.exists(userProfileImportKey(entry.id)) and not m.phoneSetup.active, "opening recovery never discards the fence or leaves the receiver running")

    resetImportTest()
    m.registry.values.delete(userProfileImportKey(entry.id))
    m.recoverySlot = ""
    onPhoneSetupClosed()
    check(m.recoverySlot = "" and m.page = "setup" and m.apiKey = "old-runtime-key", "non-import recovery flag alone does not trigger incomplete-import recovery")
    m.phoneRecoveryRequired = false
end sub

sub resetConnectionRuntime()
    m.apiKey = ""
    m.page = "setup"
end sub

sub applySelectedConnection()
end sub

function showIncompletePhoneImportRecovery() as boolean
    m.recoverySlot = m.selectedConnectionId
    return true
end function

sub checkPhoneReopenAfterPinAdmission()
    resetImportTest()
    m.page = "setup"
    m.busy = false
    m.phoneSetup.active = false
    entry = {id: "old", name: "Saved", provider: "dispatcharr", url: "https://old.example.test", remember: true}
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
    m.registry = {store: store, key: m.apiKey, exists: function(key as string) as boolean
        return key = "userProfilesV1_old"
    end function, read: function(key as string) as string
        if key = "userProfilesV1_old" then return FormatJson(m.store)
        if key = "connKey_old" then return m.key
        if key = m.ownKeyName then return textValue(m.ownKey)
        return ""
    end function}
    scope = userProfileSessionScope(entry, profile.id, 7, "current", "00000000-0000-4000-8000-000000000002")
    m.activeUserScope = scope
    m.global = {activeusersession: scope.sessionId, profilegateclosed: false, profileswitchpending: false}
    m.profileUnlockGrant = invalid
    m.phoneTestBrokerPermit = true
    m.phoneSetupPinAdmission = {scope: scope, pin: {slot: "old", id: profile.id, pinType: profile.pinType, pinHash: profile.pinHash, pinSalt: profile.pinSalt}}
    check(selectedUserProfileGate().reason = "pin", "ordinary startup gate has no reusable raw PIN grant")
    openPhoneSetup()
    check(m.phoneSetup.active and m.page = "phoneSetup", "an already PIN-admitted holder can reopen its receiver")
    m.registry.key = ""
    check(not phoneSetupSelectedProfileGate().allowed, "deleted own saved key stops reuse even if the old runtime key remains")
    m.registry.key = m.apiKey
    m.phoneTestBrokerPermit = false
    check(not phoneSetupSelectedProfileGate().allowed, "broker hold stops reuse of PIN admission")
    m.phoneTestBrokerPermit = true
    m.registry.store.profiles[0].pinHash = "2345678901234567890123456789012345678901234567890123456789012345"
    m.phonePending = invalid
    m.phoneSetup.phase = "Connecting to your server"
    acceptPhoneSetupPayload({})
    check(m.phonePending = invalid and m.phoneSetup.retryAvailable = false and instr(1, m.phoneSetup.phase, "Reopen phone setup") > 0, "new PIN after QR ends the attempt with actionable reopen guidance")
    m.phonePending = {entry: {id: "new"}}
    m.phoneResult = {apiKey: "replacement"}
    commitPhoneSetup("replace")
    check(m.phonePending = invalid and m.phoneResult = invalid and m.connectionStore.selected = "old", "new PIN before commit retires staged phone setup without writing")
    m.registry.store.profiles[0].pinHash = profile.pinHash
    m.page = "setup"
    m.phoneSetup.active = false
    m.global.activeusersession = "00000000-0000-4000-8000-000000000003"
    openPhoneSetup()
    check(not m.phoneSetup.active, "session change cannot reuse phone setup admission")
    m.global.activeusersession = scope.sessionId
    m.registry.store.profiles[0].pinHash = "2345678901234567890123456789012345678901234567890123456789012345"
    openPhoneSetup()
    check(not m.phoneSetup.active, "changed saved PIN cannot reuse phone setup admission")
    checkPhoneImportFencedActor(entry, profile, scope)
end sub

sub checkPhoneImportFencedActor(entry as object, profile as object, scope as object)
    saved = defaultUserProfileStore(entry.id)
    saved.active = profile.id
    saved.profiles = [profile]
    originalKey = m.apiKey
    m.phoneResult = {apiKey: "new-default-key"}
    m.registry.key = m.phoneResult.apiKey
    context = {commitActor: scope, commitActorConnection: entry, commitActorKey: originalKey, replacedActorDefaultKey: true}
    check(phoneSetupFencedActorCredentialCurrent(context, saved), "phase two can rely on the exact default credential intentionally replaced by this import")
    m.registry.key = "different-key"
    check(not phoneSetupFencedActorCredentialCurrent(context, saved), "default exception requires the exact key written by this import")
    m.registry.key = m.phoneResult.apiKey
    holder = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000009", {id: 9, username: "Other", user_level: 1}, 1)
    holder.isDefault = false
    saved.profiles.push(holder)
    saved.active = holder.id
    context.commitActor = userProfileSessionScope(entry, holder.id, 9, "current", scope.sessionId)
    m.registry.ownKeyName = userProfileKeyName(entry.id, holder.id)
    m.registry.ownKey = originalKey
    check(phoneSetupFencedActorCredentialCurrent(context, saved), "same-slot nondefault holder uses its current own key")
    m.registry.ownKey = ""
    check(not phoneSetupFencedActorCredentialCurrent(context, saved), "same-slot nondefault holder cannot bypass a missing own key")
    saved.active = profile.id
    context.commitActor = scope
    entry.remember = false
    m.profileSessionKeys = {}
    bucket = preferenceScope(entry.url + "|" + entry.id + "|" + profile.id)
    m.profileSessionKeys[bucket] = originalKey
    check(phoneSetupFencedActorCredentialCurrent(context, saved), "same-slot session holder uses its current own lease")
    m.profileSessionKeys.delete(bucket)
    check(not phoneSetupFencedActorCredentialCurrent(context, saved), "same-slot default with a retired session lease cannot use the replacement exception")
end sub

function requestGateAccessAllowed(url as string, key as string) as boolean
    return m.phoneTestBrokerPermit = true
end function

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
    m.selectedConnectionId = "old"
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
