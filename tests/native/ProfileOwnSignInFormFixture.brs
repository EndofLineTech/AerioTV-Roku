' Native dialog lifecycle fixture. All storage and HTTP endpoints are private.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.activeUserScope = invalid or m.page <> "guide" then return
        store = loadUserProfileStore(m.registry, "slot-a")
        target = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
        target.isDefault = false
        target.order = 1
        m.ownProbeHeld = OWN_PROBE_HELD
        if m.ownProbeHeld then target.addressHeld = true
        ' Imported synthetic PIN material, never generated for owner storage.
        target.pinType = "numbers"
        target.pinSalt = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        target.pinHash = "OWN_PROBE_PIN_HASH"
        store.profiles.push(target)
        recorded = userProfileRecordDefaultIdentity(store, false)
        if not recorded.ok
            m.managementProbeClock.control = "stop"
            print "[own-signin] "; FormatJson({kind: "result", passed: false, address_record: false})
            return
        end if
        store = recorded.store
        if m.ownProbeHeld
            other = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 9, username: "Synthetic9", user_level: 1}, 1)
            other.isDefault = false
            other.addressHeld = true
            other = setCanonicalPreference(other, "defaultIdentityTag", invalid)
            store.profiles.push(other)
            store = setCanonicalPreference(store, "addressChangeSnapshot", {userId: 7, username: "Synthetic7"})
        end if
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        preferences = m.preferenceStore
        preferences.accounts[preferenceScope(connectionPreferenceIdentity(entry, "8"))] = {favoriteIds: ["own-only"], futureField: {value: 9}}
        m.registry.write("settingsV1", FormatJson(preferences))
        m.registry.flush()
        m.ownProbeStore = loadUserProfileStore(m.registry, "slot-a")
        m.ownProbeTarget = target.id
        m.ownProbeSession = currentUserSessionId()
        m.ownProbeCases = ["rejected", "name", "no-api", "correct"]
        m.ownProbeCase = 0
        m.ownProbePassed = beginUserProfileOwnSignIn(target.id)
        m.ownProbePassed = unlockOwnProbePin() and m.ownProbePassed
        m.ownProbeStore = loadUserProfileStore(m.registry, "slot-a")
        if m.profileOwnSignInDialog = invalid
            m.managementProbeClock.control = "stop"
            print "[own-signin] "; FormatJson({kind: "result", passed: false, started: m.ownProbePassed, dialog_type: type(m.profileOwnSignInDialog)})
            return
        end if
        if m.ownProbeHeld then m.ownProbePassed = m.ownProbePassed and instr(1, m.profileOwnSignInDialog.message, "changed. Sign in again to use this profile.") > 0
        m.managementProbePhase = 1
    else if phase = 1
        beforeForm = m.profileOwnSignInDialog
        beforePreferences = FormatJson(m.accountPreferences)
        openSettingsHub()
        showConnection()
        openUserProfileManagement()
        switched = beginUserProfileSwitch(m.ownProbeTarget)
        onGuidePlayerRequest({node: m.guide, getRoSGNode: function() as object
            return m.node
        end function, getData: function() as string
            return "toggleVod"
        end function})
        m.ownProbePassed = m.ownProbePassed and not switched and m.page = "guide" and m.profileOwnSignInDialog.isSameNode(beforeForm) and FormatJson(m.accountPreferences) = beforePreferences and m.profileManagementDialog = invalid
        m.ownProbePassed = m.ownProbePassed and m.profileOwnSignInDialog.subtype() = "AerioDialog" and m.profileOwnSignInDialog.title = "Sign in to Dispatcharr"
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 1))
        m.ownProbePassed = m.ownProbePassed and m.profileOwnSignInDialog.subtype() = "StandardKeyboardDialog" and m.profileOwnSignInDialog.keyboardDomain = "password" and m.profileOwnSignInDialog.textEditBox.secureMode
        m.profileOwnSignInDialog.text = "synthetic-" + m.ownProbeCases[m.ownProbeCase]
        onProfileOwnSignInEdited(managementProbeEvent(m.profileOwnSignInDialog, 0))
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 2))
        m.managementProbePhase = 2
    else if phase = 2
        if m.profileOwnSignInTask <> invalid then return
        scenario = m.ownProbeCases[m.ownProbeCase]
        if scenario = "correct"
            actual = loadUserProfileStore(m.registry, "slot-a")
            passed = m.profileOwnSignInContext = invalid and actual.profiles[1].userId = 88
            if m.ownProbeHeld then passed = passed and not actual.profiles[1].addressHeld and actual.profiles[2].addressHeld and actual.doesExist("addressChangeSnapshot") and actual.profiles[1]["defaultIdentityTag"]["userId"] = 7
            entry = connectionStoreEntry(m.connectionStore, "slot-a")
            oldKey = preferenceScope(connectionPreferenceIdentity(entry, "8"))
            newKey = preferenceScope(connectionPreferenceIdentity(entry, "88"))
            passed = passed and not m.preferenceStore.accounts.doesExist(oldKey) and m.preferenceStore.accounts[newKey].favoriteIds[0] = "own-only"
            m.accountPreferences.favoriteIds = ["current-default-only"]
            m.ownProbeRebased = persistCurrentUserProfilePreferences()
            reloaded = ParseJson(m.registry.read("settingsV1"), "d")
            m.ownProbeRebased = m.ownProbeRebased and not reloaded.accounts.doesExist(oldKey) and reloaded.accounts[newKey].favoriteIds[0] = "own-only"
        else
            passed = m.profileOwnSignInContext <> invalid and m.profileOwnSignInContext.password = "" and FormatJson(loadUserProfileStore(m.registry, "slot-a")) = FormatJson(m.ownProbeStore)
            expected = "Dispatcharr did not accept that username or password."
            if scenario = "no-api" then expected = "This account has no API key yet. Ask your Dispatcharr administrator to turn on API access for it."
            if m.ownProbeHeld
                passed = passed and instr(1, m.profileOwnSignInDialog.message, expected) > 0 and instr(1, m.profileOwnSignInDialog.message, "changed. Sign in again to use this profile.") > 0
            else
                passed = passed and m.profileOwnSignInDialog.message = expected
            end if
        end if
        m.ownProbePassed = m.ownProbePassed and passed
        print "[own-signin] "; FormatJson({kind: "case", scenario: scenario, passed: passed})
        if m.ownProbeCase < m.ownProbeCases.count() - 1
            m.ownProbeCase++
            m.managementProbePhase = 1
        else
            m.managementProbePhase = 3
        end if
    else if phase = 3
        m.ownProbeCancelStore = m.registry.read(userProfileStoreKey("slot-a"))
        m.ownProbeCancelSettings = m.registry.read("settingsV1")
        started = beginUserProfileOwnSignIn(m.ownProbeTarget)
        m.ownProbePassed = m.ownProbePassed and started
        pinCancelled = m.profileOwnSignInDialog = invalid and m.profilePinDialog <> invalid
        onProfilePinClosed(managementProbeEvent(m.profilePinDialog, 0))
        pinCancelled = pinCancelled and m.profileOwnSignInContext = invalid and m.profilePinDialog = invalid and m.guide.active and not m.global.profilegateclosed and m.registry.read(userProfileStoreKey("slot-a")) = m.ownProbeCancelStore
        started = beginUserProfileOwnSignIn(m.ownProbeTarget)
        m.ownProbePassed = m.ownProbePassed and pinCancelled and started
        m.ownProbePassed = unlockOwnProbePin() and m.ownProbePassed
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 1))
        m.profileOwnSignInDialog.text = "synthetic-delayed"
        onProfileOwnSignInEdited(managementProbeEvent(m.profileOwnSignInDialog, 0))
        onProfileOwnSignInChoice(managementProbeEvent(m.profileOwnSignInDialog, 2))
        m.managementProbePhase = 4
    else if phase = 4
        if m.profileOwnSignInTask.progress <> "Verifying account" then return
        print "[own-signin] "; FormatJson({kind: "cancel-ready"})
        m.managementProbePhase = 5
    else if phase < 10
        m.managementProbePhase++
    else
        m.managementProbeClock.control = "stop"
        actual = loadUserProfileStore(m.registry, "slot-a")
        cancelled = m.profileOwnSignInContext = invalid and m.profileOwnSignInDialog = invalid and m.profileOwnSignInTask = invalid and m.registry.read(userProfileStoreKey("slot-a")) = m.ownProbeCancelStore and m.registry.read("settingsV1") = m.ownProbeCancelSettings and m.top.exitRequested <> true and m.guide.active
        trustPreserved = actual["knownDefault"]["userId"] = 7 and actual.profiles[1]["defaultIdentityTag"]["userId"] = 7
        print "[own-signin] "; FormatJson({kind: "result", passed: m.ownProbePassed and cancelled and m.ownProbeRebased and trustPreserved, trust_preserved: trustPreserved, cancelled: cancelled, root_rebased: m.ownProbeRebased, default_preserved: m.registry.read("connKey_slot-a") = "synthetic-a", own_saved: m.registry.read(userProfileKeyName("slot-a", m.ownProbeTarget)) = "synthetic-new-own-key", active_preserved: actual.active = m.ownProbeStore.active and currentUserSessionId() = m.ownProbeSession and m.apiKey = "synthetic-a", no_autoplay: m.playingChannel = invalid})
    end if
end sub

function unlockOwnProbePin() as boolean
    if m.profilePinDialog = invalid or m.profileOwnSignInDialog <> invalid then return false
    pad = m.profilePinDialog
    protected = m.global.profilegateclosed and m.profileGateCover.visible
    pad.textEditBox.text = "1234"
    onProfilePinSubmit(managementProbeEvent(pad, 0))
    return protected and m.profilePinDialog = invalid and m.profileOwnSignInDialog <> invalid and m.profileOwnSignInContext.pin.id = m.ownProbeTarget and m.profileUnlockGrant = invalid and not m.global.profilegateclosed
end function
