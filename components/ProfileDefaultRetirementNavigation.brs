' Explicit system transition after an actual outgoing tombstone. No fabricated
' outgoing/default scope or profile-unlock grant is used at any phase.
sub beginUserProfileDefaultRetirement(context as object, proof as object, decoded as object, apply as boolean)
    memory = userProfileSwitchRosterMemory(context)
    selected = commitDispatcharrDefaultRetirementSelection(m.registry, context, proof, decoded, apply, CreateObject("roDateTime").asSeconds(), m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), memory)
    if not selected.ok
        m.userProfileRecoveryRequired = true
        rollbackUserProfileSwitch("Could not safely select the default profile. Saved data was retained.")
        return
    end if
    finishUserProfileDefaultRetirement(context, selected, proof, decoded, apply, memory)
end sub

' A writer receipt belongs to the ACTUAL outgoing holder, not the chosen target.
' Keep its admission distinct; no synthetic target proof or scope is constructed.
function beginOwnSyncDefaultRetirement(chosen as object, receipt as object, memory as object) as boolean
    if m.profileDefaultRetirementReady <> true then return false
    context = {ownRetirement: true, nonce: CreateObject("roDeviceInfo").getRandomUUID(), connection: chosen.connection, store: chosen.store, key: m.apiKey, receipt: receipt, authorizationSignature: m.profileAuthorizationSignature}
    selected = commitDispatcharrOwnRetirementSelection(m.registry, context.connection, context.store, receipt, m.activeUserScope, textValue(m.apiKey), memory, textValue(context.authorizationSignature), m.profileRosterEnabled <> false, CreateObject("roDateTime").asSeconds(), context.nonce)
    if not selected.ok then return false
    chosen.key = ""
    chosen.pin = invalid
    if type(chosen.authentication) = "roAssociativeArray" then chosen.authentication.apiKey = ""
    finishUserProfileDefaultRetirement(context, selected, invalid, invalid, m.profileRosterEnabled <> false, memory)
    return true
end function

