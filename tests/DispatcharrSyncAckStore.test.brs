sub main()
    syncScheduledFixture()
    m.profileSyncEnabled = false
    m.profileSyncClock = {control: "stop"}
    activateProfileSyncScheduling()
    check(m.profileSyncClock.control = "stop", "explicit sync opt-out must not restart the scheduler timer after controls reopen")
    syncScheduledFixture()
    onProfileSyncScheduleTick()
    oldTask = m.profileScheduledSyncTask
    onProfileSyncNetworkLink(syncFlushEvent(m.top, {linked: false, returned: false, sequence: 1}))
    check(m.profileScheduledSyncTask = invalid and oldTask.apiKey = "" and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "real Scene link-loss handling retires scheduled transport without clearing durable dirty intent")
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask = invalid, "known disconnected link admits no scheduled request")
    onProfileSyncNetworkLink(syncFlushEvent(m.top, {linked: true, returned: true, sequence: 2}))
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask <> invalid and m.profileScheduledSyncTask.aeriosession = m.scope.sessionId, "link return re-admits only current adopted holder's discovery")
    sequence = m.profileSyncNetworkSequence
    onProfileSyncNetworkLink(syncFlushEvent(m.top, {linked: false, returned: false, sequence: 1}))
    check(m.profileSyncNetworkSequence = sequence and m.profileSyncLinkUp, "stale link event cannot undo a newer observed network state")
    closeScheduledProfileSync()
    syncAckFixture()
    m.receipt.state = "unchanged"
    m.receipt.submitted = false
    m.receipt.readStatus = 200
    saved = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
    check(saved.ok and not saved.store.pendingRoster, "fresh matching unchanged GET acknowledgement clears exact pending snapshot without inventing a submitted PUT")
    for each change in ["status", "submitted", "root"]
        syncAckFixture()
        m.receipt.state = "unchanged"
        m.receipt.submitted = false
        m.receipt.readStatus = 200
        if change = "status" then m.receipt.readStatus = 404
        if change = "submitted" then m.receipt.submitted = true
        if change = "root" then m.receipt.storeRoot += " "
        before = FormatJson(m.registry.values)
        saved = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
        check(not saved.ok and FormatJson(m.registry.values) = before, "unchanged acknowledgement refuses invalid " + change)
    end for
    syncScheduledFixture()
    onProfileSyncScheduleTick()
    task = m.profileScheduledSyncTask
    check(task <> invalid and task.pullOnly and task.apiKey = m.key and task.aeriosession = m.scope.sessionId, "scheduled session start reads under actual adopted source, without prematurely flushing dirty data")
    onScheduledProfileSyncResult(syncFlushEvent(task, syncFlushReadReceipt({rows: []})))
    check(m.profileScheduledSyncTask = invalid and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "scheduled own read retains pending intent until debounced write")
    m.syncTestNow = 101
    onProfileSyncScheduleTick()
    task = m.profileScheduledSyncTask
    check(task <> invalid and task.pullOnly = false, "one-second durable dirty debounce launches own writer")
    m.receipt.storeRoot = task.storeRoot
    onScheduledProfileSyncResult(syncFlushEvent(task, m.receipt))
    check(m.profileScheduledSyncTask = invalid and not loadUserProfileStore(m.registry, "slot-a").pendingRoster and task.apiKey = "", "scheduled successful own PUT uses real atomic acknowledgement and wipes Task key")
    m.syncTestNow = 102
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask = invalid, "clean acknowledged snapshot does not produce a write loop")
    for each refusal in ["too-large", "storage-full"]
        syncScheduledFixture()
        onProfileSyncScheduleTick()
        onScheduledProfileSyncResult(syncFlushEvent(m.profileScheduledSyncTask, syncFlushReadReceipt({rows: []})))
        m.syncTestNow = 101
        onProfileSyncScheduleTick()
        task = m.profileScheduledSyncTask
        before = FormatJson(m.registry.values)
        onScheduledProfileSyncResult(syncFlushEvent(task, {ok: false, state: refusal, phase: "budget", submitted: false}))
        check(m.profileSyncSchedule.pause = refusal and not m.profileSyncSchedule.creationBlocked, "preflight size/quota refusals are not server-confirmed max_apps")
        check(FormatJson(m.registry.values) = before and task.apiKey = "", "capacity refusal keeps exact pending root without acknowledging and wipes Task key")
        m.syncTestNow = 102
        onProfileSyncScheduleTick()
        check(m.profileScheduledSyncTask = invalid, "capacity refusal does not immediately retry")
        m.syncTestNow = 1001
        onProfileSyncScheduleTick()
        task = m.profileScheduledSyncTask
        check(task <> invalid and task.pullOnly = (refusal = "too-large") and not task.creationBlocked, "fresh quota is retried on cadence; an unchanged oversize snapshot stays read-only")
        if refusal = "too-large"
            read = syncFlushReadReceipt({rows: [[8, "Bob", "Remote Bob", "none", "", "", "user", 200]]})
            read.storeRoot = task.storeRoot
            onScheduledProfileSyncResult(syncFlushEvent(task, read))
            current = loadUserProfileStore(m.registry, "slot-a")
            check(current.pendingRoster and current.profiles[1].displayName = "Remote Bob", "oversize pause still applies fresh peer roster without acknowledging")
            m.syncTestNow = 1002
            onProfileSyncScheduleTick()
            check(m.profileScheduledSyncTask = invalid, "imported metadata does not unblock oversize writes")
            launchChoice = setCanonicalPreference(current, "askAtLaunch", not current.askAtLaunch)
            check(commitUserProfileStore(m.registry, current, launchChoice, {}, true).ok, "save the local launch choice while roster edits are pending")
            current = loadUserProfileStore(m.registry, "slot-a")
            askRoot = m.registry.read(userProfileStoreKey("slot-a"))
            onProfileSyncScheduleTick()
            m.syncTestNow = 1003
            onProfileSyncScheduleTick()
            check(m.profileScheduledSyncTask = invalid and m.profileSyncSchedule.pause = "too-large", "changing Ask at Launch while pending must not retry the same roster content")
            current.profiles[1] = setCanonicalPreference(current.profiles[1], "displayName", "Local Bob")
            m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(current)
            onProfileSyncScheduleTick()
            m.syncTestNow = 1004
            onProfileSyncScheduleTick()
            check(m.profileScheduledSyncTask <> invalid and not m.profileScheduledSyncTask.pullOnly and not m.profileScheduledSyncTask.creationBlocked, "next local edit schedules a fresh eligible write after debounce")
            task = m.profileScheduledSyncTask
            check(task.storeRoot <> askRoot and task.storeRoot = m.registry.read(userProfileStoreKey("slot-a")), "writer still captures the exact durable root for acknowledgement")
            launchChoice = setCanonicalPreference(current, "askAtLaunch", not current.askAtLaunch)
            check(commitUserProfileStore(m.registry, current, launchChoice, {}, true).ok, "save the next launch choice during an admitted roster write")
            m.receipt.storeRoot = task.storeRoot
            onScheduledProfileSyncResult(syncFlushEvent(task, m.receipt))
            check(loadUserProfileStore(m.registry, "slot-a").pendingRoster and not m.registry.exists(userProfileSyncAckKey("slot-a")), "same wire intent cannot acknowledge across changed exact root")
        end if
        closeScheduledProfileSync()
    end for
    syncScheduledFixture()
    onProfileSyncScheduleTick()
    onScheduledProfileSyncResult(syncFlushEvent(m.profileScheduledSyncTask, syncFlushReadReceipt({rows: []})))
    m.syncTestNow = 101
    onProfileSyncScheduleTick()
    task = m.profileScheduledSyncTask
    changed = loadUserProfileStore(m.registry, "slot-a")
    changed.profiles[1] = setCanonicalPreference(changed.profiles[1], "displayName", "New Bob")
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(changed)
    onProfileSyncScheduleTick()
    onScheduledProfileSyncResult(syncFlushEvent(task, syncMaxAppsReceipt(task)))
    m.syncTestNow = 1001
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask <> invalid and m.profileScheduledSyncTask.creationBlocked and not m.profileScheduledSyncTask.pullOnly, "Scene carries confirmed creation refusal without disallowing a canonical update")
    check(m.profileScheduledSyncTask.storeRoot <> task.storeRoot and loadUserProfileStore(m.registry, "slot-a").pendingRoster and not m.registry.exists(userProfileSyncAckKey("slot-a")), "confirmed max_apps survives a new pending roster root without acknowledging it")
    closeScheduledProfileSync()
    syncScheduledFixture()
    onProfileSyncScheduleTick()
    onScheduledProfileSyncResult(syncFlushEvent(m.profileScheduledSyncTask, syncFlushReadReceipt({rows: []})))
    m.syncTestNow = 101
    onProfileSyncScheduleTick()
    task = m.profileScheduledSyncTask
    m.registry.values["connKey_slot-a"] = "replacement-own"
    onScheduledProfileSyncResult(syncFlushEvent(task, syncMaxAppsReceipt(task)))
    check(not m.profileSyncSchedule.creationBlocked and m.profileSyncSchedule.pause <> "storage-full" and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "Scene does not apply old credential capacity feedback after saved credential replacement")
    for each change in ["launch-choice", "roster-edit"]
        syncScheduledFixture()
        onProfileSyncScheduleTick()
        onScheduledProfileSyncResult(syncFlushEvent(m.profileScheduledSyncTask, syncFlushReadReceipt({rows: []})))
        m.syncTestNow = 101
        onProfileSyncScheduleTick()
        task = m.profileScheduledSyncTask
        current = loadUserProfileStore(m.registry, "slot-a")
        feedback = syncMaxAppsReceipt(task)
        feedback.state = "too-large"
        feedback.status = 413
        feedback.creationBlocked = false
        feedback.rosterIntent = dispatcharrSyncRosterIntentDigest(current)
        changed = setCanonicalPreference(current, "askAtLaunch", not current.askAtLaunch)
        if change = "roster-edit" then changed.profiles[1] = setCanonicalPreference(changed.profiles[1], "displayName", "New roster intent")
        check(commitUserProfileStore(m.registry, current, changed, {}, true).ok and task.storeRoot <> m.registry.read(userProfileStoreKey("slot-a")), "edit advances the exact root while a write is in flight")
        onScheduledProfileSyncResult(syncFlushEvent(task, feedback))
        check((m.profileSyncSchedule.pause = "too-large") = (change = "launch-choice"), "without another timer tick, oversize applies only to the current roster intent")
        check(loadUserProfileStore(m.registry, "slot-a").pendingRoster and not m.registry.exists(userProfileSyncAckKey("slot-a")), "typed oversize does not acknowledge the changed durable root")
        m.syncTestNow = 102
        onProfileSyncScheduleTick()
        m.syncTestNow = 1001
        onProfileSyncScheduleTick()
        check(m.profileScheduledSyncTask <> invalid and m.profileScheduledSyncTask.pullOnly = (change = "launch-choice"), "unchanged intent refreshes read-only; a changed roster can retry")
        closeScheduledProfileSync()
    end for
    syncScheduledFixture()
    onProfileSyncScheduleTick()
    onScheduledProfileSyncResult(syncFlushEvent(m.profileScheduledSyncTask, syncFlushReadReceipt({rows: []})))
    held = loadUserProfileStore(m.registry, "slot-a")
    held.profiles[1] = setCanonicalPreference(held.profiles[1], "addressHeld", true)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(held)
    m.syncTestNow = 101
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask = invalid and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "a held slot sends nothing and keeps pending")
    held = loadUserProfileStore(m.registry, "slot-a")
    released = copyPreferenceValue(held)
    released.profiles[1] = setCanonicalPreference(released.profiles[1], "addressHeld", false)
    check(commitUserProfileStore(m.registry, held, released, {}, true).ok, "releasing the last hold preserves the durable read fence in the same transaction")
    m.profileSyncSchedule = invalid
    m.syncTestNow = 102
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask <> invalid and m.profileScheduledSyncTask.pullOnly, "releasing the final hold pulls immediately before flushing dirty edits")
    onScheduledProfileSyncResult(syncFlushEvent(m.profileScheduledSyncTask, {ok: false, state: "unavailable"}))
    m.syncTestNow = 132
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask <> invalid and m.profileScheduledSyncTask.pullOnly, "expired retry backoff must still run pull-only after a failed post-hold read")
    staleReceipt = syncFlushReadReceipt({rows: []})
    onScheduledProfileSyncResult(syncFlushEvent(m.profileScheduledSyncTask, staleReceipt))
    check(loadUserProfileStore(m.registry, "slot-a").rosterPullRequired = true, "a stale-root read cannot release the durable fence")
    m.syncTestNow = 252
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask <> invalid and m.profileScheduledSyncTask.pullOnly, "stale read publication leaves the next retry read-only")
    currentReceipt = syncFlushReadReceipt({rows: []})
    currentReceipt.storeRoot = m.profileScheduledSyncTask.storeRoot
    onScheduledProfileSyncResult(syncFlushEvent(m.profileScheduledSyncTask, currentReceipt))
    currentStore = loadUserProfileStore(m.registry, "slot-a")
    check(currentStore.rosterPullRequired <> true and currentStore.pendingRoster, "only current committed read releases the durable fence without acknowledging the edit")
    m.syncTestNow = 253
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask <> invalid and not m.profileScheduledSyncTask.pullOnly, "only after committed read can the current session schedule a write")
    closeScheduledProfileSync()
    syncScheduledFixture()
    m.profileSyncEnabled = false
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask = invalid, "device-wide opt-in is required even behind private scheduler readiness")
    syncScheduledFixture()
    m.global.profilegateclosed = true
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask = invalid, "scheduled tasks cannot use the outgoing-flush closed-gate exception")
    syncScheduledFixture()
    m.phoneProfileOnboarding = {phase: "who"}
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask = invalid, "Sync consent defers background transactions until Who watches finishes, keeping dialog roots current")
    m.phoneProfileOnboarding = invalid
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask <> invalid, "Continue releases deferred own Sync discovery without changing the session")
    closeScheduledProfileSync()
    syncScheduledFixture()
    m.profileOwnSignInContext = {adding: true}
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask = invalid and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "own-credential Add suspends scheduled Sync without clearing pending changes")
    m.profileOwnSignInContext = invalid
    onProfileSyncScheduleTick()
    task = m.profileScheduledSyncTask
    check(task <> invalid and task.aeriosession = m.scope.sessionId, "leaving Add resumes existing scheduler under the same actual source session")
    m.profileOwnSignInContext = {adding: true}
    onScheduledProfileSyncResult(syncFlushEvent(task, m.receipt))
    check(loadUserProfileStore(m.registry, "slot-a").pendingRoster, "a delayed pre-form Sync receipt cannot acknowledge changes while Add owns the UI")
    onProfileSyncScheduleTick()
    check(m.profileScheduledSyncTask = invalid and task.apiKey = "", "scheduler retires suspended transport rather than publishing into the Add form")
    m.profileOwnSignInContext = invalid
    syncScheduledFixture()
    onProfileSyncScheduleTick()
    task = m.profileScheduledSyncTask
    m.activeUserScope = setCanonicalPreference(m.scope, "sessionId", "00000000-0000-4000-8000-000000000096")
    m.global.activeusersession = m.activeUserScope.sessionId
    onScheduledProfileSyncResult(syncFlushEvent(task, m.receipt))
    check(loadUserProfileStore(m.registry, "slot-a").pendingRoster and m.registry.exists(userProfileSyncAckKey("slot-a")) = false, "late scheduled completion cannot clear dirty data after scope replacement")
    closeScheduledProfileSync()
    syncFlushFixture()
    m.store = setCanonicalPreference(m.store, "pendingRoster", false)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.store)
    receipt = syncFlushReadReceipt({rows: [[8, "Bob", "Clean imported name", "none", "", "", "user", 200]]})
    receipt.storeRoot = m.registry.values[userProfileStoreKey("slot-a")]
    saved = commitDispatcharrSyncRosterRead(m.registry, m.connection, m.store, receipt, m.scope, m.key, {}, m.profileAuthorizationSignature, true, 600)
    check(saved.ok and not saved.store.pendingRoster and saved.store.profiles[1].displayName = "Clean imported name", "scheduled read imports metadata without requiring or inventing dirty intent")
    for each fault in ["write", "flush", "rollback"]
        syncOwnRetirementFixture()
        before = FormatJson(m.registry.values)
        m.registry.fault = fault
        selected = commitDispatcharrOwnRetirementSelection(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {}, m.profileAuthorizationSignature, true, 600, m.retirementNonce)
        check(not selected.ok and FormatJson(m.registry.values) = before and selected.recoveryRequired = (fault = "rollback"), "own selection faults retain original actor storage and all private ownership")
        syncOwnRetirementFixture()
        selected = commitDispatcharrOwnRetirementSelection(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {}, m.profileAuthorizationSignature, true, 600, m.retirementNonce)
        before = FormatJson(m.registry.values)
        m.registry.failed = false
        m.registry.fault = fault
        result = commitDispatcharrOwnRetirementCleanup(m.registry, m.connection, m.store, selected, m.receipt, invalid, "", {}, m.profileAuthorizationSignature, true, 700, m.retirementNonce)
        check(not result.ok and FormatJson(m.registry.values) = before and result.recoveryRequired = (fault = "rollback"), "own cleanup faults preserve exact selected protection and fenced intent")
    end for
    for each change in ["scope", "authority", "key", "root", "nonce", "profiles-off"]
        syncOwnRetirementFixture()
        before = FormatJson(m.registry.values)
        scope = m.scope
        authority = m.profileAuthorizationSignature
        enabled = true
        nonce = m.retirementNonce
        if change = "scope" then scope = setCanonicalPreference(scope, "sessionId", m.retirementNonce)
        if change = "authority" then authority = "successor"
        if change = "key" then m.key = "successor"
        if change = "root" then m.receipt.storeRoot += " "
        if change = "nonce" then nonce = m.scope.sessionId
        if change = "profiles-off" then enabled = false
        selected = commitDispatcharrOwnRetirementSelection(m.registry, m.connection, m.store, m.receipt, scope, m.key, {}, authority, enabled, 600, nonce)
        check(not selected.ok and FormatJson(m.registry.values) = before, "own retirement refuses stale admission: " + change)
    end for
    for each cold in [false, true]
        syncOwnRetirementFixture()
        selected = commitDispatcharrOwnRetirementSelection(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {}, m.profileAuthorizationSignature, true, 600, m.retirementNonce)
        check(selected.ok and selected.store.active = m.store.profiles[1].id and m.registry.exists(m.retirementSourceKey) and selected.scope = invalid, "actual-own receipt selects real default before deleting source ownership, without staged target scope")
        before = FormatJson(m.registry.values)
        denied = commitDispatcharrOwnRetirementCleanup(m.registry, m.connection, m.store, selected, m.receipt, m.scope, m.key, {}, m.profileAuthorizationSignature, true, 700, m.retirementNonce)
        check(not denied.ok and FormatJson(m.registry.values) = before, "actual-own cleanup cannot run while source runtime remains authenticated")
        if cold
            result = resumeUserProfileRetirement(m.registry, m.connection, invalid, "")
            check(result.ok and result.committed <> true, "cold own retirement grants no system-adoption receipt")
        else
            result = commitDispatcharrOwnRetirementCleanup(m.registry, m.connection, m.store, selected, m.receipt, invalid, "", {}, m.profileAuthorizationSignature, true, 700, m.retirementNonce)
            check(result.ok and result.committed and result.needsDefaultSwitch, "explicit live actual-own retirement returns its bounded system transition receipt")
        end if
        check(result.ok and not m.registry.exists(m.retirementSourceKey) and result.store.active = m.store.profiles[1].id and result.store.pendingRoster and not m.registry.exists(userProfileSyncAckKey("slot-a")), "own tombstone cleans removed source without a PUT acknowledgement or dirty-state loss")
    end for
    for each fault in ["", "write", "flush", "rollback"]
        syncAckFixture()
        m.store = setCanonicalPreference(m.store, "removed", [["removed-example", 200]])
        m.receipt.storeRoot = FormatJson(m.store)
        m.registry.values[userProfileStoreKey("slot-a")] = m.receipt.storeRoot
        m.registry.fault = fault
        before = FormatJson(m.registry.values)
        result = ensureDispatcharrSyncDeviceIdentity(m.registry, "00000000-0000-4000-8000-000000000080")
        if fault = ""
            again = ensureDispatcharrSyncDeviceIdentity(m.registry, "00000000-0000-4000-8000-000000000081")
            check(result.ok and again.id = result.id and m.registry.flushes = 1, "sync install identity persists once and is reused across sessions without regeneration")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "failed identity creation restores exact missing record and leaves dirty metadata intact")
        end if
    end for
    syncAckFixture()
    check(not ensureDispatcharrSyncDeviceIdentity(m.registry, "not-a-uuid").ok and m.registry.flushes = 0, "invalid install identity cannot become a wire device ID")
    m.registry.values["dispatcharrSyncDeviceV1"] = "opaque-existing-value"
    before = FormatJson(m.registry.values)
    check(not ensureDispatcharrSyncDeviceIdentity(m.registry, "00000000-0000-4000-8000-000000000080").ok and FormatJson(m.registry.values) = before, "opaque present identity fails closed rather than being overwritten as absent")
    for each fault in ["", "write", "flush", "rollback"]
        syncAckFixture()
        m.registry.fault = fault
        before = FormatJson(m.registry.values)
        result = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
        if fault = ""
            check(result.ok and not result.store.pendingRoster and result.store.removed.count() = 0 and m.registry.flushes = 1, "successful own 200 clears pending and carried local tombstone intent and stores highwater in one atomic transaction")
            ack = loadDispatcharrSyncRosterAck(m.registry, m.connection)
            check(ack.ok and ack.stamp = 100 and instr(1, m.registry.read(userProfileSyncAckKey("slot-a")), "synthetic-own") = 0 and m.registry.read("connKey_slot-a") = "synthetic-own", "ack records metadata only, never credentials, and retains the own key")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "ack transaction faults restore exact dirty root and previous ack")
        end if
    end for
    for each change in ["scope", "generation", "root", "connection", "key", "held", "status", "not-submitted", "digest", "future-ack", "malformed-ack"]
        syncAckFixture()
        if change = "scope" then m.scope = setCanonicalPreference(m.scope, "sessionId", "00000000-0000-4000-8000-000000000091")
        if change = "generation" then m.scope = setCanonicalPreference(m.scope, "authorizationGeneration", "successor-generation")
        if change = "root" then m.registry.values[userProfileStoreKey("slot-a")] += " "
        if change = "connection" then m.registry.values["connectionsV1"] += " "
        if change = "key"
            m.registry.values["connKey_slot-a"] = "successor-key"
            m.key = "successor-key"
        end if
        if change = "held" then m.held = true
        if change = "status" then m.receipt.ok = false
        if change = "not-submitted" then m.receipt.submitted = false
        if change = "digest" then m.receipt.credentialHash = string(64, "b")
        if change = "future-ack" then m.registry.values[userProfileSyncAckKey("slot-a")] = "{""schema"":2}"
        if change = "malformed-ack" then m.registry.values[userProfileSyncAckKey("slot-a")] = ""
        before = FormatJson(m.registry.values)
        result = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
        check(not result.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "late acknowledgement cannot clear pending after changed " + change)
    end for
    syncAckFixture()
    m.registry.values[userProfileSyncAckKey("slot-a")] = "{""schema"":1,""playlistId"":""slot-a"",""baseUrl"":""https://example.test"",""maximumSentStamp"":200}"
    result = commitDispatcharrSyncRosterAck(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {})
    check(result.ok and loadDispatcharrSyncRosterAck(m.registry, m.connection).stamp = 200, "late lower highwater cannot regress an existing successful acknowledgement")
    syncAckFixture()
    m.receipt.ok = false
    m.receipt.state = "local-commit"
    m.receipt.submitted = false
    m.receipt.readStatus = 200
    m.receipt.authorizationSignature = "bound-own-authority"
    m.receipt.profileData = {rows: [[7, "Alice", "Remote name", "none", "", "", "user", 200]]}
    result = commitDispatcharrSyncRosterRead(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {}, "bound-own-authority", true, 500)
    check(result.ok and result.store.profiles[0].displayName = "Remote name" and result.store.pendingRoster and not m.registry.exists(userProfileSyncAckKey("slot-a")), "fresh own read publishes newer metadata without acknowledging or clearing outgoing dirty state")
    before = FormatJson(m.registry.values)
    check(not commitDispatcharrSyncRosterRead(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {}, "bound-own-authority", true, 500).ok and FormatJson(m.registry.values) = before, "read receipt cannot replay after its exact saved snapshot advanced")
    syncAckFixture()
    m.receipt.ok = false
    m.receipt.state = "local-commit"
    m.receipt.submitted = false
    m.receipt.readStatus = 200
    m.receipt.authorizationSignature = "old-own-authority"
    m.receipt.profileData = {rows: []}
    before = FormatJson(m.registry.values)
    check(not commitDispatcharrSyncRosterRead(m.registry, m.connection, m.store, m.receipt, m.scope, m.key, {}, "new-own-authority", true, 500).ok and FormatJson(m.registry.values) = before, "read publication requires the actual current own authority signature, not just matching user IDs")
    syncFlushFixture()
    m.store = setCanonicalPreference(m.store, "rosterPullRequired", true)
    m.profileSwitchContext.store = m.store
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.store)
    check(beginOutgoingUserProfileSync(m.profileSwitchContext) and m.profileSyncWriteTask.pullOnly, "outgoing switch cannot bypass a persisted post-hold fence without a scheduled session")
    closeOutgoingUserProfileSync()
    syncFlushFixture()
    m.profileScheduledSyncTask = {}
    check(not beginOutgoingUserProfileSync(m.profileSwitchContext), "outgoing flush cannot race an already scheduled own operation")
    m.profileScheduledSyncTask = invalid
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "private flush starts under the actual outgoing adopted session")
    check(m.profileSyncWriteTask.apiKey = "synthetic-own" and m.profileSyncWriteTask.aeriosession = m.scope.sessionId and m.global.activeusersession = m.scope.sessionId and m.profileSwitchContext.key = "target-own-key", "outgoing flush never uses target credentials or retires its actual source nonce early")
    sourceTask = m.profileSyncWriteTask
    onOutgoingUserProfileSyncResult(syncFlushEvent(sourceTask, m.receipt))
    check(m.flushResumes = 1 and m.profileSyncWriteTask = invalid and sourceTask.apiKey = "" and not m.profileSwitchContext.store.pendingRoster and not loadUserProfileStore(m.registry, "slot-a").pendingRoster, "only own matching acknowledgement publishes the clean switch snapshot and resumes incoming staging")
    syncFlushFixture()
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "unchanged outgoing flush fixture starts")
    m.receipt.state = "unchanged"
    m.receipt.submitted = false
    m.receipt.readStatus = 200
    onOutgoingUserProfileSyncResult(syncFlushEvent(m.profileSyncWriteTask, m.receipt))
    check(m.flushResumes = 1 and not loadUserProfileStore(m.registry, "slot-a").pendingRoster, "unchanged own GET acknowledgement may settle outgoing dirty intent without a fabricated PUT")
    syncFlushFixture()
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "failed flush fixture starts")
    onOutgoingUserProfileSyncResult(syncFlushEvent(m.profileSyncWriteTask, {ok: false, state: "pending", submitted: true}))
    check(m.flushResumes = 0 and m.flushRollbacks = 1 and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "failed outgoing write retains dirty data and cannot start incoming authentication")
    syncFlushFixture()
    m.playingChannel = {uuid: "owned-source"}
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "authority refusal fixture starts")
    onOutgoingUserProfileSyncResult(syncFlushEvent(m.profileSyncWriteTask, {ok: false, state: "authority", submitted: false}))
    check(m.flushResumes = 0 and m.flushRollbacks = 1 and m.userProfileRecoveryRequired and m.apiKey = "" and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "fresh outgoing authority mismatch cannot restore content under the previous authorization")
    check(m.syncSourceStopped and m.syncSourceFenced, "changed outgoing authority stops source playback and fences native renderers rather than only covering old permissions")
    syncFlushFixture()
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "metadata read settlement fixture starts")
    readReceipt = syncFlushReadReceipt({rows: [[8, "Bob", "Remote Bob", "none", "", "", "user", 200]]})
    onOutgoingUserProfileSyncResult(syncFlushEvent(m.profileSyncWriteTask, readReceipt))
    check(m.flushResumes = 1 and m.profileSwitchContext.store.profiles[1].displayName = "Remote Bob" and m.profileSwitchContext.store.pendingRoster and m.profileSwitchContext.syncReadSettlements = 1, "read publication resumes bounded fresh outgoing staging without acknowledging metadata as written")
    syncFlushFixture()
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "new target protection fixture starts")
    readReceipt = syncFlushReadReceipt({rows: [[8, "Bob", "Bob", "numbers", string(64, "a"), string(32, "b"), "user", 200]]})
    onOutgoingUserProfileSyncResult(syncFlushEvent(m.profileSyncWriteTask, readReceipt))
    check(m.flushResumes = 0 and m.syncPinPrompts = 1 and m.profileSwitchContext.pin = invalid and m.profileSwitchContext.target.pinType = "numbers" and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "newly imported target PIN invalidates any old one-shot ticket and prompts before fresh outgoing continuation")
    syncFlushFixture()
    check(beginOutgoingUserProfileSync(m.profileSwitchContext), "stale flush fixture starts")
    sourceTask = m.profileSyncWriteTask
    m.global.activeusersession = "00000000-0000-4000-8000-000000000092"
    m.apiKey = "successor-key"
    onOutgoingUserProfileSyncResult(syncFlushEvent(sourceTask, m.receipt))
    check(m.flushResumes = 0 and m.flushRollbacks = 0 and m.apiKey = "successor-key" and loadUserProfileStore(m.registry, "slot-a").pendingRoster, "stale flush callback cannot clear dirty state, wipe successor key or resume an incoming request")
    closeOutgoingUserProfileSync()
    syncOwnRetirementFixture()
    m.profileSwitchContext.store = m.store
    m.profileSwitchContext.target = m.store.profiles[1]
    m.receipt.profileData.removed[0][1] = CreateObject("roDateTime").asSeconds()
    before = FormatJson(m.registry.values)
    settleOutgoingUserProfileSyncRead(m.profileSwitchContext, m.receipt)
    check(m.ownRetirementRequests = 1 and m.flushResumes = 0 and m.flushRollbacks = 0 and FormatJson(m.registry.values) = before, "active-own tombstone dispatches distinct own retirement rather than staging a chosen-target proof")
    print "ALL TESTS PASSED"
