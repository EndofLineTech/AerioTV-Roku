' Private synthetic HTTP only; run after actual B adoption in the normal app.
sub advanceProfileSyncWriterProbe()
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
