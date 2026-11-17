' Private synthetic HTTP only; run after actual B adoption in the normal app.
sub advanceProfileSyncWriterProbe()
    m.writerProbeMode = PROFILE_WRITER_MODE
    if left(m.writerProbeMode, 8) = "controls"
        advanceProfileSyncControlsProbe()
        return
    end if
    if left(m.writerProbeMode, 8) = "schedule"
        advanceProfileSyncScheduleProbe()
        return
    end if
    if m.writerProbeMode <> "direct" and m.writerProbeMode <> "unchanged" and left(m.writerProbeMode, 6) <> "create"
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
    if m.writerProbeMode = "unchanged" and m.writerFirstAcknowledged = true and result.state = "local-commit" and m.writerUnchangedReadPublished <> true
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        published = commitDispatcharrSyncRosterRead(m.registry, entry, store, result, m.activeUserScope, m.apiKey, {}, m.profileAuthorizationSignature, true, CreateObject("roDateTime").asSeconds())
        if published.ok
            m.writerUnchangedReadPublished = true
            m.userProfileStore = published.store
            m.writerProbeTask = invalid
            m.writerProbeStarted = false
            m.writerProbeQuiesced = false
            m.managementProbeClock.control = "start"
            return
        end if
    end if
    passed = result.ok = true and result.submitted = true and result.state = "written" and m.writerProbeTask.apiKey = "" and m.activeUserScope.accountId = "8" and userProfileSameSession(m.activeUserScope, result.scope) and store.pendingRoster and m.registry.read(userProfileStoreKey("slot-a")) = m.writerProbeBefore and m.apiKey = "synthetic-b" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", store.active)) = "synthetic-b"
    if m.writerProbeMode = "unchanged" and m.writerFirstAcknowledged = true
        passed = result.ok = true and result.submitted = false and result.state = "unchanged" and result.readStatus = 200 and store.pendingRoster and m.writerProbeTask.apiKey = "" and userProfileSameSession(m.activeUserScope, result.scope) and m.registry.read(userProfileStoreKey("slot-a")) = m.writerProbeBefore and m.apiKey = "synthetic-b" and m.writerUnchangedReadPublished = true
    end if
    refused = m.writerProbeMode = "create-legacy" or m.writerProbeMode = "create-proxy404"
    if refused
        passed = not result.ok and result.submitted <> true and m.writerProbeTask.apiKey = "" and store.pendingRoster and m.registry.read(userProfileStoreKey("slot-a")) = m.writerProbeBefore and not m.registry.exists(userProfileSyncAckKey("slot-a")) and m.apiKey = "synthetic-b" and m.activeUserScope.accountId = "8" and m.registry.read("connKey_slot-a") = "synthetic-a"
        if m.writerProbeMode = "create-legacy" then passed = passed and result.state = "legacy"
        if m.writerProbeMode = "create-proxy404" then passed = passed and result.state = "unavailable"
    end if
    if passed and not refused
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        acknowledged = commitDispatcharrSyncRosterAck(m.registry, entry, store, result, m.activeUserScope, m.apiKey, {})
        passed = acknowledged.ok
        if passed
            m.userProfileStore = acknowledged.store
            ack = loadDispatcharrSyncRosterAck(m.registry, entry)
            passed = not loadUserProfileStore(m.registry, "slot-a").pendingRoster and ack.ok and ack.stamp = result.maximumSentStamp
        end if
    end if
    if passed and m.writerProbeMode = "unchanged" and m.writerFirstAcknowledged <> true
        m.writerFirstAcknowledged = true
        m.writerProbeTask = invalid
        m.writerProbeStarted = false
        m.writerProbeQuiesced = false
        m.managementProbeClock.control = "start"
        return
    end if
    print "[profile-management] "; FormatJson({kind: "result", writer: passed, passed: passed, writer_state: textValue(result.state), submitted: result.submitted = true})
end sub

