' General default setup, not ProfileOwnSignInNavigation's separate own form.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.capabilityTask <> invalid or m.page <> "guide" then return
        m.defaultSetupProfile = m.activeUserScope.profileId
        m.defaultSetupOldSession = currentUserSessionId()
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        m.defaultSetupOther = strictJsonEncode(m.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(entry, "8"))]).text
        m.defaultSetupOldData = strictJsonEncode(m.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(entry, "7"))]).text
        print "[own-signin] "; FormatJson({kind: "revoke-ready"})
        m.managementProbePhase = 1
    else if phase = 1
        refreshCapabilities()
        m.managementProbePhase = 2
    else if phase = 2
        if m.capabilityTask <> invalid or m.busy then return
        if m.page <> "setup" or m.apiKey <> "" or m.registry.exists("connKey_slot-a") then return
        closeConnectionDialog()
        m.authMode = "password"
        m.username = "Synthetic7"
        if OWN_SETUP_REPLACEMENT then m.username = "Synthetic99"
        m.password = "synthetic-correct"
        print "[own-signin] "; FormatJson({kind: "default-setup-ready", no_scope: m.activeUserScope = invalid})
        connectServer(true)
        m.managementProbePhase = 3
    else if phase = 3 and (OWN_SETUP_CANCEL or OWN_SETUP_TIMEOUT)
        if m.profileSetupCredentialHold = invalid then return
        m.defaultSetupOldProof = m.profileSetupCredentialContext
        if OWN_SETUP_CANCEL
            print "[own-signin] "; FormatJson({kind: "cancel-ready"})
        else
            print "[own-signin] "; FormatJson({kind: "wait-ready"})
        end if
        m.managementProbePhase = 4
    else if phase >= 4 and phase < 14 and (OWN_SETUP_CANCEL or OWN_SETUP_TIMEOUT)
        m.managementProbePhase++
    else if phase = 14 and (OWN_SETUP_CANCEL or OWN_SETUP_TIMEOUT)
        safe = m.profileSetupCredentialContext = invalid and m.profileSetupCredentialHold = invalid and m.global.profileownsigninnonce = "" and not m.busy and m.activeUserScope = invalid and m.apiKey = "" and m.page = "setup" and not m.registry.exists("connKey_slot-a") and m.defaultSetupOldProof.pending.apiKey = ""
        held = m.requestGate.snapshot.keys.doesExist(requestGateCredentialHash(OWN_SETUP_KEY))
        if OWN_SETUP_CANCEL or not safe or not held
            m.managementProbeClock.control = "stop"
            print "[own-signin] "; FormatJson({kind: "result", passed: safe and held, cancelled: OWN_SETUP_CANCEL, safe: safe, hash_held: held})
            return
        end if
        print "[own-signin] "; FormatJson({kind: "timeout-ready", passed: safe and held})
        m.password = "synthetic-correct"
        connectServer(true)
        m.managementProbePhase = 15
    else
        if m.busy or m.task <> invalid or m.capabilityTask <> invalid then return
        m.managementProbeClock.control = "stop"
        own = m.page = "guide" and m.activeUserScope <> invalid
        account = "7"
        if OWN_SETUP_REPLACEMENT then account = "99"
        if own then own = m.activeUserScope.profileId = m.defaultSetupProfile and m.activeUserScope.accountId = account and currentUserSessionId() <> m.defaultSetupOldSession and currentUserSettingsRole() = "user"
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        other = strictJsonEncode(m.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(entry, "8"))]).text = m.defaultSetupOther and m.registry.read(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002")) = "synthetic-b"
        data = m.accountPreferences.favoriteIds.count() = 1 and m.devicePreferences.themePreset = "midnight"
        if data then data = m.accountPreferences.favoriteIds[0] = "00000000-0000-4000-8000-000000000007"
        if OWN_SETUP_REPLACEMENT
            old = m.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(entry, "7"))]
            data = m.accountPreferences.favoriteIds.count() = 0 and old.favoriteIds.count() = 1 and strictJsonEncode(old).text = m.defaultSetupOldData and m.requestGate.snapshot.keys.doesExist(requestGateCredentialHash("synthetic-a"))
        end if
        held = m.requestGate.snapshot.keys.doesExist(requestGateCredentialHash(OWN_SETUP_KEY))
        key = m.apiKey = OWN_SETUP_KEY and m.registry.read("connKey_slot-a") = OWN_SETUP_KEY
        print "[own-signin] "; FormatJson({kind: "result", passed: own and other and data and key and not held and m.playingChannel = invalid, default_setup: own, other_preserved: other, data: data, key: key, hash_held: held, no_autoplay: m.playingChannel = invalid})
    end if
end sub
