' Isolated read-only diagnostics. No application registry, requests or PIN data.
sub init()
    m.clock = m.top.findNode("clock")
    m.clock.observeField("fire", "onVoiceDiagnosticTick")
end sub

sub startVoiceDiagnostic()
    if m.top.start <> true or m.started = true then return
    m.started = true
    device = CreateObject("roDeviceInfo")
    print "[voice-diagnostic] "; FormatJson({kind: "capabilities", model: device.getModel(), os: device.getOSVersion(), locale: device.getCurrentLocale(), appCountry: device.getCountryCode(), accountCountry: device.getUserCountryCode(), voiceRemote: device.hasFeature("voice_remote"), handsfree: device.hasFeature("handsfree_voice")})
    m.modes = ["generic", "password", "numeric", "dynamic"]
    m.index = -1
    m.phase = 0
    m.clock.control = "start"
end sub

sub onVoiceDiagnosticTick()
    if m.phase = 0
        m.index++
        if m.index >= m.modes.count()
            m.clock.control = "stop"
            print "[voice-diagnostic] "; FormatJson({kind: "complete", modes: m.modes.count()})
            return
        end if
        m.mode = m.modes[m.index]
        kind = "StandardKeyboardDialog"
        if m.mode = "numeric" then kind = "StandardPinPadDialog"
        if m.mode = "dynamic" then kind = "DynamicKeyboard"
        m.dialog = CreateObject("roSGNode", kind)
        voiceDiagnosticRecord("created")
        if m.mode = "dynamic"
            m.top.appendChild(m.dialog)
        else
            m.dialog.title = "Native voice keyboard diagnostic"
            m.dialog.buttons = ["Done"]
            if m.mode = "password" then m.dialog.keyboardDomain = "password"
            if m.mode = "password" or m.mode = "numeric"
                m.dialog.textEditBox.secureMode = true
                if m.dialog.textEditBox.hasField("secureLastCharacter") then m.dialog.textEditBox.secureLastCharacter = true
            end if
            m.top.dialog = m.dialog
        end if
        m.dialog.setFocus(true)
        m.phase = 1
    else if m.phase = 1
        voiceDiagnosticRecord("shown-default")
        m.dialog.textEditBox.voiceEnabled = true
        m.phase = 2
    else
        voiceDiagnosticRecord("shown-requested")
        if m.mode = "dynamic"
            m.top.removeChild(m.dialog)
        else
            m.dialog.close = true
            m.top.dialog = invalid
        end if
        m.dialog = invalid
        m.phase = 0
    end if
end sub

sub voiceDiagnosticRecord(phase as string)
    inputNode = m.dialog.textEditBox
    print "[voice-diagnostic] "; FormatJson({kind: "keyboard", mode: m.mode, phase: phase, voice: inputNode.voiceEnabled, voiceEntryType: inputNode.voiceEntryType, voiceNode: inputNode.isSubtype("VoiceTextEditBox"), focused: m.dialog.isInFocusChain(), masked: inputNode.secureMode})
end sub
