' Covered own-key recovery waits for the real sixty-second broker schedule.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        m.ownRecheckOldSession = currentUserSessionId()
        m.ownRecheckProfile = m.activeUserScope.profileId
        print "[own-signin] "; FormatJson({kind: "revoke-ready"})
        m.managementProbePhase = 1
    else if phase = 1
        refreshCapabilities()
        m.managementProbePhase = 2
    else if phase = 2
        if m.capabilityTask <> invalid then return
        held = m.requestGateBinding <> invalid
        if held then held = textValue(m.requestGateBinding.recoveryNonce) <> "" and m.activeUserScope = invalid and currentUserSessionId() = "" and m.apiKey = "" and m.global.profilegateclosed and m.profileGateCover.visible
        if not held
            m.managementProbeClock.control = "stop"
            print "[own-signin] "; FormatJson({kind: "result", passed: false, recovery_binding: false})
            return
        end if
        print "[own-signin] "; FormatJson({kind: "recheck-ready"})
        m.managementProbePhase = 3
    else
        if OWN_RECHECK_CANCEL
            if m.profileOwnSignInContext = invalid then return
            if m.ownRecheckCancelTicks = invalid then m.ownRecheckCancelTicks = 0
            m.ownRecheckCancelTicks++
            if m.ownRecheckCancelTicks < 6 then return
            m.managementProbeClock.control = "stop"
            entry = connectionStoreEntry(m.connectionStore, "slot-a")
            bucket = preferenceScope(entry.url + "|slot-a|" + m.ownRecheckProfile)
            protected = m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible and m.profileOwnSignInContext <> invalid and currentUserSessionId() = m.profileOwnSignInContext.nonce
            retired = m.requestGateBinding = invalid and m.requestGateRecheck = invalid and textValue(m.global.requestgaterecovery) = "" and not m.profileSessionKeys.doesExist(bucket)
            print "[own-signin] "; FormatJson({kind: "result", passed: protected and retired, retired: retired, protected: protected, default_preserved: m.registry.read("connKey_slot-a") = "synthetic-a", own_key_absent: not m.registry.exists(userProfileKeyName("slot-a", m.ownRecheckProfile)), no_autoplay: m.playingChannel = invalid})
            return
        end if
        if m.busy or m.capabilityTask <> invalid or m.activeUserScope = invalid or m.page <> "guide" then return
        m.managementProbeClock.control = "stop"
        own = m.activeUserScope.profileId = m.ownRecheckProfile and m.activeUserScope.accountId = "8" and currentUserSessionId() <> m.ownRecheckOldSession and m.apiKey = "synthetic-b"
        data = m.accountPreferences.favoriteIds.count() = 1 and m.devicePreferences.themePreset = "forest"
        if data then data = m.accountPreferences.favoriteIds[0] = "00000000-0000-4000-8000-000000000008"
        retired = m.requestGateBinding = invalid and m.requestGateRecheck = invalid and textValue(m.global.requestgaterecovery) = ""
        print "[own-signin] "; FormatJson({kind: "result", passed: own and data and retired and m.playingChannel = invalid, own: own, data: data, retired: retired, default_preserved: m.registry.read("connKey_slot-a") = "synthetic-a", no_autoplay: m.playingChannel = invalid})
    end if
end sub
