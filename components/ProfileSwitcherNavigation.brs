' Authenticated switcher. Startup selection retains its separate no-actor path.
sub refreshUserProfileChrome()
    descriptor = invalid
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry <> invalid and type(m.userProfileStore) = "roAssociativeArray"
        descriptor = userProfileSwitcherDescriptor(m.userProfileStore, m.activeUserScope, entry.provider, m.profileBaselineReady)
    end if
    if m.guide <> invalid then m.guide.profileSwitcher = descriptor
    if descriptor = invalid and m.profileSwitcher <> invalid then closeUserProfileSwitcher()
end sub

function openUserProfileSwitcher(focusId = "" as string, message = "" as string) as boolean
    if m.profileSwitcher <> invalid or m.top.dialog <> invalid then return false
    context = profileBaselineContext()
    if context = invalid then return false
    model = userProfilePickerPlan(context.store, "switcher", context.connection.provider, false)
    if not model.ok or not model.show then return false
    context.nonce = CreateObject("roDeviceInfo").getRandomUUID()
    context.page = m.page
    context.guideActive = m.guide.active
    context.settingsActive = m.settingsHub.active
    model.uiNonce = context.nonce
    for i = 0 to model.tiles.count() - 1
        if model.tiles[i].id = focusId and focusId <> "" then model.focus = i
    end for
    picker = CreateObject("roSGNode", "UserProfilePicker")
    picker.model = model
    picker.message = message
    picker.observeField("intent", "onUserProfileSwitcherIntent")
    m.profileSwitcher = picker
    m.profileSwitcherContext = context
    m.guide.active = false
    m.settingsHub.active = false
    m.top.appendChild(picker)
    picker.setFocus(true)
    requestScheduledProfileSync("picker")
    return true
end function

' A read triggered by this picker may change names, order or protection.
' Replace the snapshot only on the same idle picker. Rotate its UI nonce so
' a queued index from the previous layout cannot select a different holder.
sub refreshUserProfileSwitcherAfterSync()
    context = m.profileSwitcherContext
    picker = m.profileSwitcher
    if context = invalid or picker = invalid then return
    if picker.busy or m.profileSwitcherMoveDialog <> invalid or m.profileManagementDialog <> invalid then return
    current = profileBaselineContext()
    if current = invalid or context.page <> m.page then return
    if not userProfileSameSession(context.scope, current.scope) or context.connectionRoot <> current.connectionRoot then return
    if context.storeRoot = current.storeRoot then return
    before = picker.model
    model = userProfilePickerPlan(current.store, "switcher", current.connection.provider, false)
    if not model.ok or not model.show then closeUserProfileSwitcher() : return
    focus = picker.focusIndex
    if userProfileInteger(focus) and focus >= 0 and focus < before.tiles.count()
        tile = before.tiles[focus]
        for i = 0 to model.tiles.count() - 1
            if tile.kind = model.tiles[i].kind and tile.id = model.tiles[i].id then model.focus = i
        end for
    end if
    context.store = current.store
    context.storeRoot = current.storeRoot
    context.nonce = CreateObject("roDeviceInfo").getRandomUUID()
    model.uiNonce = context.nonce
    picker.model = model
end sub

function userProfileSwitcherCurrent() as boolean
    context = m.profileSwitcherContext
    if m.profileSwitcher = invalid or type(context) <> "roAssociativeArray" then return false
    current = profileBaselineContext()
    if current = invalid then return false
    return userProfileSameSession(context.scope, current.scope) and context.connectionRoot = current.connectionRoot and context.storeRoot = current.storeRoot and context.page = m.page
end function

sub retireUserProfileSwitcher()
    closeUserProfileSwitcherMove()
    if m.profileSwitcherContext <> invalid
        if m.profileSwitcherConfirmNonce = m.profileSwitcherContext.nonce then closeProfileManagementDialog()
    end if
    m.profileSwitcherConfirmNonce = ""
    picker = m.profileSwitcher
    m.profileSwitcher = invalid
    m.profileSwitcherContext = invalid
    if picker = invalid then return
    picker.unobserveField("intent")
    m.top.removeChild(picker)
end sub

