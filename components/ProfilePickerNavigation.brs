' Private startup controller. It owns no outgoing authenticated actor or key.
' The ordinary authenticated switcher and unavailable-Child escape stay separate.
function beginUserProfileLaunchPicker(deepLink as boolean) as boolean
    if m.profilePickerReady <> true or deepLink then return false
    if m.activeUserScope <> invalid or m.profilePicker <> invalid then return false
    if m.profileSwitchContext <> invalid or m.profileOwnSignInContext <> invalid or m.task <> invalid then return false
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid or m.userProfileRecoveryRequired = true then return false
    connection = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if connection = invalid or connection.provider <> "dispatcharr" then return false
    store = loadUserProfileStore(m.registry, connection.id)
    model = userProfilePickerPlan(store, "launch", connection.provider, deepLink)
    if not model.ok or not model.show then return false
    connections = loadConnectionStore(m.registry)
    current = connectionStoreEntry(connections, connection.id)
    if connections.readOnly = true or connections.selected <> connection.id or current = invalid then return false
    if FormatJson(current) <> FormatJson(normalizeConnectionEntry(connection)) then return false
    if not m.registry.exists(userProfileStoreKey(connection.id)) then return false
    picker = invalid
    if m.profilePickerFactory <> invalid then picker = m.profilePickerFactory()
    if picker = invalid then picker = CreateObject("roSGNode", "UserProfilePicker")
    if picker = invalid then return false
    nonce = CreateObject("roDeviceInfo").getRandomUUID()
    m.profilePickerContext = {purpose: "launch", nonce: nonce, connection: connection, connectionRoot: m.registry.read("connectionsV1"), connectionRootPresent: m.registry.exists("connectionsV1"), store: store, storeRoot: m.registry.read(userProfileStoreKey(connection.id))}
    m.profilePicker = picker
    m.apiKey = ""
    m.global.profilegateclosed = true
    m.global.profileswitchpending = false
    m.global.activeusersession = ""
    m.profileGateCover.visible = true
    m.guide.active = false
    if m.screen <> invalid then m.screen.visible = false
    m.page = "profile-picker"
    picker.model = model
    picker.busy = false
    picker.observeField("intent", "onUserProfilePickerIntent")
    m.top.appendChild(picker)
    picker.setFocus(true)
    if type(m.top) = "roSGNode" then requestGateFenceRenderers(m.top)
    return true
end function

sub onUserProfilePickerIntent(event as object)
    if m.profilePicker = invalid or m.profilePickerContext = invalid then return
    if not m.profilePicker.isSameNode(event.getRoSGNode()) then return
    intent = event.getData()
    if type(intent) <> "roAssociativeArray" then return
    if intent.action = "back"
        cancelStartupProfileTask()
        closeUserProfileLaunchPicker()
        m.global.profilegateclosed = true
        m.profileGateCover.visible = true
        m.top.exitRequested = true
        return
    end if
    if m.profilePicker.busy = true or m.activeUserScope <> invalid then return
    context = m.profilePickerContext
    if context.connection.id <> m.selectedConnectionId then return
    if context.connectionRoot <> m.registry.read("connectionsV1") or context.connectionRootPresent <> m.registry.exists("connectionsV1") then return
    if context.storeRoot <> m.registry.read(userProfileStoreKey(context.connection.id)) then return
    expected = userProfilePickerChoice(m.profilePicker.model, intent.index)
    if expected = "" then return
    if intent.action <> expected
        if intent.action = "reorder" then m.profilePicker.message = "Profile management is not enabled in this private startup flow."
        return
    end if
    if expected = "add" or expected = "manage"
        m.profilePicker.message = "Profile management is not enabled in this private startup flow."
        return
    end if
    tile = m.profilePicker.model.tiles[intent.index]
    beginStartupProfileSelection(tile.id)
end sub

