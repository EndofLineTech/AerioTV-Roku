' Developer baseline entry point. No flags enable sync writes or PIN creation.
function profileBaselineContext() as dynamic
    if m.profileBaselineReady <> true or m.busy = true or userProfileGateClosed() then return invalid
    if m.page <> "guide" and m.page <> "settings" then return invalid
    if m.profileOwnSignInContext <> invalid or m.profileSwitchContext <> invalid then return invalid
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return invalid
    scope = m.activeUserScope
    if not userProfileSameSession(scope, scope) or textValue(m.apiKey) = "" then return invalid
    if scope.sessionId <> currentUserSessionId() then return invalid
    connections = loadConnectionStore(m.registry)
    entry = connectionStoreEntry(connections, m.selectedConnectionId)
    if connections.readOnly = true or connections.selected <> m.selectedConnectionId or entry = invalid then return invalid
    if entry.provider <> "dispatcharr" or entry.url <> normalizeBaseUrl(m.baseUrl) then return invalid
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true or store.active <> scope.profileId or scope.playlistId <> entry.id then return invalid
    if scope.preferenceIdentity <> connectionPreferenceIdentity(entry, scope.accountId) then return invalid
    for each profile in store.profiles
        if profile.id = store.active
            if profile.userId.toStr() <> scope.accountId or not userProfileFullAccess(profile.role) or profile.addressHeld then return invalid
        end if
    end for
    if not requestGateAccessAllowed(entry.url, m.apiKey) then return invalid
    return {connection: entry, store: store, scope: scope, connectionRoot: m.registry.read("connectionsV1"), storeRoot: m.registry.read(userProfileStoreKey(entry.id))}
end function

sub openProfileBaselineMenu()
    context = profileBaselineContext()
    if context = invalid then return
    closeProfileBaselineMenu()
    choices = []
    for each profile in userProfileSorted(context.store.profiles)
        title = profile.displayName
        if profile.id = context.store.active then title += " (Active)"
        choices.push({title: title, action: "switch", id: profile.id})
    end for
    choices.push({title: "Add Profile", action: "add"})
    choices.push({title: "Manage Profiles", action: "manage"})
    title = "Ask who is watching at launch: Off"
    if context.store.askAtLaunch then title = "Ask who is watching at launch: On"
    choices.push({title: title, action: "ask"})
    choices.push({title: "Done", action: "done"})
    dialog = CreateObject("roSGNode", "AerioDialog")
    dialog.title = "Profiles — baseline"
    dialog.message = "Choose a profile or add another Dispatcharr login. Each profile uses its own credentials; Sync follows this TV's saved choice."
    buttons = []
    for each choice in choices
        buttons.push(choice.title)
    end for
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "onProfileBaselineChoice")
    dialog.observeField("wasClosed", "onProfileBaselineClosed")
    m.profileBaselineMenu = dialog
    m.profileBaselineMenuContext = context
    m.profileBaselineMenuChoices = choices
    m.top.dialog = dialog
    dialog.setFocus(true)
end sub

sub closeProfileBaselineMenu()
    dialog = m.profileBaselineMenu
    m.profileBaselineMenu = invalid
    m.profileBaselineMenuContext = invalid
    m.profileBaselineMenuChoices = []
    if dialog = invalid then return
    dialog.unobserveField("buttonSelected")
    dialog.unobserveField("wasClosed")
    dialog.close = true
    if m.top.dialog <> invalid
        if m.top.dialog.isSameNode(dialog) then m.top.dialog = invalid
    end if
end sub

sub onProfileBaselineClosed(event as object)
    if m.profileBaselineMenu = invalid then return
    if not m.profileBaselineMenu.isSameNode(event.getRoSGNode()) then return
    closeProfileBaselineMenu()
end sub