end sub

function syncMaxAppsReceipt(task as object) as object
    return {ok: false, state: "storage-full", phase: "put", status: 409, submitted: true, creationBlocked: true, scope: m.scope, connectionRoot: task.connectionRoot, credentialHash: requestGateCredentialHash(m.key), canonicalKey: "alice.aeriotv"}
end function

sub syncScheduledFixture()
    syncFlushFixture()
    m.profileSwitchContext = invalid
    m.profileSyncSchedulingReady = true
    m.profileSyncEnabled = true
    m.profileSyncSchedule = invalid
    m.profileScheduledSyncTask = invalid
    m.profileScheduledSyncContext = invalid
    m.profileSyncSettingsContext = invalid
    m.profileSyncLinkKnown = false
    m.profileSyncLinkUp = false
    m.profileSyncNetworkSequence = 0
    m.top.token = "scene"
    m.top.isSameNode = function(other as object) as boolean
        return m.token = other.token
    end function
    m.syncTestNow = 100
    m.profileSyncScheduleNow = function() as integer
        return m.syncTestNow
    end function
    m.profileScheduledSyncTaskFactory = m.profileSyncWriteTaskFactory
end sub

sub syncOwnRetirementFixture()
    syncFlushFixture()
    m.store.profiles[0] = setCanonicalPreference(m.store.profiles[0], "isDefault", false)
    m.store.profiles[1] = setCanonicalPreference(m.store.profiles[1], "isDefault", true)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.store)
    m.retirementSourceKey = userProfileKeyName("slot-a", m.store.active)
    m.registry.values[m.retirementSourceKey] = m.key
    m.registry.values["connKey_slot-a"] = "target-own-key"
    m.receipt = syncFlushReadReceipt({rows: [[8, "Bob", "Protected default", "numbers", string(64, "e"), string(32, "f"), "user", 550]], removed: [["alice", 500]]})
    m.receipt.storeRoot = m.registry.values[userProfileStoreKey("slot-a")]
    m.retirementNonce = "00000000-0000-4000-8000-000000000095"