sub beginStartupProfileSelection(targetId as string)
    picker = m.profilePickerContext
    if picker = invalid or m.profileStartupSelectionContext <> invalid then return
    if m.activeUserScope <> invalid or textValue(m.apiKey) <> "" then return
    target = invalid
    for each profile in picker.store.profiles
        if profile.id = targetId then target = profile
    end for
    if target = invalid then return
    selected = setCanonicalPreference(picker.store, "active", targetId)
    memory = {}
    if type(m.profileSessionKeys) = "roAssociativeArray"
        bucket = preferenceScope(picker.connection.url + "|" + picker.connection.id + "|" + targetId)
        if m.profileSessionKeys.doesExist(bucket)
            name = connectionRegistryKey(picker.connection.id)
            if not target.isDefault then name = userProfileKeyName(picker.connection.id, targetId)
            memory[name] = m.profileSessionKeys[bucket]
        end if
    end if
    credential = userProfileCredential(m.registry, picker.connection, selected, memory)
    ' Own-form/Child picker admission remains a separate unfinished boundary.
    if not credential.ok or target.role = "child" or not requestGateAccessAllowed(picker.connection.url, credential.key)
        m.profilePicker.message = "This profile needs its own protected sign-in. No account was switched."
        return
    end if
    nonce = CreateObject("roDeviceInfo").getRandomUUID()
    context = {purpose: "startup-picker", nonce: nonce, connection: picker.connection, connectionRoot: picker.connectionRoot, connectionRootPresent: picker.connectionRootPresent, store: picker.store, storeRoot: picker.storeRoot, target: target, key: credential.key, memoryKeys: memory, phase: "pin"}
    if not userProfileStartupSelectionCurrent(m.registry, context, nonce, m.activeUserScope, textValue(m.apiKey), memory, false) then return
    m.profileStartupSelectionContext = context
    m.profilePicker.busy = true
    m.profilePicker.message = ""
    if target.pinType <> "none"
        if beginProfilePinGate(target, "startup-selection", nonce) then return
        failStartupProfileSelection("This profile's PIN is not available on this build.")
        return
    end if
    startStartupProfileTask("authenticate")
end sub

function startupProfilePinContextCurrent(pin as object) as boolean
    context = m.profileStartupSelectionContext
    if context = invalid or m.profilePickerContext = invalid then return false
    if pin.continuation <> "startup-selection" or pin.resume <> context.nonce or pin.slot <> context.connection.id then return false
    if m.global.profilegateclosed <> true then return false
    material = {slot: pin.slot, id: pin.profile.id, pinType: pin.profile.pinType, pinHash: pin.profile.pinHash, pinSalt: pin.profile.pinSalt}
    if not userProfilePinGrantMatches(material, context.connection.id, context.target) then return false
    return userProfileStartupSelectionCurrent(m.registry, context, context.nonce, m.activeUserScope, textValue(m.apiKey), context.memoryKeys, false)
end function

sub onStartupProfilePin(nonce as string)
    context = m.profileStartupSelectionContext
    if context = invalid or context.nonce <> nonce then return
    if not userProfilePinGrantMatches(m.profileUnlockGrant, context.connection.id, context.target) then return
    current = loadUserProfileStore(m.registry, context.connection.id)
    if not userProfileSwitchAcceptPinStore(context.store, current, context.target.id, m.profileUnlockGrant)
        failStartupProfileSelection("Saved profile protection changed. Please retry.")
        return
    end if
    context.store = current
    context.storeRoot = m.registry.read(userProfileStoreKey(context.connection.id))
    for each profile in current.profiles
        if profile.id = context.target.id then context.target = profile
    end for
    context.pin = m.profileUnlockGrant
    m.profileUnlockGrant = invalid
    context.protectionReceipt = invalid
    if context.authenticated = true
        startStartupProfileTask("read")
    else
        startStartupProfileTask("authenticate")
    end if
end sub

