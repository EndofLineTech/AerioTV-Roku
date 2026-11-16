' Scene-owned launch/authentication pad. Cover stays up until persisted PIN
' verification succeeds, or Main closes the entire application on wasClosed.
function beginProfilePinGate(profile as object, continuation as string, resume = invalid as dynamic) as boolean
    if m.profilePinDialog <> invalid then return true
    if not userProfilePinRecordValid(profile) then return false
    directions = profile.pinType = "directions"
    if directions
        if CreateObject("roAppInfo").getValue("aeriotv_profile_directions_test") <> "1" then return false
    end if
    m.profileGateCover.visible = true
    m.global.profilegateclosed = true
    if type(m.top) = "roSGNode" then requestGateFenceRenderers(m.top)
    m.profilePinLockUntil = 0
    if m.playingChannel <> invalid then stopPlayback()
    m.profileUnlockGrant = invalid
    m.profilePinContext = {slot: m.selectedConnectionId, profile: profile, continuation: continuation, resume: resume}
    dialog = invalid
    if m.profilePinDialogFactory <> invalid then dialog = m.profilePinDialogFactory()
    if dialog = invalid
        if directions
            dialog = CreateObject("roSGNode", "DirectionsPinPad")
        else
            dialog = CreateObject("roSGNode", "StandardPinPadDialog")
        end if
    end if
    dialog.title = "Enter PIN for " + profile.displayName
    ' Roku's platform-specific rule requires six native slots even when the
    ' profile's locally learned length is known (spec 7.7, Roku item 1).
    dialog.textEditBox.maxTextLength = 6
    if directions
        lengthType = type(profile.pinLength)
        if lengthType = "Integer" or lengthType = "roInt" or lengthType = "roInteger"
            if profile.pinLength >= 4 and profile.pinLength <= 6 then dialog.textEditBox.maxTextLength = profile.pinLength
        end if
    end if
    uiSecureTextInput(dialog.textEditBox)
    if not directions then dialog.textEditBox.voiceEnabled = true
    dialog.buttons = ["OK"]
    dialog.observeField("buttonSelected", "onProfilePinSubmit")
    dialog.observeField("wasClosed", "onProfilePinClosed")
    m.profilePinDialog = dialog
    if directions
        m.top.appendChild(dialog)
    else
        m.top.dialog = dialog
    end if
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
    switching = context.continuation = "switch" or context.continuation = "switch-roster"
    startupSelection = context.continuation = "startup-selection"
    if startupSelection and not startupProfilePinContextCurrent(context)
        m.profilePinDialog.textEditBox.text = ""
        return
    end if
    if switching and not profileSwitchPinContextCurrent(context)
        m.profilePinDialog.textEditBox.text = ""
        return
    end if
    text = m.profilePinDialog.textEditBox.text
    m.profilePinDialog.textEditBox.text = ""
    pattern = "^[0-9]{4,6}$"
    message = "Enter 4 to 6 numbers"
    if context.profile.pinType = "directions"
        pattern = "^[UDLR]{4,6}$"
        message = "Enter 4 to 6 directions"
    end if
    if not CreateObject("roRegex", pattern, "").isMatch(text)
        m.profilePinDialog.title = message
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
    if type(m.profilePinDialog) = "roSGNode"
        if m.profilePinDialog.isSubtype("DirectionsPinPad") then m.top.removeChild(m.profilePinDialog)
    end if
    m.profilePinDialog = invalid
    m.profilePinContext = invalid
    m.profileGateClock.control = "stop"
    ' The switch continuation owns unblocking after current protection checks
    ' and incoming nonce retirement. Do not briefly resume old authenticated Tasks.
    if not switching and not startupSelection
        m.global.profilegateclosed = false
        m.profileGateCover.visible = false
    end if
    if m.startupDialogOpen = true and not startupSelection then completeStartupDialog()
    if context.continuation = "connect" then connectServer(true)
    if context.continuation = "complete" then completeConnection(context.resume)
    if context.continuation = "switch" then onUserProfileSwitchPin(context.resume)
    if context.continuation = "switch-roster" then onUserProfileSwitchRosterPin(context.resume)
    if context.continuation = "own-signin" then onUserProfileOwnSignInPin(context.resume)
    if startupSelection then onStartupProfilePin(context.resume)
end sub

sub onProfilePinClosed(event as object)
    if m.profilePinDialog = invalid then return
    if not m.profilePinDialog.isSameNode(event.getRoSGNode()) then return
    context = m.profilePinContext
    staleSwitch = false
    staleStartup = false
    if context <> invalid
        if context.continuation = "switch" or context.continuation = "switch-roster" then staleSwitch = not profileSwitchPinContextCurrent(context)
        if context.continuation = "startup-selection" then staleStartup = not startupProfilePinContextCurrent(context)
    end if
    m.profilePinDialog.unobserveField("buttonSelected")
    m.profilePinDialog.unobserveField("wasClosed")
    m.profilePinDialog.textEditBox.text = ""
    m.profilePinDialog.close = true
    if type(m.profilePinDialog) = "roSGNode"
        if m.profilePinDialog.isSubtype("DirectionsPinPad") then m.top.removeChild(m.profilePinDialog)
    end if
    m.profilePinDialog = invalid
    m.profilePinContext = invalid
    if staleSwitch or staleStartup then return
    m.profileGateClock.control = "stop"
    m.profileGateCover.visible = true
    m.global.profilegateclosed = true
    if context <> invalid
        if context.continuation = "switch" or context.continuation = "switch-roster"
            rollbackUserProfileSwitch("Switch cancelled. The previous profile was retained.")
            return
        end if
        if context.continuation = "own-signin"
            cancelUserProfileOwnSignIn()
            return
        end if
    end if
    m.top.exitRequested = true
end sub

function profileSwitchPinContextCurrent(pin as object) as boolean
    context = m.profileSwitchContext
    if context = invalid or m.global = invalid then return false
    if type(context.connection) <> "roAssociativeArray" or type(context.target) <> "roAssociativeArray" or type(pin.profile) <> "roAssociativeArray" then return false
    if textValue(context.nonce) = "" or context.nonce <> pin.resume then return false
    if context.connection.id <> m.selectedConnectionId or pin.slot <> context.connection.id then return false
    if m.global.profilegateclosed <> true then return false
    material = {slot: pin.slot, id: pin.profile.id, pinType: pin.profile.pinType, pinHash: pin.profile.pinHash, pinSalt: pin.profile.pinSalt}
    if not userProfilePinGrantMatches(material, context.connection.id, context.target) then return false
    if pin.continuation = "switch-roster"
        if m.profileSwitchRosterReady <> true or context.phase <> "pin" or m.global.profileswitchpending <> true then return false
        if textValue(m.global.activeusersession) <> context.nonce then return false
        if context.unavailableChild = true
            return m.activeUserScope = invalid and textValue(m.apiKey) = "" and m.page = "profile-unavailable"
        end if
        return textValue(m.global.activeusersession) = context.nonce and userProfileSameSession(context.outgoing, m.activeUserScope)
    end if
    if m.global.profileswitchpending = true then return false
    if context.unavailableChild = true
        return m.activeUserScope = invalid and textValue(m.global.activeusersession) = "" and textValue(m.apiKey) = "" and m.page = "profile-unavailable"
    end if
    if not userProfileSameSession(context.outgoing, m.activeUserScope) then return false
    return textValue(m.global.activeusersession) = context.outgoing.sessionId
end function

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