end sub

sub syncFlushFixture()
    syncAckFixture()
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 1)
    b = setCanonicalPreference(b, "isDefault", false)
    m.store.profiles.push(b)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.store)
    m.registry.values["dispatcharrSyncDeviceV1"] = "00000000-0000-4000-8000-000000000080"
    m.receipt.storeRoot = m.registry.values[userProfileStoreKey("slot-a")]
    m.profileSyncWriterReady = true
    m.userProfileRecoveryRequired = false
    m.playingChannel = invalid
    m.syncSourceStopped = false
    m.syncSourceFenced = false
    m.syncPinPrompts = 0
    m.ownRetirementRequests = 0
    m.profilePinDialog = invalid
    m.profileSyncAppVersion = "1"
    m.profileSyncNonceFactory = function() as string
        return "00000000-0000-4000-8000-000000000093"
    end function
    m.profileSyncWriteTask = invalid
    m.profileSyncContext = invalid
    m.activeUserScope = m.scope
    m.apiKey = m.key
    m.selectedConnectionId = "slot-a"
    m.profileAuthorizationSignature = dispatcharrAuthorizationSignature({id: 7, username: "Alice", user_level: 1})
    m.global = {activeusersession: m.scope.sessionId, profilegateclosed: false}
    m.profileSwitchContext = {nonce: "00000000-0000-4000-8000-000000000091", outgoing: m.scope, connection: m.connection, store: m.store, target: b, key: "target-own-key"}
    m.profileGateCover = {visible: false}
    m.guide = {active: true}
    m.top = {message: {}
        findNode: function(id as string) as object
            return m.message
        end function
    }
    m.flushResumes = 0
    m.flushRollbacks = 0
    m.profileSyncWriteTaskFactory = function() as object
        return {apiKey: "", token: "outgoing-task", result: invalid
            observeField: sub(field as string, callback as string)
            end sub
            unobserveField: sub(field as string)
            end sub
            isSameNode: function(other as object) as boolean
                return m.token = other.token
            end function
        }
    end function