sub startStartupProfileTask(phase as string)
    context = m.profileStartupSelectionContext
    if context = invalid or m.profileStartupTask <> invalid then return
    if not userProfileStartupSelectionCurrent(m.registry, context, context.nonce, m.activeUserScope, textValue(m.apiKey), context.memoryKeys, true)
        failStartupProfileSelection("Profile access changed. No account was switched.")
        return
    end if
    if phase <> "authenticate" and phase <> "read" and phase <> "load" then return
    if phase = "load" and context.protectionReceipt = invalid then return
    m.global.profilegateclosed = false
    m.global.profileswitchpending = true
    m.global.activeusersession = context.nonce
    m.profileGateCover.visible = true
    context.phase = phase
    kind = "DispatcharrTask"
    if phase = "read"
        kind = "DispatcharrSyncReadTask"
        context.readNonce = CreateObject("roDeviceInfo").getRandomUUID()
    end if
    task = invalid
    if m.profileStartupTaskFactory <> invalid then task = m.profileStartupTaskFactory(kind)
    if task = invalid then task = CreateObject("roSGNode", kind)
    tagTaskForCurrentUser(task)
    task.baseUrl = context.connection.url
    task.apiKey = context.key
    task.authMode = context.connection.authMode
    if phase = "read"
        task.accountId = context.target.userId.toStr()
        task.username = context.target.username
    else
        task.verifyOnly = phase = "authenticate"
        task.expectedUserId = context.target.userId.toStr()
        task.expectedUsername = context.target.username
        if context.target.isDefault
            task.profileId = context.connection.profileId
            task.channelProfileIds = context.connection.channelProfileIds
        end if
        if phase = "load" then task.expectedAuthorizationSignature = context.protectionReceipt.authorizationSignature
    end if
    task.observeField("result", "onStartupProfileResult")
    task.observeField("state", "onStartupProfileState")
    m.profileStartupTask = task
    task.control = "RUN"
end sub

sub onStartupProfileState(event as object)
    if not isCurrentTaskEvent(event, m.profileStartupTask) then return
    if event.getData() <> "done" and event.getData() <> "stop" then return
    if type(m.profileStartupTask.result) = "roAssociativeArray" then return
    failStartupProfileSelection("Could not load this profile. No account was switched.")
end sub

