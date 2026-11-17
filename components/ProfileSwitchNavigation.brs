' Staged own-key switch controller. Public rollout remains gated; the developer
' baseline admits local approved-profile switches while Sync settings are Off.
function beginUserProfileSwitch(targetId as string, unavailableChild = false as boolean) as boolean
    if m.profileScheduledSyncTask <> invalid then return false
    if m.profileOwnSignInContext <> invalid then return false
    if m.profileSwitchContext <> invalid or m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return false
    if m.userProfileRecoveryRequired = true then return false
    if unavailableChild
        if m.activeUserScope <> invalid or m.apiKey <> "" or m.page <> "profile-unavailable" or not userProfileGateClosed() then return false
    else
        if m.activeUserScope = invalid then return false
    end if
    connection = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if connection = invalid or connection.provider <> "dispatcharr" then return false
    if not unavailableChild
        if m.activeUserScope.playlistId <> connection.id or m.activeUserScope.preferenceIdentity <> connectionPreferenceIdentity(connection, m.activeUserScope.accountId) then return false
    end if
    store = loadUserProfileStore(m.registry, connection.id)
    if store.readOnly = true then return false
    childSource = false
    outgoingProtection = ""
    if not unavailableChild
        if store.active <> m.activeUserScope.profileId then return false
    end if
    for each profile in store.profiles
        if profile.id = store.active
            childSource = profile.role = "child"
            if not unavailableChild
                if profile.userId.toStr() <> m.activeUserScope.accountId then return false
                outgoingProtection = FormatJson(profile)
            end if
        end if
    end for
    if unavailableChild and not childSource then return false
    if targetId = store.active then return true
    ' The shipping boundary still refuses pending edits; private writer staging
    ' may settle them under the actual outgoing session AFTER the target PIN.
    if store.pendingRoster = true and (not unavailableChild or m.profileSwitchRosterReady = true)
        localPending = false
        if m.profileBaselineReady = true and not unavailableChild
            settings = loadDispatcharrSyncSettings(m.registry)
            localPending = settings.ok and not settings.enabled
        end if
        if (m.profileSyncWriterReady <> true and not localPending) or unavailableChild then return false
    end if
    target = invalid
    for each profile in store.profiles
        if profile.id = targetId then target = profile
    end for
    if target = invalid or target.addressHeld then return false
    ' The private Child controller must be qualified before live selection.
    if target.role = "child" and m.profileChildAccessReady <> true then return false
    admin = userProfileLoadDeviceAdminPin(m.registry, connection.id)
    if not admin.ok then return false
    if not userProfileManagementGrantMatches(store, admin.record, m.profileManagementGrant, textValue(m.profileManagementNonce)) then return false
    selected = copyJson(store)
    selected.active = targetId
    ' Session credentials are bound to address, slot AND local profile ID. A
    ' default profile recreated after Forget cannot inherit an old slot bucket.
    if type(m.profileSessionKeys) <> "roAssociativeArray" then m.profileSessionKeys = {}
    for each profile in store.profiles
        if not unavailableChild
            if profile.id = store.active and profile.id = m.activeUserScope.profileId and profile.userId.toStr() = m.activeUserScope.accountId
                if m.apiKey <> "" then m.profileSessionKeys[preferenceScope(connection.url + "|" + connection.id + "|" + profile.id)] = m.apiKey
            end if
        end if
    end for
    memory = {}
    memoryScope = preferenceScope(connection.url + "|" + connection.id + "|" + target.id)
    if m.profileSessionKeys.doesExist(memoryScope)
        keyName = connectionRegistryKey(connection.id)
        if not target.isDefault then keyName = userProfileKeyName(connection.id, target.id)
        memory[keyName] = m.profileSessionKeys[memoryScope]
    end if
    credential = userProfileCredential(m.registry, connection, selected, memory)
    if not credential.ok then return false
    if not requestGateAccessAllowed(connection.url, credential.key) then return false
    nonce = CreateObject("roDeviceInfo").getRandomUUID()
    m.profileSwitchContext = {nonce: nonce, unavailableChild: unavailableChild, connection: connection, connectionRoot: m.registry.read("connectionsV1"), connectionRootPresent: m.registry.exists("connectionsV1"), store: store, target: target, key: credential.key, outgoing: m.activeUserScope, outgoingProtection: outgoingProtection, unlock: m.profileUnlockGrant, management: m.profileManagementGrant, managementNonce: textValue(m.profileManagementNonce)}
    if m.profileBaselineReady = true and not unavailableChild
        settings = loadDispatcharrSyncSettings(m.registry)
        m.profileSwitchContext.localOnly = settings.ok and not settings.enabled
    end if
    if target.pinType <> "none"
        if beginProfilePinGate(target, "switch", nonce) then return true
        m.profileSwitchContext = invalid
        return false
    end if
    startUserProfileSwitchTask(nonce)
    return true
