' Private opt-in scheduler. Timing is not transport authority: the own Task and
' receipt stores independently recheck exact roots, actor, credential and broker.
sub activateProfileSyncScheduling()
    if m.profileSyncSchedulingReady <> true or m.profileSyncWriterReady <> true then return
    if m.profileSyncEnabled <> true or m.profileRosterEnabled = false then return
    if m.profileSyncClock = invalid
        m.profileSyncClock = m.top.createChild("Timer")
        m.profileSyncClock.duration = 1
        m.profileSyncClock.repeat = true
        m.profileSyncClock.observeField("fire", "onProfileSyncScheduleTick")
    end if
    m.profileSyncClock.control = "start"
    onProfileSyncScheduleTick()
end sub

function profileSyncSchedulingNow() as integer
    if m.profileSyncScheduleNow <> invalid then return m.profileSyncScheduleNow()
    return CreateObject("roDateTime").asSeconds()
end function

function scheduledProfileSyncAllowed() as boolean
    if m.profileSyncSchedulingReady <> true or m.profileSyncWriterReady <> true or m.profileSyncEnabled <> true then return false
    if m.userProfileRecoveryRequired = true or m.profileRosterEnabled = false or m.busy = true then return false
    if m.profileSyncLinkKnown = true and m.profileSyncLinkUp <> true then return false
    if m.profileSwitchContext <> invalid or m.profileOwnSignInContext <> invalid or m.profileSyncWriteTask <> invalid then return false
    if m.profileSyncSettingsContext <> invalid then return false
    if m.phoneProfileOnboarding <> invalid then return false
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid or m.profileManagementDialog <> invalid then return false
    if userProfileGateClosed() or m.activeUserScope = invalid or textValue(m.apiKey) = "" then return false
    if textValue(m.global.activeusersession) <> textValue(m.activeUserScope.sessionId) then return false
    connections = loadConnectionStore(m.registry)
    if connections.readOnly = true or connections.selected <> m.selectedConnectionId then return false
    entry = connectionStoreEntry(connections, m.selectedConnectionId)
    if entry = invalid then return false
    if entry.provider <> "dispatcharr" or entry.id <> m.activeUserScope.playlistId then return false
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true or store.active <> m.activeUserScope.profileId then return false
    own = invalid
    for each profile in store.profiles
        if profile.addressHeld then return false
        if profile.id = store.active then own = profile
    end for
    if own = invalid then return false
    if not userProfileFullAccess(own.role) or textValue(m.profileAuthorizationSignature) = "" then return false
    expected = userProfileSessionScope(entry, own.id, own.userId, m.activeUserScope.authorizationGeneration, m.activeUserScope.sessionId)
    if not userProfileSameSession(expected, m.activeUserScope) then return false
    return requestGateAccessAllowed(entry.url, m.apiKey)
end function

sub onProfileSyncNetworkLink(event as object)
    node = event.getRoSGNode()
    if node = invalid then return
    if not m.top.isSameNode(node) then return
    data = event.getData()
    if type(data) <> "roAssociativeArray" then return
    if not userProfileBoolean(data.linked) or not userProfileBoolean(data.returned) then return
    if not userProfileInteger(data.sequence) then return
    if data.sequence <= 0 then return
    if userProfileInteger(m.profileSyncNetworkSequence)
        if data.sequence <= m.profileSyncNetworkSequence then return
    end if
    m.profileSyncNetworkSequence = data.sequence
    m.profileSyncLinkKnown = true
    m.profileSyncLinkUp = data.linked
    if not data.linked
        if m.profileScheduledSyncContext <> invalid and m.profileSyncSchedule <> invalid
            m.profileSyncSchedule = dispatcharrSyncScheduleComplete(m.profileSyncSchedule, m.profileScheduledSyncContext.ticket, false, profileSyncSchedulingNow())
        end if
        closeScheduledProfileSync()
        return
    end if
    if data.returned then requestScheduledProfileSync("network-return")
end sub

sub onProfileSyncScheduleTick()
    scope = m.activeUserScope
    if not scheduledProfileSyncAllowed()
        if m.profileScheduledSyncTask <> invalid
            context = m.profileScheduledSyncContext
            if context <> invalid and m.profileSyncSchedule <> invalid
                m.profileSyncSchedule = dispatcharrSyncScheduleComplete(m.profileSyncSchedule, context.ticket, false, profileSyncSchedulingNow())
            end if
            closeScheduledProfileSync()
        end if
        return
    end if
    now = profileSyncSchedulingNow()
    if m.profileSyncSchedule = invalid
        m.profileSyncSchedule = dispatcharrSyncScheduleBind(invalid, scope, now)
    else if not userProfileSameSession(m.profileSyncSchedule.scope, scope)
        closeScheduledProfileSync()
        m.profileSyncSchedule = dispatcharrSyncScheduleBind(m.profileSyncSchedule, scope, now)
    end if
    if m.profileSyncSchedule = invalid then return
    store = loadUserProfileStore(m.registry, scope.playlistId)
    m.profileSyncSchedule = dispatcharrSyncScheduleDirty(m.profileSyncSchedule, scope, dispatcharrSyncRosterIntentDigest(store), store.pendingRoster = true, now)
    ' Absence of held siblings admits transport, not writes. Keep the durable
    ' fence through failure/backoff until the exact own pull commits.
    nextWork = dispatcharrSyncScheduleTake(m.profileSyncSchedule, scope, now, true, store.rosterPullRequired = true)
    m.profileSyncSchedule = nextWork.state
    if not nextWork.run then return
    if not startScheduledProfileSync(store, nextWork.ticket, nextWork.push)
        m.profileSyncSchedule = dispatcharrSyncScheduleComplete(m.profileSyncSchedule, nextWork.ticket, false, now)
    end if