sub finishUserProfileDefaultRetirement(context as object, selected as object, proof as dynamic, decoded as dynamic, apply as boolean, memory as object)
    preserveSubmittedRecording()
    if m.profileSwitchTask <> invalid then m.profileSwitchTask.apiKey = ""
    closeUserProfileSwitchTask()
    m.profileSwitchContext = invalid
    ' Selecting the local default is NOT authentication. Tear down every old
    ' resource/key before the separate deletion transaction can run.
    resetConnectionRuntime()
    m.userProfileStore = selected.store
    m.profileGateCover.visible = true
    m.global.profilegateclosed = true
    m.global.activeusersession = context.nonce
    m.global.profileswitchpending = true
    m.guide.active = false
    m.busy = true
    if type(m.profileSessionKeys) = "roAssociativeArray"
        m.profileSessionKeys.delete(preferenceScope(context.connection.url + "|" + context.connection.id + "|" + selected.outgoingId))
    end if
    if context.ownRetirement = true
        saved = commitDispatcharrOwnRetirementCleanup(m.registry, context.connection, context.store, selected, context.receipt, m.activeUserScope, textValue(m.apiKey), memory, textValue(context.authorizationSignature), apply, CreateObject("roDateTime").asSeconds(), m.global.activeusersession)
    else
        saved = commitDispatcharrDefaultRetirementCleanup(m.registry, context, selected, proof, decoded, apply, CreateObject("roDateTime").asSeconds(), m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), memory)
    end if
    context.key = ""
    context.pin = invalid
    if type(context.authentication) = "roAssociativeArray" then context.authentication.apiKey = ""
    if type(proof) = "roAssociativeArray" then proof.apiKey = ""
    if not saved.ok
        m.global.activeusersession = ""
        m.global.profileswitchpending = false
        m.busy = false
        m.userProfileRecoveryRequired = true
        m.top.findNode("profileGateMessage").text = "The default was selected, but removed profile data needs recovery. Back exits AerioTV."
        return
    end if
    publishUserProfileSwitchRosterStore(context, saved)
    target = invalid
    for each profile in saved.store.profiles
        if profile.isDefault and profile.id = saved.store.active then target = profile
    end for
    if target = invalid
        m.userProfileRecoveryRequired = true
        m.global.activeusersession = ""
        m.global.profileswitchpending = false
        m.busy = false
        return
    end if
    incoming = {systemDefaultRetirement: true, phase: "authenticate", nonce: CreateObject("roDeviceInfo").getRandomUUID(), connection: context.connection, connectionRoot: m.registry.read("connectionsV1"), connectionRootPresent: m.registry.exists("connectionsV1"), store: saved.store, storeRoot: m.registry.read(userProfileStoreKey(context.connection.id)), target: target, retirement: saved, retirementStoreRoot: FormatJson(saved.store), retiredProfileId: selected.outgoingId, outgoing: invalid, key: ""}
    ownMemory = userProfileSwitchRosterMemory(incoming)
    credential = userProfileCredential(m.registry, incoming.connection, incoming.store, ownMemory)
    m.profileSwitchContext = incoming
    m.global.activeusersession = incoming.nonce
    if target.role = "child" and m.profileChildAccessReady <> true
        stopSystemDefaultProfileSwitch("The default Child profile is selected. Its own access must be verified before content can load.")
        return
    end if
    if not credential.ok
        stopSystemDefaultProfileSwitch("The default profile is selected and needs its own sign-in.")
        return
    end if
    incoming.key = credential.key
    if not systemDefaultProfileAccessCurrent(m.registry, incoming, m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), ownMemory)
        stopSystemDefaultProfileSwitch("The default profile is selected. Its own server access is not available yet.")
        return
    end if
    m.global.profilegateclosed = false
    m.top.findNode("profileGateMessage").text = "Verifying the default profile..."
    startSystemDefaultProfileTask(true)
end sub

