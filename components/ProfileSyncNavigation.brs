' Outgoing roster flush keeps the REAL adopted source session until its own
' write/ack settles. The incoming nonce and credentials are not transport scope.
function beginOutgoingUserProfileSync(context as object) as boolean
    if m.userProfileRecoveryRequired = true then return false
    if m.profileSyncWriterReady <> true or context.unavailableChild = true then return false
    if m.profileSyncWriteTask <> invalid or m.profileSyncContext <> invalid then return false
    if context.connection.id <> m.selectedConnectionId or not userProfileSwitchActorCurrent(context) then return false
    if m.activeUserScope = invalid or textValue(m.apiKey) = "" then return false
    if textValue(m.global.activeusersession) <> textValue(m.activeUserScope.sessionId) then return false
    connections = loadConnectionStore(m.registry)
    entry = connectionStoreEntry(connections, context.connection.id)
    if connections.readOnly = true or entry = invalid then return false
    if connections.selected <> entry.id or FormatJson(entry) <> FormatJson(normalizeConnectionEntry(context.connection)) then return false
    current = loadUserProfileStore(m.registry, entry.id)
    if current.readOnly = true or current.pendingRoster <> true then return false
    if FormatJson(current) <> FormatJson(normalizeUserProfileStore(context.store, entry.id)) then return false
    incoming = invalid
    for each profile in current.profiles
        if profile.id = context.target.id then incoming = profile
    end for
    if incoming = invalid then return false
    if incoming.pinType <> "none"
        if not userProfilePinGrantMatches(context.pin, entry.id, incoming) then return false
    else if userProfileGateClosed()
        return false
    end if
    if textValue(m.profileAuthorizationSignature) = "" then return false
    if not requestGateAccessAllowed(entry.url, m.apiKey) then return false
    ack = loadDispatcharrSyncRosterAck(m.registry, entry)
    if not ack.ok then return false
    candidate = ""
    if not m.registry.exists("dispatcharrSyncDeviceV1") then candidate = CreateObject("roDeviceInfo").getRandomUUID()
    device = ensureDispatcharrSyncDeviceIdentity(m.registry, candidate)
    if not device.ok
        if device.recoveryRequired = true then m.userProfileRecoveryRequired = true
        return false
    end if
    version = textValue(m.profileSyncAppVersion)
    if version = ""
        info = CreateObject("roAppInfo")
        version = info.getValue("major_version") + "." + info.getValue("minor_version") + "." + info.getValue("build_version")
        m.profileSyncAppVersion = version
    end if
    task = invalid
    if m.profileSyncWriteTaskFactory <> invalid then task = m.profileSyncWriteTaskFactory()
    if task = invalid then task = CreateObject("roSGNode", "DispatcharrSyncWriteTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = entry.url
    task.apiKey = m.apiKey
    task.authMode = entry.authMode
    task.userScope = m.activeUserScope
    task.connectionRoot = m.registry.read("connectionsV1")
    task.storeRoot = m.registry.read(userProfileStoreKey(entry.id))
    task.profilesEnabled = m.profileRosterEnabled <> false
    task.expectedAuthorizationSignature = m.profileAuthorizationSignature
    task.deviceId = device.id
    task.appVersion = version
    task.acknowledgedStamp = ack.stamp
    flushNonce = ""
    if m.profileSyncNonceFactory <> invalid
        flushNonce = m.profileSyncNonceFactory()
    else
        flushNonce = CreateObject("roDeviceInfo").getRandomUUID()
    end if
    if userProfileLocalId(flushNonce) = "" then return false
    task.flushNonce = flushNonce
    m.global.profilesyncflush = flushNonce
    m.global.profilegateclosed = true
    m.profileSyncContext = {switchNonce: context.nonce, flushNonce: flushNonce, scope: m.activeUserScope, connection: entry}
    m.profileSyncWriteTask = task
    context.phase = "flush"
    m.busy = true
    m.guide.active = false
    m.profileGateCover.visible = true
    m.top.findNode("profileGateMessage").text = "Saving outgoing profile changes..."
    task.observeField("result", "onOutgoingUserProfileSyncResult")
    task.observeField("state", "onOutgoingUserProfileSyncState")
    task.control = "RUN"
    return true
end function

sub onOutgoingUserProfileSyncResult(event as object)
    if not currentOutgoingUserProfileSyncEvent(event) then return
    flush = m.profileSyncContext
    context = m.profileSwitchContext
    if flush = invalid or context = invalid then return
    if context.nonce <> flush.switchNonce or context.connection.id <> m.selectedConnectionId then return
    if not userProfileSwitchActorCurrent(context) or not userProfileSameSession(flush.scope, m.activeUserScope) then return
    result = event.getData()
    closeOutgoingUserProfileSync()
    if type(result) <> "roAssociativeArray"
        rollbackUserProfileSwitch("Could not save outgoing changes. They remain pending.")
        return
    end if
    if result.ok <> true
        changedAuthority = result.state = "authority" or result.state = "identity"
        if type(result.localPlan) = "roAssociativeArray" or changedAuthority
            m.userProfileRecoveryRequired = true
            if m.playingChannel <> invalid then stopPlayback()
            requestGateFenceRenderers(m.top)
        end if
        rollbackUserProfileSwitch("Could not safely settle outgoing changes. Saved edits were retained.")
        if m.userProfileRecoveryRequired = true then m.apiKey = ""
        return
    end if
    memory = {}
    if not context.connection.remember
        for each profile in context.store.profiles
            if profile.id = context.store.active
                keyName = userProfileKeyName(context.connection.id, profile.id)
                if profile.isDefault then keyName = connectionRegistryKey(context.connection.id)
                memory[keyName] = m.apiKey
            end if
        end for
    end if
    saved = commitDispatcharrSyncRosterAck(m.registry, context.connection, context.store, result, m.activeUserScope, m.apiKey, memory)
    if not saved.ok
        if saved.recoveryRequired = true then m.userProfileRecoveryRequired = true
        rollbackUserProfileSwitch("Could not acknowledge outgoing changes. Saved edits were retained.")
        return
    end if
    m.userProfileStore = saved.store
    context.store = saved.store
    for each profile in saved.store.profiles
        if profile.id = context.target.id then context.target = profile
    end for
    context.syncFlushed = true
    startUserProfileSwitchTask(context.nonce)
end sub

sub onOutgoingUserProfileSyncState(event as object)
    if not currentOutgoingUserProfileSyncEvent(event) then return
    state = lcase(textValue(event.getData()))
    if state <> "done" and state <> "stop" then return
    if type(m.profileSyncWriteTask.result) = "roAssociativeArray" then return
    context = m.profileSwitchContext
    if context = invalid or not userProfileSwitchActorCurrent(context) then return
    closeOutgoingUserProfileSync()
    rollbackUserProfileSwitch("Could not finish saving outgoing changes. They remain pending.")
end sub

sub closeOutgoingUserProfileSync()
    context = m.profileSyncContext
    if context <> invalid and m.global <> invalid
        if textValue(m.global.profilesyncflush) = textValue(context.flushNonce) then m.global.profilesyncflush = ""
    end if
    if m.profileSyncWriteTask <> invalid
        m.profileSyncWriteTask.unobserveField("result")
        m.profileSyncWriteTask.unobserveField("state")
        m.profileSyncWriteTask.apiKey = ""
        cancelNetworkTask(m.profileSyncWriteTask)
    end if
    m.profileSyncWriteTask = invalid
    m.profileSyncContext = invalid
end sub

function currentOutgoingUserProfileSyncEvent(event as object) as boolean
    task = m.profileSyncWriteTask
    context = m.profileSyncContext
    if task = invalid or context = invalid then return false
    node = event.getRoSGNode()
    if node = invalid then return false
    if not task.isSameNode(node) then return false
    if textValue(task.flushNonce) = "" or task.flushNonce <> context.flushNonce then return false
    if textValue(m.global.profilesyncflush) <> context.flushNonce then return false
    if textValue(task.aeriosession) <> textValue(m.global.activeusersession) then return false
    return userProfileSameSession(context.scope, m.activeUserScope)
end function
