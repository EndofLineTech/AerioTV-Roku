' The held/refused nondefault Child has no usable outgoing authentication.
' Other Child launch/keyless/default recovery paths remain fenced separately.
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

function showUnavailableChildProfile() as boolean
    if m.userProfileRecoveryRequired = true or m.activeUserScope <> invalid or m.apiKey <> "" then return false
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid or entry.provider <> "dispatcharr" then return false
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true then return false
    target = invalid
    for each profile in store.profiles
        if profile.id = store.active then target = profile
    end for
    if target = invalid then return false
    if target.role <> "child" or target.isDefault then return false
    if target.pinType <> "none"
        if not userProfilePinGrantMatches(m.profileUnlockGrant, entry.id, target) then return false
    end if
    rejected = m.childRejectedIdentity = entry.url + "|" + entry.id + "|" + target.id
    if not target.addressHeld and not rejected then return false
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
    dialog = CreateObject("roSGNode", "AerioDialog")
    dialog.title = "Could not reach your Dispatcharr server"
    dialog.message = "Manage Profiles requires a PIN from an Admin or Standard profile. Back exits AerioTV."
    dialog.buttons = ["Manage Profiles"]
    dialog.observeField("buttonSelected", "onUnavailableChildChoice")
    dialog.observeField("wasClosed", "onUnavailableChildClosed")
    m.childUnavailableContext = {connection: FormatJson(normalizeConnectionEntry(entry)), slot: entry.id, roster: m.registry.read(userProfileStoreKey(entry.id))}
    m.childUnavailableDialog = dialog
    m.top.dialog = dialog
    dialog.setFocus(true)
    return true
end function

sub onUnavailableChildChoice(event as object)
    if m.childUnavailableDialog = invalid or m.childUnavailableContext = invalid then return
    if not m.childUnavailableDialog.isSameNode(event.getRoSGNode()) then return
    context = m.childUnavailableContext
    if event.getData() <> 0 or m.page <> "profile-unavailable" or not userProfileGateClosed() then return
    if m.activeUserScope <> invalid or m.apiKey <> "" or context.slot <> m.selectedConnectionId then return
    connections = loadConnectionStore(m.registry)
    entry = connectionStoreEntry(connections, context.slot)
    if connections.readOnly = true or connections.selected <> context.slot or entry = invalid then return
    if FormatJson(entry) <> context.connection or m.registry.read(userProfileStoreKey(entry.id)) <> context.roster then return
    closeUnavailableChildDialog()
    openUserProfileManagement()
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
end sub