end function

sub onUserProfileSwitchPin(nonce as string)
    context = m.profileSwitchContext
    if context = invalid or context.nonce <> nonce then return
    if userProfileTrue(context.localOnly)
        if m.profileBaselineReady <> true or not dispatcharrSyncLocalPendingAllowed(m.registry, context) then rollbackUserProfileSwitch("Sync choices changed. Switch cancelled.") : return
    end if
    if not userProfilePinGrantMatches(m.profileUnlockGrant, context.connection.id, context.target) then return
    current = loadUserProfileStore(m.registry, context.connection.id)
    if not userProfileSwitchAcceptPinStore(context.store, current, context.target.id, m.profileUnlockGrant)
        rollbackUserProfileSwitch("Saved profiles changed while entering the PIN. Please retry.")
        return
    end if
    context.store = current
    context.pin = m.profileUnlockGrant
    m.profileUnlockGrant = invalid
    startUserProfileSwitchTask(nonce)
end sub

sub startUserProfileSwitchTask(nonce as string)
    context = m.profileSwitchContext
    if context = invalid or context.nonce <> nonce then return
    if userProfileTrue(context.localOnly)
        if m.profileBaselineReady <> true or not dispatcharrSyncLocalPendingAllowed(m.registry, context) then rollbackUserProfileSwitch("Sync choices changed. Switch cancelled.") : return
    end if
    if context.connection.id <> m.selectedConnectionId then return
    connections = loadConnectionStore(m.registry)
    currentEntry = connectionStoreEntry(connections, context.connection.id)
    if connections.readOnly = true or connections.selected <> context.connection.id or currentEntry = invalid
        rollbackUserProfileSwitch("Saved connections changed. Please verify access again.")
        return
    end if
    currentStore = loadUserProfileStore(m.registry, context.connection.id)
    admin = userProfileLoadDeviceAdminPin(m.registry, context.connection.id)
    if FormatJson(currentEntry) <> FormatJson(normalizeConnectionEntry(context.connection)) or FormatJson(currentStore) <> FormatJson(context.store) or not admin.ok
        rollbackUserProfileSwitch("Saved profiles changed. Please retry.")
        return
    end if
    if not userProfileManagementGrantMatches(currentStore, admin.record, context.management, context.managementNonce)
        rollbackUserProfileSwitch("Profile access changed. Please retry.")
        return
    end if
    if m.profileSwitchRosterReady = true
        ' Re-resolve the own credential after any initial PIN wait, BEFORE
        ' outgoing teardown or the first target request. This is key presence/
        ' ownership only, not a fabricated verified-user proof or target scope.
        if not dispatcharrSyncSwitchRosterStorageCurrent(m.registry, context, textValue(context.key), userProfileSwitchRosterMemory(context))
            rollbackUserProfileSwitch("Profile access changed. Please verify access again.")
            return
        end if
    end if
    if context.unavailableChild = true
        if m.activeUserScope <> invalid or m.apiKey <> "" then return
    else
        if not userProfileSameSession(context.outgoing, m.activeUserScope) then return
        if currentStore.pendingRoster = true and not dispatcharrSyncLocalPendingAllowed(m.registry, context)
            if context.phase = "flush" then return
            if not beginOutgoingUserProfileSync(context) then rollbackUserProfileSwitch("Could not safely flush outgoing changes. Saved edits were retained.")
            return
        end if
        if not persistCurrentUserProfilePreferences()
            rollbackUserProfileSwitch("Could not save the outgoing profile. Switch cancelled.")
            return
        end if
    end if
    ' Keep a submitted operation observable, but close unsent inputs before
    ' retiring the outgoing authorization nonce or adopting another holder.
    preserveSubmittedRecording()
    cancelRecordFlow()
    if m.playingChannel <> invalid then stopPlayback()
    resetMediaNavigation()
    cancelCapabilityRefresh()
    cancelProfileTask()
    m.capabilityClock.control = "stop"
    m.reminderClock.control = "stop"
    m.guide.callFunc("cancelMetadataLoads")
    retireProfileRequestBinding()
    m.busy = true
    m.guide.active = false
    m.profileGateCover.visible = true
    m.top.findNode("profileGateMessage").text = "Switching profile..."
    ' Retire outgoing view/Task callbacks before creating an incoming Task. The
    ' scrim is distinct from a PIN gate: only the incoming tagged Task may work.
    m.global.activeusersession = nonce
    m.global.profileswitchpending = true
    m.global.profilegateclosed = false
    requestGateFenceRenderers(m.top)
    task = invalid
    if m.profileSwitchTaskFactory <> invalid then task = m.profileSwitchTaskFactory()
    if task = invalid then task = CreateObject("roSGNode", "DispatcharrTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = context.connection.url
    task.apiKey = context.key
    task.authMode = context.connection.authMode
    if m.profileSwitchRosterReady = true
        context.phase = "authenticate"
        task.verifyOnly = true
    end if
    task.expectedUserId = context.target.userId.toStr()
    task.expectedUsername = context.target.username
    if context.target.isDefault
        task.profileId = context.connection.profileId
        task.channelProfileIds = context.connection.channelProfileIds
    end if
    task.observeField("result", "onUserProfileSwitchResult")
    task.observeField("state", "onUserProfileSwitchState")
    m.profileSwitchTask = task
    task.control = "RUN"
end sub

sub onUserProfileSwitchState(event as object)
    if not isCurrentTaskEvent(event, m.profileSwitchTask) then return
    if not userProfileSwitchActorCurrent(m.profileSwitchContext) then return
    if event.getData() <> "done" and event.getData() <> "stop" then return
    if type(m.profileSwitchTask.result) = "roAssociativeArray" then return
    if m.profileSwitchContext.systemDefaultRetirement = true
        stopSystemDefaultProfileSwitch("Could not verify the default profile's own access.")
        return
    end if
    rollbackUserProfileSwitch("Could not load this profile. The previous profile was retained.")
end sub

sub onUserProfileSwitchResult(event as object)
    if not isCurrentTaskEvent(event, m.profileSwitchTask) then return
    context = m.profileSwitchContext
    if context = invalid or context.connection.id <> m.selectedConnectionId then return
    if not userProfileSwitchActorCurrent(context) then return
    if userProfileTrue(context.localOnly)
        if m.profileBaselineReady <> true or not dispatcharrSyncLocalPendingAllowed(m.registry, context) then rollbackUserProfileSwitch("Sync choices changed. Switch cancelled.") : return
    end if
    verified = event.getData()
    if context.systemDefaultRetirement = true
        if type(verified) <> "roAssociativeArray" then stopSystemDefaultProfileSwitch("Could not verify the default profile.") : return
        if handleSystemDefaultProfileResult(verified) then return
    end if
    if type(verified) <> "roAssociativeArray" then rollbackUserProfileSwitch("Could not verify this profile.") : return
    if verified.ok <> true
        message = "Could not switch profiles. The previous profile was retained."
        if verified.relogin = true then message = "The API key for " + context.target.username + " was rejected."
        rollbackUserProfileSwitch(message)
        return
    end if
    if context.systemDefaultRetirement <> true
        if handleUserProfileSwitchRosterResult(verified) then return
    end if
    if context.systemDefaultRetirement = true
        saved = commitSystemDefaultProfileSwitch(m.registry, context, verified, m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), userProfileSwitchRosterMemory(context))
    else if context.unavailableChild = true
        if m.activeUserScope <> invalid or m.apiKey <> "" then return
        saved = commitUnavailableChildProfileSwitch(m.registry, context.connection, context.store, context.target.id, verified, context.pin, context.management, context.managementNonce, context.nonce, m.global.activeusersession)
    else
        saved = commitUserProfileSwitch(m.registry, context.connection, context.store, context.target.id, verified, context.pin, context.management, context.managementNonce, context.nonce, m.global.activeusersession, context.outgoing, m.activeUserScope)
    end if
    if not saved.ok
        m.userProfileRecoveryRequired = saved.recoveryRequired
        rollbackUserProfileSwitch("Could not safely save the switch. The previous profile was retained.")
        return
    end if
    closeUserProfileSwitchTask()
    ' Release outgoing owned resources before replacing its credentials.
    m.profileSwitchContext = invalid
    adoptCompletedUserProfileState(context, saved, verified)
