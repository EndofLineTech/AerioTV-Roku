' Own credential recovery. Public picker and default/Child unavailable recovery
' remain separate boundaries; active nondefault recovery has no borrowed scope.
function showActiveUserProfileRecoveryPrompt() as boolean
    if m.userProfileRecoveryRequired = true or m.activeUserScope <> invalid or m.apiKey <> "" then return false
    if not userProfileGateClosed() or m.page <> "setup" or m.profileOwnSignInContext <> invalid then return false
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid or entry.provider <> "dispatcharr" then return false
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true then return false
    target = invalid
    for each profile in store.profiles
        if profile.id = store.active then target = profile
    end for
    if target = invalid then return false
    if target.isDefault or target.addressHeld or not userProfileFullAccess(target.role) then return false
    closeActiveUserProfileRecoveryPrompt()
    dialog = newProfileOwnSignInDialog("form")
    dialog.title = "API key no longer valid"
    dialog.message = "Dispatcharr no longer accepts the API key for " + entry.name + ". It may have been changed on the server. Sign in with your Dispatcharr username and password to reconnect."
    dialog.buttons = ["Sign In with Remote", "Not Now"]
    dialog.observeField("buttonSelected", "onActiveUserProfileRecoveryChoice")
    dialog.observeField("wasClosed", "onActiveUserProfileRecoveryClosed")
    m.profileRecoveryNonce = CreateObject("roDeviceInfo").getRandomUUID()
    m.profileRecoveryContext = {nonce: m.profileRecoveryNonce, connection: entry, store: store, targetId: target.id}
    m.profileRecoveryDialog = dialog
    m.top.dialog = dialog
    dialog.setFocus(true)
    return true
end function

sub onActiveUserProfileRecoveryChoice(event as object)
    if m.profileRecoveryDialog = invalid or m.profileRecoveryContext = invalid then return
    if not m.profileRecoveryDialog.isSameNode(event.getRoSGNode()) then return
    context = m.profileRecoveryContext
    current = context.nonce = m.profileRecoveryNonce and m.selectedConnectionId = context.connection.id and m.activeUserScope = invalid and m.apiKey = "" and userProfileGateClosed() and m.page = "setup"
    connections = loadConnectionStore(m.registry)
    entry = connectionStoreEntry(connections, context.connection.id)
    current = current and connections.readOnly <> true and connections.selected = context.connection.id
    if entry = invalid then current = false
    if current then current = FormatJson(entry) = FormatJson(context.connection) and FormatJson(loadUserProfileStore(m.registry, entry.id)) = FormatJson(context.store)
    choice = event.getData()
    closeActiveUserProfileRecoveryPrompt()
    if current and choice = 0 then beginUserProfileOwnSignIn(context.targetId, true)
end sub

sub onActiveUserProfileRecoveryClosed(event as object)
    if m.profileRecoveryDialog = invalid then return
    if not m.profileRecoveryDialog.isSameNode(event.getRoSGNode()) then return
    closeActiveUserProfileRecoveryPrompt()
end sub

sub closeActiveUserProfileRecoveryPrompt()
    if m.profileRecoveryDialog <> invalid
        m.profileRecoveryDialog.unobserveField("buttonSelected")
        m.profileRecoveryDialog.unobserveField("wasClosed")
        m.profileRecoveryDialog.close = true
    end if
    m.profileRecoveryDialog = invalid
    m.profileRecoveryContext = invalid
    m.profileRecoveryNonce = ""
end sub