end sub

function beginOwnSyncDefaultRetirement(context as object, receipt as object, memory as object) as boolean
    if not userProfileSameSession(receipt.scope, m.activeUserScope) then return false
    if receipt.scope.profileId = context.target.id then return false
    m.ownRetirementRequests++
    return true
end function

function syncFlushReadReceipt(data as object) as object
    receipt = copyPreferenceValue(m.receipt)
    receipt.ok = false
    receipt.state = "local-commit"
    receipt.submitted = false
    receipt.readStatus = 200
    receipt.authorizationSignature = m.profileAuthorizationSignature
    receipt.profileData = data
    return receipt
end function

function beginProfilePinGate(profile as object, continuation as string, resume = invalid as dynamic) as boolean
    m.syncPinPrompts++
    return true
end function

function syncFlushEvent(node as object, data as object) as object
    return {node: node, data: data
        getRoSGNode: function() as object
            return m.node
        end function
        getData: function() as object
            return m.data
        end function
    }
end function

function userProfileSwitchActorCurrent(context as object) as boolean
    return userProfileSameSession(context.outgoing, m.activeUserScope)
end function

sub startUserProfileSwitchTask(nonce as string)
    m.flushResumes++
end sub

sub rollbackUserProfileSwitch(message as string)
    m.flushRollbacks++
