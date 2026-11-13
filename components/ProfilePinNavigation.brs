' Scene-owned launch/authentication pad. Cover stays up until persisted PIN
' verification succeeds, or Main closes the entire application on wasClosed.
function beginProfilePinGate(profile as object, continuation as string, resume = invalid as dynamic) as boolean
    if m.profilePinDialog <> invalid then return true
    if profile.pinType <> "numbers" or not userProfilePinRecordValid(profile) then return false
    m.profileGateCover.visible = true
    m.global.profilegateclosed = true
    if type(m.top) = "roSGNode" then requestGateFenceRenderers(m.top)
    m.profilePinLockUntil = 0
    if m.playingChannel <> invalid then stopPlayback()
    m.profileUnlockGrant = invalid
    m.profilePinContext = {slot: m.selectedConnectionId, profile: profile, continuation: continuation, resume: resume}
    dialog = invalid
    if m.profilePinDialogFactory <> invalid then dialog = m.profilePinDialogFactory()
    if dialog = invalid then dialog = CreateObject("roSGNode", "StandardPinPadDialog")
    dialog.title = "Enter PIN for " + profile.displayName
    ' Roku's platform-specific rule requires six native slots even when the
    ' profile's locally learned length is known (spec 7.7, Roku item 1).
    dialog.textEditBox.maxTextLength = 6
    uiSecureTextInput(dialog.textEditBox)
    dialog.textEditBox.voiceEnabled = true
    dialog.buttons = ["OK"]
    dialog.observeField("buttonSelected", "onProfilePinSubmit")
    dialog.observeField("wasClosed", "onProfilePinClosed")
    m.profilePinDialog = dialog
    m.top.dialog = dialog
    dialog.setFocus(true)
    if m.registry <> invalid and m.profilePinVerifier = invalid
        checked = userProfilePinAttemptStored(m.registry, m.selectedConnectionId, profile.id, profile, [], CreateObject("roDateTime").asSeconds())
        updateProfilePinFeedback(checked)
    end if
    return true
end function

sub onProfilePinSubmit(event as object)
    if m.profilePinDialog = invalid or m.profilePinContext = invalid then return
    if not m.profilePinDialog.isSameNode(event.getRoSGNode()) then return
    if event.getData() <> 0 then return
    context = m.profilePinContext
    if context.slot <> m.selectedConnectionId then return
    text = m.profilePinDialog.textEditBox.text
    m.profilePinDialog.textEditBox.text = ""
    if not CreateObject("roRegex", "^[0-9]{4,6}$", "").isMatch(text)
        m.profilePinDialog.title = "Enter 4 to 6 numbers"
        return
    end if
    entries = []
    for i = 1 to len(text)
        entries.push(mid(text, i, 1))
    end for
    text = ""
    if m.profilePinVerifier <> invalid
        checked = m.profilePinVerifier(context.profile, entries)
    else
        checked = userProfilePinAttemptStored(m.registry, context.slot, context.profile.id, context.profile, entries, CreateObject("roDateTime").asSeconds())
    end if
    entries = []
    if checked.recoveryRequired
        m.profilePinDialog.title = "PIN storage needs recovery"
        return
    end if
    if not checked.verified
        updateProfilePinFeedback(checked)
        return
    end if
    profile = context.profile
    m.profileUnlockGrant = {slot: context.slot, id: profile.id, pinType: profile.pinType, pinHash: profile.pinHash, pinSalt: profile.pinSalt}
    m.profilePinDialog.unobserveField("buttonSelected")
    m.profilePinDialog.unobserveField("wasClosed")
    m.profilePinDialog.close = true
    m.profilePinDialog = invalid
    m.profilePinContext = invalid
    m.profileGateClock.control = "stop"
    m.global.profilegateclosed = false
    m.profileGateCover.visible = false
    if m.startupDialogOpen = true then completeStartupDialog()
    if context.continuation = "connect" then connectServer(true)
    if context.continuation = "complete" then completeConnection(context.resume)
end sub

sub onProfilePinClosed(event as object)
    if m.profilePinDialog = invalid then return
    if not m.profilePinDialog.isSameNode(event.getRoSGNode()) then return
    m.profilePinDialog.unobserveField("buttonSelected")
    m.profilePinDialog.unobserveField("wasClosed")
    m.profilePinDialog = invalid
    m.profilePinContext = invalid
    m.profileGateClock.control = "stop"
    m.profileGateCover.visible = true
    m.global.profilegateclosed = true
    m.top.exitRequested = true
end sub

sub updateProfilePinFeedback(checked as object)
    if m.profilePinDialog = invalid then return
    if checked.recoveryRequired
        m.profilePinDialog.title = "PIN storage needs recovery"
    else if checked.locked
        m.profilePinLockUntil = CreateObject("roDateTime").asSeconds() + checked.remaining
        m.profileGateClock.control = "start"
        onProfilePinTick()
    else if checked.validInput
        m.profilePinDialog.title = "Wrong PIN"
    end if
end sub

sub onProfilePinTick()
    if m.profilePinDialog = invalid or m.profilePinContext = invalid
        m.profileGateClock.control = "stop"
        return
    end if
    remaining = m.profilePinLockUntil - CreateObject("roDateTime").asSeconds()
    if remaining > 0
        m.profilePinDialog.title = "Try again in " + remaining.toStr() + " seconds"
    else
        m.profileGateClock.control = "stop"
        m.profilePinDialog.title = "Enter PIN for " + m.profilePinContext.profile.displayName
    end if
end sub
