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
    m.task.authMode = textValue(result.authModeUsed)
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
    m.profileRosterSuggestionScope = invalid
    if not profileRosterReadAuthorityCurrent(context, read)
        coverProfileRosterAuthorityChange()
        return
    end if
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
            m.profileRosterSuggestionScope = m.activeUserScope
            m.preferenceStore = loadPreferenceStore(m.registry, true)
        end if
    end if
    m.profileRosterGrant = {slot: context.connection.id, profile: m.userProfileStore.active, key: context.verified.apiKey, scope: context.scope, authorizationSignature: dispatcharrAuthorizationSignature(context.verified.verifiedUser)}
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

function profileRosterReadAuthorityCurrent(context as object, read as object) as boolean
    if type(context.verified) <> "roAssociativeArray" then return false
    expected = context.verified.verifiedUser
    if not dispatcharrAuthorityComparable(expected) then return false
    ' A genuinely unavailable read retains known local protection. Successful
    ' discovery, including missing/legacy, must bind its latest own authority.
    if read.ok <> true then return true
    actual = read.verifiedUser
    if not dispatcharrAuthorityComparable(actual) then return false
    if textValue(context.connection.url) = "" or read.verifiedBaseUrl <> context.connection.url then return false
    if context.scope.playlistId <> context.connection.id then return false
    id = textValue(expected.id)
    if id <> textValue(actual.id) or id <> textValue(read.accountId) or id <> textValue(context.scope.accountId) or id <> textValue(context.verified.accountId) then return false
    name = lcase(textValue(expected.username))
    if name <> lcase(textValue(actual.username)) or name <> lcase(textValue(read.accountUsername)) or name <> lcase(textValue(context.verified.accountUsername)) then return false
    return dispatcharrAuthorizationSignature(actual) = dispatcharrAuthorizationSignature(expected)
end function

function profileRosterConnectionCallbackCurrent(task as dynamic) as boolean
    if task = invalid or m.profileRosterContext <> invalid then return false
    return taskUserSessionCurrent(task)
end function

function acceptProfileRosterLineupAuthority(result as dynamic, task as dynamic) as boolean
    if task <> invalid
        if not profileRosterConnectionCallbackCurrent(task) then return false
    end if
    expected = ""
    if type(task) = "roAssociativeArray"
        expected = textValue(task.expectedAuthorizationSignature)
    else if type(task) = "roSGNode"
        if task.hasField("expectedAuthorizationSignature") then expected = textValue(task.expectedAuthorizationSignature)
    end if
    if expected <> ""
        if m.activeUserScope = invalid then return false
        if textValue(task.aeriosession) <> textValue(m.activeUserScope.sessionId) then return false
    end if
    if type(result) <> "roAssociativeArray" then return true
    if result.protectionAuthorityChanged = true
        if expected = "" then return false
        coverProfileRosterAuthorityChange()
        return false
    end if
    if expected = "" or result.ok <> true or result.phase = "verified" then return true
    matches = dispatcharrAuthorityComparable(result.verifiedUser)
    if matches then matches = dispatcharrAuthorizationSignature(result.verifiedUser) = expected
    if matches then return true
    coverProfileRosterAuthorityChange()
    return false
end function

sub coverProfileRosterAuthorityChange()
    preserveSubmittedRecording()
    cancelRecordFlow()
    if m.playingChannel <> invalid then stopPlayback()
    if m.task <> invalid
        m.task.unobserveField("result")
        m.task.unobserveField("progress")
        m.task.unobserveField("state")
        cancelNetworkTask(m.task)
        m.task = invalid
    end if
    if m.connectionClock <> invalid then m.connectionClock.control = "stop"
    m.profileRosterContext = invalid
    m.profileRosterGrant = invalid
    m.activeUserScope = invalid
    m.global.activeusersession = ""
    m.global.profilegateclosed = true
    m.global.profileswitchpending = false
    m.profileGateCover.visible = true
    m.guide.active = false
    m.busy = false
    m.password = ""
    m.userProfileRecoveryRequired = true
    m.top.findNode("profileGateMessage").text = "Profile access changed while verifying protection. Back exits AerioTV; reopen to verify again."
    requestGateFenceRenderers(m.top)
end sub

function consumeProfileRosterGrant(connection as object) as boolean
    grant = m.profileRosterGrant
    m.profileRosterGrant = invalid
    if type(grant) <> "roAssociativeArray" then return false
    if textValue(grant.authorizationSignature) = "" then return false
    if type(m.userProfileStore) <> "roAssociativeArray" then return false
    if not userProfileSameSession(grant.scope, m.activeUserScope) then return false
    return grant.slot = connection.id and grant.profile = m.userProfileStore.active and grant.key = m.apiKey
end function