end sub

sub stopPlayback()
    m.syncSourceStopped = true
    m.playingChannel = invalid
end sub

sub requestGateFenceRenderers(root as object)
    m.syncSourceFenced = true
end sub

sub syncAckFixture()
    connections = connectionStoreAdd(defaultConnectionStore(), "slot-a", "Synthetic")
    connections = connectionStoreUpdate(connections, "slot-a", {url: "https://example.test", accountId: "7", remember: true})
    m.connection = connectionStoreEntry(connections, "slot-a")
    profile = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    m.store = defaultUserProfileStore("slot-a")
    m.store.profiles = [profile]
    m.store.active = profile.id
    m.store.pendingRoster = true
    m.scope = userProfileSessionScope(m.connection, profile.id, 7, "own-generation", "00000000-0000-4000-8000-000000000090")
    m.key = "synthetic-own"
    m.held = false
    values = {connectionsV1: FormatJson(connections)}
    values["connKey_slot-a"] = m.key
    values[userProfileStoreKey("slot-a")] = FormatJson(m.store)
    m.receipt = {ok: true, state: "written", submitted: true, scope: m.scope, storeRoot: values[userProfileStoreKey("slot-a")], connectionRoot: values.connectionsV1, credentialHash: string(64, "a"), maximumSentStamp: 100}
    m.registry = {values: values, fault: "", failed: false, flushes: 0
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            if m.fault = "write" and not m.failed then m.failed = true : return false
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            m.flushes++
            if m.fault = "rollback" then return false
            if m.fault = "flush" and not m.failed then m.failed = true : return false
            return true
        end function
    }
end sub

function requestGateCredentialHash(key as string) as string
    if key = "synthetic-own" then return string(64, "a")
    ' Host fixture identity for roster snapshots; tested wire edits change byte length.
    if left(key, 1) = "[" or left(key, 1) = "{" then return len(key).toStr()
    return string(64, "b")
end function

function requestGateAccessAllowed(url as string, key as string) as boolean
    return not m.held
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
