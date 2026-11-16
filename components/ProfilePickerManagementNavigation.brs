' Local startup-picker controls never create an authenticated actor or request.
' Hold intent reserves a target; only its actual OK release may open a native
' dialog, so the held release cannot accidentally choose the first move.
function startupProfileReorderCurrent(context as dynamic) as boolean
    if type(context) <> "roAssociativeArray" then return false
    if m.userProfileRecoveryRequired = true then return false
    if m.profilePickerReady <> true or m.profilePicker = invalid or m.profilePickerContext = invalid then return false
    if context.nonce <> m.profilePickerReorderNonce or userProfileLocalId(context.nonce) = "" then return false
    if m.page <> "profile-picker" or m.activeUserScope <> invalid or textValue(m.apiKey) <> "" then return false
    if m.global.profilegateclosed <> true or m.profileLaunchPickerDeepLink = true then return false
    if m.profileStartupSelectionContext <> invalid or m.profileStartupTask <> invalid or m.profileOwnSignInContext <> invalid then return false
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return false
    if m.top.dialog <> invalid
        if m.profilePickerReorderDialog = invalid then return false
        if not m.top.dialog.isSameNode(m.profilePickerReorderDialog) then return false
    end if
    if context.connection.id <> m.selectedConnectionId then return false
    if context.connectionRootPresent <> m.registry.exists("connectionsV1") or context.connectionRoot <> m.registry.read("connectionsV1") then return false
    connections = loadConnectionStore(m.registry)
    entry = connectionStoreEntry(connections, context.connection.id)
    if connections.readOnly = true or connections.selected <> context.connection.id or entry = invalid then return false
    if FormatJson(entry) <> FormatJson(normalizeConnectionEntry(context.connection)) then return false
    if context.storeRoot <> m.registry.read(userProfileStoreKey(entry.id)) then return false
    store = loadUserProfileStore(m.registry, entry.id)
    model = userProfilePickerPlan(store, "launch", entry.provider, false)
    if not model.ok or not model.show then return false
    if not userProfileInteger(context.index) or context.index < 0 or context.index >= model.tiles.count() then return false
    tile = model.tiles[context.index]
    return tile.kind = "profile" and tile.id = context.targetId
end function

sub beginStartupProfileReorder(index as dynamic)
    if m.profilePickerReorderContext <> invalid
        if m.profilePickerReorderContext.stage <> "held" then return
        closeStartupProfileReorder()
    end if
    if not userProfileInteger(index) or m.profilePickerContext = invalid or m.profilePicker = invalid then return
    model = m.profilePicker.model
    if index < 0 or index >= model.tiles.count() then return
    tile = model.tiles[index]
    if tile.kind <> "profile" then return
    picker = m.profilePickerContext
    nonce = CreateObject("roDeviceInfo").getRandomUUID()
    context = {nonce: nonce, stage: "held", index: index, targetId: tile.id, name: tile.name, store: picker.store, storeRoot: picker.storeRoot, connection: picker.connection, connectionRoot: picker.connectionRoot, connectionRootPresent: picker.connectionRootPresent}
    m.profilePickerReorderNonce = nonce
    if not startupProfileReorderCurrent(context)
        m.profilePickerReorderNonce = ""
        return
    end if
    m.profilePickerReorderContext = context
end sub

sub releaseStartupProfileReorder(index as dynamic)
    context = m.profilePickerReorderContext
    if context = invalid then return
    if context.stage <> "held" or not userProfileInteger(index) then return
    if index <> context.index or not startupProfileReorderCurrent(context)
        closeStartupProfileReorder()
        return
    end if
    buttons = []
    context.moves = []
    count = context.store.profiles.count()
    if index > 0
        buttons.push("Move Left")
        context.moves.push(index - 1)
    end if
    if index < count - 1
        buttons.push("Move Right")
        context.moves.push(index + 1)
    end if
    if index > 0
        buttons.push("Move to Front")
        context.moves.push(0)
    end if
    buttons.push("Cancel")
    context.moves.push(-1)
    dialog = invalid
    if m.profilePickerReorderDialogFactory <> invalid then dialog = m.profilePickerReorderDialogFactory()
    if dialog = invalid then dialog = CreateObject("roSGNode", "AerioDialog")
    dialog.title = context.name
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "onStartupProfileReorderChoice")
    dialog.observeField("wasClosed", "onStartupProfileReorderClosed")
    context.stage = "menu"
    m.profilePickerReorderDialog = dialog
    m.profilePicker.busy = true
    m.top.dialog = dialog
    dialog.setFocus(true)
end sub

sub onStartupProfileReorderChoice(event as object)
    if m.profilePickerReorderDialog = invalid or m.profilePickerReorderContext = invalid then return
    if not m.profilePickerReorderDialog.isSameNode(event.getRoSGNode()) then return
    context = m.profilePickerReorderContext
    choice = event.getData()
    current = startupProfileReorderCurrent(context)
    if not current
        closeStartupProfileReorder()
        failStartupProfileSelection("Saved profiles changed. No profiles were moved.", context.targetId)
        return
    end if
    if not userProfileInteger(choice)
        closeStartupProfileReorder()
        failStartupProfileSelection("", context.targetId)
        return
    end if
    if choice < 0 or choice >= context.moves.count()
        closeStartupProfileReorder()
        failStartupProfileSelection("", context.targetId)
        return
    end if
    destination = context.moves[choice]
    message = ""
    if destination >= 0
        saved = commitUserProfileMetadataEdit(m.registry, context.connection, context.store, context.targetId, "order", destination, invalid, context.nonce, m.profilePickerReorderNonce, CreateObject("roDateTime").asSeconds())
        if not saved.ok
            if saved.recoveryRequired = true then m.userProfileRecoveryRequired = true
            message = "Could not move this profile. Saved data was retained."
        end if
    end if
    closeStartupProfileReorder()
    failStartupProfileSelection(message, context.targetId)
end sub

sub onStartupProfileReorderClosed(event as object)
    if m.profilePickerReorderDialog = invalid or m.profilePickerReorderContext = invalid then return
    if not m.profilePickerReorderDialog.isSameNode(event.getRoSGNode()) or not userProfileTrue(event.getData()) then return
    targetId = m.profilePickerReorderContext.targetId
    closeStartupProfileReorder()
    failStartupProfileSelection("", targetId)
end sub

sub closeStartupProfileReorder()
    dialog = m.profilePickerReorderDialog
    m.profilePickerReorderDialog = invalid
    m.profilePickerReorderContext = invalid
    m.profilePickerReorderNonce = ""
    if dialog <> invalid
        dialog.unobserveField("buttonSelected")
        dialog.unobserveField("wasClosed")
        dialog.buttons = []
        dialog.close = true
        if m.top.dialog <> invalid
            if m.top.dialog.isSameNode(dialog) then m.top.dialog = invalid
        end if
    end if
    if m.profilePicker <> invalid then m.profilePicker.busy = false
end sub
