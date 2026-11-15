' Private synthetic HTTP only; run after actual B adoption in the normal app.
sub advanceProfileSyncWriterProbe()
    m.writerProbeMode = PROFILE_WRITER_MODE
    if m.writerProbeMode <> "direct"
        advanceProfileSyncFlushProbe()
        return
    end if
    if m.writerProbeTask = invalid
        m.guide.active = false
        store = loadUserProfileStore(m.registry, "slot-a")
        store = setCanonicalPreference(store, "pendingRoster", true)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.flush()
        m.userProfileStore = loadUserProfileStore(m.registry, "slot-a")
        task = CreateObject("roSGNode", "DispatcharrSyncWriteTask")
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        tagTaskForCurrentUser(task)
        task.baseUrl = entry.url
        task.apiKey = m.apiKey
        task.authMode = entry.authMode
        task.userScope = m.activeUserScope
        task.connectionRoot = m.registry.read("connectionsV1")
        task.storeRoot = m.registry.read(userProfileStoreKey("slot-a"))
        task.profilesEnabled = true
        task.expectedAuthorizationSignature = dispatcharrAuthorizationSignature({id: 8, username: "Synthetic8", user_level: 1})
        task.deviceId = "00000000-0000-4000-8000-000000000080"
        task.appVersion = "1"
        m.writerProbeTask = task
        m.writerProbeBefore = task.storeRoot
        return
    end if
    if m.writerProbeQuiesced <> true
        m.writerProbeQuiesced = true
        print "[profile-management] "; FormatJson({kind: "writer-ready"})
        return
    end if
    if m.writerProbeStarted <> true
        m.writerProbeStarted = true
        m.writerProbeTask.control = "RUN"
        return
    end if
    if type(m.writerProbeTask.result) <> "roAssociativeArray" then return
    m.managementProbeClock.control = "stop"
    result = m.writerProbeTask.result
    store = loadUserProfileStore(m.registry, "slot-a")
    passed = result.ok = true and result.submitted = true and result.state = "written" and m.writerProbeTask.apiKey = "" and m.activeUserScope.accountId = "8" and userProfileSameSession(m.activeUserScope, result.scope) and store.pendingRoster and m.registry.read(userProfileStoreKey("slot-a")) = m.writerProbeBefore and m.apiKey = "synthetic-b" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", store.active)) = "synthetic-b"
    if passed
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        acknowledged = commitDispatcharrSyncRosterAck(m.registry, entry, store, result, m.activeUserScope, m.apiKey, {})
        passed = acknowledged.ok
        if passed
            m.userProfileStore = acknowledged.store
            ack = loadDispatcharrSyncRosterAck(m.registry, entry)
            passed = not loadUserProfileStore(m.registry, "slot-a").pendingRoster and ack.ok and ack.stamp = result.maximumSentStamp
        end if
    end if
    print "[profile-management] "; FormatJson({kind: "result", writer: passed, passed: passed})
end sub

