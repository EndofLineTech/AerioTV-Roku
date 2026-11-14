' Actual own Child rejection: exact cut prompt, safe dismissal/form and Back.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if OWN_CHILD_PIN and m.profilePinDialog <> invalid
            if m.childRejectedPinSeen <> true
                m.childRejectedPinSeen = true
                print "[profile-management] "; FormatJson({kind: "child-pin-ready", covered: m.activeUserScope = invalid and m.global.profilegateclosed})
                return
            end if
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
            return
        end if
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        store = loadUserProfileStore(m.registry, "slot-a")
        m.childRejectedLocalId = store.active
        m.childRejectedRoster = m.registry.read(userProfileStoreKey("slot-a"))
        m.childRejectedSettings = m.registry.read("settingsV1")
        m.childRejectedPassed = currentUserSettingsRole() = "child"
        print "[profile-management] "; FormatJson({kind: "revoke-ready"})
        m.managementProbePhase = 1
    else if phase = 1
        refreshCapabilities()
        m.managementProbePhase = 2
    else if phase = 2
        if m.childRejectedDialog = invalid then return
        body = "Dispatcharr no longer accepts the API key for Synthetic. It may have been changed on the server."
        count = 1
        if OWN_CHILD_DEFAULT
            body += " Sign in with your Dispatcharr username and password to reconnect."
            count = 2
        end if
        prompt = m.childRejectedDialog
        m.childRejectedPassed = m.childRejectedPassed and prompt.title = "API key no longer valid" and prompt.message = body and prompt.buttons.count() = count and prompt.buttons[count - 1] = "Not Now" and m.childUnavailableDialog = invalid and m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible and m.global.profilegateclosed
        m.childRejectedOldNode = prompt
        print "[profile-management] "; FormatJson({kind: "child-rejection-ready", passed: m.childRejectedPassed})
        if OWN_CHILD_DEFAULT
            m.childRejectedPassed = m.childRejectedPassed and prompt.buttons[0] = "Sign In with Remote"
            onChildRejectedKeyChoice(managementProbeEvent(prompt, 0))
            own = m.profileOwnSignInContext <> invalid and m.profilePinDialog = invalid and m.profileOwnSignInDialog <> invalid
            if own then own = m.profileOwnSignInContext.childRecovery and m.profileOwnSignInContext.target.id = m.childRejectedLocalId and m.activeUserScope = invalid
            m.childRejectedPassed = m.childRejectedPassed and own
            print "[profile-management] "; FormatJson({kind: "cancel-ready"})
            m.managementProbePhase = 3
        else
            onChildRejectedKeyChoice(managementProbeEvent(prompt, 0))
            m.managementProbePhase = 8
        end if
    else if phase < 8
        m.managementProbePhase++
    else
        m.managementProbeClock.control = "stop"
        available = m.childUnavailableDialog <> invalid and m.childRejectedDialog = invalid and m.profileOwnSignInContext = invalid and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.profileGateCover.visible
        if available
            showUnavailableChildProfile()
            available = m.childRejectedDialog = invalid and m.childUnavailableDialog <> invalid
            onChildRejectedKeyChoice(managementProbeEvent(m.childRejectedOldNode, 0))
            available = available and m.profileOwnSignInContext = invalid and m.childRejectedDialog = invalid
        end if
        if not OWN_CHILD_DEFAULT and available
            m.childRejectedPassed = m.childRejectedPassed and m.childUnavailableDialog.buttons.count() = 1 and m.childUnavailableDialog.buttons[0] = "Manage Profiles"
            onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, 0))
            adult = m.adultPinDialog <> invalid and m.profileManagementDialog = invalid
            if adult then adult = m.adultPinDialog.title = "Enter a PIN from an Admin or Standard profile"
            m.childRejectedPassed = m.childRejectedPassed and adult
            if adult then onAdultProfilePinClosed(managementProbeEvent(m.adultPinDialog, 0))
        end if
        unchanged = m.registry.read(userProfileStoreKey("slot-a")) = m.childRejectedRoster and m.registry.read("settingsV1") = m.childRejectedSettings
        credentials = m.registry.read("connKey_slot-a") = "synthetic-a" and not m.registry.exists(userProfileKeyName("slot-a", m.childRejectedLocalId))
        if OWN_CHILD_DEFAULT then credentials = not m.registry.exists("connKey_slot-a") and m.registry.read(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002")) = "synthetic-b"
        safe = m.childRejectedPassed and available and unchanged and credentials and m.childUnavailableDialog <> invalid and m.playingChannel = invalid and m.top.exitRequested <> true
        print "[profile-management] "; FormatJson({kind: "rejection-safe", passed: safe, unavailable: available, unchanged: unchanged, credentials: credentials, no_autoplay: m.playingChannel = invalid})
        if safe
            print "[profile-management] "; FormatJson({kind: "cancel-ready"})
        else
            print "[profile-management] "; FormatJson({kind: "result", passed: false})
        end if
    end if
end sub
