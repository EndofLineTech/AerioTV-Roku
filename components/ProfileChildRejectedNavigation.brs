' Memory-only rejected-key UI belongs to one Child holder and hold generation.
' It never supplies an authenticated outgoing scope or a general setup route.
sub captureChildRejectedEvidence(entry as object, store as object, profileId as string)
    m.childRejectedEvidence = invalid
    if m.apiKey = "" then return
    target = invalid
    for each profile in store.profiles
        if profile.id = profileId then target = profile
    end for
    if target = invalid then return
    if target.role <> "child" or store.active <> target.id then return
    hash = requestGateCredentialHash(m.apiKey)
    if not requestGateDigestValid(hash) then return
    version = 0
    if m.requestGate <> invalid
        state = m.requestGate.snapshot
        if type(state) = "roAssociativeArray"
            if state.keys.doesExist(hash) then version = state.keys[hash].version
        end if
    end if
    m.childRejectedEvidence = {slot: entry.id, base: entry.url, profile: target.id, account: target.userId.toStr(), username: target.username, hash: hash, version: version, nonce: CreateObject("roDeviceInfo").getRandomUUID()}
end sub

function childRejectedPromptIdentity(access as object) as string
    evidence = m.childRejectedEvidence
    if type(evidence) <> "roAssociativeArray" or access.keyRejected <> true then return ""
    if evidence.slot <> access.entry.id or evidence.base <> access.entry.url or evidence.profile <> access.target.id then return ""
    if evidence.account <> access.target.userId.toStr() or lcase(evidence.username) <> lcase(access.target.username) then return ""
    if m.childRejectedIdentity <> evidence.base + "|" + evidence.slot + "|" + evidence.profile then return ""
    if not requestGateDigestValid(evidence.hash) or not userProfileInteger(evidence.version) then return ""
    generation = ""
    if evidence.version > 0
        if m.requestGate = invalid then return ""
        state = m.requestGate.snapshot
        if type(state) <> "roAssociativeArray" then return ""
        if not state.keys.doesExist(evidence.hash) then return ""
        if state.keys[evidence.hash].version <> evidence.version then return ""
        generation = evidence.version.toStr()
    else
        if evidence.version <> 0 or userProfileLocalId(evidence.nonce) = "" then return ""
        generation = evidence.nonce
    end if
    return preferenceScope(evidence.base + "|" + evidence.slot + "|" + evidence.profile + "|" + evidence.hash + "|" + generation)
end function

function showChildRejectedKeyPrompt() as boolean
    if m.profileChildAccessReady <> true or m.profileOwnSignInContext <> invalid or m.profileSwitchContext <> invalid then return false
    if m.activeUserScope <> invalid or m.apiKey <> "" then return false
    if m.page <> "profile-unavailable" or not userProfileGateClosed() then return false
    access = unavailableChildAccessContext()
    if access = invalid then return false
    if access.entry.id <> m.selectedConnectionId then return false
    identity = childRejectedPromptIdentity(access)
    if identity = "" then return false
    if type(m.childRejectedShown) <> "roAssociativeArray" then m.childRejectedShown = {}
    owner = preferenceScope(access.entry.url + "|" + access.entry.id + "|" + access.target.id)
    if m.childRejectedShown.doesExist(owner)
        if m.childRejectedShown[owner] = identity then return false
    end if
    plan = userProfileChildRejectedPrompt(access.target, access.entry.name, access.plan.signIn)
    if plan = invalid then return false
    closeChildRejectedKeyDialog()
    closeUnavailableChildDialog()
    dialog = invalid
    if m.childRejectedDialogFactory <> invalid then dialog = m.childRejectedDialogFactory()
    if dialog = invalid then dialog = CreateObject("roSGNode", "AerioDialog")
    dialog.title = plan.title
    dialog.message = plan.message
    dialog.buttons = plan.buttons
    dialog.observeField("buttonSelected", "onChildRejectedKeyChoice")
    dialog.observeField("wasClosed", "onChildRejectedKeyClosed")
    m.childRejectedContext = {identity: identity, connection: FormatJson(normalizeConnectionEntry(access.entry)), roster: m.registry.read(userProfileStoreKey(access.entry.id)), signIn: plan.signIn, buttonCount: plan.buttons.count()}
    m.childRejectedDialog = dialog
    m.childRejectedShown[owner] = identity
    m.top.dialog = dialog
    dialog.setFocus(true)
    return true
end function

function currentChildRejectedPromptAccess() as dynamic
    context = m.childRejectedContext
    if context = invalid or m.page <> "profile-unavailable" or not userProfileGateClosed() then return invalid
    if m.profileOwnSignInContext <> invalid or m.profileSwitchContext <> invalid then return invalid
    if m.activeUserScope <> invalid or m.apiKey <> "" then return invalid
    access = unavailableChildAccessContext()
    if access = invalid then return invalid
    if access.entry.id <> m.selectedConnectionId then return invalid
    if context.identity <> childRejectedPromptIdentity(access) then return invalid
    if context.connection <> FormatJson(normalizeConnectionEntry(access.entry)) then return invalid
    if context.roster <> m.registry.read(userProfileStoreKey(access.entry.id)) then return invalid
    return access
end function

sub onChildRejectedKeyChoice(event as object)
    if m.childRejectedDialog = invalid or m.childRejectedContext = invalid then return
    if not m.childRejectedDialog.isSameNode(event.getRoSGNode()) then return
    index = event.getData()
    if not userProfileInteger(index) then return
    if index < 0 or index >= m.childRejectedContext.buttonCount then return
    access = currentChildRejectedPromptAccess()
    signIn = m.childRejectedContext.signIn and index = 0
    closeChildRejectedKeyDialog()
    if access = invalid then return
    if signIn and access.plan.signIn
        if beginUserProfileOwnSignIn(access.target.id, true, true) then return
    end if
    showUnavailableChildProfile()
end sub

sub onChildRejectedKeyClosed(event as object)
    if m.childRejectedDialog = invalid then return
    if not m.childRejectedDialog.isSameNode(event.getRoSGNode()) then return
    access = currentChildRejectedPromptAccess()
    closeChildRejectedKeyDialog()
    if access <> invalid then showUnavailableChildProfile()
end sub

sub closeChildRejectedKeyDialog()
    if m.childRejectedDialog <> invalid
        m.childRejectedDialog.unobserveField("buttonSelected")
        m.childRejectedDialog.unobserveField("wasClosed")
        m.childRejectedDialog.close = true
    end if
    m.childRejectedDialog = invalid
    m.childRejectedContext = invalid
end sub
