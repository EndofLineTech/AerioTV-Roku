' Private app fixture: switch to B through the production controller, then
' recover inactive default A using real credential Tasks and numeric PIN UI.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.activeUserScope = invalid or m.page <> "guide" then return
        store = loadUserProfileStore(m.registry, "slot-a")
        b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
        b.isDefault = false
        b.order = 1
        store.profiles.push(b)
        recorded = userProfileRecordDefaultIdentity(store, false)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(recorded.store))
        m.registry.write(userProfileKeyName("slot-a", b.id), "synthetic-b")
        m.registry.flush()
        m.ownProbePassed = recorded.ok and beginUserProfileSwitch(b.id)
        m.managementProbePhase = 1
    else if phase = 1
        if m.profileSwitchContext <> invalid then return
        store = loadUserProfileStore(m.registry, "slot-a")
        m.ownProbePassed = m.ownProbePassed and store.active = store.profiles[1].id and m.apiKey = "synthetic-b" and m.activeUserScope.accountId = "8"
        target = store.profiles[0]
        target = setCanonicalPreference(target, "pinType", "numbers")
        target = setCanonicalPreference(target, "pinSalt", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        target = setCanonicalPreference(target, "pinHash", "OWN_PROBE_PIN_HASH")
        store.profiles[0] = target
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.flush()
        m.ownProbeTarget = target.id
        m.ownProbeSession = currentUserSessionId()
        m.ownProbeSettings = m.registry.read("settingsV1")
        m.ownProbeCases = ["rejected", "name", "id", "no-api", "correct"]
        m.ownProbeCase = 0
        started = beginUserProfileOwnSignIn(target.id)
        m.ownProbePassed = started and m.ownProbePassed
        if not started
            m.managementProbeClock.control = "stop"
            print "[own-signin] "; FormatJson({kind: "result", passed: false, started: false, switched: m.activeUserScope.accountId = "8", page: m.page, role: currentUserSettingsRole(), active_target: store.active = target.id, known: userProfileDefaultOwnIdentityMatches(connectionStoreEntry(m.connectionStore, "slot-a"), store, {id: target.userId, username: target.username}), pending: m.profileSwitchContext <> invalid, closed: userProfileGateClosed(), readonly: store.readOnly = true})
            return
        end if
        m.ownProbePassed = unlockDefaultOwnProbePin() and m.ownProbePassed
        m.ownProbeStore = m.registry.read(userProfileStoreKey("slot-a"))
        m.managementProbePhase = 2
    else if phase = 2
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 1))
        m.ownProbePassed = m.ownProbePassed and m.profileOwnSignInDialog.subtype() = "StandardKeyboardDialog" and m.profileOwnSignInDialog.textEditBox.secureMode
        m.profileOwnSignInDialog.text = "synthetic-" + m.ownProbeCases[m.ownProbeCase]
        onProfileOwnSignInEdited(managementProbeEvent(m.profileOwnSignInDialog, 0))
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 2))
        m.ownProbePassed = m.ownProbePassed and m.profileOwnSignInTask.expectedUserId = "7" and m.profileOwnSignInTask.expectedUsername = "Synthetic7"
        m.managementProbePhase = 3
    else if phase = 3
        if m.profileOwnSignInTask <> invalid then return
        scenario = m.ownProbeCases[m.ownProbeCase]
        if scenario = "correct"
            passed = m.profileOwnSignInContext = invalid and m.registry.read("connKey_slot-a") = "synthetic-new-own-key"
        else
            expected = "Dispatcharr did not accept that username or password."
            if scenario = "no-api" then expected = "This account has no API key yet. Ask your Dispatcharr administrator to turn on API access for it."
            passed = m.profileOwnSignInContext <> invalid and m.profileOwnSignInDialog.message = expected and m.registry.read("connKey_slot-a") = "synthetic-a"
        end if
        passed = passed and m.registry.read("settingsV1") = m.ownProbeSettings and m.registry.read(userProfileStoreKey("slot-a")) = m.ownProbeStore
        m.ownProbePassed = m.ownProbePassed and passed
        print "[own-signin] "; FormatJson({kind: "case", scenario: scenario, passed: passed})
        if m.ownProbeCase < m.ownProbeCases.count() - 1
            m.ownProbeCase++
            m.managementProbePhase = 2
        else
            m.managementProbePhase = 4
        end if
    else if phase = 4
        started = beginUserProfileOwnSignIn(m.ownProbeTarget)
        m.ownProbePassed = started and m.ownProbePassed
        onProfilePinClosed(managementProbeEvent(m.profilePinDialog, 0))
        m.ownProbePassed = m.ownProbePassed and m.profileOwnSignInContext = invalid and m.guide.active
        started = beginUserProfileOwnSignIn(m.ownProbeTarget)
        m.ownProbePassed = started and m.ownProbePassed
        m.ownProbePassed = unlockDefaultOwnProbePin() and m.ownProbePassed
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 1))
        m.profileOwnSignInDialog.text = "synthetic-delayed"
        onProfileOwnSignInEdited(managementProbeEvent(m.profileOwnSignInDialog, 0))
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 2))
        m.managementProbePhase = 5
    else if phase = 5
        if m.profileOwnSignInTask.progress <> "Verifying account" then return
        print "[own-signin] "; FormatJson({kind: "cancel-ready"})
        m.managementProbePhase = 6
    else if phase < 12
        m.managementProbePhase++
    else
        m.managementProbeClock.control = "stop"
        actual = loadUserProfileStore(m.registry, "slot-a")
        cancelled = m.profileOwnSignInContext = invalid and m.profileOwnSignInDialog = invalid and m.profileOwnSignInTask = invalid and m.guide.active and m.top.exitRequested <> true
        ownSaved = m.registry.read("connKey_slot-a") = "synthetic-new-own-key" and not m.registry.exists(userProfileKeyName("slot-a", m.ownProbeTarget))
        outgoingPreserved = m.registry.read(userProfileKeyName("slot-a", actual.active)) = "synthetic-b"
        activePreserved = actual.active = actual.profiles[1].id and m.activeUserScope.accountId = "8" and currentUserSessionId() = m.ownProbeSession and m.apiKey = "synthetic-b"
        trustPreserved = actual["knownDefault"]["userId"] = 7 and actual.profiles[1]["defaultIdentityTag"]["userId"] = 7
        settingsPreserved = m.registry.read("settingsV1") = m.ownProbeSettings
        print "[own-signin] "; FormatJson({kind: "result", passed: m.ownProbePassed and cancelled and ownSaved and outgoingPreserved and activePreserved and trustPreserved and settingsPreserved, cancelled: cancelled, own_saved: ownSaved, outgoing_preserved: outgoingPreserved, active_preserved: activePreserved, trust_preserved: trustPreserved, settings_preserved: settingsPreserved, no_autoplay: m.playingChannel = invalid})
    end if
end sub

function unlockDefaultOwnProbePin() as boolean
    if m.profilePinDialog = invalid or m.profileOwnSignInDialog <> invalid then return false
    pad = m.profilePinDialog
    covered = m.global.profilegateclosed and m.profileGateCover.visible
    pad.textEditBox.text = "1234"
    onProfilePinSubmit(managementProbeEvent(pad, 0))
    return covered and m.profilePinDialog = invalid and m.profileOwnSignInDialog <> invalid and m.profileOwnSignInContext.pin.id = m.ownProbeTarget and m.profileUnlockGrant = invalid
end function
