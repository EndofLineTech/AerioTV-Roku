' A separate adult-purpose gate: it never installs a profile-unlock grant and
' never labels the pad with a holder name. Cancellation returns to its caller.
function beginAdultProfilePinGate(inputType = "numbers" as string) as boolean
    if m.adultPinDialog <> invalid then return false
    if inputType <> "numbers" and inputType <> "directions" then return false
    store = loadUserProfileStore(m.registry, m.selectedConnectionId)
    admin = userProfileLoadDeviceAdminPin(m.registry, m.selectedConnectionId)
    if store.readOnly = true or not admin.ok then return false
    if userProfileLocalId(m.profileManagementNonce) = "" then return false
    holders = userProfileAdultPinHolders(store.profiles, admin.record)
    if type(holders) <> "roArray" then return false
    context = {slot: store.playlistId, active: store.active, nonce: m.profileManagementNonce, store: store, admin: admin.record, inputType: inputType, covered: m.profileGateCover.visible, closed: m.global.profilegateclosed}
    m.adultPinContext = context
    m.adultPinWasLocked = false
    m.profileManagementGrant = invalid
    if holders.count() = 0
        m.profileManagementGrant = {slot: context.slot, active: context.active, nonce: context.nonce, purpose: "manage-profiles", kind: "stranded"}
        m.adultPinContext = invalid
        onAdultProfileAuthorized()
        return true
    end if
    if inputType = "directions"
        if CreateObject("roAppInfo").getValue("aeriotv_profile_directions_test") <> "1"
            m.adultPinContext = invalid
            return false
        end if
    end if
    choices = []
    present = false
    otherType = ""
    for each holder in holders
        kind = holder.record.pinType
        if kind = inputType then present = true
        if kind <> inputType then otherType = kind
    end for
    if not present
        m.adultPinContext = invalid
        if otherType <> "" then return beginAdultProfilePinGate(otherType)
        return false
    end if
    m.profileGateCover.visible = true
    m.global.profilegateclosed = true
    if m.playingChannel <> invalid then stopPlayback()
    if type(m.top) = "roSGNode" then requestGateFenceRenderers(m.top)
    dialog = invalid
    if m.adultPinDialogFactory <> invalid then dialog = m.adultPinDialogFactory()
    if dialog = invalid
        if inputType = "directions"
            dialog = CreateObject("roSGNode", "DirectionsPinPad")
        else
            dialog = CreateObject("roSGNode", "StandardPinPadDialog")
        end if
    end if
    dialog.title = "Enter a PIN from an Admin or Standard profile"
    dialog.textEditBox.maxTextLength = 6
    uiSecureTextInput(dialog.textEditBox)
    if inputType = "numbers" then dialog.textEditBox.voiceEnabled = true
    choices.push("OK")
    if otherType <> ""
        if otherType = "numbers" or CreateObject("roAppInfo").getValue("aeriotv_profile_directions_test") = "1"
            choices.push("Use " + otherType + " PIN")
            context.otherType = otherType
        end if
    end if
    dialog.buttons = choices
    dialog.observeField("buttonSelected", "onAdultProfilePinSubmit")
    dialog.observeField("wasClosed", "onAdultProfilePinClosed")
    m.adultPinDialog = dialog
    if inputType = "directions"
        m.top.appendChild(dialog)
    else
        m.top.dialog = dialog
    end if
    dialog.setFocus(true)
    m.adultPinClock = m.top.createChild("Timer")
    m.adultPinClock.duration = 1
    m.adultPinClock.repeat = true
    m.adultPinClock.observeField("fire", "onAdultProfilePinTick")
    m.adultPinClock.control = "start"
    onAdultProfilePinTick()
    return true
end function

function adultProfilePinContextCurrent() as boolean
    context = m.adultPinContext
    if type(context) <> "roAssociativeArray" then return false
    if context.slot <> m.selectedConnectionId or context.nonce <> m.profileManagementNonce then return false
    current = loadUserProfileStore(m.registry, context.slot)
    return current.readOnly <> true and current.active = context.active
