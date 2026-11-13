' Synthetic dialog surface only. No application registry, account or network.
sub init()
    m.dialog = invalid
    m.mode = ""
    m.launchGate = false
    m.lastLength = -1
    m.top.setFocus(true)
    m.top.findNode("sample").observeField("fire", "profileDialogSample")
    m.top.findNode("sample").control = "start"
    m.top.findNode("gateDelay").observeField("fire", "profileBeaconGateDone")
    m.top.findNode("lineupDelay").observeField("fire", "profileBeaconLineupDone")
end sub

sub profileDialogCommand()
    command = m.top.command
    if command = "inspect"
        print "[profile-dialog] "; FormatJson({kind: "inspect", mode: m.mode, open: m.dialog <> invalid, protected: m.top.findNode("protected").visible})
        return
    end if
    if m.launchGate and m.dialog <> invalid
        print "[profile-dialog] "; FormatJson({kind: "second-dialog-blocked", protected: m.top.findNode("protected").visible})
        return
    end if
    if m.dialog <> invalid
        m.dialog.unobserveField("wasClosed")
        m.dialog.close = true
        m.dialog = invalid
    end if
    m.mode = command
    if command = "beacons"
        m.launchGate = false
        m.beaconClock = CreateObject("roTimespan")
        m.beaconClock.mark()
        beginStartupBeacons(false)
        m.top.findNode("gateDelay").control = "start"
        print "[profile-dialog] "; FormatJson({kind: "beacon-wait", protected: false})
        return
    end if
    m.lastLength = -1
    m.launchGate = command = "launch"
    if command = "numbers" or command = "launch"
        dialog = CreateObject("roSGNode", "StandardPinPadDialog")
        dialog.title = "Synthetic profile PIN — no real credentials"
        dialog.textEditBox.maxTextLength = 6
        uiSecureTextInput(dialog.textEditBox)
    else
        dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
        dialog.title = "Synthetic credential — no real account"
        dialog.keyboardDomain = command
        if command = "password" then uiSecureTextInput(dialog.textEditBox)
    end if
    dialog.textEditBox.voiceEnabled = true
    dialog.buttons = ["OK", "Cancel"]
    if m.launchGate then dialog.buttons = ["OK"]
    dialog.observeField("wasClosed", "profileDialogClosed")
    m.dialog = dialog
    if m.launchGate then m.top.signalBeacon("AppDialogInitiate")
    m.top.dialog = dialog
    dialog.setFocus(true)
    lastMasked = false
    if dialog.textEditBox.hasField("secureLastCharacter") then lastMasked = dialog.textEditBox.secureLastCharacter
    print "[profile-dialog] "; FormatJson({kind: "ready", mode: command, secure: dialog.textEditBox.secureMode, lastmasked: lastMasked, maximum: dialog.textEditBox.maxTextLength, protected: m.top.findNode("protected").visible})
end sub

' Isolated accounting fixture: two seconds of simulated selection, then a
' three-second slow lineup. No user authentication or real guide is claimed.
sub profileBeaconGateDone()
    completeStartupDialog()
    m.gateMs = m.beaconClock.totalMilliseconds()
    m.top.findNode("lineupDelay").control = "start"
end sub

sub profileBeaconLineupDone()
    dialogClosed = not m.startupDialogOpen
    completeStartupBeacons()
    chargedMs = m.beaconClock.totalMilliseconds() - m.gateMs
    print "[profile-dialog] "; FormatJson({kind: "beacon-complete", dialogclosed: dialogClosed, launchsent: m.startupBeaconSent, chargedms: chargedMs, protected: false})
end sub

sub profileDialogSample()
    if m.dialog = invalid then return
    count = len(m.dialog.textEditBox.text)
    if count <> m.lastLength
        m.lastLength = count
        print "[profile-dialog] "; FormatJson({kind: "input", mode: m.mode, length: count, protected: m.top.findNode("protected").visible})
    end if
end sub

sub profileDialogClosed(event as object)
    print "[profile-dialog] "; FormatJson({kind: "close-event", value: event.getData(), protected: m.top.findNode("protected").visible})
    if m.dialog = invalid then return
    ' wasClosed is a signal on this firmware: getData() is invalid, not true.
    ' Observing the current dialog's event is the cancellation indication.
    if not m.dialog.isSameNode(event.getRoSGNode()) then return
    m.dialog.unobserveField("wasClosed")
    m.dialog = invalid
    print "[profile-dialog] "; FormatJson({kind: "closed", mode: m.mode, protected: m.top.findNode("protected").visible})
    if m.launchGate then m.top.exitRequested = true
end sub
