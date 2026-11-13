' Profile metadata UI. Every callback checks both its node and a fresh local
' lifecycle; registry commits independently recheck the captured store/grant.
sub openUserProfileManagement()
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
    for each profile in m.userProfileStore.profiles
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
            choices = [{title: "Rename", action: "name"}, {title: "Avatar", action: "avatar"}, {title: "Move earlier", action: "earlier"}, {title: "Move later", action: "later"}]
            if profile.userLevel < 10 then choices.push({title: "Role: " + profile.role, action: "role"})
            choices.push({title: "Back", action: "roster"})
            openProfileManagementChoices(profile.displayName, "Changes apply only to this connection's profile.", choices)
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
    m.top.dialog = dialog
    dialog.setFocus(true)
end sub

function profileManagementEventCurrent(event as object) as boolean
    if m.profileManagementDialog = invalid then return false
    if not m.profileManagementDialog.isSameNode(event.getRoSGNode()) then return false
    return m.profileManagementDialogNonce = m.profileManagementNonce and profileManagementContextCurrent()
end function

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
        return
    end if
    if action = "edit" then showProfileManagementEditor(choice.id) : return
    if action = "roster" then showProfileManagementRoster() : return
    target = invalid
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    for each profile in store.profiles
        if profile.id = m.profileManagementTarget then target = profile
    end for
    if target = invalid then return
    m.userProfileStore = store
    if action = "name"
        dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
        dialog.title = "Profile name"
        dialog.text = target.displayName
        dialog.textEditBox.maxTextLength = 160
        dialog.buttons = ["Save", "Cancel"]
        dialog.observeField("buttonSelected", "onProfileManagementName")
        dialog.observeField("wasClosed", "onProfileManagementClosed")
        m.profileManagementDialog = dialog
        m.profileManagementDialogNonce = m.profileManagementNonce
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
        position = target.order - 1
        if action = "later" then position = target.order + 1
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
    else
        showNotice("Could not save this profile safely. " + textValue(result.reason))
    end if
    showProfileManagementEditor(m.profileManagementTarget)
end sub

sub onProfileManagementClosed(event as object)
    if not profileManagementEventCurrent(event) then return
    closeProfileManagementDialog()
    m.profileManagementGrant = invalid
    m.profileManagementNonce = ""
end sub

sub closeProfileManagementDialog()
    if m.profileManagementDialog = invalid then return
    for each field in ["buttonSelected", "wasClosed"]
        m.profileManagementDialog.unobserveField(field)
    end for
    m.profileManagementDialog.close = true
    m.profileManagementDialog = invalid
end sub

sub retireProfileManagement()
    closeProfileManagementDialog()
    closeAdultProfilePinGate()
    m.profileManagementGrant = invalid
    m.profileManagementPending = invalid
    m.profileManagementNonce = ""
    m.profileManagementSlot = ""
    m.profileManagementTarget = ""
    m.profileManagementChoices = []
end sub
