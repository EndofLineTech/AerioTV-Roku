sub main()
    m.global = {}
    m.top = {exitRequested: false, dialog: invalid}
    m.profileGateCover = {visible: false}
    m.profileGateClock = {control: "stop"}
    m.selectedConnectionId = "slot-a"
    m.profilePinDialogFactory = function() as object
        return {id: "pin-dialog", title: "", text: "", textEditBox: {text: "", maxTextLength: 0, hasField: function(field as string) as boolean
            return false
        end function}, buttons: [], close: false
            observeField: function(field as string, callback as string) as boolean
                return true
            end function
            unobserveField: sub(field as string)
            end sub
            setFocus: sub(value as boolean)
            end sub
            isSameNode: function(other as object) as boolean
                return other.id = "pin-dialog"
            end function
        }
    end function
    m.profilePinVerifier = function(profile as object, entries as object) as object
        m.submissions++
        m.lastPinEntries = entries
        return m.nextVerification
    end function
    m.submissions = 0
    profile = {id: "00000000-0000-4000-8000-000000000001", displayName: "Alice", pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    check(beginProfilePinGate(profile, "connect"), "native numeric gate opens")
    check(m.profileGateCover.visible and m.global.profilegateclosed and m.profilePinDialog.buttons.count() = 1 and m.profilePinDialog.textEditBox.maxTextLength = 6, "protected cover precedes undismissable native launch pad")
    event = {getRoSGNode: function() as object
        return {id: "pin-dialog"}
    end function
    getData: function() as integer
        return 0
    end function}
    m.profilePinDialog.textEditBox.text = "12"
    onProfilePinSubmit(event)
    check(m.submissions = 0 and m.profileGateCover.visible, "short input never verifies or uncovers")
    m.profilePinDialog.textEditBox.text = "9999"
    m.nextVerification = {verified: false, validInput: true, locked: false, remaining: 0, recoveryRequired: false}
    onProfilePinSubmit(event)
    check(m.submissions = 1 and m.profileGateCover.visible and m.profilePinDialog.textEditBox.text = "", "wrong PIN clears digits but keeps cover")
    updateProfilePinFeedback({recoveryRequired: false, locked: true, validInput: true, remaining: 30})
    check(m.profileGateClock.control = "start" and instr(1, m.profilePinDialog.title, "Try again in") = 1, "locked holder starts visible native countdown")
    m.profilePinLockUntil = CreateObject("roDateTime").asSeconds() - 1
    onProfilePinTick()
    check(m.profileGateClock.control = "stop" and m.profilePinDialog.title = "Enter PIN for Alice", "expired countdown restores prompt without granting access")
    m.profilePinDialog.textEditBox.text = "1234"
    m.nextVerification = {verified: true, validInput: true, locked: false, remaining: 0, recoveryRequired: true}
    onProfilePinSubmit(event)
    check(m.profileGateCover.visible and m.connectCalls = invalid, "storage recovery never grants access even with verified response")
    m.nextVerification.recoveryRequired = false
    onProfilePinSubmit(event)
    check(m.profileGateCover.visible, "cleared text must be re-entered after failed persistence")
    m.profilePinDialog.textEditBox.text = "1234"
    onProfilePinSubmit(event)
    check(not m.profileGateCover.visible and not m.global.profilegateclosed and m.connectCalls = 1, "verified persisted PIN closes safely before continuation")
    check(userProfilePinGrantMatches(m.profileUnlockGrant, "slot-a", profile), "unlock belongs only to exact slot/profile/PIN material")
    profile.pinSalt = string(32, "c")
    check(not userProfilePinGrantMatches(m.profileUnlockGrant, "slot-a", profile), "changed imported PIN retires old grant")
    beginProfilePinGate(profile, "connect")
    event.getData = function() as dynamic
        return invalid
    end function
    onProfilePinClosed(event)
    check(m.top.exitRequested and m.profileGateCover.visible and m.connectCalls = 1, "native wasClosed exits launch without showing protected content")
    m.top.exitRequested = false
    pinSwitchOwner(profile, "fresh-switch-attempt")
    beginProfilePinGate(profile, "switch", "fresh-switch-attempt")
    onProfilePinClosed(event)
    check(not m.top.exitRequested and m.switchRollbacks = 1, "target-switch PIN cancellation rolls back rather than using launch whole-app exit")
    pinSwitchOwner(profile, "valid-switch-attempt")
    beginProfilePinGate(profile, "switch", "valid-switch-attempt")
    m.profilePinDialog.textEditBox.text = "1234"
    event.getData = function() as integer
        return 0
    end function
    onProfilePinSubmit(event)
    check(m.switchResumes and m.gateAtSwitchResume and m.global.profilegateclosed and m.profileGateCover.visible, "valid switch PIN keeps the old network gate and cover closed until its controller validates and rotates admission")
    pinSwitchOwner(profile, "retired-switch-attempt")
    beginProfilePinGate(profile, "switch", "retired-switch-attempt")
    m.profileSwitchContext = invalid
    m.profileUnlockGrant = {marker: "successor"}
    m.profilePinDialog.textEditBox.text = "1234"
    event.getData = function() as integer
        return 0
    end function
    before = m.submissions
    onProfilePinSubmit(event)
    check(m.global.profilegateclosed and m.profileGateCover.visible and m.submissions = before and m.profileUnlockGrant.marker = "successor", "retired switch PIN cannot verify, overwrite a successor grant or open the global gate before its continuation rejects stale ownership")
    m.global.profilegateclosed = false
    m.profileGateCover.visible = false
    onProfilePinClosed(event)
    check(not m.global.profilegateclosed and not m.profileGateCover.visible and m.switchRollbacks = 1 and m.profileUnlockGrant.marker = "successor", "stale pad closure leaves a successor gate/lifecycle alone instead of rolling back the current switch")
    m.profileSwitchContext = {connection: {id: "slot-a"}, target: profile, nonce: "unavailable-child-attempt", unavailableChild: true}
    m.activeUserScope = invalid
    m.apiKey = ""
    m.page = "profile-unavailable"
    m.global.activeusersession = ""
    m.global.profileswitchpending = false
    beginProfilePinGate(profile, "switch", "unavailable-child-attempt")
    onProfilePinClosed(event)
    check(m.switchRollbacks = 2 and m.activeUserScope = invalid and m.global.activeusersession = "" and m.global.profilegateclosed, "actual unavailable-Child cancellation needs no fabricated outgoing authenticated scope")
    m.top.exitRequested = false
    m.top.signalBeacon = sub(name as string)
    end sub
    m.startupDialogOpen = true
    m.startupPinCurrent = true
    beginProfilePinGate(profile, "startup-selection", "startup-attempt")
    m.profilePinDialog.textEditBox.text = "1234"
    onProfilePinSubmit(event)
    check(m.startupPinResumed = true and m.startupPinCovered = true and m.global.profilegateclosed and m.profileGateCover.visible and m.startupDialogOpen, "startup PIN leaves cover/dialog timing with its own no-actor protection-read continuation")
    m.startupPinCurrent = false
    beginProfilePinGate(profile, "startup-selection", "retired-startup-attempt")
    m.profileUnlockGrant = {marker: "startup-successor"}
    m.profilePinDialog.textEditBox.text = "1234"
    before = m.submissions
    onProfilePinSubmit(event)
    check(m.submissions = before and m.profileUnlockGrant.marker = "startup-successor", "retired startup PIN cannot verify or replace successor authority")
    m.global.profilegateclosed = false
    m.profileGateCover.visible = false
    onProfilePinClosed(event)
    check(not m.top.exitRequested and not m.global.profilegateclosed and not m.profileGateCover.visible, "stale startup close cannot exit or cover a successor lifecycle")
    profile.pinType = "directions"
    m.profileNativePinKeyboardReady = true
    m.profileSwitchContext = invalid
    m.profilePinDialog = invalid
    check(beginProfilePinGate(profile, "connect"), "native Directions keyboard opens only under explicit developer readiness")
    check(m.profilePinContext.keyboard and m.top.dialog <> invalid and m.profilePinDialog.keyboardDomain = "password", "Directions keyboard is the owned native dialog rather than an appended Dpad surface")
    check(m.profilePinDialog.textEditBox.secureMode and m.profilePinDialog.textEditBox.voiceEnabled and m.profilePinDialog.textEditBox.maxTextLength = 64, "Directions native keyboard requests voice, masks input and bounds spoken words")
    m.profilePinDialog.text = "up up left right"
    m.profilePinDialog.textEditBox.text = "stale-alias"
    m.nextVerification = {verified: false, validInput: true, locked: false, remaining: 0, recoveryRequired: false}
    onProfilePinSubmit(event)
    check(userProfilePinNormalize("directions", m.lastPinEntries) = "UULR" and m.profileGateCover.visible, "native text alias supplies canonical ordered entries to unchanged durable verifier")
    check(m.profilePinDialog.text = "" and m.profilePinDialog.textEditBox.text = "", "every attempt scrubs both native text aliases")
    m.profilePinDialog.text = "up down left select"
    before = m.submissions
    onProfilePinSubmit(event)
    check(m.submissions = before and m.profilePinDialog.text = "", "malformed voice text never consumes a PIN attempt")
    oldDialog = m.profilePinDialog
    oldDialog.text = "udlr"
    onProfilePinClosed(event)
    check(m.top.dialog = invalid and oldDialog.text = "" and m.top.exitRequested and m.profileGateCover.visible, "native Directions launch closure scrubs text and exits without revealing content")
    m.top.exitRequested = false
    pinSwitchOwner(profile, "native-keyboard-switch")
    beginProfilePinGate(profile, "switch", "native-keyboard-switch")
    m.profilePinDialog.text = "u d l r"
    m.nextVerification = {verified: true, validInput: true, locked: false, remaining: 0, recoveryRequired: false}
    onProfilePinSubmit(event)
    check(m.profileUnlockGrant.pinType = "directions" and m.gateAtSwitchResume and m.top.dialog = invalid, "native keyboard switch retains exact hash grant and covered continuation ownership")
    pinSwitchOwner(profile, "retired-native-keyboard-switch")
    beginProfilePinGate(profile, "switch", "retired-native-keyboard-switch")
    m.profilePinDialog.text = "up down left right"
    m.profileSwitchContext = invalid
    m.profileUnlockGrant = {marker: "native-successor"}
    before = m.submissions
    onProfilePinSubmit(event)
    check(m.submissions = before and m.profileUnlockGrant.marker = "native-successor" and m.profilePinDialog.text = "", "retired native switch input cannot consume an attempt or replace successor authority")
    onProfilePinClosed(event)
    check(not m.top.exitRequested and m.profileUnlockGrant.marker = "native-successor", "retired native keyboard close cannot exit a successor lifecycle")
    beginProfilePinGate(profile, "connect")
    m.profilePinDialog.text = "up down left right"
    m.profilePinDialog.textEditBox.text = "alias"
    m.selectedConnectionId = "slot-b"
    before = m.submissions
    onProfilePinSubmit(event)
    check(m.submissions = before and m.profilePinDialog.text = "" and m.profilePinDialog.textEditBox.text = "", "same owned native keyboard on a changed slot is scrubbed without verification")
    print "ALL TESTS PASSED"
end sub

function startupProfilePinContextCurrent(context as object) as boolean
    return m.startupPinCurrent = true
end function

sub onStartupProfilePin(nonce as string)
    m.startupPinResumed = true
    m.startupPinCovered = m.global.profilegateclosed and m.profileGateCover.visible
end sub

sub pinSwitchOwner(profile as object, nonce as string)
    m.activeUserScope = {playlistId: "slot-a", profileId: profile.id, accountId: "7", preferenceIdentity: "https://example.test|7|slot-a", authorizationGeneration: "old", sessionId: "00000000-0000-4000-8000-000000000090"}
    m.profileSwitchContext = {connection: {id: "slot-a"}, target: profile, outgoing: m.activeUserScope, nonce: nonce}
    m.global.activeusersession = m.activeUserScope.sessionId
    m.global.profileswitchpending = false
end sub

sub onUserProfileSwitchPin(nonce as string)
    m.switchResumes = true
    m.gateAtSwitchResume = m.global.profilegateclosed
end sub

sub rollbackUserProfileSwitch(message as string)
    if m.switchRollbacks = invalid then m.switchRollbacks = 0
    m.switchRollbacks++
end sub

sub connectServer(skipRfi = false as boolean)
    if m.connectCalls = invalid then m.connectCalls = 0
    m.connectCalls++
end sub

sub completeConnection(value as object)
    stop
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