end sub

' Runtime publication only AFTER a caller's distinct storage admission succeeds.
' This helper grants no switching/startup/PIN authority on its own.
sub adoptCompletedUserProfileState(context as object, saved as object, verified as object)
    onboarding = m.phoneProfileOnboarding
    preservePhoneOnboarding = false
    if type(onboarding) = "roAssociativeArray"
        preservePhoneOnboarding = onboarding.scope = invalid and m.activeUserScope = invalid and onboarding.slot = context.connection.id and onboarding.connectionRoot = m.registry.read("connectionsV1")
    end if
    resetConnectionRuntime()
    if preservePhoneOnboarding then m.phoneProfileOnboarding = onboarding
    m.userProfileStore = saved.store
    if type(context.rosterSuggestions) = "roArray" then m.profileRosterSuggestions = context.rosterSuggestions
    m.preferenceStore = saved.preferenceStore
    m.accountPreferences = saved.preferences
    m.devicePreferences = saved.device
    m.activeUserScope = saved.scope
    m.profileAuthorizationSignature = dispatcharrAuthorizationSignature(verified.verifiedUser)
    m.scopedPreferencesRequired = true
    m.global.activeusersession = saved.scope.sessionId
    m.apiKey = verified.apiKey
    m.baseUrl = context.connection.url
    m.serverAccountId = verified.accountId
    m.accountIdentity = saved.scope.preferenceIdentity
    m.authMode = "key"
    m.hlsAvailable = verified.hlsAvailable = true
    m.global.authHeaderMode = dispatcharrHeaderMode(textValue(verified.authModeUsed))
    if preservePhoneOnboarding
        m.accountPreferences = takePhoneSetupPreferences(m.accountPreferences, context.connection)
        m.phoneCommittedId = ""
        if not persistCurrentUserProfilePreferences()
            coverProfileManagementRecovery("Could not preserve the imported playlist options.")
            return
        end if
    end if
    applyDevicePreferences()
    m.global.cacheEpoch = CreateObject("roDeviceInfo").getRandomUUID()
    m.guide.historyAccount = m.accountIdentity
    m.guide.config = {aeriosession: currentUserSessionId(), userRole: currentUserSettingsRole(), channels: verified.channels, groups: verified.groups, warning: verified.warning, baseUrl: m.baseUrl, apiKey: m.apiKey, accountId: m.serverAccountId, preferences: m.accountPreferences, providerType: "dispatcharr", guideUrl: context.connection.epgUrl, tmdbKey: m.registry.read("tmdbApiKey"), scope: verified.scope, generation: verified.generation}
    m.banner.session = {baseUrl: m.baseUrl, apiKey: m.apiKey}
    m.banner.preferences = m.devicePreferences
    m.guide.remotePreferences = m.devicePreferences
    m.page = "guide"
    m.screen.visible = false
    m.guide.visible = true
    m.guide.active = true
    m.busy = false
    m.profileGateCover.visible = false
    m.global.profilegateclosed = false
    m.global.profileswitchpending = false
    refreshCapabilities()
    m.capabilityClock.control = "start"
    m.reminderClock.control = "start"
    ' Deliberately no configured mini-player auto-start on a profile switch.
    activateProfileSyncScheduling()
    if m.profileBaselineReady = true then refreshUserProfileChrome()
    if type(context.afterRemoval) = "roAssociativeArray" then resumeProfileManagementRemoval(context.afterRemoval)
    if preservePhoneOnboarding then continuePhoneProfileOnboarding()