function beginUserProfileOwnSignIn(targetId as string, activeRecovery = false as boolean, childRecovery = false as boolean) as boolean
    if m.userProfileRecoveryRequired = true then return false
    if childRecovery and (not activeRecovery or m.profileChildAccessReady <> true) then return false
    if m.profileOwnSignInContext <> invalid or m.profileSwitchContext <> invalid then return false
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return false
    if m.playingChannel <> invalid then return false
    if activeRecovery
        recoveryPage = "setup"
        if childRecovery then recoveryPage = "profile-unavailable"
        if m.activeUserScope <> invalid or not userProfileGateClosed() or m.apiKey <> "" or m.page <> recoveryPage then return false
    else
        if userProfileGateClosed() then return false
        role = currentUserSettingsRole()
        if role <> "user" and role <> "admin" then return false
        if m.page <> "guide" and m.page <> "settings" then return false
    end if
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid or entry.provider <> "dispatcharr" then return false
    if normalizeBaseUrl(m.baseUrl) <> entry.url then return false
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true then return false
    if activeRecovery
        if store.active <> targetId then return false
    else
        if store.active = targetId then return false
    end if
    target = invalid
    for each profile in store.profiles
        if profile.id = targetId then target = profile
    end for
    if target = invalid then return false
    if childRecovery
        if target.role <> "child" then return false
        access = unavailableChildAccessContext()
        if access = invalid then return false
        if access.target.id <> targetId or not access.plan.signIn then return false
    else
        if not userProfileFullAccess(target.role) then return false
        if activeRecovery and (target.isDefault or target.addressHeld) then return false
    end if
    if target.isDefault and target.addressHeld then return false
    if target.isDefault
        if not userProfileDefaultOwnIdentityMatches(entry, store, {id: target.userId, username: target.username}) then return false
    end if
    holds = {}
    if m.requestGate <> invalid
        state = m.requestGate.snapshot
        if type(state) = "roAssociativeArray"
            if type(state.keys) = "roAssociativeArray" then holds = requestGateCopy(state.keys)
        end if
    end if
    retireProfileRequestBinding()
    if childRecovery then closeUnavailableChildDialog()
    m.profileOwnSignInNonce = CreateObject("roDeviceInfo").getRandomUUID()
    m.profileOwnSignInContext = {nonce: m.profileOwnSignInNonce, activeRecovery: activeRecovery, childRecovery: childRecovery, connection: copyJson(entry), store: store, target: target, scope: copyJson(m.activeUserScope), page: m.page, guideActive: m.guide.active, covered: m.profileGateCover.visible, closed: m.global.profilegateclosed, unlock: m.profileUnlockGrant, username: target.username, password: ""}
    m.profileOwnSignInContext.holds = holds
    m.global.profileownsigninpending = true
    m.global.profileownsigninnonce = m.profileOwnSignInNonce
    if activeRecovery
        ' This nonce authorizes only the credential Task. No authenticated
        ' user scope is invented while the unavailable holder has no key.
        m.global.activeusersession = m.profileOwnSignInNonce
        m.global.profilegateclosed = false
        m.scopedPreferencesRequired = true
        m.profileGateCover.visible = true
    end if
    m.guide.active = false
    if target.pinType <> "none"
        if childRecovery and userProfilePinGrantMatches(m.profileUnlockGrant, entry.id, target)
            m.profileOwnSignInContext.pin = m.profileUnlockGrant
        else
            if beginProfilePinGate(target, "own-signin", m.profileOwnSignInNonce) then return true
            cancelUserProfileOwnSignIn()
            return false
        end if
    end if
    showProfileOwnSignInForm()
    return m.profileOwnSignInDialog <> invalid
end function

function profileOwnSignInContextCurrent() as boolean
    if m.userProfileRecoveryRequired = true then return false
    context = m.profileOwnSignInContext
    if type(context) <> "roAssociativeArray" then return false
    if context.nonce <> m.profileOwnSignInNonce or context.connection.id <> m.selectedConnectionId or context.page <> m.page then return false
    if textValue(m.global.profileownsigninnonce) <> context.nonce or m.global.profileownsigninpending <> true then return false
    if context.childRecovery = true and m.profileChildAccessReady <> true then return false
    if context.activeRecovery = true
        if m.activeUserScope <> invalid or m.apiKey <> "" or currentUserSessionId() <> context.nonce then return false
    else
        if not userProfileSameSession(context.scope, m.activeUserScope) then return false
        if currentUserSessionId() <> context.scope.sessionId then return false
        role = currentUserSettingsRole()
        if role <> "user" and role <> "admin" then return false
    end if
    connections = loadConnectionStore(m.registry)
    if connections.readOnly = true or connections.selected <> context.connection.id then return false
    actual = connectionStoreEntry(connections, context.connection.id)
    if actual = invalid then return false
    if FormatJson(actual) <> FormatJson(normalizeConnectionEntry(context.connection)) then return false
    return FormatJson(loadUserProfileStore(m.registry, context.connection.id)) = FormatJson(context.store)