end function

sub onAdultProfilePinSubmit(event as object)
    if m.adultPinDialog = invalid then return
    if not m.adultPinDialog.isSameNode(event.getRoSGNode()) then return
    if not adultProfilePinContextCurrent() then closeAdultProfilePinGate() : return
    context = m.adultPinContext
    button = event.getData()
    if button = 1 and context.otherType <> invalid
        other = context.otherType
        closeAdultProfilePinGate()
        beginAdultProfilePinGate(other)
        return
    end if
    if button <> 0 then return
    text = m.adultPinDialog.textEditBox.text
    m.adultPinDialog.textEditBox.text = ""
    entries = []
    for i = 1 to len(text)
        entries.push(mid(text, i, 1))
    end for
    text = ""
    checked = userProfileAdultPinAttemptStored(m.registry, context.slot, context.store, context.admin, entries, context.inputType, CreateObject("roDateTime").asSeconds())
    entries = []
    if checked.verified
        record = checked.deviceAdmin
        if checked.holder <> "device-admin"
            for each profile in checked.store.profiles
                if profile.id = checked.holder then record = profile
            end for
        end if
        grant = {slot: context.slot, active: context.active, nonce: context.nonce, purpose: "manage-profiles", kind: "pin", id: checked.holder, pinType: record.pinType, pinHash: record.pinHash, pinSalt: record.pinSalt}
        closeAdultProfilePinGate()
        m.userProfileStore = checked.store
        m.profileManagementGrant = grant
        onAdultProfileAuthorized()
        return
    end if
    updateAdultProfilePinFeedback(checked)
end sub

sub onAdultProfilePinTick()
    if m.adultPinDialog = invalid then return
    if not adultProfilePinContextCurrent() then closeAdultProfilePinGate() : return
    context = m.adultPinContext
    checked = userProfileAdultPinAttemptStored(m.registry, context.slot, context.store, context.admin, [], context.inputType, CreateObject("roDateTime").asSeconds())
    updateAdultProfilePinFeedback(checked)
end sub

sub updateAdultProfilePinFeedback(checked as object)
    if checked.recoveryRequired
        m.adultPinDialog.title = "PIN storage changed or needs recovery. Close and retry."
    else if checked.locked or checked.typeLocked
        m.adultPinWasLocked = true
        m.adultPinDialog.title = "Try again in " + checked.remaining.toStr() + " seconds"
    else if checked.validInput
        m.adultPinDialog.title = "Wrong PIN"
    else if m.adultPinWasLocked = true
        m.adultPinWasLocked = false
        m.adultPinDialog.title = "Enter a PIN from an Admin or Standard profile"
    end if
end sub

sub onAdultProfilePinClosed(event as object)
    if m.adultPinDialog = invalid then return
    if not m.adultPinDialog.isSameNode(event.getRoSGNode()) then return
    closeAdultProfilePinGate()
    m.profileManagementGrant = invalid
    m.profileManagementPending = invalid
    if m.page = "profile-unavailable" then showUnavailableChildProfile()
end sub

sub closeAdultProfilePinGate()
    if m.adultPinClock <> invalid
        m.adultPinClock.control = "stop"
        m.adultPinClock.unobserveField("fire")
        m.top.removeChild(m.adultPinClock)
        m.adultPinClock = invalid
    end if
    if m.adultPinDialog <> invalid
        m.adultPinDialog.unobserveField("buttonSelected")
        m.adultPinDialog.unobserveField("wasClosed")
        m.adultPinDialog.textEditBox.text = ""
        m.adultPinDialog.close = true
        if m.adultPinContext.inputType = "directions" then m.top.removeChild(m.adultPinDialog)
    end if
    if m.adultPinContext <> invalid
        if adultProfilePinContextCurrent()
            m.profileGateCover.visible = m.adultPinContext.covered
            m.global.profilegateclosed = m.adultPinContext.closed
        end if
    end if
    m.adultPinDialog = invalid
    m.adultPinContext = invalid
end sub