end sub

function userProfileSwitchActorCurrent(context as dynamic) as boolean
    if type(context) <> "roAssociativeArray" then return false
    if context.connection.id <> m.selectedConnectionId then return false
    if context.systemDefaultRetirement = true
        return m.activeUserScope = invalid and textValue(m.apiKey) = "" and textValue(m.global.activeusersession) = context.nonce
    end if
    if context.unavailableChild = true
        return m.activeUserScope = invalid and textValue(m.apiKey) = "" and m.page = "profile-unavailable"
    end if
    return userProfileSameSession(context.outgoing, m.activeUserScope)
end function

sub rollbackUserProfileSwitch(message as string)
    context = m.profileSwitchContext
    if context = invalid then return
    if context.systemDefaultRetirement = true
        stopSystemDefaultProfileSwitch(message)
        return
    end if
    if context.connection.id <> m.selectedConnectionId then return
    if type(context.outgoing) = "roAssociativeArray" and type(m.activeUserScope) = "roAssociativeArray"
        if not userProfileSameSession(context.outgoing, m.activeUserScope) then return
    end if
    if type(context.outgoing) = "roAssociativeArray"
        if userProfileSameSession(context.outgoing, m.activeUserScope) then preserveSubmittedRecording()
    end if
    retireUserProfileSwitch()
    m.global.profileswitchpending = false
    if m.userProfileRecoveryRequired = true
        if m.profileSwitcher <> invalid then retireUserProfileSwitcher()
        m.activeUserScope = invalid
        m.global.activeusersession = ""
        m.global.profilegateclosed = true
        m.profileGateCover.visible = true
        m.guide.active = false
        m.top.findNode("profileGateMessage").text = "Saved profiles need recovery. Back exits AerioTV."
        return
    end if
    if context.unavailableChild = true
        m.activeUserScope = invalid
        m.global.activeusersession = ""
        m.global.profilegateclosed = true
        m.profileGateCover.visible = true
        m.guide.active = false
        m.page = "profile-unavailable"
        m.busy = false
        m.profileUnlockGrant = context.unlock
        showUnavailableChildProfile()
        return
    end if
    if not profileSwitchOutgoingProtectionCurrent(context)
        if m.profileSwitcher <> invalid then retireUserProfileSwitcher()
        if m.playingChannel <> invalid then stopPlayback()
        m.activeUserScope = invalid
        m.global.activeusersession = ""
        m.global.profilegateclosed = true
        m.profileGateCover.visible = true
        m.guide.active = false
        m.profileUnlockGrant = invalid
        m.busy = false
        m.userProfileRecoveryRequired = true
        m.top.findNode("profileGateMessage").text = "Profile access changed. Saved data was retained. Back exits AerioTV; reopen to verify access."
        requestGateFenceRenderers(m.top)
        return
    end if
    restored = userProfileSessionScope(context.connection, context.outgoing.profileId, context.outgoing.accountId, context.outgoing.authorizationGeneration, CreateObject("roDeviceInfo").getRandomUUID())
    if restored = invalid then return
    m.activeUserScope = restored
    m.global.activeusersession = restored.sessionId
    m.profileUnlockGrant = context.unlock
    config = m.guide.config
    if type(config) = "roAssociativeArray"
        config = setCanonicalPreference(config, "aeriosession", restored.sessionId)
        m.guide.config = config
    end if
    m.profileGateCover.visible = false
    m.global.profilegateclosed = false
    m.page = "guide"
    m.guide.visible = true
    m.guide.active = true
    m.busy = false
    m.capabilityClock.control = "start"
    m.reminderClock.control = "start"
    if m.profileBaselineReady = true then refreshUserProfileChrome()
    if context.dismissSwitcher = true
        retireUserProfileSwitcher()
        return
    end if
    if m.profileSwitcher <> invalid
        if resumeUserProfileSwitcherFailure(message) then return
    end if
    showNotice(message)
