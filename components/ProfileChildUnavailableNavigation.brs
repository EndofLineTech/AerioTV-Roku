' Unavailable Child controls never invent an authenticated outgoing scope.
' Broader Retry/own-form actions remain behind the private readiness seam.
function drawChildProfileLoading() as boolean
    if m.profileChildAccessReady <> true or m.busy <> true or userProfileGateClosed() then return false
    if not selectedUserProfileIsChild() then return false
    m.childConnectionLoading = true
    m.page = "profile-loading"
    m.screen.visible = false
    m.guide.active = false
    m.guide.visible = false
    m.profileGateCover.visible = true
    ' Loading is not a PIN gate: incoming auth/roster/lineup Tasks may run,
    ' while old views and all remote renderers remain behind the scrim.
    m.global.profileswitchpending = true
    m.statusLabel = m.top.findNode("profileGateMessage")
    m.statusLabel.text = m.status
    requestGateFenceRenderers(m.top)
    return true
end function

function unavailableChildAccessContext() as dynamic
    if m.userProfileRecoveryRequired = true or m.activeUserScope <> invalid or m.apiKey <> "" then return invalid
    connections = loadConnectionStore(m.registry)
    if connections.readOnly = true or connections.selected <> m.selectedConnectionId then return invalid
    entry = connectionStoreEntry(connections, m.selectedConnectionId)
    if entry = invalid or entry.provider <> "dispatcharr" then return invalid
    if normalizeBaseUrl(m.baseUrl) <> entry.url then return invalid
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true then return invalid
    target = invalid
    for each profile in store.profiles
        if profile.id = store.active then target = profile
    end for
    if target = invalid then return invalid
    if target.role <> "child" then return invalid
    if target.pinType <> "none"
        if not userProfilePinGrantMatches(m.profileUnlockGrant, entry.id, target) then return invalid
    end if
    rejected = m.childRejectedIdentity = entry.url + "|" + entry.id + "|" + target.id
    memory = {}
    name = userProfileChildCredentialName(entry, target)
    if name = "" then return invalid
    if type(m.profileSessionKeys) = "roAssociativeArray"
        bucket = preferenceScope(entry.url + "|" + entry.id + "|" + target.id)
        if m.profileSessionKeys.doesExist(bucket) then memory[name] = m.profileSessionKeys[bucket]
    end if
    present = userProfileChildKeyPresent(m.registry, entry, target, memory)
    credential = userProfileCredential(m.registry, entry, store, memory)
    if credential.ok and m.requestGate <> invalid
        state = m.requestGate.snapshot
        if type(state) = "roAssociativeArray"
            if type(state.keys) <> "roAssociativeArray" then return invalid
            rejected = rejected or state.keys.doesExist(requestGateCredentialHash(credential.key))
        end if
    end if
    if m.profileChildAccessReady <> true
        if target.isDefault or not target.addressHeld and not rejected then return invalid
    end if
    return {entry: entry, store: store, target: target, plan: userProfileChildAccessPlan(target, present, rejected), credential: credential}
end function

function showUnavailableChildProfile() as boolean
    access = unavailableChildAccessContext()
    if access = invalid then return false
    entry = access.entry
    closeUnavailableChildDialog()
    m.page = "profile-unavailable"
    m.screen.visible = false
    m.guide.active = false
    m.guide.visible = false
    m.busy = false
    m.global.activeusersession = ""
    m.global.profilegateclosed = true
    m.profileGateCover.visible = true
    m.top.findNode("profileGateMessage").text = "Could not reach your Dispatcharr server. Back exits AerioTV."
    dialog = invalid
    if m.childUnavailableDialogFactory <> invalid then dialog = m.childUnavailableDialogFactory()
    if dialog = invalid then dialog = CreateObject("roSGNode", "AerioDialog")
    dialog.title = "Could not reach your Dispatcharr server"
    dialog.message = "Manage Profiles requires a PIN from an Admin or Standard profile. Back exits AerioTV."
    choices = []
    if m.profileChildAccessReady = true
        if access.plan.retry then choices.push({title: "Retry", action: "retry"})
        if access.plan.signIn then choices.push({title: "Sign in to Dispatcharr", action: "sign-in"})
    end if
    choices.push({title: "Manage Profiles", action: "manage"})
    buttons = []
    for each choice in choices
        buttons.push(choice.title)
    end for
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "onUnavailableChildChoice")
    dialog.observeField("wasClosed", "onUnavailableChildClosed")
    m.childUnavailableContext = {connection: FormatJson(normalizeConnectionEntry(entry)), slot: entry.id, roster: m.registry.read(userProfileStoreKey(entry.id))}
    m.childUnavailableChoices = choices
    m.childUnavailableDialog = dialog
    m.top.dialog = dialog
    dialog.setFocus(true)
    return true
end function

sub onUnavailableChildChoice(event as object)
    if m.childUnavailableDialog = invalid or m.childUnavailableContext = invalid then return
    if not m.childUnavailableDialog.isSameNode(event.getRoSGNode()) then return
    context = m.childUnavailableContext
    index = event.getData()
    if not userProfileInteger(index) then return
    if index < 0 or index >= m.childUnavailableChoices.count() then return
    if m.page <> "profile-unavailable" or not userProfileGateClosed() then return
    if m.activeUserScope <> invalid or m.apiKey <> "" or context.slot <> m.selectedConnectionId then return
    connections = loadConnectionStore(m.registry)
    entry = connectionStoreEntry(connections, context.slot)
    if connections.readOnly = true or connections.selected <> context.slot or entry = invalid then return
    if FormatJson(entry) <> context.connection or m.registry.read(userProfileStoreKey(entry.id)) <> context.roster then return
    access = unavailableChildAccessContext()
    if access = invalid then return
    action = m.childUnavailableChoices[index].action
    allowed = action = "manage"
    if m.profileChildAccessReady = true
        if action = "retry" then allowed = access.plan.retry and access.credential.ok
        if action = "sign-in" then allowed = access.plan.signIn
    end if
    if not allowed then showUnavailableChildProfile() : return
    closeUnavailableChildDialog()
    if action = "manage"
        openUserProfileManagement()
    else if action = "retry"
        m.apiKey = access.credential.key
        m.baseUrl = entry.url
        m.global.profilegateclosed = false
        m.profileGateCover.visible = true
        m.profileRefreshReload = true
        connectServer(true)
    else if action = "sign-in"
        if not beginUserProfileOwnSignIn(access.target.id, true, true) then showUnavailableChildProfile()
    end if
end sub

sub onUnavailableChildClosed(event as object)
    if m.childUnavailableDialog = invalid then return
    if not m.childUnavailableDialog.isSameNode(event.getRoSGNode()) then return
    closeUnavailableChildDialog()
    m.top.exitRequested = true
end sub

sub closeUnavailableChildDialog()
    if m.childUnavailableDialog <> invalid
        m.childUnavailableDialog.unobserveField("buttonSelected")
        m.childUnavailableDialog.unobserveField("wasClosed")
        m.childUnavailableDialog.close = true
    end if
    m.childUnavailableDialog = invalid
    m.childUnavailableContext = invalid
    m.childUnavailableChoices = []
end sub
