' Profile metadata UI. Every callback checks both its node and a fresh local
' lifecycle; registry commits independently recheck the captured store/grant.
sub openUserProfileManagement()
    if m.profileOwnSignInContext <> invalid then return
    if m.childRejectedDialog <> invalid then return
    connection = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if connection = invalid or connection.provider <> "dispatcharr" then return
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return
    m.userProfileStore = loadUserProfileStore(m.registry, connection.id)
    if m.userProfileStore.readOnly = true then showNotice("Saved profiles need recovery.") : return
    closeProfileManagementDialog()
    m.profileManagementNonce = CreateObject("roDeviceInfo").getRandomUUID()
    m.profileManagementSlot = connection.id
    m.profileManagementGrant = invalid
    m.profileManagementPending = invalid
    admin = userProfileLoadDeviceAdminPin(m.registry, connection.id)
    if not admin.ok then showNotice("PIN storage needs recovery.") : return
    if not userProfileManagementGrantMatches(m.userProfileStore, admin.record, invalid, m.profileManagementNonce)
        if not beginAdultProfilePinGate() then showNotice("This PIN type requires approved access on this Roku.")
        return
    end if
    showProfileManagementRoster()
end sub

sub onAdultProfileAuthorized()
    if not profileManagementContextCurrent() then return
    pending = m.profileManagementPending
    m.profileManagementPending = invalid
    if type(pending) = "roAssociativeArray"
        if pending.action = "baseline-add"
            current = profileBaselineContext()
            if current = invalid then return
            if not userProfileSameSession(pending.scope, current.scope) or pending.connectionRoot <> current.connectionRoot then return
            beginProfileBaselineAdd(true, pending.returnToSwitcher = true)
            return
        end if
        if pending.action = "remove-confirm"
            showProfileManagementRemoveConfirmation(pending.id)
            return
        end if
        showProfileManagementEditor(pending.id)
    else
        showProfileManagementRoster()
    end if
end sub

function profileManagementContextCurrent() as boolean
    if userProfileLocalId(m.profileManagementNonce) = "" then return false
    if m.profileManagementSlot <> m.selectedConnectionId then return false
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    if store.readOnly = true then return false
    if type(m.userProfileStore) <> "roAssociativeArray" then return false
    return store.active = m.userProfileStore.active
end function

function profileManagementAuthorized() as boolean
    if not profileManagementContextCurrent() then return false
    current = loadUserProfileStore(m.registry, m.selectedConnectionId)
    admin = userProfileLoadDeviceAdminPin(m.registry, m.selectedConnectionId)
    if not admin.ok then return false
    return userProfileManagementGrantMatches(current, admin.record, m.profileManagementGrant, m.profileManagementNonce)
end function

sub showProfileManagementRoster()
    if not profileManagementAuthorized() then return
    m.userProfileStore = loadUserProfileStore(m.registry, m.selectedConnectionId)
    choices = []
    for each profile in userProfileSorted(m.userProfileStore.profiles)
        label = profile.displayName
        if profile.id = m.userProfileStore.active then label += " (Active)"
        if profile.pinType <> "none" then label += " — PIN"
        choices.push({title: label, action: "edit", id: profile.id})
    end for
    choices.push({title: "Done", action: "done"})
    openProfileManagementChoices("Profiles", "Profiles belong to this Dispatcharr connection.", choices)
end sub

sub showProfileManagementEditor(id as string)
    if not profileManagementAuthorized() then return
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    for each profile in store.profiles
        if profile.id = id
            m.userProfileStore = store
            m.profileManagementTarget = id
            choices = [{title: "Rename", action: "name"}]
            if m.activeUserScope <> invalid and profile.id <> store.active then choices.unshift({title: "Switch to this profile", action: "switch"})
            if profile.userLevel < 10 and m.profileChildAccessReady = true then choices.push({title: "Role: " + profile.role, action: "role"})
            choices.push({title: "Avatar", action: "avatar"})
            if profile.pinType <> "none" and m.activeUserScope <> invalid then choices.push({title: "Remove PIN", action: "pin-remove"})
            if m.profileBaselineReady = true
                if profileServerAdminHint() then choices.push({title: "Channel Profiles", action: "server-channels"})
            end if
            if m.page = "profile-unavailable" and m.activeUserScope = invalid and profile.id <> store.active and userProfileFullAccess(profile.role) and not profile.addressHeld
                choices.unshift({title: "Switch to this profile", action: "switch-unavailable"})
            end if
            if not profile.isDefault and m.activeUserScope <> invalid then choices.push({title: "Remove", action: "remove"})
            choices.push({title: "Back", action: "roster"})
            caption = "Standard"
            if profile.role = "admin" then caption = "Admin"
            if profile.role = "child" then caption = "Child"
            if profile.id = store.active then caption = "Active — " + caption
            if profile.pinType <> "none" then caption += " — PIN"
            caption += chr(10) + profile.username
            openProfileManagementChoices(profile.displayName, caption, choices)
            return
        end if
    end for
