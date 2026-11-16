' Private startup controller. It owns no outgoing authenticated actor or key.
' The ordinary authenticated switcher and unavailable-Child escape stay separate.
function deferUserProfileLaunch() as boolean
    if m.profilePickerReady <> true or m.profileStartupRoutingStarted = true then return false
    if m.activeUserScope <> invalid then return false
    connection = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if connection = invalid or connection.provider <> "dispatcharr" then return false
    m.profileStartupLaunchConnection = normalizeConnectionEntry(connection)
    m.profileStartupLaunchConnectionRoot = m.registry.read("connectionsV1")
    m.profileStartupLaunchConnectionRootPresent = m.registry.exists("connectionsV1")
    m.profileStartupDeferred = true
    m.apiKey = ""
    m.global.profilegateclosed = true
    m.profileGateCover.visible = true
    m.guide.active = false
    return true
end function

' Main sends this only AFTER screen.show and registering exitRequested. Never
' read launchRequest during init or infer screen readiness from elapsed time.
sub onSceneStartupReady()
    if m.profilePickerReady <> true or m.profileStartupDeferred <> true then return
    if m.top.exitRequested = true then return
    if m.top.startupReady <> true or m.profileStartupRoutingTimer <> invalid then return
    m.profileStartupScreenReady = true
    clock = invalid
    if m.profileStartupRoutingTimerFactory <> invalid then clock = m.profileStartupRoutingTimerFactory()
    if clock = invalid then clock = m.top.createChild("Timer")
    clock.duration = 0.01
    clock.repeat = false
    clock.observeField("fire", "onDeferredUserProfileLaunch")
    m.profileStartupRoutingTimer = clock
    clock.control = "start"
end sub

sub onDeferredUserProfileLaunch()
    if m.profileStartupDeferred <> true or m.profileStartupScreenReady <> true then return
    if m.profileStartupRoutingTimer <> invalid
        m.profileStartupRoutingTimer.control = "stop"
        m.profileStartupRoutingTimer.unobserveField("fire")
        m.profileStartupRoutingTimer = invalid
    end if
    m.profileStartupDeferred = false
    m.profileStartupRoutingStarted = true
    raw = m.top.launchRequest
    m.pendingLaunch = normalizeLaunchRequest(raw)
    m.profileLaunchPickerDeepLink = launchRequestHasMediaIntent(raw)
    entry = m.profileStartupLaunchConnection
    if entry = invalid then coverDeferredProfileLaunch("Saved connection access changed.") : return
    if m.profileStartupLaunchConnectionRoot <> m.registry.read("connectionsV1") or m.profileStartupLaunchConnectionRootPresent <> m.registry.exists("connectionsV1")
        coverDeferredProfileLaunch("Saved connection access changed.")
        return
    end if
    store = loadUserProfileStore(m.registry, entry.id)
    model = userProfilePickerPlan(store, "launch", entry.provider, m.profileLaunchPickerDeepLink)
    if model.ok and model.show
        if beginUserProfileLaunchPicker(false) then return
        coverDeferredProfileLaunch("Could not safely open profile selection.")
        return
    end if
    resumeUserProfileLaunch()
end sub