end sub

' Rollback is a fresh admission, not permission to revive a captured PIN/role.
' Re-read storage, including the current address and only the outgoing key.
function profileSwitchOutgoingProtectionCurrent(context as object) as boolean
    if not userProfileSameSession(context.outgoing, m.activeUserScope) then return false
    if type(context.store) <> "roAssociativeArray" then return false
    if GetInterface(context.connectionRoot, "ifString") = invalid then return false
    if context.connectionRoot <> m.registry.read("connectionsV1") or context.connectionRootPresent <> m.registry.exists("connectionsV1") then return false
    connections = loadConnectionStore(m.registry)
    if connections.readOnly = true or connections.selected <> context.connection.id then return false
    entry = connectionStoreEntry(connections, context.connection.id)
    if entry = invalid then return false
    if FormatJson(entry) <> FormatJson(normalizeConnectionEntry(context.connection)) then return false
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true or FormatJson(store) <> FormatJson(context.store) then return false
    if store.active <> context.outgoing.profileId then return false
    if context.outgoing.preferenceIdentity <> connectionPreferenceIdentity(entry, context.outgoing.accountId) then return false
    if m.accountIdentity <> context.outgoing.preferenceIdentity or m.serverAccountId <> context.outgoing.accountId or textValue(m.apiKey) = "" then return false
    if m.global.activeusersession <> context.nonce and m.global.activeusersession <> context.outgoing.sessionId then return false
    holder = invalid
    for each profile in store.profiles
        if profile.id = store.active then holder = profile
    end for
    if holder = invalid then return false
    ' The working roster may later advance after a target-owned import. It is
    ' never a replacement for the outgoing admission captured before staging.
    if textValue(context.outgoingProtection) = "" or FormatJson(holder) <> context.outgoingProtection then return false
    if holder.addressHeld or textValue(holder.userId) <> context.outgoing.accountId then return false
    keyName = userProfileKeyName(entry.id, holder.id)
    if holder.isDefault then keyName = connectionRegistryKey(entry.id)
    key = ""
    if entry.remember
        key = m.registry.read(keyName)
    else if type(m.profileSessionKeys) = "roAssociativeArray"
        memoryScope = preferenceScope(entry.url + "|" + entry.id + "|" + holder.id)
        if m.profileSessionKeys.doesExist(memoryScope) then key = textValue(m.profileSessionKeys[memoryScope])
    end if
    if key = "" or key <> m.apiKey then return false
    return requestGateAccessAllowed(entry.url, key)