end sub

sub openProfileManagementChoices(title as string, message as string, choices as object)
    closeProfileManagementDialog()
    dialog = CreateObject("roSGNode", "AerioDialog")
    dialog.title = title
    dialog.message = message
    buttons = []
    for each choice in choices
        buttons.push(choice.title)
    end for
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "onProfileManagementChoice")
    dialog.observeField("wasClosed", "onProfileManagementClosed")
    m.profileManagementDialog = dialog
    m.profileManagementChoices = choices
    m.profileManagementDialogNonce = m.profileManagementNonce
    captureProfileManagementDialogRoots()
    m.top.dialog = dialog
    dialog.setFocus(true)
end sub

function profileManagementEventCurrent(event as object) as boolean
    if m.profileManagementDialog = invalid then return false
    if not m.profileManagementDialog.isSameNode(event.getRoSGNode()) then return false
    roots = m.profileManagementDialogRoots
    if type(roots) <> "roAssociativeArray" then return false
    if roots.store <> m.registry.read(userProfileStoreKey(m.selectedConnectionId)) then return false
    if roots.connections <> m.registry.read("connectionsV1") then return false
    return m.profileManagementDialogNonce = m.profileManagementNonce and profileManagementContextCurrent()
end function

sub captureProfileManagementDialogRoots()
    m.profileManagementDialogRoots = {store: m.registry.read(userProfileStoreKey(m.selectedConnectionId)), connections: m.registry.read("connectionsV1")}
end sub

sub onProfileManagementChoice(event as object)
    if not profileManagementEventCurrent(event) then return
    if not profileManagementAuthorized() then closeProfileManagementDialog() : return
    index = event.getData()
    if index < 0 or index >= m.profileManagementChoices.count() then return
    choice = m.profileManagementChoices[index]
    closeProfileManagementDialog()
    action = choice.action
    if action = "done"
        m.profileManagementGrant = invalid
        m.profileManagementNonce = ""
        if m.page = "profile-unavailable" then showUnavailableChildProfile()
        return
    end if
    if action = "edit" then showProfileManagementEditor(choice.id) : return
    if action = "roster" then showProfileManagementRoster() : return
    if action = "remove-confirm" then commitProfileManagementRemoval() : return
    target = invalid
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    for each profile in store.profiles
        if profile.id = m.profileManagementTarget then target = profile
    end for
    if target = invalid then return
    m.userProfileStore = store
    if action = "server-channels"
        beginProfileServerAdmin(target.id)
    else if action = "switch"
        if openUserProfileSwitcher(target.id)
            model = m.profileSwitcher.model
            m.profileSwitcher.intent = {action: "switch", index: model.focus, uiNonce: model.uiNonce}
        else if not beginUserProfileSwitch(target.id)
            showNotice("Sign in as this profile to verify its own access before switching.")
        end if
    else if action = "remove"
        showProfileManagementRemoveConfirmation(target.id)
    else if action = "pin-remove"
        beginProfileManagementPinRemoval(target.id)
    else if action = "switch-unavailable"
        if not beginUserProfileSwitch(target.id, true) then showProfileManagementEditor(target.id)
    else if action = "name"
        dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
        dialog.title = "Profile name"
        dialog.text = target.displayName
        dialog.textEditBox.maxTextLength = 160
        dialog.buttons = ["Save", "Cancel"]
        dialog.observeField("buttonSelected", "onProfileManagementName")
        dialog.observeField("wasClosed", "onProfileManagementClosed")
        m.profileManagementDialog = dialog
        m.profileManagementDialogNonce = m.profileManagementNonce
        captureProfileManagementDialogRoots()
        m.top.dialog = dialog
        dialog.setFocus(true)
    else if action = "avatar"
        ' Split the long catalog into bounded native dialogs, not clipped rows.
        m.profileAvatarPage = 0
        showProfileAvatarPage()
    else if action = "icon"
        m.profileAvatarIcon = choice.value
        choices = []
        for each color in userProfileAvatarColors()
            choices.push({title: color, action: "color", value: color})
        end for
        openProfileManagementChoices("Avatar color", "Choose a color.", choices)
    else if action = "color"
        saveProfileManagementMetadata("avatar", {icon: m.profileAvatarIcon, color: choice.value})
    else if action = "icons-next"
        m.profileAvatarPage = 1 - m.profileAvatarPage
        showProfileAvatarPage()
    else if action = "earlier" or action = "later"
        delta = -1
        if action = "later" then delta = 1
        position = userProfileMoveDestination(store.profiles, target.id, delta)
        if position < 0 then showProfileManagementEditor(target.id) : return
        saveProfileManagementMetadata("order", position)
    else if action = "role"
        admin = userProfileLoadDeviceAdminPin(m.registry, m.selectedConnectionId)
        if not admin.ok then return
        if not userProfileMayEditMetadata(store, target.id, "role", admin.record, m.profileManagementGrant, m.profileManagementNonce)
            m.profileManagementPending = {id: target.id}
            if not beginAdultProfilePinGate() then showNotice("This PIN type requires approved access on this Roku.")
            return
        end if
        openProfileManagementChoices("Profile role", "Child restrictions require a working adult PIN exit path.", [{title: "Standard", action: "set-role", value: "user"}, {title: "Child", action: "set-role", value: "child"}, {title: "Cancel", action: "edit", id: target.id}])
    else if action = "set-role"
        saveProfileManagementMetadata("role", choice.value)
    end if