sub startSystemDefaultProfileTask(verifyOnly as boolean)
    context = m.profileSwitchContext
    if not systemDefaultProfileAccessCurrent(m.registry, context, m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), userProfileSwitchRosterMemory(context))
        stopSystemDefaultProfileSwitch("Default profile access changed. Saved data was retained.")
        return
    end if
    task = invalid
    if m.profileSwitchTaskFactory <> invalid then task = m.profileSwitchTaskFactory()
    if task = invalid then task = CreateObject("roSGNode", "DispatcharrTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = context.connection.url
    task.apiKey = context.key
    task.authMode = textValue(context.authMode)
    if task.authMode = "" then task.authMode = context.connection.authMode
    task.verifyOnly = verifyOnly
    task.expectedUserId = context.target.userId.toStr()
    task.expectedUsername = context.target.username
    task.profileId = context.connection.profileId
    task.channelProfileIds = context.connection.channelProfileIds
    if not verifyOnly then task.expectedAuthorizationSignature = context.authorizationSignature
    m.profileSwitchTask = task
    task.observeField("result", "onUserProfileSwitchResult")
    task.observeField("state", "onUserProfileSwitchState")
    task.control = "RUN"
end sub

' Return false only for a current, independently checked final lineup, so the
' shared runtime adoption below the callback can use the explicit system API.
function handleSystemDefaultProfileResult(result as object) as boolean
    context = m.profileSwitchContext
    if context = invalid or context.systemDefaultRetirement <> true then return false
    if not systemDefaultProfileAccessCurrent(m.registry, context, m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), userProfileSwitchRosterMemory(context))
        stopSystemDefaultProfileSwitch("Default profile access changed. Saved data was retained.")
        return true
    end if
    if result.ok <> true
        stopSystemDefaultProfileSwitch("The default profile is selected, but its own access could not be verified.")
        return true
    end if
    if context.phase = "authenticate"
        if result.phase <> "verified" or not systemDefaultProfileProofCurrent(context, result)
            stopSystemDefaultProfileSwitch("Could not verify the default profile's own identity.")
            return true
        end if
        context.authentication = result
        context.authMode = textValue(result.authModeUsed)
        closeUserProfileSwitchTask()
        task = invalid
        if m.profileSwitchReadTaskFactory <> invalid then task = m.profileSwitchReadTaskFactory()
        if task = invalid then task = CreateObject("roSGNode", "DispatcharrSyncReadTask")
        tagTaskForCurrentUser(task)
        task.baseUrl = context.connection.url
        task.apiKey = context.key
        task.authMode = context.authMode
        task.accountId = context.target.userId.toStr()
        task.username = context.target.username
        context.phase = "roster"
        m.profileSwitchTask = task
        task.observeField("result", "onUserProfileSwitchResult")
        task.observeField("state", "onUserProfileSwitchState")
        task.control = "RUN"
        return true
    end if
    if context.phase = "roster"
        proof = {ok: true, apiKey: context.key, verifiedBaseUrl: result.verifiedBaseUrl, accountId: result.accountId, accountUsername: result.accountUsername, verifiedUser: result.verifiedUser}
        if not systemDefaultProfileProofCurrent(context, proof)
            stopSystemDefaultProfileSwitch("Could not verify the default profile's current protection.")
            return true
        end if
        decoded = {ok: true, rows: [], removed: []}
        apply = false
        if result.state = "ready" and result.profilesState = "ready"
            decoded = dispatcharrSyncRosterDecode(result.data["categories"]["profiles"]["data"])
            apply = m.profileRosterEnabled <> false
        end if
        saved = commitSystemDefaultRosterPull(m.registry, context, proof, decoded, apply, CreateObject("roDateTime").asSeconds(), m.global.activeusersession, m.activeUserScope, textValue(m.apiKey), userProfileSwitchRosterMemory(context))
        if not saved.ok
            m.userProfileRecoveryRequired = saved.recoveryRequired = true
            stopSystemDefaultProfileSwitch("Could not safely store the default profile's protection.")
            return true
        end if
        publishUserProfileSwitchRosterStore(context, saved)
        context.storeRoot = m.registry.read(userProfileStoreKey(context.connection.id))
        for each profile in saved.store.profiles
            if profile.id = saved.store.active then context.target = profile
        end for
        context.authorizationSignature = dispatcharrAuthorizationSignature(proof.verifiedUser)
        closeUserProfileSwitchTask()
        if context.target.role = "child" and m.profileChildAccessReady <> true
            stopSystemDefaultProfileSwitch("The default Child profile is selected. Its own access must be verified before content can load.")
            return true
        end if
        context.phase = "lineup"
        startSystemDefaultProfileTask(false)
        return true
    end if
    if context.phase = "lineup"
        matches = systemDefaultProfileProofCurrent(context, result)
        if matches then matches = dispatcharrAuthorizationSignature(result.verifiedUser) = context.authorizationSignature
        if matches then return false
    end if
    stopSystemDefaultProfileSwitch("Default profile permissions changed. Please verify access again.")
    return true
end function

sub stopSystemDefaultProfileSwitch(message as string)
    context = m.profileSwitchContext
    if context = invalid or context.systemDefaultRetirement <> true then return
    if not userProfileSwitchActorCurrent(context) then return
    if m.profileSwitchTask <> invalid then m.profileSwitchTask.apiKey = ""
    closeUserProfileSwitchTask()
    context.key = ""
    if type(context.authentication) = "roAssociativeArray" then context.authentication.apiKey = ""
    m.profileSwitchContext = invalid
    m.global.activeusersession = ""
    m.global.profileswitchpending = false
    m.global.profilegateclosed = true
    m.profileGateCover.visible = true
    m.guide.active = false
    m.busy = false
    m.top.findNode("profileGateMessage").text = message + " Back exits AerioTV."
end sub