sub advanceProfileSyncFlushProbe()
    if m.writerFlushSeeded <> true
        m.writerFlushSeeded = true
        m.guide.active = false
        m.writerFlushSource = m.activeUserScope
        store = loadUserProfileStore(m.registry, "slot-a")
        for i = 0 to store.profiles.count() - 1
            profile = store.profiles[i]
            if profile.isDefault
                profile = setCanonicalPreference(profile, "pinType", "numbers")
                profile = setCanonicalPreference(profile, "pinSalt", string(32, "e"))
                profile = setCanonicalPreference(profile, "pinHash", userProfilePinHash(profile.pinSalt, "1234"))
                store.profiles[i] = profile
                m.writerFlushTarget = profile.id
            end if
        end for
        store = setCanonicalPreference(store, "pendingRoster", true)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        if m.writerProbeMode = "flush-own-retirement" then m.registry.write(userProfilePinBackoffKey("slot-a", store.active), FormatJson({failures: 1, round: 0, until: 0}))
        m.registry.flush()
        m.userProfileStore = loadUserProfileStore(m.registry, "slot-a")
        return
    end if
    if m.writerFlushQuiet <> true
        m.writerFlushQuiet = true
        print "[profile-management] "; FormatJson({kind: "writer-ready"})
        return
    end if
    if m.writerFlushStarted <> true
        m.writerFlushStarted = beginUserProfileSwitch(m.writerFlushTarget)
        ready = m.writerFlushStarted and m.profilePinDialog <> invalid and m.profileSyncWriteTask = invalid and userProfileSameSession(m.writerFlushSource, m.activeUserScope)
        print "[profile-management] "; FormatJson({kind: "writer-target-pin-ready", ready: ready})
        if not ready
            m.managementProbeClock.control = "stop"
            print "[profile-management] "; FormatJson({kind: "result", writer: false})
        end if
        return
    end if
    if m.writerFlushPinSubmitted <> true
        m.writerFlushPinSubmitted = true
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        m.writerFlushTask = m.profileSyncWriteTask
        m.writerInitialFlushTask = m.writerFlushTask
        admitted = m.writerFlushTask <> invalid and m.profileSwitchTask = invalid and userProfileSameSession(m.writerFlushSource, m.activeUserScope) and m.global.activeusersession = m.writerFlushSource.sessionId
        print "[profile-management] "; FormatJson({kind: "writer-flush-started", admitted: admitted})
        return
    end if
    if m.writerProbeMode = "flush-import-pin" and m.profilePinDialog <> invalid
        if m.writerImportedPinReady <> true
            m.writerImportedPinReady = true
            ready = m.profileSyncWriteTask = invalid and m.profileSwitchTask = invalid and userProfileSameSession(m.writerFlushSource, m.activeUserScope) and m.profileSwitchContext.target.pinType = "numbers" and m.profileSwitchContext.pin = invalid
            print "[profile-management] "; FormatJson({kind: "writer-imported-pin-ready", ready: ready})
            return
        end if
        if m.writerImportedOldRefused <> true
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
            m.writerImportedOldRefused = m.profilePinDialog <> invalid and m.profileSyncWriteTask = invalid and m.profileSwitchTask = invalid
            print "[profile-management] "; FormatJson({kind: "writer-import-old-refused", refused: m.writerImportedOldRefused})
            return
        end if
        if m.writerImportedPinSubmitted <> true
            m.writerImportedPinSubmitted = true
            m.profilePinDialog.textEditBox.text = "5678"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
            m.writerFlushTask = m.profileSyncWriteTask
            return
        end if
    end if
    if m.profileSwitchContext <> invalid then return
    if m.writerFlushTask <> invalid
        if type(m.writerFlushTask.result) <> "roAssociativeArray" then return
    end if
    m.managementProbeClock.control = "stop"
    entry = connectionStoreEntry(m.connectionStore, "slot-a")
    store = loadUserProfileStore(m.registry, "slot-a")
    ack = loadDispatcharrSyncRosterAck(m.registry, entry)
    passed = m.activeUserScope <> invalid
    if passed then passed = m.activeUserScope.accountId = "7" and m.activeUserScope.profileId = m.writerFlushTarget and m.activeUserScope.sessionId <> m.writerFlushSource.sessionId and m.apiKey = "synthetic-a" and m.guide.callFunc("profileSwitchProbeLineup") = "7"
    passed = passed and not store.pendingRoster and ack.ok and ack.stamp > 0 and m.profileSyncWriteTask = invalid and m.profileSyncContext = invalid and m.writerFlushTask <> invalid
    if passed then passed = m.writerFlushTask.apiKey = "" and m.writerFlushTask.result.scope.accountId = "8" and userProfileSameSession(m.writerFlushTask.result.scope, m.writerFlushSource)
    if m.writerProbeMode = "flush-import-pin"
        passed = passed and m.writerImportedPinReady = true and m.writerImportedOldRefused = true and m.writerImportedPinSubmitted = true
        if passed then passed = m.writerInitialFlushTask.apiKey = "" and m.writerInitialFlushTask.result.state = "local-commit" and m.writerInitialFlushTask.flushNonce <> m.writerFlushTask.flushNonce and m.writerFlushTask.flushNonce <> m.writerFlushSource.sessionId
        for each profile in store.profiles
            if profile.isDefault then passed = passed and profile.pinHash = userProfilePinHash(profile.pinSalt, "5678") and profile.pinLength = 4
        end for
    end if
    failed = m.writerProbeMode = "flush-failed" or m.writerProbeMode = "flush-cancel"
    if failed
        passed = m.activeUserScope <> invalid and m.writerFlushTask <> invalid
        if passed then passed = m.activeUserScope.accountId = "8" and m.activeUserScope.profileId = m.writerFlushSource.profileId and m.activeUserScope.sessionId <> m.writerFlushSource.sessionId and m.apiKey = "synthetic-b" and store.pendingRoster and not m.registry.exists(userProfileSyncAckKey("slot-a")) and m.profileSyncWriteTask = invalid and m.profileSyncContext = invalid and not m.global.profilegateclosed and not m.profileGateCover.visible
        if passed then passed = m.writerFlushTask.result.ok <> true and m.writerFlushTask.result.submitted = true and m.writerFlushTask.apiKey = "" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", store.active)) = "synthetic-b"
    end if
    authority = m.writerProbeMode = "flush-authority"
    if authority
        passed = m.activeUserScope = invalid and m.apiKey = "" and store.pendingRoster and not m.registry.exists(userProfileSyncAckKey("slot-a")) and m.global.profilegateclosed and m.profileGateCover.visible and m.userProfileRecoveryRequired and m.profileSyncWriteTask = invalid
        if passed then passed = m.writerFlushTask.result.ok <> true and m.writerFlushTask.result.state = "authority" and m.writerFlushTask.result.submitted <> true and m.writerFlushTask.apiKey = "" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", store.active)) = "synthetic-b"
    end if
    ownRetired = m.writerProbeMode = "flush-own-retirement"
    if ownRetired
        sourceId = m.writerFlushSource.profileId
        preferences = ParseJson(m.registry.read("settingsV1"), "d")
        passed = m.activeUserScope <> invalid
        if passed then passed = m.activeUserScope.accountId = "7" and m.activeUserScope.sessionId <> m.writerFlushSource.sessionId and m.apiKey = "synthetic-a" and m.guide.callFunc("profileSwitchProbeLineup") = "7" and not m.global.profilegateclosed and not m.profileGateCover.visible
        passed = passed and store.profiles.count() = 1 and store.pendingRoster and not m.registry.exists(userProfileSyncAckKey("slot-a")) and not m.registry.exists(userProfileKeyName("slot-a", sourceId)) and not m.registry.exists(userProfilePinBackoffKey("slot-a", sourceId)) and not m.registry.exists(userProfileRetirementKey("slot-a")) and not preferences.accounts.doesExist(preferenceScope(connectionPreferenceIdentity(entry, "8"))) and m.registry.read("connKey_slot-a") = "synthetic-a"
        if passed then passed = m.writerFlushTask.result.state = "local-commit" and m.writerFlushTask.result.submitted = false and m.writerFlushTask.apiKey = "" and userProfileSameSession(m.writerFlushTask.result.scope, m.writerFlushSource) and m.profilePinDialog = invalid
        for each profile in store.profiles
            if profile.isDefault then passed = passed and profile.pinHash = userProfilePinHash(profile.pinSalt, "5678") and profile.pinLength = 0
        end for
    end if
    state = "invalid"
    if m.writerFlushTask <> invalid
        if type(m.writerFlushTask.result) = "roAssociativeArray" then state = textValue(m.writerFlushTask.result.state)
    end if
    print "[profile-management] "; FormatJson({kind: "result", writer: passed, flush: passed, pending_retained: failed and passed, authority_covered: authority and passed, own_retired: ownRetired and passed, writer_state: state})
end sub