sub resumeUserProfileLaunch()
    if m.activeUserScope <> invalid or m.profileStartupSelectionContext <> invalid then return
    connection = m.profileStartupLaunchConnection
    if connection = invalid then coverDeferredProfileLaunch("Saved connection access changed.") : return
    if m.profileStartupLaunchConnectionRoot <> m.registry.read("connectionsV1") or m.profileStartupLaunchConnectionRootPresent <> m.registry.exists("connectionsV1")
        coverDeferredProfileLaunch("Saved connection access changed.")
        return
    end if
    connections = loadConnectionStore(m.registry)
    entry = connectionStoreEntry(connections, connection.id)
    if connections.readOnly = true or connections.selected <> connection.id or entry = invalid then coverDeferredProfileLaunch("Saved connection access changed.") : return
    if FormatJson(entry) <> FormatJson(normalizeConnectionEntry(connection)) then coverDeferredProfileLaunch("Saved connection access changed.") : return
    m.connectionStore = connections
    m.selectedConnectionId = entry.id
    m.baseUrl = entry.url
    m.guideUrl = entry.epgUrl
    m.remember = entry.remember
    m.global.authHeaderMode = entry.authMode
    m.global.httpUserAgent = dispatcharrUserAgent(entry.userAgent)
    m.global.httpReferer = textValue(entry.referer)
    store = loadUserProfileStore(m.registry, entry.id)
    memory = {}
    if type(m.profileSessionKeys) = "roAssociativeArray"
        bucket = preferenceScope(entry.url + "|" + entry.id + "|" + store.active)
        if m.profileSessionKeys.doesExist(bucket)
            for each profile in store.profiles
                if profile.id = store.active
                    name = connectionRegistryKey(entry.id)
                    if not profile.isDefault then name = userProfileKeyName(entry.id, profile.id)
                    memory[name] = m.profileSessionKeys[bucket]
                end if
            end for
        end if
    end if
    credential = userProfileCredential(m.registry, entry, store, memory)
    m.apiKey = ""
    if credential.ok
        for each profile in store.profiles
            if profile.id = store.active
                if startupProfileIdentityRefused(entry, profile, credential.key)
                    coverDeferredProfileLaunch("Sign in as " + profile.username + " to verify this profile's account.")
                    return
                end if
            end if
        end for
        m.apiKey = credential.key
    end if
    gate = selectedUserProfileGate()
    if gate.reason = "picker"
        if beginUserProfileLaunchPicker(false) then return
        coverDeferredProfileLaunch("Could not safely open profile selection.")
        return
    end if
    if gate.reason = "pin"
        beginStartupDialog()
        for each profile in m.userProfileStore.profiles
            if profile.id = m.userProfileStore.active
                if beginProfilePinGate(profile, "connect") then return
            end if
        end for
        coverDeferredProfileLaunch("This profile's PIN requires approved access on this Roku.")
        return
    end if
    if not gate.allowed
        if selectedUserProfileIsChild()
            if showUnavailableChildProfile() then return
        end if
        coverDeferredProfileLaunch(userProfileGateMessage(gate))
        return
    end if
    if m.startupDialogOpen = true then completeStartupDialog()
    m.global.profilegateclosed = false
    m.profileGateCover.visible = false
    if m.baseUrl <> "" and m.apiKey <> ""
        connectServer(true)
    else
        drawSetup()
    end if
end sub

sub coverDeferredProfileLaunch(message as string)
    if m.activeUserScope <> invalid then return
    if m.profileStartupSelectionContext <> invalid then cancelStartupProfileTask()
    closeUserProfileLaunchPicker()
    m.apiKey = ""
    m.global.profilegateclosed = true
    m.profileGateCover.visible = true
    m.top.findNode("profileGateMessage").text = message + " Back exits AerioTV."
    m.top.setFocus(true)
end sub

sub dismissStartupPickerForDeepLink()
    if m.profilePickerReady <> true or m.activeUserScope <> invalid then return
    context = m.profileStartupSelectionContext
    if m.profilePinDialog <> invalid
        pin = m.profilePinContext
        if context = invalid or pin = invalid then coverDeferredProfileLaunch("Profile protection changed.") : return
        if pin.continuation <> "startup-selection" or pin.resume <> context.nonce then coverDeferredProfileLaunch("Profile protection changed.") : return
        dialog = m.profilePinDialog
        dialog.unobserveField("buttonSelected")
        dialog.unobserveField("wasClosed")
        dialog.textEditBox.text = ""
        dialog.close = true
        if m.top.dialog <> invalid
            if m.top.dialog.isSameNode(dialog) then m.top.dialog = invalid
        end if
        if type(dialog) = "roSGNode"
            if dialog.isSubtype("DirectionsPinPad") then m.top.removeChild(dialog)
        end if
        m.profilePinDialog = invalid
        m.profilePinContext = invalid
        m.profileGateClock.control = "stop"
    end if
    cancelStartupProfileTask()
    closeUserProfileLaunchPicker()
    m.profileLaunchPickerDeepLink = true
    if m.startupDialogOpen = true then completeStartupDialog()
    resumeUserProfileLaunch()
end sub

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
    if m.profileStartupLaunchConnection = invalid
        m.profileStartupLaunchConnection = normalizeConnectionEntry(connection)
        m.profileStartupLaunchConnectionRoot = m.registry.read("connectionsV1")
        m.profileStartupLaunchConnectionRootPresent = m.registry.exists("connectionsV1")
    end if
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

' A successful HTTP /me can still prove the cached key belongs to somebody
' else. This is not a typed rejection and must not manufacture a broker hold.
' Keep only exact identity/credential digests for this app process; own-form
' replacement can proceed with a different key without touching the source.
function startupProfileIdentityToken(connection as object, target as object, key as string) as string
    hash = ""
    if m.profileStartupCredentialDigest <> invalid
        hash = m.profileStartupCredentialDigest(key)
    else
        hash = requestGateCredentialHash(key)
    end if
    if hash = "" then return ""
    return FormatJson([connection.url, connection.id, target.id, target.userId.toStr(), lcase(target.username), hash])
end function

