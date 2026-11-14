' Private readiness seam only: actual Child own authentication/roster/lineup.
sub onManagementProbeTick()
    if m.childAvailableTicks = invalid then m.childAvailableTicks = 0
    m.childAvailableTicks++
    if OWN_CHILD_PIN and m.childAvailablePinDone <> true
        if m.profilePinDialog = invalid
            if m.childAvailableTicks < 4 then return
            m.managementProbeClock.control = "stop"
            print "[profile-management] "; FormatJson({kind: "result", passed: false, child_available: false, launch_pin: false})
            return
        end if
        if m.childAvailablePinAnnounced <> true
            m.childAvailablePinAnnounced = true
            m.childAvailablePinSafe = m.task = invalid and m.activeUserScope = invalid and m.profileGateCover.visible and m.global.profilegateclosed
            print "[profile-management] "; FormatJson({kind: "child-pin-ready", covered: m.childAvailablePinSafe})
            return
        end if
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        m.childAvailablePinDone = true
        return
    end if
    if m.busy or m.capabilityTask <> invalid then return
    if m.page <> "guide"
        if m.childAvailableTicks < 4 then return
        m.managementProbeClock.control = "stop"
        print "[profile-management] "; FormatJson({kind: "result", passed: false, child_available: false, page: m.page, closed: m.global.profilegateclosed})
        return
    end if
    m.managementProbeClock.control = "stop"
    expected = OWN_CHILD_ACCOUNT
    store = loadUserProfileStore(m.registry, "slot-a")
    own = m.activeUserScope <> invalid
    if own then own = m.activeUserScope.accountId = expected and m.activeUserScope.profileId = store.active and currentUserSettingsRole() = "child" and currentUserSessionId() <> ""
    theme = "forest"
    if expected = "7" then theme = "midnight"
    data = m.accountPreferences.favoriteIds.count() = 1 and m.devicePreferences.themePreset = theme
    if data then data = m.accountPreferences.favoriteIds[0] = "00000000-0000-4000-8000-" + right("000000000000" + expected, 12)
    preserved = m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", store.profiles[1].id)) = "synthetic-b"
    localChild = false
    for each profile in store.profiles
        if profile.id = store.active then localChild = profile.role = "child" and profile.displayName <> "Foreign roster rename"
    end for
    roster = localChild and m.profileRosterSuggestions.count() = 0
    lineup = m.guide.callFunc("profileSwitchProbeLineup") = expected
    pin = not OWN_CHILD_PIN or m.childAvailablePinSafe = true
    print "[profile-management] "; FormatJson({kind: "result", passed: own and data and preserved and roster and pin and lineup and not m.profileGateCover.visible and m.playingChannel = invalid, child_available: own, data: data, lineup: lineup, preserved: preserved, roster_untouched: roster, own_pin: pin, no_autoplay: m.playingChannel = invalid})
end sub