sub advanceProfileSyncControlsProbe()
    if m.writerControlsQuiet <> true
        m.writerControlsQuiet = true
        m.guide.active = false
        m.writerControlsScope = m.activeUserScope
        m.writerControlsRoster = m.registry.read(userProfileStoreKey("slot-a"))
        m.writerControlsAccounts = FormatJson(loadStrictPreferenceStore(m.registry).accounts)
        m.profileSyncControlsReady = true
        m.profileSyncSchedulingReady = true
        return
    end if
    if m.writerControlsBoundary <> true
        m.writerControlsBoundary = true
        print "[profile-management] "; FormatJson({kind: "writer-ready"})
        return
    end if
    if m.writerControlsOpened <> true
        m.writerControlsOpened = true
        showConnection()
        openConnectionManager()
        index = -1
        for i = 0 to m.connectionChoices.count() - 1
            if m.connectionChoices[i].action = "syncControls" then index = i
        end for
        if index >= 0 then onConnectionChoice(managementProbeEvent(m.connectionDialog, index))
        ready = index >= 0 and m.profileSyncSettingsContext <> invalid and m.connectionChoices[0].value = true and not loadDispatcharrSyncSettings(m.registry).enabled
        print "[profile-management] "; FormatJson({kind: "controls-ready", ready: ready})
        return
    end if
    settings = loadDispatcharrSyncSettings(m.registry)
    if m.writerControlsEnabled <> true
        if not settings.enabled then return
        m.writerControlsEnabled = true
        valid = m.profileSyncEnabled and m.profileSyncSettingsContext <> invalid and m.profileScheduledSyncTask = invalid and m.registry.read(userProfileStoreKey("slot-a")) = m.writerControlsRoster
        print "[profile-management] "; FormatJson({kind: "controls-enabled", valid: valid})
        return
    end if
    if m.writerControlsProfilesOff <> true
        if settings.profiles then return
        m.writerControlsProfilesOff = true
        valid = settings.enabled and not m.profileRosterEnabled and m.profileScheduledSyncTask = invalid and m.registry.read(userProfileStoreKey("slot-a")) = m.writerControlsRoster
        print "[profile-management] "; FormatJson({kind: "controls-profiles-off", valid: valid})
        return
    end if
    if m.writerProbeMode = "controls-restore"
        if m.writerControlsRelaunch <> true
            m.writerControlsRelaunch = true
            store = loadUserProfileStore(m.registry, "slot-a")
            store = setCanonicalPreference(store, "pendingRoster", true)
            m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
            m.registry.write("syncSettingsProbeRestore", "1")
            m.registry.write("syncSettingsProbeOldSession", m.activeUserScope.sessionId)
            m.registry.flush()
            closeConnectionDialog()
            m.managementProbeClock.control = "stop"
            ready = settings.enabled and not settings.profiles and not m.profileRosterEnabled and m.profileScheduledSyncTask = invalid
            print "[profile-management] "; FormatJson({kind: "controls-relaunch-ready", ready: ready})
            m.top.exitRequested = true
        end if
        return
    end if
    if m.writerControlsRestored <> true
        if not settings.profiles then return
        m.writerControlsRestored = true
        valid = settings.enabled and m.profileRosterEnabled and m.profileScheduledSyncTask = invalid and m.profileSyncSettingsContext <> invalid
        print "[profile-management] "; FormatJson({kind: "controls-restored", valid: valid})
        return
    end if
    if m.writerControlsRead <> true
        if m.connectionDialog <> invalid or m.profileScheduledSyncTask <> invalid then return
        if m.profileSyncSchedule = invalid then return
        if m.profileSyncSchedule.flight <> invalid or m.profileSyncSchedule.sequence < 1 then return
        m.writerControlsRead = true
        openDispatcharrSyncControls()
        ready = m.profileSyncSettingsContext <> invalid and m.connectionChoices[0].value = false
        print "[profile-management] "; FormatJson({kind: "controls-disable-ready", ready: ready})
        return
    end if
    if settings.enabled then return
    m.managementProbeClock.control = "stop"
    closeConnectionDialog()
    store = loadUserProfileStore(m.registry, "slot-a")
    passed = settings.ok and not m.profileSyncEnabled and settings.profiles and m.profileScheduledSyncTask = invalid and m.profileSyncClock.control = "stop" and not store.pendingRoster and not m.registry.exists(userProfileSyncAckKey("slot-a")) and userProfileSameSession(m.writerControlsScope, m.activeUserScope) and m.apiKey = "synthetic-b" and m.registry.read("connKey_slot-a") = "synthetic-a" and FormatJson(settings.store.accounts) = m.writerControlsAccounts
    print "[profile-management] "; FormatJson({kind: "result", writer: passed, controls: passed, timer_control: m.profileSyncClock.control, accounts_retained: FormatJson(settings.store.accounts) = m.writerControlsAccounts})
end sub