end sub

function profileManagementPinOwnerCurrent(context as dynamic) as boolean
    if type(context) <> "roAssociativeArray" then return false
    if context.nonce <> m.profileManagementNonce or context.page <> m.page then return false
    if not userProfileSameSession(context.scope, m.activeUserScope) then return false
    if currentUserSessionId() <> context.scope.sessionId then return false
    connections = loadConnectionStore(m.registry)
    entry = connectionStoreEntry(connections, context.connection.id)
    if connections.readOnly = true or connections.selected <> context.connection.id or entry = invalid then return false
    if FormatJson(entry) <> FormatJson(normalizeConnectionEntry(context.connection)) then return false
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true or store.active <> context.scope.profileId then return false
    previous = invalid
    current = invalid
    for each profile in context.store.profiles
        if profile.id = context.scope.profileId then previous = profile
    end for
    for each profile in store.profiles
        if profile.id = context.scope.profileId then current = profile
    end for
    if previous = invalid or current = invalid then return false
    if current.userId.toStr() <> context.scope.accountId then return false
    for each field in ["userId", "role", "pinType", "pinHash", "pinSalt", "addressHeld"]
        if previous[field] <> current[field] then return false
    end for
    return true
end function

function profileManagementPinContextCurrent(pin as object) as boolean
    context = m.profileManagementPinContext
    if not profileManagementPinOwnerCurrent(context) then return false
    if pin.resume <> context.nonce or pin.slot <> context.connection.id or pin.profile.id <> context.targetId then return false
    current = loadUserProfileStore(m.registry, context.connection.id)
    return FormatJson(current) = FormatJson(context.store)
end function

sub beginProfileManagementPinRemoval(id as string)
    if not profileManagementAuthorized() or m.activeUserScope = invalid then return
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    target = invalid
    for each profile in store.profiles
        if profile.id = id then target = profile
    end for
    if entry = invalid or target = invalid then return
    if target.pinType = "none" then return
    if userProfileFullAccess(target.role)
        for each profile in store.profiles
            if profile.role = "child" then showNotice("While a Child profile exists, Admin and Standard profiles keep a PIN.") : return
        end for
    end if
    m.profileManagementPinContext = {connection: entry, store: store, targetId: id, scope: m.activeUserScope, nonce: m.profileManagementNonce, page: m.page, unlock: m.profileUnlockGrant, covered: m.profileGateCover.visible, closed: m.global.profilegateclosed}
    if not beginProfilePinGate(target, "pin-remove", m.profileManagementNonce)
        m.profileManagementPinContext = invalid
        showNotice("This PIN type needs approved access on this Roku.")
    end if
end sub

sub coverProfileManagementRecovery(message as string)
    retireProfileManagement()
    m.userProfileRecoveryRequired = true
    m.global.profilegateclosed = true
    m.profileGateCover.visible = true
    if m.playingChannel <> invalid then stopPlayback()
    m.activeUserScope = invalid
    m.global.activeusersession = ""
    m.apiKey = ""
    m.guide.active = false
    m.top.findNode("profileGateMessage").text = message + " Back exits AerioTV."