end function

sub onUserProfileOwnSignInPin(nonce as string)
    context = m.profileOwnSignInContext
    if context = invalid or context.nonce <> nonce then return
    current = loadUserProfileStore(m.registry, context.connection.id)
    if not userProfileSwitchAcceptPinStore(context.store, current, context.target.id, m.profileUnlockGrant)
        cancelUserProfileOwnSignIn()
        return
    end if
    context.store = current
    context.pin = m.profileUnlockGrant
    m.profileUnlockGrant = context.unlock
    if not profileOwnSignInContextCurrent() then cancelUserProfileOwnSignIn() : return
    if context.activeRecovery = true then m.profileGateCover.visible = true
    showProfileOwnSignInForm()
end sub

function newProfileOwnSignInDialog(kind as string) as object
    if m.profileOwnSignInDialogFactory <> invalid then return m.profileOwnSignInDialogFactory(kind)
    if kind = "form" then return CreateObject("roSGNode", "AerioDialog")
    return CreateObject("roSGNode", "StandardKeyboardDialog")
end function

sub showProfileOwnSignInForm(message = "" as string)
    closeProfileOwnSignInDialog()
    if not profileOwnSignInContextCurrent() then cancelUserProfileOwnSignIn() : return
    context = m.profileOwnSignInContext
    dialog = newProfileOwnSignInDialog("form")
    dialog.title = "Sign in to Dispatcharr"
    if context.target.addressHeld
        explanation = userProfileOwnSignInAddressMessage(context.connection.name)
        if message <> "" then explanation += chr(10) + chr(10) + message
        message = explanation
    end if
    dialog.message = message
    mask = ""
    if context.password <> "" then mask = "********"
    dialog.buttons = ["Username: " + context.username, "Password: " + mask, "Sign In", "Cancel"]
    if m.profileOwnSignInTask <> invalid or m.profileOwnSignInHold <> invalid then dialog.buttons = ["Cancel"]
    dialog.observeField("buttonSelected", "onProfileOwnSignInChoice")
    dialog.observeField("wasClosed", "onProfileOwnSignInClosed")
    m.profileOwnSignInDialog = dialog
    m.profileOwnSignInDialogKind = "form"
    m.top.dialog = dialog
    dialog.setFocus(true)
end sub

function userProfileOwnSignInAddressMessage(playlist as string) as string
    playlist = playlist.trim()
    if playlist = "" then playlist = "this playlist"
    return "The server address for " + playlist + " changed. Sign in again to use this profile."
end function

function profileOwnSignInEventCurrent(event as object) as boolean
    if m.profileOwnSignInDialog = invalid then return false
    if not m.profileOwnSignInDialog.isSameNode(event.getRoSGNode()) then return false
    if not profileOwnSignInContextCurrent()
        cancelUserProfileOwnSignIn()
        return false
    end if
    return true
end function

