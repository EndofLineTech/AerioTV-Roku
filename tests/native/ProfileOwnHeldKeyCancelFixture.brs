' Private broker acknowledgement delay: Cancel must invalidate proof before commit.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if OWN_HOLD_PIN and m.profilePinDialog <> invalid
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
            return
        end if
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        m.heldCancelProfile = m.activeUserScope.profileId
        m.heldCancelRoster = m.registry.read(userProfileStoreKey("slot-a"))
        m.heldCancelSettings = m.registry.read("settingsV1")
        print "[own-signin] "; FormatJson({kind: "revoke-ready"})
        m.managementProbePhase = 1
    else if phase = 1
        refreshCapabilities()
        m.managementProbePhase = 2
    else if phase = 2
        if m.capabilityTask <> invalid then return
        if OWN_HOLD_CHILD
            if m.childUnavailableDialog = invalid then return
            onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, 0))
        else
            if m.profileRecoveryDialog = invalid then return
            onActiveUserProfileRecoveryChoice(managementProbeEvent(m.profileRecoveryDialog, 0))
        end if
        if m.profileOwnSignInContext = invalid then return
        m.profileOwnSignInContext.password = "synthetic-correct"
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 2))
        m.managementProbePhase = 3
    else if phase = 3
        if m.profileOwnSignInHold = invalid then return
        m.heldWaitNonce = m.profileOwnSignInNonce
        if OWN_HOLD_TIMEOUT
            print "[own-signin] "; FormatJson({kind: "wait-ready"})
        else
            print "[own-signin] "; FormatJson({kind: "cancel-ready"})
        end if
        m.managementProbePhase = 4
    else if phase < 10
        m.managementProbePhase++
    else if phase = 10
        slotKey = m.registry.read("connKey_slot-a") = "synthetic-a"
        if OWN_HOLD_CHILD then slotKey = not m.registry.exists("connKey_slot-a") and m.registry.read(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002")) = "synthetic-b"
        unchanged = m.registry.read(userProfileStoreKey("slot-a")) = m.heldCancelRoster and m.registry.read("settingsV1") = m.heldCancelSettings and not m.registry.exists(userProfileKeyName("slot-a", m.heldCancelProfile)) and slotKey
        if OWN_HOLD_TIMEOUT
            usable = m.profileOwnSignInContext <> invalid and m.profileOwnSignInDialog <> invalid and m.profileOwnSignInHold = invalid and m.profileOwnSignInNonce <> m.heldWaitNonce and m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible
            if usable then usable = m.profileOwnSignInDialog.buttons.count() = 4 and currentUserSessionId() = m.profileOwnSignInContext.nonce
            held = m.requestGate.snapshot.keys.count() = 1
            m.heldWaitPassed = usable and unchanged and held
            print "[own-signin] "; FormatJson({kind: "timeout-ready", passed: m.heldWaitPassed, unchanged: unchanged, usable: usable, held: held})
            if not m.heldWaitPassed
                m.managementProbeClock.control = "stop"
                print "[own-signin] "; FormatJson({kind: "result", passed: false})
                return
            end if
            m.profileOwnSignInContext.password = "synthetic-correct"
            onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 2))
            m.managementProbePhase = 11
            return
        end if
        m.managementProbeClock.control = "stop"
        retired = m.profileOwnSignInContext = invalid and m.profileOwnSignInHold = invalid and m.global.profileownsigninnonce = "" and m.activeUserScope = invalid and m.apiKey = "" and currentUserSessionId() = "" and m.global.profilegateclosed and m.profileGateCover.visible
        held = m.requestGate.snapshot.keys.count() = 1
        print "[own-signin] "; FormatJson({kind: "result", passed: unchanged and retired and held and m.playingChannel = invalid, unchanged: unchanged, retired: retired, held: held, no_autoplay: m.playingChannel = invalid})
    else
        if m.busy or m.capabilityTask <> invalid or m.page <> "guide" or m.activeUserScope = invalid then return
        m.managementProbeClock.control = "stop"
        expected = "88"
        if OWN_HOLD_CHILD then expected = "7"
        own = m.activeUserScope.profileId = m.heldCancelProfile and m.activeUserScope.accountId = expected and m.profileOwnSignInContext = invalid and m.global.profileownsigninnonce = "" and m.registry.read("connKey_slot-a") = "synthetic-a" and m.top.exitRequested <> true
        if OWN_HOLD_CHILD then own = own and currentUserSettingsRole() = "child"
        print "[own-signin] "; FormatJson({kind: "result", passed: m.heldWaitPassed and own and m.playingChannel = invalid, own: own, no_autoplay: m.playingChannel = invalid})
    end if
end sub