end sub

sub onProfileManagementPinVerified(nonce as string)
    context = m.profileManagementPinContext
    if type(context) <> "roAssociativeArray" then return
    if nonce <> context.nonce then return
    if not profileManagementPinOwnerCurrent(context) then coverProfileManagementRecovery("Saved profile access changed.") : return
    current = loadUserProfileStore(m.registry, context.connection.id)
    if not userProfileSwitchAcceptPinStore(context.store, current, context.targetId, m.profileUnlockGrant)
        coverProfileManagementRecovery("Saved PIN protection changed.")
        return
    end if
    proof = m.profileUnlockGrant
    m.profileUnlockGrant = context.unlock
    m.profileManagementPinContext = invalid
    m.userProfileStore = current
    m.profileManagementTarget = context.targetId
    saveProfileManagementMetadata("pin-remove", proof)
    if context.targetId = current.active then m.profileUnlockGrant = invalid
end sub

sub cancelProfileManagementPinRemoval(nonce as string)
    context = m.profileManagementPinContext
    if type(context) <> "roAssociativeArray" then return
    if context.nonce <> nonce then return
    if not profileManagementPinOwnerCurrent(context) then coverProfileManagementRecovery("Saved profile access changed.") : return
    m.profileManagementPinContext = invalid
    m.profileUnlockGrant = context.unlock
    m.global.profilegateclosed = context.closed
    m.profileGateCover.visible = context.covered
    m.userProfileStore = loadUserProfileStore(m.registry, context.connection.id)
    showProfileManagementEditor(context.targetId)
end sub

sub showProfileManagementRemoveConfirmation(id as string)
    if not profileManagementAuthorized() or m.activeUserScope = invalid then return
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    target = invalid
    for each profile in store.profiles
        if profile.id = id then target = profile
    end for
    if entry = invalid or target = invalid then return
    if target.isDefault then return
    admin = userProfileLoadDeviceAdminPin(m.registry, entry.id)
    if not admin.ok then return
    if not userProfileMayEditMetadata(store, id, "remove", admin.record, m.profileManagementGrant, m.profileManagementNonce)
        m.userProfileStore = store
        m.profileManagementPending = {action: "remove-confirm", id: id}
        if not beginAdultProfilePinGate() then showNotice("Verify an Admin or Standard PIN before removing this profile.")
        return
    end if
    m.profileManagementTarget = id
    m.userProfileStore = store
    m.profileManagementRemovalContext = {connection: entry, connectionRoot: m.registry.read("connectionsV1"), store: store, targetId: id, scope: m.activeUserScope, nonce: m.profileManagementNonce, page: m.page}
    message = "Remove this profile from this playlist? Its local data will be removed. Other profiles stay unchanged."
    if id = store.active then message = "Stop playback and switch to the default profile before removing this profile? The default profile's own access and PIN are required."
    openProfileManagementChoices("Remove " + target.displayName + "?", message, [{title: "Remove", action: "remove-confirm"}, {title: "Cancel", action: "edit", id: id}])
end sub

sub commitProfileManagementRemoval()
    context = m.profileManagementRemovalContext
    m.profileManagementRemovalContext = invalid
    if type(context) <> "roAssociativeArray" then return
    if context.page <> m.page or userProfileGateClosed() or not profileManagementAuthorized() then return
    saved = commitManagedUserProfileRemoval(m.registry, context, CreateObject("roDateTime").asSeconds(), m.activeUserScope, m.profileManagementNonce, m.profileManagementGrant)
    if saved.needsDefaultSwitch
        target = invalid
        defaultId = ""
        for each profile in context.store.profiles
            if profile.isDefault then defaultId = profile.id
            if profile.id = context.targetId then target = profile
        end for
        if target <> invalid and defaultId <> ""
            if beginUserProfileSwitch(defaultId)
                if m.profileSwitchContext <> invalid then m.profileSwitchContext.afterRemoval = {id: target.id, userId: target.userId, username: target.username}
                return
            end if
        end if
        showNotice("Switch to the default profile using its own sign-in before removing this profile.")
        return
    end if
    if not saved.ok
        if saved.recoveryRequired = true then m.userProfileRecoveryRequired = true
        showNotice("Could not remove this profile safely. Existing profiles were retained.")
        return
    end if
    m.userProfileStore = saved.store
    m.preferenceStore = saved.preferences
    if m.profileBaselineReady = true then refreshUserProfileChrome()
    if type(m.profileSessionKeys) = "roAssociativeArray" then m.profileSessionKeys.delete(preferenceScope(context.connection.url + "|" + context.connection.id + "|" + context.targetId))
    showProfileManagementRoster()