sub onProfileOwnSignInChoice(event as object)
    if not profileOwnSignInEventCurrent(event) then return
    index = event.getData()
    if m.profileOwnSignInTask <> invalid or m.profileOwnSignInHold <> invalid then cancelUserProfileOwnSignIn() : return
    if index = 3 then cancelUserProfileOwnSignIn() : return
    context = m.profileOwnSignInContext
    if index = 0 or index = 1
        kind = "username"
        if index = 1 then kind = "password"
        closeProfileOwnSignInDialog()
        dialog = newProfileOwnSignInDialog(kind)
        dialog.title = "Username"
        dialog.keyboardDomain = "email"
        dialog.text = context.username
        dialog.textEditBox.voiceEnabled = true
        dialog.textEditBox.maxTextLength = 256
        if kind = "password"
            dialog.title = "Password"
            dialog.text = ""
            dialog.keyboardDomain = "password"
            dialog.textEditBox.maxTextLength = 512
            uiSecureTextInput(dialog.textEditBox)
        end if
        dialog.buttons = ["Save", "Cancel"]
        dialog.observeField("buttonSelected", "onProfileOwnSignInEdited")
        dialog.observeField("wasClosed", "onProfileOwnSignInClosed")
        m.profileOwnSignInDialog = dialog
        m.profileOwnSignInDialogKind = kind
        m.top.dialog = dialog
        dialog.setFocus(true)
    else if index = 2
        if lcase(context.username.trim()) <> lcase(context.target.username) or context.password = ""
            context.password = ""
            showProfileOwnSignInForm("Dispatcharr did not accept that username or password.")
            return
        end if
        task = invalid
        if m.profileOwnSignInTaskFactory <> invalid then task = m.profileOwnSignInTaskFactory()
        if task = invalid then task = CreateObject("roSGNode", "DispatcharrTask")
        tagTaskForCurrentUser(task)
        task.baseUrl = context.connection.url
        task.authMode = context.connection.authMode
        task.ownProfileSignIn = true
        task.verifyOnly = true
        task.expectedUsername = context.target.username
        task.expectedUserId = ""
        ' Default recovery is narrower than recreated non-default recovery:
        ' only the existing holder is qualified, even with legacy name-only data.
        if context.target.isDefault then task.expectedUserId = context.target.userId.toStr()
        task.apiKey = ""
        task.username = context.username.trim()
        task.password = context.password
        context.password = ""
        task.observeField("result", "onProfileOwnSignInResult")
        task.observeField("state", "onProfileOwnSignInState")
        m.profileOwnSignInTask = task
        showProfileOwnSignInForm("Signing in to Dispatcharr...")
        task.control = "RUN"
    end if
end sub

sub onProfileOwnSignInEdited(event as object)
    if not profileOwnSignInEventCurrent(event) then return
    kind = m.profileOwnSignInDialogKind
    if event.getData() = 0
        value = m.profileOwnSignInDialog.text
        if kind = "username" then m.profileOwnSignInContext.username = value.trim()
        if kind = "password" then m.profileOwnSignInContext.password = value
        value = ""
    else if kind = "password"
        m.profileOwnSignInContext.password = ""
    end if
    closeProfileOwnSignInDialog()
    showProfileOwnSignInForm()
end sub

sub onProfileOwnSignInResult(event as object)
    if not isCurrentTaskEvent(event, m.profileOwnSignInTask) then return
    if not profileOwnSignInContextCurrent() then cancelUserProfileOwnSignIn() : return
    context = m.profileOwnSignInContext
    result = event.getData()
    closeProfileOwnSignInTask()
    if type(result) <> "roAssociativeArray" then showProfileOwnSignInForm("Dispatcharr did not accept that username or password.") : return
    if result.ok <> true
        message = "Dispatcharr did not accept that username or password."
        if result.apiAccessRequired = true then message = "This account has no API key yet. Ask your Dispatcharr administrator to turn on API access for it."
        showProfileOwnSignInForm(message)
        return
    end if
    if context.activeRecovery = true and result.verifiedBaseUrl <> context.connection.url
        result.apiKey = ""
        showProfileOwnSignInForm("Dispatcharr did not accept that username or password.")
        return
    end if
    planned = userProfileOwnSignInPlan(context.connection, context.store, context.target.id, result, CreateObject("roDateTime").asSeconds(), context.childRecovery = true)
    if not planned.ok
        result.apiKey = ""
        showProfileOwnSignInForm("Could not safely save this profile. Existing credentials and data were retained.")
        return
    end if
    if m.requestGate <> invalid
        state = m.requestGate.snapshot
        if type(state) = "roAssociativeArray"
            if state.keys.count() > 0
                if beginProfileOwnSignInHeldCredential(result, requestGateCredentialHash(result.apiKey)) then return
            end if
        end if
    end if
    finishUserProfileOwnSignIn(result)
end sub