sub onProfileBaselineChoice(event as object)
    if m.profileBaselineMenu = invalid then return
    if not m.profileBaselineMenu.isSameNode(event.getRoSGNode()) then return
    before = m.profileBaselineMenuContext
    current = profileBaselineContext()
    index = event.getData()
    if current = invalid or before = invalid then closeProfileBaselineMenu() : return
    if not userProfileSameSession(before.scope, current.scope) or before.connectionRoot <> current.connectionRoot or before.storeRoot <> current.storeRoot then closeProfileBaselineMenu() : return
    if not userProfileInteger(index) then return
    if index < 0 or index >= m.profileBaselineMenuChoices.count() then return
    choice = m.profileBaselineMenuChoices[index]
    closeProfileBaselineMenu()
    if choice.action = "done" then return
    if choice.action = "manage" then openUserProfileManagement() : return
    if choice.action = "ask"
        candidate = setCanonicalPreference(current.store, "askAtLaunch", not current.store.askAtLaunch)
        saved = commitUserProfileStore(m.registry, current.store, candidate, {}, current.connection.remember)
        if not saved.ok then showNotice("Could not save the launch choice.") : return
        m.userProfileStore = candidate
        openProfileBaselineMenu()
        return
    end if
    if choice.action = "add" then beginProfileBaselineAdd() : return
    settings = loadDispatcharrSyncSettings(m.registry)
    if not settings.ok or settings.enabled then showNotice("This baseline supports local switching while Dispatcharr Sync is off.") : return
    if choice.action = "switch"
        if choice.id = current.store.active then return
        if not beginUserProfileSwitch(choice.id)
            if not beginUserProfileOwnSignIn(choice.id) then showNotice("This profile cannot be selected in the baseline yet.")
        end if
    end if
end sub

sub beginProfileBaselineAdd(admitted = false as boolean, returnToSwitcher = false as boolean, returnToPhoneOnboarding = false as boolean)
    context = profileBaselineContext()
    if context = invalid then return
    if context.store.profiles.count() >= 4 then showNotice("This playlist already has four profiles.") : return
    settings = loadDispatcharrSyncSettings(m.registry)
    if not settings.ok then showNotice("Sync settings need recovery before adding a profile.") : return
    if not userProfileAddSyncAvailable(settings, m.profileScheduledSyncTask, m.profileSyncWriteTask)
        showNotice("Sync is finishing. Try Add Profile again in a moment.")
        return
    end if
    admin = userProfileLoadDeviceAdminPin(m.registry, context.connection.id)
    if not admin.ok then showNotice("PIN storage needs recovery.") : return
    holders = userProfileAdultPinHolders(context.store.profiles, admin.record)
    if holders.count() > 0 and not admitted
        m.profileManagementNonce = CreateObject("roDeviceInfo").getRandomUUID()
        m.profileManagementSlot = context.connection.id
        m.userProfileStore = context.store
        m.profileManagementGrant = invalid
        m.profileManagementPending = {action: "baseline-add", scope: context.scope, connectionRoot: context.connectionRoot, returnToSwitcher: returnToSwitcher, returnToPhoneOnboarding: returnToPhoneOnboarding}
        if not beginAdultProfilePinGate() then showNotice("This PIN type needs approved access on this Roku.")
        return
    end if
    if not userProfileManagementGrantMatches(context.store, admin.record, m.profileManagementGrant, textValue(m.profileManagementNonce), true) then return
    retireProfileRequestBinding()
    nonce = CreateObject("roDeviceInfo").getRandomUUID()
    target = {id: CreateObject("roDeviceInfo").getRandomUUID(), username: "", isDefault: false, addressHeld: false, pinType: "none"}
    m.profileOwnSignInNonce = nonce
    m.profileOwnSignInContext = {adding: true, nonce: nonce, connection: context.connection, store: context.store, scope: context.scope, target: target, page: m.page, guideActive: m.guide.active, covered: m.profileGateCover.visible, closed: m.global.profilegateclosed, unlock: m.profileUnlockGrant, username: "", password: "", addGrant: m.profileManagementGrant, holds: {}}
    m.profileOwnSignInContext.returnToSwitcher = returnToSwitcher
    m.profileOwnSignInContext.returnToPhoneOnboarding = returnToPhoneOnboarding
    m.profileOwnSignInContext.addRosterRows = []
    m.profileOwnSignInContext.addRosterScope = context.scope
    if userProfileSameSession(m.profileRosterSuggestionScope, context.scope) and settings.profiles
        if type(m.profileRosterSuggestions) = "roArray"
            for each row in m.profileRosterSuggestions
                if type(row) = "roAssociativeArray"
                    if type(row.raw) = "roArray" then m.profileOwnSignInContext.addRosterRows.push(row.raw)
                end if
            end for
        end if
    end if
    if m.requestGate <> invalid then m.profileOwnSignInContext.holds = requestGateCopy(m.requestGate.snapshot.keys)
    m.global.profileownsigninpending = true
    m.global.profileownsigninnonce = nonce
    m.guide.active = false
    showProfileOwnSignInForm()
end sub

sub beginBaselineAddFromStartup()
    if m.profileBaselineReady <> true or m.profilePickerContext = invalid then return
    m.profileBaselinePendingAdd = true
    m.profileLaunchPickerResolved = true
    closeUserProfileLaunchPicker()
    if m.startupDialogOpen = true then completeStartupDialog()
    resumeUserProfileLaunch()
end sub