sub onStartupProfileResult(event as object)
    if not isCurrentTaskEvent(event, m.profileStartupTask) then return
    context = m.profileStartupSelectionContext
    if context = invalid or context.connection.id <> m.selectedConnectionId then return
    if not userProfileStartupSelectionCurrent(m.registry, context, context.nonce, m.activeUserScope, textValue(m.apiKey), context.memoryKeys, true)
        failStartupProfileSelection("Profile access changed. No account was switched.")
        return
    end if
    result = event.getData()
    phase = context.phase
    closeStartupProfileTask()
    if type(result) <> "roAssociativeArray"
        failStartupProfileSelection("Could not verify this profile.")
        return
    end if
    if result.ok <> true
        message = "Could not load this profile. No account was switched."
        if result.relogin = true then message = "The API key for " + context.target.username + " was rejected."
        failStartupProfileSelection(message)
        return
    end if
    if phase = "authenticate"
        facts = userProfileFromVerified(context.connection.id, context.target.id, result.verifiedUser, 0)
        if facts = invalid then failStartupProfileSelection("Could not verify this profile.") : return
        if result.phase <> "verified" or result.verifiedBaseUrl <> context.connection.url or result.apiKey <> context.key or facts.userId <> context.target.userId or lcase(facts.username) <> lcase(context.target.username)
            failStartupProfileSelection("This sign-in does not name the selected profile.")
            return
        end if
        context.authenticated = true
        startStartupProfileTask("read")
        return
    end if
    if phase = "read"
        published = commitUserProfileStartupRosterPull(m.registry, context, result, context.readNonce, m.profileRosterEnabled <> false, CreateObject("roDateTime").asSeconds(), context.nonce, m.activeUserScope, textValue(m.apiKey), context.memoryKeys)
        if not published.ok
            m.userProfileRecoveryRequired = published.recoveryRequired = true
            failStartupProfileSelection("Could not safely retain profile protection.")
            return
        end if
        if type(m.profileSessionKeys) = "roAssociativeArray"
            for each removed in published.removed
                m.profileSessionKeys.delete(preferenceScope(context.connection.url + "|" + context.connection.id + "|" + removed.id))
            end for
        end if
        m.userProfileStore = published.store
        m.profilePickerContext.store = published.store
        m.profilePickerContext.storeRoot = m.registry.read(userProfileStoreKey(context.connection.id))
        if published.sourceRemoved or published.targetRemoved or published.sourceChild or published.target = invalid
            failStartupProfileSelection("Saved profiles changed. Restart AerioTV to continue through the restored profile's launch gate.")
            return
        end if
        m.profileStartupSelectionContext = published.context
        context = published.context
        if not userProfileFullAccess(context.target.role)
            failStartupProfileSelection("This profile requires protected Child access.")
            return
        end if
        if published.requiresPin
            m.global.profilegateclosed = true
            m.profileUnlockGrant = invalid
            context.phase = "pin"
            if beginProfilePinGate(context.target, "startup-selection", context.nonce) then return
            failStartupProfileSelection("This profile's updated PIN is not available on this build.")
            return
        end if
        if context.protectionReceipt = invalid then failStartupProfileSelection("Could not verify current profile protection.") : return
        m.profilePicker.visible = false
        m.top.setFocus(true)
        if m.startupDialogOpen = true then completeStartupDialog()
        startStartupProfileTask("load")
        return
    end if
    if phase <> "load" then return
    saved = commitUserProfileStartupSelection(m.registry, context, result, context.nonce, m.activeUserScope, textValue(m.apiKey), context.memoryKeys)
    if not saved.ok
        m.userProfileRecoveryRequired = saved.recoveryRequired = true
        failStartupProfileSelection("Could not safely save the selected profile.")
        return
    end if
    m.profileStartupSelectionContext = invalid
    closeUserProfileLaunchPicker()
    adoptCompletedUserProfileState(context, saved, result)
    signalStartupComplete()
end sub

sub closeStartupProfileTask()
    task = m.profileStartupTask
    m.profileStartupTask = invalid
    if task = invalid then return
    task.unobserveField("result")
    task.unobserveField("state")
    cancelNetworkTask(task)
    task.apiKey = ""
end sub

sub cancelStartupProfileTask()
    closeStartupProfileTask()
    m.profileStartupSelectionContext = invalid
    m.profileUnlockGrant = invalid
    if m.activeUserScope = invalid
        m.apiKey = ""
        m.global.activeusersession = ""
        m.global.profileswitchpending = false
        m.global.profilegateclosed = true
    end if
end sub

sub closeUserProfileLaunchPicker()
    picker = m.profilePicker
    m.profilePicker = invalid
    m.profilePickerContext = invalid
    if picker = invalid then return
    picker.unobserveField("intent")
    picker.model = {}
    m.top.removeChild(picker)
end sub

sub failStartupProfileSelection(message as string)
    cancelStartupProfileTask()
    if m.profilePicker = invalid or m.profilePickerContext = invalid then return
    context = m.profilePickerContext
    store = loadUserProfileStore(m.registry, context.connection.id)
    model = userProfilePickerPlan(store, "launch", context.connection.provider, false)
    if m.userProfileRecoveryRequired = true or not model.ok or not model.show or context.connectionRoot <> m.registry.read("connectionsV1")
        closeUserProfileLaunchPicker()
        m.profileGateCover.visible = true
        m.top.findNode("profileGateMessage").text = message + " Back exits AerioTV."
        m.top.setFocus(true)
        return
    end if
    context.store = store
    context.storeRoot = m.registry.read(userProfileStoreKey(context.connection.id))
    m.profilePicker.model = model
    m.profilePicker.message = message
    m.profilePicker.busy = false
    m.profilePicker.visible = true
    m.profilePicker.setFocus(true)
    if m.startupDialogOpen = false then beginStartupDialog()
end sub