' Only a verified current own-password result reaches this boundary. The broker
' independently checks the credential lifecycle and captured hold generation.
' No raw key, bearer token or account response is put on the broker mailbox.
function beginProfileOwnSignInHeldCredential(result as object, hash as string) as boolean
    if not profileOwnSignInContextCurrent()
        result.apiKey = ""
        cancelUserProfileOwnSignIn()
        return true
    end if
    state = m.requestGate.snapshot
    if not state.keys.doesExist(hash) then return false
    context = m.profileOwnSignInContext
    if not context.holds.doesExist(hash)
        result.apiKey = ""
        showProfileOwnSignInForm("Profile access changed. Please sign in again.")
        return true
    end if
    captured = context.holds[hash].version
    if captured <> state.keys[hash].version
        result.apiKey = ""
        showProfileOwnSignInForm("Profile access changed. Please sign in again.")
        return true
    end if
    ticket = invalid
    if m.profileOwnSignInHoldFactory <> invalid then ticket = m.profileOwnSignInHoldFactory()
    if ticket = invalid then ticket = CreateObject("roSGNode", "RequestGateTicket")
    tagTaskForCurrentUser(ticket)
    ticket.id = CreateObject("roDeviceInfo").getRandomUUID()
    ticket.action = "own-verified"
    ticket.hash = hash
    ticket.holdVersion = captured
    ticket.credentialNonce = context.nonce
    ticket.observeField("result", "onProfileOwnSignInHoldResolved")
    user = result.verifiedUser
    context.pendingVerified = {ok: true, apiKey: result.apiKey, verifiedBaseUrl: result.verifiedBaseUrl, verifiedUser: {id: user.id, username: user.username, user_level: user.user_level, is_staff: user.is_staff = true, is_superuser: user.is_superuser = true}}
    ' Retain only commit facts and one wipeable raw-key field, not the bearer
    ' response's nested api_key or any other unused server/account payload.
    result.apiKey = ""
    result.verifiedUser = invalid
    m.profileOwnSignInHold = ticket
    m.profileOwnSignInHoldClock = CreateObject("roTimespan")
    m.profileOwnSignInHoldClock.mark()
    m.requestGate.request = ticket
    return true
end function

sub tickUserProfileOwnSignInHold()
    if m.profileOwnSignInHold = invalid or m.profileOwnSignInHoldClock = invalid then return
    if m.profileOwnSignInHoldClock.totalMilliseconds() < 5000 then return
    current = profileOwnSignInContextCurrent()
    context = m.profileOwnSignInContext
    cancelUserProfileOwnSignIn()
    if not current or context = invalid then return
    ' Retire the credential nonce, not just its observer: an old broker ticket
    ' processed after the deadline must also refuse. Reopen only the same own
    ' form under fresh admission so a lost reply does not require app restart.
    if beginUserProfileOwnSignIn(context.target.id, context.activeRecovery = true, context.childRecovery = true)
        if m.profileOwnSignInDialog <> invalid then showProfileOwnSignInForm("Could not verify profile access. Please try again.")
    end if
end sub

sub onProfileOwnSignInHoldResolved(event as object)
    if not isCurrentTaskEvent(event, m.profileOwnSignInHold) then return
    if not profileOwnSignInContextCurrent() then cancelUserProfileOwnSignIn() : return
    m.profileOwnSignInHold.unobserveField("result")
    m.profileOwnSignInHold = invalid
    m.profileOwnSignInHoldClock = invalid
    result = m.profileOwnSignInContext.pendingVerified
    m.profileOwnSignInContext.delete("pendingVerified")
    decision = event.getData()
    accepted = false
    if type(decision) = "roAssociativeArray" then accepted = decision.allowed = true
    if not accepted
        result.apiKey = ""
        showProfileOwnSignInForm("Profile access changed. Please sign in again.")
        return
    end if
    finishUserProfileOwnSignIn(result)
end sub