function startupProfileIdentityRefused(connection as object, target as object, key as string) as boolean
    token = startupProfileIdentityToken(connection, target, key)
    if token = "" then return true
    if type(m.profileStartupIdentityRefusals) <> "roAssociativeArray" then return false
    return m.profileStartupIdentityRefusals.doesExist(token)
end function

' Credential-form admission is separate from cached-key selection. It grants
' neither PIN verification nor an authenticated source. Defaults must retain
' their known identity; Child recovery keeps its separate boundary.
function startupProfileOwnSignInAdmission(targetId as string) as object
    denied = {ok: false}
    if m.profilePickerReady <> true or m.profilePicker = invalid or m.page <> "profile-picker" then return denied
    picker = m.profilePickerContext
    if picker = invalid or m.activeUserScope <> invalid or textValue(m.apiKey) <> "" then return denied
    if m.profileStartupSelectionContext <> invalid or m.profileStartupTask <> invalid then return denied
    if m.profileOwnSignInContext <> invalid or m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return denied
    if m.userProfileRecoveryRequired = true or m.global.profilegateclosed <> true then return denied
    if picker.connection.id <> m.selectedConnectionId then return denied
    if picker.connectionRootPresent <> m.registry.exists("connectionsV1") or picker.connectionRoot <> m.registry.read("connectionsV1") then return denied
    connections = loadConnectionStore(m.registry)
    entry = connectionStoreEntry(connections, picker.connection.id)
    if connections.readOnly = true or connections.selected <> picker.connection.id or entry = invalid then return denied
    if FormatJson(entry) <> FormatJson(normalizeConnectionEntry(picker.connection)) then return denied
    if picker.storeRoot <> m.registry.read(userProfileStoreKey(entry.id)) then return denied
    store = loadUserProfileStore(m.registry, entry.id)
    model = userProfilePickerPlan(store, "launch", entry.provider, false)
    if not model.ok or not model.show then return denied
    for each target in store.profiles
        if target.id = targetId
            if not userProfileFullAccess(target.role) then return denied
            if target.isDefault
                if not userProfileDefaultOwnIdentityMatches(entry, store, {id: target.userId, username: target.username}) then return denied
            end if
            return {ok: true, connection: entry, store: store, target: target, requiresPin: target.pinType <> "none"}
        end if
    end for
    return denied
end function

sub finishStartupProfileOwnSignIn(context as object, accepted as boolean)
    if m.activeUserScope <> invalid or textValue(m.apiKey) <> "" then return
    if currentUserSessionId() <> context.nonce then return
    m.global.activeusersession = ""
    m.global.profilegateclosed = true
    m.global.profileswitchpending = false
    m.profileGateCover.visible = true
    m.profileUnlockGrant = context.unlock
    message = "Sign-in cancelled. No account was switched."
    if accepted then message = ""
    failStartupProfileSelection(message, context.target.id)
    if accepted and m.profilePicker <> invalid and m.profilePickerContext <> invalid
        beginStartupProfileSelection(context.target.id, context.pin)
    end if
end sub

function startupProfileTargetAllowed(context as object) as boolean
    if not userProfileStartupTargetRoleAllowed(context, context.target) then return false
    if context.target.role = "child" then return m.profileChildAccessReady = true
    return true
end function

sub beginStartupProfileSelection(targetId as string, ownPin = invalid as dynamic)
    picker = m.profilePickerContext
    if picker = invalid or m.profileStartupSelectionContext <> invalid then return
    if m.profileOwnSignInContext <> invalid then return
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
    if target.role <> "child"
        if credential.reason = "sign-in" or credential.reason = "address-held"
            if beginUserProfileOwnSignIn(targetId, false, false, true) then return
        else if credential.ok and startupProfileIdentityRefused(picker.connection, target, credential.key)
            if beginUserProfileOwnSignIn(targetId, false, false, true) then return
        end if
    end if
    roleReady = userProfileFullAccess(target.role) or (target.role = "child" and m.profileChildAccessReady = true)
    if not credential.ok or not roleReady or not requestGateAccessAllowed(picker.connection.url, credential.key)
        m.profilePicker.message = "This profile needs its own protected sign-in. No account was switched."
        return
    end if
    if startupProfileIdentityRefused(picker.connection, target, credential.key)
        m.profilePicker.message = "Sign in as " + target.username + " to verify this profile's account."
        return
    end if
    nonce = CreateObject("roDeviceInfo").getRandomUUID()
    context = {purpose: "startup-picker", nonce: nonce, connection: picker.connection, connectionRoot: picker.connectionRoot, connectionRootPresent: picker.connectionRootPresent, store: picker.store, storeRoot: picker.storeRoot, target: target, key: credential.key, memoryKeys: memory, phase: "pin", childAccessReady: m.profileChildAccessReady = true}
    if not userProfileStartupSelectionCurrent(m.registry, context, nonce, m.activeUserScope, textValue(m.apiKey), memory, false) then return
    m.profileStartupSelectionContext = context
    m.profilePicker.busy = true
    m.profilePicker.message = ""
    if target.pinType <> "none"
        if userProfilePinGrantMatches(ownPin, picker.connection.id, target)
            context.pin = ownPin
            startStartupProfileTask("authenticate")
            return
        end if
        if beginProfilePinGate(target, "startup-selection", nonce) then return
        failStartupProfileSelection("This profile's PIN is not available on this build.")
        return
    end if
    startStartupProfileTask("authenticate")
