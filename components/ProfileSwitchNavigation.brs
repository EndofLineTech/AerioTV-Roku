' Internal staged own-key switch controller. No picker/Settings entry enables
' this until outgoing sync, Child access and all handler fences are integrated.
function beginUserProfileSwitch(targetId as string, unavailableChild = false as boolean) as boolean
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
    if not unavailableChild
        if store.active <> m.activeUserScope.profileId then return false
    end if
    for each profile in store.profiles
        if profile.id = store.active
            childSource = profile.role = "child"
            if not unavailableChild
                if profile.userId.toStr() <> m.activeUserScope.accountId then return false
            end if
        end if
    end for
    if unavailableChild and not childSource then return false
    if targetId = store.active then return true
    ' There is no writer yet: never discard an outgoing pending roster edit.
    if store.pendingRoster = true and not unavailableChild then return false
    target = invalid
    for each profile in store.profiles
        if profile.id = targetId then target = profile
    end for
    if target = invalid or target.addressHeld then return false
    ' Child sessions remain fenced until their handler/access controller lands.
    if target.role = "child" then return false
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
    m.profileSwitchContext = {nonce: nonce, unavailableChild: unavailableChild, connection: connection, store: store, target: target, key: credential.key, outgoing: m.activeUserScope, unlock: m.profileUnlockGrant, management: m.profileManagementGrant, managementNonce: textValue(m.profileManagementNonce)}
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
    if context.connection.id <> m.selectedConnectionId then return
    connections = loadConnectionStore(m.registry)
    currentEntry = connectionStoreEntry(connections, context.connection.id)
    if connections.readOnly = true or connections.selected <> context.connection.id or currentEntry = invalid then return
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
    if context.unavailableChild = true
        if m.activeUserScope <> invalid or m.apiKey <> "" then return
    else
        if not userProfileSameSession(context.outgoing, m.activeUserScope) then return
        if not persistCurrentUserProfilePreferences()
            rollbackUserProfileSwitch("Could not save the outgoing profile. Switch cancelled.")
            return
        end if
    end if
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
    task = CreateObject("roSGNode", "DispatcharrTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = context.connection.url
    task.apiKey = context.key
    task.authMode = context.connection.authMode
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
    if event.getData() <> "done" and event.getData() <> "stop" then return
    if type(m.profileSwitchTask.result) = "roAssociativeArray" then return
    rollbackUserProfileSwitch("Could not load this profile. The previous profile was retained.")
end sub

sub onUserProfileSwitchResult(event as object)
    if not isCurrentTaskEvent(event, m.profileSwitchTask) then return
    context = m.profileSwitchContext
    if context = invalid or context.connection.id <> m.selectedConnectionId then return
    verified = event.getData()
    if type(verified) <> "roAssociativeArray" then rollbackUserProfileSwitch("Could not verify this profile.") : return
    if verified.ok <> true
        message = "Could not switch profiles. The previous profile was retained."
        if verified.relogin = true then message = "The API key for " + context.target.username + " was rejected."
        rollbackUserProfileSwitch(message)
        return
    end if
    if context.unavailableChild = true
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
    resetConnectionRuntime()
    m.userProfileStore = saved.store
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
end sub

sub rollbackUserProfileSwitch(message as string)
    context = m.profileSwitchContext
    if context = invalid then return
    closeUserProfileSwitchTask()
    m.profileSwitchContext = invalid
    m.global.profileswitchpending = false
    if context.connection.id <> m.selectedConnectionId then return
    if m.userProfileRecoveryRequired = true
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
    showNotice(message)
end sub

sub retireUserProfileSwitch()
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
