sub main()
    m.global = {}
    m.top = {exitRequested: false, dialog: invalid}
    m.profileGateCover = {visible: false}
    m.profileGateClock = {control: "stop"}
    m.selectedConnectionId = "slot-a"
    m.profilePinDialogFactory = function() as object
        return {title: "", textEditBox: {text: "", maxTextLength: 0, hasField: function(field as string) as boolean
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
    beginProfilePinGate(profile, "switch", "fresh-switch-attempt")
    onProfilePinClosed(event)
    check(not m.top.exitRequested and m.switchRollbacks = 1, "target-switch PIN cancellation rolls back rather than using launch whole-app exit")
    print "ALL TESTS PASSED"
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