sub finishUserProfileOwnSignIn(result as object)
    if not profileOwnSignInContextCurrent() then cancelUserProfileOwnSignIn() : return
    context = m.profileOwnSignInContext
    saved = commitUserProfileOwnSignIn(m.registry, context.connection, context.store, context.target.id, result, CreateObject("roDateTime").asSeconds(), context.nonce, m.profileOwnSignInNonce, context.childRecovery = true)
    if not saved.ok
        result.apiKey = ""
        if saved.recoveryRequired = true
            m.userProfileRecoveryRequired = true
            retireUserProfileOwnSignIn()
            m.activeUserScope = invalid
            m.global.activeusersession = ""
            m.global.profilegateclosed = true
            m.profileGateCover.visible = true
            if type(m.top) = "roSGNode"
                m.top.findNode("profileGateMessage").text = "Saved profiles need recovery. Back exits AerioTV."
                requestGateFenceRenderers(m.top)
            end if
            return
        end if
        showProfileOwnSignInForm("Could not safely save this profile. Existing credentials and data were retained.")
        return
    end if
    if type(m.profileSessionKeys) <> "roAssociativeArray" then m.profileSessionKeys = {}
    m.profileSessionKeys[preferenceScope(context.connection.url + "|" + context.connection.id + "|" + context.target.id)] = result.apiKey
    result.apiKey = ""
    m.userProfileStore = saved.store
    markerSuffix = "|" + context.connection.id + "|" + context.target.id
    if right(textValue(m.childRejectedIdentity), len(markerSuffix)) = markerSuffix then m.childRejectedIdentity = ""
    if type(saved.preferenceStore) = "roAssociativeArray" then m.preferenceStore = saved.preferenceStore
    if context.activeRecovery = true
        key = m.profileSessionKeys[preferenceScope(context.connection.url + "|" + context.connection.id + "|" + context.target.id)]
        pin = context.pin
        retireUserProfileOwnSignIn()
        resetConnectionRuntime()
        applySelectedConnection()
        m.apiKey = key
        key = ""
        m.profileUnlockGrant = pin
        m.profileRefreshReload = true
        m.global.profilegateclosed = false
        m.profileGateCover.visible = false
        connectServer(true)
        return
    end if
    cancelUserProfileOwnSignIn()
    showNotice("Signed in. Select this profile when switching is available.")
end sub

sub onProfileOwnSignInState(event as object)
    if not isCurrentTaskEvent(event, m.profileOwnSignInTask) then return
    if event.getData() <> "done" and event.getData() <> "stop" then return
    if type(m.profileOwnSignInTask.result) = "roAssociativeArray" then return
    closeProfileOwnSignInTask()
    showProfileOwnSignInForm("Dispatcharr did not accept that username or password.")
end sub

sub onProfileOwnSignInClosed(event as object)
    if not profileOwnSignInEventCurrent(event) then return
    if m.profileOwnSignInDialogKind = "form"
        cancelUserProfileOwnSignIn()
    else
        if m.profileOwnSignInDialogKind = "password" then m.profileOwnSignInContext.password = ""
        closeProfileOwnSignInDialog()
        showProfileOwnSignInForm()
    end if
end sub

sub closeProfileOwnSignInDialog()
    if m.profileOwnSignInDialog = invalid then return
    dialog = m.profileOwnSignInDialog
    dialog.unobserveField("buttonSelected")
    dialog.unobserveField("wasClosed")
    if m.profileOwnSignInDialogKind <> "form"
        dialog.text = ""
        dialog.textEditBox.text = ""
    end if
    dialog.buttons = []
    dialog.close = true
    m.profileOwnSignInDialog = invalid
end sub

sub closeProfileOwnSignInTask()
    if m.profileOwnSignInTask = invalid then return
    task = m.profileOwnSignInTask
    task.unobserveField("result")
    task.unobserveField("state")
    cancelNetworkTask(task)
    task.password = ""
    task.apiKey = ""
    task.username = ""
    task.result = invalid
    m.profileOwnSignInTask = invalid
end sub

