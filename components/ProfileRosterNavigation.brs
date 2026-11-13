' Early own-user read: authentication precedes roster import, which precedes
' channel/cache/settings activation. This controller never writes App Data.
sub beginAuthenticatedRosterRead(result as object)
    m.profileRosterGrant = invalid
    if not ensureConnectedUserProfile(result)
        m.apiKey = ""
        drawSetup()
        return
    end if
    connection = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    nonce = CreateObject("roDeviceInfo").getRandomUUID()
    scope = userProfileSessionScope(connection, m.userProfileStore.active, result.accountId, "authentication:" + nonce, nonce)
    if scope = invalid
        m.status = "Could not establish profile identity. Saved profiles were retained."
        drawSetup()
        return
    end if
    m.apiKey = result.apiKey
    m.authMode = "key"
    m.username = ""
    applyVerifiedHeaderMode(textValue(result.authModeUsed))
    m.activeUserScope = scope
    m.global.activeusersession = scope.sessionId
    m.profileRosterContext = {scope: scope, connection: connection, verified: result}
    m.busy = true
    m.connectionStage = "Reading profile protection"
    m.task = CreateObject("roSGNode", "DispatcharrSyncReadTask")
    tagTaskForCurrentUser(m.task)
    m.task.baseUrl = connection.url
    m.task.apiKey = result.apiKey
    m.task.accountId = result.accountId
    m.task.username = result.accountUsername
    m.task.observeField("result", "onProfileRosterRead")
    m.task.observeField("state", "onProfileRosterState")
    m.connectionClock.control = "stop"
    m.task.control = "RUN"
end sub

sub onProfileRosterState(event as object)
    if not isCurrentTaskEvent(event, m.task) then return
    if event.getData() <> "done" and event.getData() <> "stop" then return
    if type(m.task.result) = "roAssociativeArray" then return
    finishAuthenticatedRosterRead({ok: false, state: "unavailable"})
end sub

sub onProfileRosterRead(event as object)
    if not isCurrentTaskEvent(event, m.task) then return
    finishAuthenticatedRosterRead(event.getData())
end sub

sub finishAuthenticatedRosterRead(read as object)
    context = m.profileRosterContext
    if context = invalid then return
    if not userProfileSameSession(context.scope, m.activeUserScope) then return
    if context.connection.id <> m.selectedConnectionId then return
    m.task.unobserveField("result")
    m.task.unobserveField("state")
    m.task = invalid
    m.profileRosterContext = invalid
    m.busy = false
    m.profileRosterSuggestions = []
    if read.ok = true and read.state = "ready" and read.profilesState = "ready"
        ' Decode directly from double-preserving wire JSON, never copyJson.
        decoded = dispatcharrSyncRosterDecode(read.data["categories"]["profiles"]["data"])
        saved = commitDispatcharrRosterPull(m.registry, context.connection, m.userProfileStore, decoded, m.profileRosterEnabled <> false, CreateObject("roDateTime").asSeconds(), context.scope, m.activeUserScope)
        if not saved.ok
            m.userProfileRecoveryRequired = saved.recoveryRequired
            m.status = "Could not safely apply profile protection. Saved profiles were retained."
            drawSetup()
            return
        end if
        if saved.applied
            m.userProfileStore = saved.store
            m.profileRosterSuggestions = saved.suggestions
            m.preferenceStore = loadPreferenceStore(m.registry)
        end if
    end if
    m.profileRosterGrant = {slot: context.connection.id, profile: m.userProfileStore.active, key: context.verified.apiKey, scope: context.scope}
    gate = selectedUserProfileGate()
    if not gate.allowed
        for each profile in m.userProfileStore.profiles
            if profile.id = m.userProfileStore.active and gate.reason = "pin"
                if beginProfilePinGate(profile, "connect") then return
            end if
        end for
        m.profileGateCover.visible = true
        m.global.profilegateclosed = true
        m.top.findNode("profileGateMessage").text = userProfileGateMessage(gate) + " Back exits AerioTV."
        return
    end if
    connectServer(true)
end sub

function consumeProfileRosterGrant(connection as object) as boolean
    grant = m.profileRosterGrant
    m.profileRosterGrant = invalid
    if type(grant) <> "roAssociativeArray" then return false
    if type(m.userProfileStore) <> "roAssociativeArray" then return false
    if not userProfileSameSession(grant.scope, m.activeUserScope) then return false
    return grant.slot = connection.id and grant.profile = m.userProfileStore.active and grant.key = m.apiKey
end function