end sub

sub requestScheduledProfileSync(event as string)
    if not scheduledProfileSyncAllowed() then return
    now = profileSyncSchedulingNow()
    if m.profileSyncSchedule = invalid
        m.profileSyncSchedule = dispatcharrSyncScheduleBind(invalid, m.activeUserScope, now)
    else if not userProfileSameSession(m.profileSyncSchedule.scope, m.activeUserScope)
        closeScheduledProfileSync()
        m.profileSyncSchedule = dispatcharrSyncScheduleBind(m.profileSyncSchedule, m.activeUserScope, now)
    end if
    if m.profileSyncSchedule = invalid then return
    m.profileSyncSchedule = dispatcharrSyncScheduleRequest(m.profileSyncSchedule, m.activeUserScope, event, now)
end sub

function startScheduledProfileSync(store as object, ticket as object, push as boolean) as boolean
    if m.profileScheduledSyncTask <> invalid or not scheduledProfileSyncAllowed() then return false
    connections = loadConnectionStore(m.registry)
    entry = connectionStoreEntry(connections, m.selectedConnectionId)
    ack = loadDispatcharrSyncRosterAck(m.registry, entry)
    if not ack.ok then return false
    candidate = ""
    if not m.registry.exists("dispatcharrSyncDeviceV1") then candidate = CreateObject("roDeviceInfo").getRandomUUID()
    device = ensureDispatcharrSyncDeviceIdentity(m.registry, candidate)
    if not device.ok then return false
    version = textValue(m.profileSyncAppVersion)
    if version = ""
        info = CreateObject("roAppInfo")
        version = info.getValue("major_version") + "." + info.getValue("minor_version") + "." + info.getValue("build_version")
    end if
    task = invalid
    if m.profileScheduledSyncTaskFactory <> invalid then task = m.profileScheduledSyncTaskFactory()
    if task = invalid then task = CreateObject("roSGNode", "DispatcharrSyncWriteTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = entry.url
    task.apiKey = m.apiKey
    task.authMode = entry.authMode
    task.userScope = m.activeUserScope
    task.connectionRoot = m.registry.read("connectionsV1")
    task.storeRoot = m.registry.read(userProfileStoreKey(entry.id))
    task.profilesEnabled = true
    task.pullOnly = not push
    task.creationBlocked = m.profileSyncSchedule.creationBlocked = true
    task.expectedAuthorizationSignature = m.profileAuthorizationSignature
    task.deviceId = device.id
    task.appVersion = version
    task.acknowledgedStamp = ack.stamp
    m.profileScheduledSyncContext = {connection: entry, store: store, scope: m.activeUserScope, ticket: ticket}
    m.profileScheduledSyncTask = task
    task.observeField("result", "onScheduledProfileSyncResult")
    task.observeField("state", "onScheduledProfileSyncState")
    task.control = "RUN"
    return true
end function

function currentScheduledProfileSyncEvent(event as object) as boolean
    if m.profileScheduledSyncTask = invalid or m.profileScheduledSyncContext = invalid then return false
    if not isCurrentTaskEvent(event, m.profileScheduledSyncTask) then return false
    return userProfileSameSession(m.profileScheduledSyncContext.scope, m.activeUserScope) and scheduledProfileSyncAllowed()
end function

sub onScheduledProfileSyncResult(event as object)
    if not currentScheduledProfileSyncEvent(event) then return
    finishScheduledProfileSync(event.getData())
end sub

sub onScheduledProfileSyncState(event as object)
    if not currentScheduledProfileSyncEvent(event) then return
    state = lcase(textValue(event.getData()))
    if state <> "done" and state <> "stop" then return
    if type(m.profileScheduledSyncTask.result) = "roAssociativeArray" then return
    finishScheduledProfileSync({ok: false, state: "unavailable"})
end sub

sub finishScheduledProfileSync(result as dynamic)
    context = m.profileScheduledSyncContext
    closeScheduledProfileSync()
    if type(result) <> "roAssociativeArray" then result = {ok: false, state: "unavailable"}
    memory = {}
    if not context.connection.remember
        for each profile in context.store.profiles
            if profile.id = context.store.active
                name = userProfileKeyName(context.connection.id, profile.id)
                if profile.isDefault then name = connectionRegistryKey(context.connection.id)
                memory[name] = m.apiKey
            end if
        end for
    end if
    saved = {ok: false}
    if result.ok = true
        saved = commitDispatcharrSyncRosterAck(m.registry, context.connection, context.store, result, m.activeUserScope, m.apiKey, memory)
    else if result.state = "local-commit"
        saved = commitDispatcharrSyncRosterRead(m.registry, context.connection, context.store, result, m.activeUserScope, m.apiKey, memory, m.profileAuthorizationSignature, true, CreateObject("roDateTime").asSeconds())
        if saved.readCommitted <> true then saved.ok = false
    end if
    outcome = textValue(result.state)
    creationBlocked = false
    if result.creationBlocked = true
        creationBlocked = result.state = "storage-full" and result.status = 409 and currentScheduledProfileSyncFeedbackStore(context, result, memory) <> invalid
        if not creationBlocked then outcome = "stale-context"
    else if result.state = "too-large" and result.submitted = true
        ' A normal edit can land after the Task's check, before this callback.
        current = currentScheduledProfileSyncFeedbackStore(context, result, memory)
        outcome = "stale-context"
        if current <> invalid and result.status = 413 and result.rosterIntent <> "" and result.rosterIntent = context.ticket.intent
            if dispatcharrSyncRosterIntentDigest(current) = result.rosterIntent then outcome = "too-large"
        end if
    end if
    m.profileSyncSchedule = dispatcharrSyncScheduleComplete(m.profileSyncSchedule, context.ticket, saved.ok = true, profileSyncSchedulingNow(), outcome, creationBlocked)
    if saved.needsDefaultSwitch = true
        if beginOwnSyncDefaultRetirement(context, result, memory) then return
        coverScheduledProfileSync()
        return
    end if
    if result.state = "authority" or result.state = "identity" or saved.recoveryRequired = true
        coverScheduledProfileSync()
        return
    end if
    if not saved.ok then return
    m.profileSyncSchedule = dispatcharrSyncScheduleDirty(m.profileSyncSchedule, m.activeUserScope, dispatcharrSyncRosterIntentDigest(saved.store), saved.store.pendingRoster = true, profileSyncSchedulingNow(), false)
    m.userProfileStore = saved.store
    if type(saved.preferenceStore) = "roAssociativeArray" then m.preferenceStore = saved.preferenceStore
    if type(saved.suggestions) = "roArray"
        m.profileRosterSuggestions = saved.suggestions
        m.profileRosterSuggestionScope = m.activeUserScope
    end if
    if type(saved.removed) = "roArray" and type(m.profileSessionKeys) = "roAssociativeArray"
        for each removed in saved.removed
            m.profileSessionKeys.delete(preferenceScope(context.connection.url + "|" + context.connection.id + "|" + removed.id))
        end for
    end if
    for each profile in saved.store.profiles
        if profile.id = saved.store.active and not userProfileFullAccess(profile.role) then coverScheduledProfileSync()
    end for
    if m.profileSwitcher <> invalid then refreshUserProfileSwitcherAfterSync()
end sub

' Only non-authorizing capacity feedback can outlive a stale roster root. The
' current live actor and storage credential must still be the Task's own.
function currentScheduledProfileSyncFeedbackStore(context as object, result as object, memory as object) as dynamic
    if result.ok <> false or result.submitted <> true or result.phase <> "put" then return invalid
    if not userProfileSameSession(result.scope, m.activeUserScope) then return invalid
    if result.connectionRoot <> m.registry.read("connectionsV1") then return invalid
    if m.apiKey = "" or not requestGateDigestValid(textValue(result.credentialHash)) then return invalid
    if result.credentialHash <> requestGateCredentialHash(m.apiKey) then return invalid
    current = loadUserProfileStore(m.registry, context.connection.id)
    credential = userProfileCredential(m.registry, context.connection, current, memory)
    if not credential.ok or credential.key <> m.apiKey or credential.profileId <> m.activeUserScope.profileId then return invalid
    if context.connection.remember and m.registry.read(credential.keyName) <> m.apiKey then return invalid
    for each profile in current.profiles
        if profile.id = credential.profileId and dispatcharrSyncUserKey(profile.username) = result.canonicalKey then return current
    end for
    return invalid
end function

sub coverScheduledProfileSync()
    if m.profileSwitcher <> invalid then retireUserProfileSwitcher()
    coverProfileRosterAuthorityChange()
    m.apiKey = ""
end sub

sub closeScheduledProfileSync()
    if m.profileScheduledSyncTask <> invalid
        m.profileScheduledSyncTask.unobserveField("result")
        m.profileScheduledSyncTask.unobserveField("state")
        m.profileScheduledSyncTask.apiKey = ""
        cancelNetworkTask(m.profileScheduledSyncTask)
    end if
    m.profileScheduledSyncTask = invalid
    m.profileScheduledSyncContext = invalid
end sub