end function

sub retireUserProfileSwitch()
    closeOutgoingUserProfileSync()
    context = m.profileSwitchContext
    pinContext = m.profilePinContext
    if context <> invalid and pinContext <> invalid and m.profilePinDialog <> invalid
        switching = pinContext.continuation = "switch" or pinContext.continuation = "switch-roster"
        if switching and pinContext.resume = context.nonce and pinContext.slot = context.connection.id
            pad = m.profilePinDialog
            pad.unobserveField("buttonSelected")
            pad.unobserveField("wasClosed")
            pad.textEditBox.text = ""
            pad.close = true
            if m.top <> invalid
                if m.top.dialog <> invalid
                    if m.top.dialog.isSameNode(pad) then m.top.dialog = invalid
                end if
            end if
            if type(pad) = "roSGNode"
                if pad.isSubtype("DirectionsPinPad") then m.top.removeChild(pad)
            end if
            m.profilePinDialog = invalid
            m.profilePinContext = invalid
            if m.profileGateClock <> invalid then m.profileGateClock.control = "stop"
        end if
    end if
    closeUserProfileSwitchTask()
    m.profileSwitchContext = invalid
    if m.global <> invalid then m.global.profileswitchpending = false
end sub

sub closeUserProfileSwitchTask()
    if m.profileSwitchTask = invalid then return
    m.profileSwitchTask.unobserveField("result")
    m.profileSwitchTask.unobserveField("state")
    cancelNetworkTask(m.profileSwitchTask)
    m.profileSwitchTask = invalid
end sub