sub runProfileSyncControlsColdProbe()
    if m.page <> "guide" or m.busy then return
    m.managementProbeClock.control = "stop"
    settings = loadDispatcharrSyncSettings(m.registry)
    store = loadUserProfileStore(m.registry, "slot-a")
    entry = connectionStoreEntry(m.connectionStore, "slot-a")
    passed = settings.ok and settings.enabled and not settings.profiles and m.profileSyncEnabled and not m.profileRosterEnabled and store.pendingRoster and not m.registry.exists(userProfileSyncAckKey("slot-a")) and m.profileScheduledSyncTask = invalid
    passed = passed and m.activeUserScope <> invalid
    if passed then passed = m.activeUserScope.accountId = "8" and m.apiKey = "synthetic-b" and m.activeUserScope.sessionId <> m.registry.read("syncSettingsProbeOldSession") and m.registry.read("connKey_slot-a") = "synthetic-a" and m.guide.callFunc("profileSwitchProbeLineup") = "8" and m.accountPreferences.favoriteIds[0] = "8"
    for each profile in store.profiles
        if profile.id = store.active then passed = passed and profile.role = "user" and profile.pinType = "none"
    end for
    print "[profile-management] "; FormatJson({kind: "result", writer: passed, controls: passed, cold_restored: passed})
end sub