end sub

sub resumeProfileManagementRemoval(expected as object)
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    matched = false
    for each profile in store.profiles
        if profile.id = expected.id and profile.userId = expected.userId and lcase(profile.username) = lcase(expected.username) then matched = true
    end for
    if not matched then showNotice("Profile changed. Open Manage Profiles again.") : return
    openUserProfileManagement()
    if m.adultPinDialog <> invalid
        m.profileManagementPending = {action: "remove-confirm", id: expected.id}
    else
        showProfileManagementRemoveConfirmation(expected.id)
    end if
end sub

sub showProfileAvatarPage()
    choices = []
    icons = userProfileAvatarIcons()
    start = m.profileAvatarPage * 7
    for i = start to start + 6
        if i < icons.count() then choices.push({title: icons[i], action: "icon", value: icons[i]})
    end for
    choices.push({title: "More icons", action: "icons-next"})
    openProfileManagementChoices("Avatar", "Choose a shared avatar icon.", choices)
end sub

sub onProfileManagementName(event as object)
    if not profileManagementEventCurrent(event) then return
    value = m.profileManagementDialog.text
    save = event.getData() = 0
    closeProfileManagementDialog()
    if save
        saveProfileManagementMetadata("name", value)
    else
        showProfileManagementEditor(m.profileManagementTarget)
    end if
end sub

sub saveProfileManagementMetadata(operation as string, value as dynamic)
    if not profileManagementAuthorized() then return
    connection = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    result = commitUserProfileMetadataEdit(m.registry, connection, m.userProfileStore, m.profileManagementTarget, operation, value, m.profileManagementGrant, m.profileManagementDialogNonce, m.profileManagementNonce, CreateObject("roDateTime").asSeconds())
    if result.ok
        m.userProfileStore = result.store
        if operation = "role" and m.profileManagementTarget = result.store.active
            ' Re-admit the current holder under its new role; old views/tasks
            ' must not retain adult actions after a Child transition.
            reloadManagedUserProfile()
            return
        end if
        if m.profileBaselineReady = true then refreshUserProfileChrome()
        if m.page = "settings" then refreshSettingsHub()
    else
        if result.recoveryRequired = true then coverProfileManagementRecovery("Saved profiles need recovery.") : return
        showNotice("Could not save this profile safely. " + textValue(result.reason))
    end if
    showProfileManagementEditor(m.profileManagementTarget)
end sub

sub reloadManagedUserProfile()
    if m.activeUserScope = invalid or textValue(m.apiKey) = "" then return
    preserveSubmittedRecording()
    cancelRecordFlow()
    if not persistCurrentUserProfilePreferences()
        coverProfileManagementRecovery("Could not preserve this profile before reloading.")
        return
    end if
    retireProfileManagement()
    ' connectServer owns re-admission/retirement. Resetting here would erase the
    ' selected holder's own key and could not safely be repaired from connKey.
    m.profileRefreshReload = true
    connectServer(true)
end sub

sub onProfileManagementClosed(event as object)
    if not profileManagementEventCurrent(event) then return
    closeProfileManagementDialog()
    m.profileManagementGrant = invalid
    m.profileManagementNonce = ""
    m.profileManagementRemovalContext = invalid
    m.profileManagementPinContext = invalid
    if m.page = "profile-unavailable" then showUnavailableChildProfile()
end sub

sub closeProfileManagementDialog()
    m.profileManagementChoices = []
    if m.profileManagementDialog = invalid then return
    for each field in ["buttonSelected", "wasClosed"]
        m.profileManagementDialog.unobserveField(field)
    end for
    dialog = m.profileManagementDialog
    dialog.close = true
    m.profileManagementDialog = invalid
    if m.top <> invalid
        if m.top.dialog <> invalid
            if m.top.dialog.isSameNode(dialog) then m.top.dialog = invalid
        end if
    end if
end sub

sub retireProfileManagement()
    closeProfileManagementDialog()
    closeAdultProfilePinGate()
    m.profileManagementGrant = invalid
    m.profileManagementPending = invalid
    m.profileManagementRemovalContext = invalid
    m.profileManagementPinContext = invalid
    m.profileManagementNonce = ""
    m.profileManagementSlot = ""
    m.profileManagementTarget = ""
    m.profileManagementChoices = []
end sub
