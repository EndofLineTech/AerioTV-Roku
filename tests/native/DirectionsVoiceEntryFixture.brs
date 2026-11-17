' Private feasibility candidate, not an approved public Directions UI.
sub onPinFixtureTick()
    if m.profilePinDialog = invalid
        m.pinFixtureClock.control = "stop"
        return
    end if
    if m.directionsVoiceAnnounced <> true
        m.profilePinDialog.textEditBox.voiceEnabled = true
        uiSecureTextInput(m.profilePinDialog.textEditBox)
        m.directionsVoiceAnnounced = true
        print "[profile-pin] "; FormatJson({kind: "covered", covered: m.profileGateCover.visible, closed: m.global.profilegateclosed, nativeKeyboard: m.profilePinDialog.isSubtype("StandardKeyboardDialog"), voice: m.profilePinDialog.textEditBox.voiceEnabled, domain: m.profilePinDialog.keyboardDomain, masked: m.profilePinDialog.textEditBox.secureMode, task: m.task <> invalid})
        return
    end if
    if m.directionsVoiceSubmit <> true then return
    m.directionsVoiceSubmit = false
    print "[profile-pin] "; FormatJson({kind: "input", characters: len(m.profilePinDialog.text), innerCharacters: len(m.profilePinDialog.textEditBox.text), covered: m.profileGateCover.visible, task: m.task <> invalid})
    event = {node: m.profilePinDialog, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return 0
    end function}
    onProfilePinSubmit(event)
end sub