sub advanceProfileSyncScheduleProbe()
    if m.writerScheduleQuiet <> true
        m.writerScheduleQuiet = true
        m.guide.active = false
        m.writerScheduleScope = m.activeUserScope
        return
    end if
    if m.writerScheduleReady <> true
        m.writerScheduleReady = true
        print "[profile-management] "; FormatJson({kind: "writer-ready"})
        return
    end if
    if m.writerScheduleStarted <> true
        m.writerScheduleStarted = true
        m.profileSyncSchedulingReady = true
        m.profileSyncEnabled = true
        activateProfileSyncScheduling()
        return
    end if
    if m.profileScheduledSyncTask <> invalid then return
    if m.profileSyncSchedule = invalid then return
    if m.profileSyncSchedule.flight <> invalid then return
    if m.profileSyncSchedule.sequence < 1 then return
    if m.writerProbeMode = "schedule-signin"
        if m.writerScheduleQuietTicks = invalid then m.writerScheduleQuietTicks = 0
        m.writerScheduleQuietTicks++
        if m.writerScheduleQuietTicks < 3 then return
        m.profileSyncClock.control = "stop"
        m.managementProbeClock.control = "stop"
        passed = m.profileSyncSchedule.pause = "signin-required" and m.profileSyncSchedule.sequence = 1 and userProfileSameSession(m.writerScheduleScope, m.activeUserScope) and m.apiKey = "synthetic-b" and not m.registry.exists(userProfileSyncAckKey("slot-a"))
        print "[profile-management] "; FormatJson({kind: "result", writer: passed, scheduled: passed})
        return
    end if
    if m.writerScheduleDirty <> true
        m.writerScheduleDirty = true
        store = loadUserProfileStore(m.registry, "slot-a")
        for i = 0 to store.profiles.count() - 1
            profile = store.profiles[i]
            if profile.id = store.active
                profile = setCanonicalPreference(profile, "displayName", "Scheduled synthetic B")
                profile = setCanonicalPreference(profile, "displayNameClaimed", true)
                profile = setCanonicalPreference(profile, "updatedAt", CreateObject("roDateTime").asSeconds())
                store.profiles[i] = profile
            end if
        end for
        store = setCanonicalPreference(store, "pendingRoster", true)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.flush()
        m.userProfileStore = loadUserProfileStore(m.registry, "slot-a")
        print "[profile-management] "; FormatJson({kind: "schedule-dirty"})
        return
    end if
    store = loadUserProfileStore(m.registry, "slot-a")
    if m.writerProbeMode = "schedule-too-large"
        if m.profileSyncSchedule.sequence < 2 then return
        if m.profileSyncSchedule.pause <> "too-large" then return
        if m.writerScheduleNetwork <> true
            if m.writerScheduleLinkDown <> true
                m.writerScheduleLinkDown = true
                m.writerScheduleLinkSequence = 1
                if userProfileInteger(m.profileSyncNetworkSequence) then m.writerScheduleLinkSequence = m.profileSyncNetworkSequence + 1
                m.top.networkLinkEvent = {linked: false, returned: false, sequence: m.writerScheduleLinkSequence}
                return
            end if
            m.writerScheduleLinkLossObserved = m.profileSyncLinkKnown = true and m.profileSyncLinkUp = false and m.profileScheduledSyncTask = invalid
            m.writerScheduleNetwork = true
            m.top.networkLinkEvent = {linked: true, returned: true, sequence: m.writerScheduleLinkSequence + 1}
            return
        end if
        if m.profileSyncSchedule.sequence < 3 then return
        if m.writerScheduleQuietTicks = invalid then m.writerScheduleQuietTicks = 0
        m.writerScheduleQuietTicks++
        if m.writerScheduleQuietTicks < 3 then return
        m.profileSyncClock.control = "stop"
        m.managementProbeClock.control = "stop"
        passed = m.profileSyncSchedule.sequence = 3 and m.profileSyncSchedule.writeBlockedRoot <> "" and store.pendingRoster and userProfileSameSession(m.writerScheduleScope, m.activeUserScope) and m.apiKey = "synthetic-b" and not m.registry.exists(userProfileSyncAckKey("slot-a")) and m.writerScheduleLinkLossObserved = true and m.profileSyncLinkUp = true
        print "[profile-management] "; FormatJson({kind: "result", writer: passed, scheduled: passed})
        return
    end if
    if store.pendingRoster or m.profileSyncSchedule.sequence < 2 then return
    if m.writerSchedulePicker <> true
        m.writerSchedulePicker = true
        requestScheduledProfileSync("picker")
        requestScheduledProfileSync("picker")
        return
    end if
    if m.profileSyncSchedule.sequence < 4 then return
    if m.writerScheduleNetwork <> true
        if m.writerScheduleLinkDown <> true
            m.writerScheduleLinkDown = true
            m.writerScheduleLinkSequence = 1
            if userProfileInteger(m.profileSyncNetworkSequence) then m.writerScheduleLinkSequence = m.profileSyncNetworkSequence + 1
            m.top.networkLinkEvent = {linked: false, returned: false, sequence: m.writerScheduleLinkSequence}
            return
        end if
        m.writerScheduleLinkLossObserved = m.profileSyncLinkKnown = true and m.profileSyncLinkUp = false and m.profileScheduledSyncTask = invalid
        m.writerScheduleNetwork = true
        m.top.networkLinkEvent = {linked: true, returned: true, sequence: m.writerScheduleLinkSequence + 1}
        return
    end if
    if m.profileSyncSchedule.sequence < 5 then return
    m.profileSyncClock.control = "stop"
    m.managementProbeClock.control = "stop"
    entry = connectionStoreEntry(m.connectionStore, "slot-a")
    ack = loadDispatcharrSyncRosterAck(m.registry, entry)
    passed = ack.ok and ack.stamp > 0 and not store.pendingRoster and userProfileSameSession(m.writerScheduleScope, m.activeUserScope) and m.apiKey = "synthetic-b" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.profileScheduledSyncTask = invalid and m.writerScheduleLinkLossObserved = true and m.profileSyncLinkUp = true
    for each profile in store.profiles
        if profile.id = store.active then passed = passed and profile.displayName = "Scheduled synthetic B"
    end for
    print "[profile-management] "; FormatJson({kind: "result", writer: passed, scheduled: passed})
end sub

sub advanceProfileSyncFlushProbe()
    if m.writerFlushSeeded <> true
        m.writerFlushSeeded = true
        if m.writerProbeMode = "flush-own-retirement" and m.profileBaselineReady = true
            ' Isolate the chosen-switch flush from the independent scheduler;
            ' do not force writer or retirement readiness on.
            m.profileSyncSchedulingReady = false
            openDispatcharrSyncControls()
            if m.connectionDialog = invalid
                m.managementProbeClock.control = "stop"
                print "[profile-management] "; FormatJson({kind: "result", writer: false, reason: "baseline-consent-unavailable"})
                return
            end if
            onConnectionChoice(managementProbeEvent(m.connectionDialog, 0))
            onConnectionChoice(managementProbeEvent(m.connectionDialog, 2))
            enabled = loadDispatcharrSyncSettings(m.registry).enabled
            print "[profile-management] "; FormatJson({kind: "baseline-retirement-consent", enabled: enabled, writerReady: m.profileSyncWriterReady, retirementReady: m.profileDefaultRetirementReady})
            if not enabled
                m.managementProbeClock.control = "stop"
                print "[profile-management] "; FormatJson({kind: "result", writer: false, reason: "baseline-consent-not-saved"})
                return
            end if
        end if
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