end sub

function startupProfilePinContextCurrent(pin as object) as boolean
    context = m.profileStartupSelectionContext
    if context = invalid or m.profilePickerContext = invalid then return false
    if not startupProfileTargetAllowed(context) then return false
    if pin.continuation <> "startup-selection" or pin.resume <> context.nonce or pin.slot <> context.connection.id then return false
    if m.global.profilegateclosed <> true then return false
    material = {slot: pin.slot, id: pin.profile.id, pinType: pin.profile.pinType, pinHash: pin.profile.pinHash, pinSalt: pin.profile.pinSalt}
    if not userProfilePinGrantMatches(material, context.connection.id, context.target) then return false
    return userProfileStartupSelectionCurrent(m.registry, context, context.nonce, m.activeUserScope, textValue(m.apiKey), context.memoryKeys, false)
end function

sub onStartupProfilePin(nonce as string)
    context = m.profileStartupSelectionContext
    if context = invalid or context.nonce <> nonce then return
    if not startupProfileTargetAllowed(context) then failStartupProfileSelection("This profile requires protected Child access.") : return
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
    if not startupProfileTargetAllowed(context) then failStartupProfileSelection("This profile requires protected Child access.") : return
    if phase <> "authenticate" and currentUserSessionId() <> context.nonce
        failStartupProfileSelection("Profile access changed. No account was switched.")
        return
    end if
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
    result = event.getData()
    if type(result) = "roAssociativeArray"
        if result.ok = true and not startupProfileTargetAllowed(context)
            failStartupProfileSelection("This profile requires protected Child access.")
            return
        end if
    end if
    owned = userProfileStartupSelectionStorageCurrent(m.registry, context, currentUserSessionId(), m.activeUserScope, textValue(m.apiKey), context.memoryKeys, true)
    if type(result) = "roAssociativeArray"
        if result.ok = true then owned = owned and userProfileStartupSelectionCurrent(m.registry, context, currentUserSessionId(), m.activeUserScope, textValue(m.apiKey), context.memoryKeys, true)
    end if
    if not owned
        failStartupProfileSelection("Profile access changed. No account was switched.")
        return
    end if
    phase = context.phase
    closeStartupProfileTask()
    if type(result) <> "roAssociativeArray"
        failStartupProfileSelection("Could not verify this profile.")
        return
    end if
    if result.ok <> true
        message = "Could not load this profile. No account was switched."
        if result.relogin = true then message = "The API key for " + context.target.username + " was rejected."
        if result.identityChanged = true
            if type(m.profileStartupIdentityRefusals) <> "roAssociativeArray" then m.profileStartupIdentityRefusals = {}
            token = startupProfileIdentityToken(context.connection, context.target, context.key)
            if token <> "" then m.profileStartupIdentityRefusals[token] = true
            message = "Sign in as " + context.target.username + " to verify this profile's account."
        end if
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
        published = commitUserProfileStartupRosterPull(m.registry, context, result, context.readNonce, m.profileRosterEnabled <> false, CreateObject("roDateTime").asSeconds(), currentUserSessionId(), m.activeUserScope, textValue(m.apiKey), context.memoryKeys)
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
        if not startupProfileTargetAllowed(context)
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
    saved = commitUserProfileStartupSelection(m.registry, context, result, currentUserSessionId(), m.activeUserScope, textValue(m.apiKey), context.memoryKeys)
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

sub failStartupProfileSelection(message as string, targetId = "" as string)
    incoming = m.profileStartupSelectionContext
    if type(incoming) = "roAssociativeArray"
        if type(incoming.target) = "roAssociativeArray" then targetId = textValue(incoming.target.id)
    end if
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
    for i = 0 to model.tiles.count() - 1
        if model.tiles[i].kind = "profile" and model.tiles[i].id = targetId then model.focus = i
    end for
    m.profilePicker.model = model
    m.profilePicker.message = message
    m.profilePicker.busy = false
    m.profilePicker.visible = true
    m.profilePicker.setFocus(true)
    if m.startupDialogOpen = false then beginStartupDialog()
end sub