sub closeUserProfileSwitcher()
    context = m.profileSwitcherContext
    if m.profileSwitchContext <> invalid
        if context <> invalid
            if userProfileSameSession(m.profileSwitchContext.outgoing, context.scope)
                m.profileSwitchContext.dismissSwitcher = true
                rollbackUserProfileSwitch("Switch cancelled.")
            end if
        end if
    end if
    retireUserProfileSwitcher()
    if type(context) <> "roAssociativeArray" or userProfileGateClosed() then return
    if not userProfileSameSession(context.scope, m.activeUserScope) then return
    m.guide.active = context.guideActive
    m.settingsHub.active = context.settingsActive
    if context.settingsActive then m.settingsHub.setFocus(true) else m.guide.setFocus(true)
end sub

sub onUserProfileSwitcherIntent(event as object)
    if m.profileSwitcher = invalid or m.profileSwitcherContext = invalid then return
    if not m.profileSwitcher.isSameNode(event.getRoSGNode()) then return
    intent = event.getData()
    if type(intent) <> "roAssociativeArray" then return
    if textValue(intent.uiNonce) <> m.profileSwitcherContext.nonce then return
    if intent.action = "back" then closeUserProfileSwitcher() : return
    if not userProfileSwitcherCurrent() then return
    model = m.profileSwitcher.model
    action = userProfilePickerChoice(model, intent.index)
    if intent.action = "reorder" or intent.action = "reorder-release"
        handleUserProfileSwitcherMove(intent)
        return
    end if
    if action <> intent.action then return
    if action = "close" then closeUserProfileSwitcher() : return
    if action = "add"
        closeUserProfileSwitcher()
        beginProfileBaselineAdd(false, true)
    else if action = "manage"
        closeUserProfileSwitcher()
        if m.page = "guide" then openSettingsHub()
        refreshSettingsHub()
        m.settingsHub.callFunc("openProfilesPage")
    else if action = "switch"
        targetId = model.tiles[intent.index].id
        m.profileSwitcherTarget = targetId
        if m.playingChannel <> invalid
            choices = [{title: "Switch", action: "switch-confirm", id: targetId}, {title: "Cancel", action: "switch-cancel"}]
            m.profileSwitcherConfirmNonce = m.profileSwitcherContext.nonce
            openProfileManagementChoices("Switch Profile", "Stop playback and switch to " + model.tiles[intent.index].name + "?", choices)
            m.profileManagementDialog.unobserveField("buttonSelected")
            m.profileManagementDialog.unobserveField("wasClosed")
            m.profileManagementDialog.observeField("buttonSelected", "onUserProfileSwitcherConfirm")
            m.profileManagementDialog.observeField("wasClosed", "onUserProfileSwitcherConfirmClosed")
        else
            startUserProfileSwitcherSelection(targetId)
        end if
    end if
end sub

sub onUserProfileSwitcherConfirm(event as object)
    if m.profileManagementDialog = invalid or not userProfileSwitcherCurrent() then return
    if not m.profileManagementDialog.isSameNode(event.getRoSGNode()) then return
    if m.profileSwitcherConfirmNonce <> m.profileSwitcherContext.nonce then return
    choice = event.getData()
    if not userProfileInteger(choice) then return
    closeProfileManagementDialog()
    if choice = 0 then startUserProfileSwitcherSelection(m.profileSwitcherTarget)
    if choice <> 0 and m.profileSwitcher <> invalid then m.profileSwitcher.setFocus(true)
end sub

sub onUserProfileSwitcherConfirmClosed(event as object)
    if m.profileManagementDialog = invalid then return
    if not m.profileManagementDialog.isSameNode(event.getRoSGNode()) then return
    closeProfileManagementDialog()
    if m.profileSwitcher <> invalid then m.profileSwitcher.setFocus(true)
end sub

sub startUserProfileSwitcherSelection(targetId as string)
    if not userProfileSwitcherCurrent() then return
    settings = loadDispatcharrSyncSettings(m.registry)
    if not settings.ok then m.profileSwitcher.message = "Sync settings need recovery." : return
    if settings.enabled and m.profileSyncWriterReady <> true then m.profileSwitcher.message = "Finish Dispatcharr Sync before switching." : return
    m.profileSwitcher.busy = true
    if beginUserProfileSwitch(targetId) then return
    if beginUserProfileOwnSignIn(targetId)
        m.profileOwnSignInContext.switchAfterSignIn = true
        return
    end if
    m.profileSwitcher.busy = false
    m.profileSwitcher.message = "Switch failed. Verify this profile's own access."