sub retireUserProfileOwnSignIn()
    if m.profileOwnSignInHold <> invalid then m.profileOwnSignInHold.unobserveField("result")
    m.profileOwnSignInHold = invalid
    m.profileOwnSignInHoldClock = invalid
    if m.profileOwnSignInContext <> invalid
        if type(m.profileOwnSignInContext.pendingVerified) = "roAssociativeArray" then m.profileOwnSignInContext.pendingVerified.apiKey = ""
    end if
    closeActiveUserProfileRecoveryPrompt()
    context = m.profileOwnSignInContext
    if context <> invalid and m.profilePinContext <> invalid and m.profilePinDialog <> invalid
        if m.profilePinContext.continuation = "own-signin" and m.profilePinContext.resume = context.nonce
            pad = m.profilePinDialog
            pad.unobserveField("buttonSelected")
            pad.unobserveField("wasClosed")
            pad.textEditBox.text = ""
            pad.close = true
            if type(pad) = "roSGNode"
                if pad.isSubtype("DirectionsPinPad") then m.top.removeChild(pad)
            end if
            m.profilePinDialog = invalid
            m.profilePinContext = invalid
            if m.profileGateClock <> invalid then m.profileGateClock.control = "stop"
        end if
    end if
    closeProfileOwnSignInDialog()
    closeProfileOwnSignInTask()
    if m.profileOwnSignInContext <> invalid then m.profileOwnSignInContext.password = ""
    m.profileOwnSignInContext = invalid
    m.profileOwnSignInNonce = ""
    if m.global <> invalid
        m.global.profileownsigninpending = false
        m.global.profileownsigninnonce = ""
    end if
end sub

sub cancelUserProfileOwnSignIn()
    context = m.profileOwnSignInContext
    retireUserProfileOwnSignIn()
    if context = invalid then return
    if context.activeRecovery = true
        if context.connection.id = m.selectedConnectionId and m.activeUserScope = invalid and currentUserSessionId() = context.nonce
            m.global.activeusersession = ""
            m.global.profilegateclosed = true
            m.profileGateCover.visible = true
            m.profileUnlockGrant = context.unlock
            if context.childRecovery = true then showUnavailableChildProfile()
        end if
        return
    end if
    if context.connection.id <> m.selectedConnectionId or not userProfileSameSession(context.scope, m.activeUserScope) then return
    live = loadUserProfileStore(m.registry, context.connection.id)
    before = invalid
    after = invalid
    for each profile in context.store.profiles
        if profile.id = context.store.active then before = profile
    end for
    if live.readOnly <> true and live.active = context.store.active
        for each profile in live.profiles
            if profile.id = live.active then after = profile
        end for
    end if
    callerAllowed = before <> invalid and after <> invalid and m.userProfileRecoveryRequired <> true and m.page = context.page
    connections = loadConnectionStore(m.registry)
    actualConnection = connectionStoreEntry(connections, context.connection.id)
    if connections.readOnly = true or connections.selected <> context.connection.id or actualConnection = invalid
        callerAllowed = false
    else
        if FormatJson(actualConnection) <> FormatJson(normalizeConnectionEntry(context.connection)) then callerAllowed = false
    end if
    if callerAllowed
        for each field in ["userId", "role", "pinType", "pinHash", "pinSalt"]
            if before[field] <> after[field] then callerAllowed = false
        end for
    end if
    if not callerAllowed
        if m.mediaPlayer <> invalid then resetMediaNavigation()
        m.userProfileStore = live
        m.userProfileRecoveryRequired = true
        m.profileUnlockGrant = invalid
        m.activeUserScope = invalid
        m.global.activeusersession = ""
        m.global.profilegateclosed = true
        m.profileGateCover.visible = true
        m.guide.active = false
        if type(m.top) = "roSGNode"
            m.top.findNode("profileGateMessage").text = "Saved profile access changed. Back exits AerioTV."
            requestGateFenceRenderers(m.top)
        end if
        return
    end if
    m.profileUnlockGrant = context.unlock
    m.profileGateCover.visible = context.covered
    m.global.profilegateclosed = context.closed
    if context.page = "guide"
        m.guide.active = context.guideActive
        m.guide.setFocus(true)
    else if m.settingsHub <> invalid
        m.settingsHub.setFocus(true)
    end if
end sub