end sub

function resumeUserProfileSwitcherFailure(message as string) as boolean
    if m.profileSwitcher = invalid then return false
    targetId = textValue(m.profileSwitcherTarget)
    retireUserProfileSwitcher()
    return openUserProfileSwitcher(targetId, "Switch failed. " + message)
end function

sub closeUserProfileSwitcherMove()
    dialog = m.profileSwitcherMoveDialog
    m.profileSwitcherMoveDialog = invalid
    m.profileSwitcherMoveTarget = ""
    m.profileSwitcherMoveChoices = []
    if dialog = invalid then return
    dialog.unobserveField("buttonSelected")
    dialog.unobserveField("wasClosed")
    dialog.close = true
    if m.top.dialog <> invalid
        if m.top.dialog.isSameNode(dialog) then m.top.dialog = invalid
    end if
end sub

sub handleUserProfileSwitcherMove(intent as object)
    model = m.profileSwitcher.model
    if not userProfileInteger(intent.index) then return
    if intent.index < 0 or intent.index >= model.tiles.count() then return
    tile = model.tiles[intent.index]
    if tile.kind <> "profile" then return
    if intent.action = "reorder"
        m.profileSwitcherMoveTarget = tile.id
        return
    end if
    if tile.id <> m.profileSwitcherMoveTarget then return
    choices = []
    count = m.profileSwitcherContext.store.profiles.count()
    if intent.index > 0 then choices.push({title: "Move Left", position: intent.index - 1})
    if intent.index < count - 1 then choices.push({title: "Move Right", position: intent.index + 1})
    if intent.index > 0 then choices.push({title: "Move to Front", position: 0})
    choices.push({title: "Cancel", position: -1})
    dialog = CreateObject("roSGNode", "AerioDialog")
    dialog.title = tile.name
    buttons = []
    for each choice in choices
        buttons.push(choice.title)
    end for
    dialog.buttons = buttons
    m.profileSwitcher.busy = true
    dialog.observeField("buttonSelected", "onUserProfileSwitcherMove")
    dialog.observeField("wasClosed", "onUserProfileSwitcherMoveClosed")
    m.profileSwitcherMoveChoices = choices
    m.profileSwitcherMoveDialog = dialog
    m.top.dialog = dialog
    dialog.setFocus(true)
end sub

sub onUserProfileSwitcherMove(event as object)
    if m.profileSwitcherMoveDialog = invalid or not userProfileSwitcherCurrent() then return
    if not m.profileSwitcherMoveDialog.isSameNode(event.getRoSGNode()) then return
    index = event.getData()
    if not userProfileInteger(index) or index < 0 or index >= m.profileSwitcherMoveChoices.count() then return
    position = m.profileSwitcherMoveChoices[index].position
    targetId = m.profileSwitcherMoveTarget
    context = m.profileSwitcherContext
    closeUserProfileSwitcherMove()
    if position >= 0
        saved = commitUserProfileMetadataEdit(m.registry, context.connection, context.store, targetId, "order", position, invalid, context.nonce, context.nonce, CreateObject("roDateTime").asSeconds())
        if not saved.ok then m.profileSwitcher.busy = false : m.profileSwitcher.message = "Could not move this profile." : return
        m.userProfileStore = saved.store
    end if
    closeUserProfileSwitcher()
    refreshUserProfileChrome()
    openUserProfileSwitcher(targetId)
end sub

sub onUserProfileSwitcherMoveClosed(event as object)
    if m.profileSwitcherMoveDialog = invalid then return
    if not m.profileSwitcherMoveDialog.isSameNode(event.getRoSGNode()) then return
    closeUserProfileSwitcherMove()
    if m.profileSwitcher <> invalid
        m.profileSwitcher.busy = false
        m.profileSwitcher.setFocus(true)
    end if
end sub
