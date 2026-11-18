' Private real-Scene fault injection; no verifier/admission/registry substitutes.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.page <> "guide" or m.activeUserScope = invalid or m.capabilityTask <> invalid then return
        m.guardCase = OWN_FAULT_CASE
        store = loadUserProfileStore(m.registry, "slot-a")
        target = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 2)
        target.isDefault = false
        target.pinType = "numbers"
        target.pinSalt = string(32, "b")
        target.pinHash = userProfilePinHash(target.pinSalt, "1234")
        if left(m.guardCase, 10) = "own-email-"
            target.pinType = "none"
            target.pinSalt = ""
            target.pinHash = ""
        end if
        store.profiles.push(target)
        if not m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store)) or not m.registry.write(userProfileKeyName("slot-a", target.id), "synthetic-b") or not m.registry.flush()
            reportSwitchFault(false)
            return
        end if
        m.guardTarget = target.id
        m.guardSource = m.activeUserScope.profileId
        m.guardSettings = m.registry.read("settingsV1")
        m.guardSourceSession = currentUserSessionId()
        if left(m.guardCase, 10) = "own-email-"
            m.guardStage = "consent-request"
            m.guardEmailUsername = "Synthetic8"
            if m.guardCase = "own-email-add"
                m.guardEmailUsername = ""
                beginProfileBaselineAdd()
                admitted = m.profileOwnSignInContext <> invalid
            else if m.guardCase = "own-email-child"
                store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
                m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
                m.registry.delete("connKey_slot-a")
                m.registry.flush()
                resetConnectionRuntime()
                applySelectedConnection()
                m.apiKey = ""
                admitted = showUnavailableChildProfile()
                if admitted then admitted = beginUserProfileOwnSignIn(m.guardSource, true, true)
                m.guardEmailUsername = "Synthetic7"
            else
                admitted = beginUserProfileOwnSignIn(target.id)
            end if
            if not admitted
                reportSwitchFault(false)
                return
            end if
            m.guardEmailRequested = m.profileOwnSignInEmail <> invalid
            if m.guardEmailRequested then m.guardEmailRequested = m.profileOwnSignInEmail.command = "getUserData" and m.profileOwnSignInEmail.requestedUserData = "email"
            m.managementProbePhase = 4
            return
        end if
        if m.guardCase = "child-key-loss" or m.guardCase = "unavailable-actor-change" or m.guardCase = "unavailable-actor-state"
            m.guardStage = "unavailable"
            store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
            m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
            m.registry.delete("connKey_slot-a")
            m.registry.flush()
            resetConnectionRuntime()
            applySelectedConnection()
            m.apiKey = ""
            if not showUnavailableChildProfile()
                reportSwitchFault(false)
                return
            end if
            m.guardStage = "adult-purpose"
            onUnavailableChildChoice(managementProbeEvent(m.childUnavailableDialog, m.childUnavailableDialog.buttons.count() - 1))
            if m.adultPinDialog = invalid
                reportSwitchFault(false)
                return
            end if
            m.adultPinDialog.textEditBox.text = "1234"
            onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 0))
            m.guardStage = "choose-target"
            if not managementProbeChoose("edit", target.id) or not managementProbeChoose("switch-unavailable")
                reportSwitchFault(false)
                return
            end if
            m.guardSettings = m.registry.read("settingsV1")
        else
            if not beginUserProfileSwitch(target.id)
                reportSwitchFault(false)
                return
            end if
        end if
        if m.profilePinDialog = invalid
            reportSwitchFault(false)
            return
        end if
        m.guardPad = m.profilePinDialog
        m.guardStage = "target-pin"
        m.guardStoreRoot = m.registry.read(userProfileStoreKey("slot-a"))
        if m.guardCase = "key-loss" or m.guardCase = "child-key-loss"
            m.registry.delete(userProfileKeyName("slot-a", target.id))
            m.registry.flush()
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
            if m.guardCase = "child-key-loss"
                own = m.profileSwitchContext = invalid and m.profileSwitchTask = invalid and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.profileGateCover.visible and m.page = "profile-unavailable"
                own = own and not m.registry.exists("connKey_slot-a") and m.childUnavailableDialog <> invalid
            else
                own = m.profileSwitchContext = invalid and m.profileSwitchTask = invalid and m.activeUserScope <> invalid
                if own then own = m.activeUserScope.profileId = m.guardSource and m.apiKey = "synthetic-a" and not m.global.profilegateclosed and m.registry.read("connKey_slot-a") = "synthetic-a"
            end if
            reportSwitchFault(own and m.registry.read("settingsV1") = m.guardSettings)
            return
        end if
        if m.guardCase = "stale-pin"
            successor = CreateObject("roDeviceInfo").getRandomUUID()
            m.profileSwitchContext.nonce = successor
            m.profileUnlockGrant = {marker: "successor"}
            originalSession = m.global.activeusersession
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.guardPad, 0))
            stale = m.profileUnlockGrant.marker = "successor" and m.profileSwitchTask = invalid and m.global.profilegateclosed
            stale = stale and m.guardPad.textEditBox.text = "" and m.registry.read(userProfileStoreKey("slot-a")) = m.guardStoreRoot
            stale = stale and not m.registry.exists(userProfilePinBackoffKey("slot-a", target.id))
            onProfilePinClosed(managementProbeEvent(m.guardPad, 0))
            stale = stale and m.profileSwitchContext.nonce = successor and m.global.activeusersession = originalSession and m.profileUnlockGrant.marker = "successor"
            stale = stale and m.profilePinDialog = invalid and m.top.dialog = invalid and m.top.exitRequested <> true and m.profileGateCover.visible
            reportSwitchFault(stale)
            return
        end if
        if m.guardCase = "retire-pin"
            m.guardPad.textEditBox.text = "1234"
            retireUserProfileSwitch()
            reportSwitchFault(m.profilePinDialog = invalid and m.profilePinContext = invalid and m.guardPad.close and m.guardPad.textEditBox.text = "" and m.top.dialog = invalid and m.global.profilegateclosed)
            return
        end if
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        m.managementProbePhase = 1
    else if phase = 1
        ' Host sends this only after the target's actual /me request is held.
        if m.guardAuthHeld <> true then return
        context = m.profileSwitchContext
        if context = invalid or m.profileSwitchTask = invalid
            reportSwitchFault(false)
            return
        end if
        if m.guardCase = "unavailable-actor-change" or m.guardCase = "unavailable-actor-state"
            m.guardStage = "late-callbacks"
            m.guardLateTask = m.profileSwitchTask
            m.guardLateNonce = context.nonce
            m.guardLateGlobal = m.global.activeusersession
            m.guardLateGate = m.global.profilegateclosed
            m.guardLateCover = m.profileGateCover.visible
            m.guardLateGrant = m.profileManagementGrant
            m.guardLateRoot = m.registry.read(userProfileStoreKey("slot-a"))
            m.guardLateSettings = m.registry.read("settingsV1")
            m.apiKey = "synthetic-successor"
            ' Deliver real SGNode result/state notifications after actor change.
            if m.guardCase = "unavailable-actor-change" then m.guardLateTask.result = {ok: false, message: "Synthetic late failure"}
            m.guardLateTask.control = "STOP"
            m.managementProbePhase = 2
            return
        end if
        store = loadUserProfileStore(m.registry, "slot-a")
        if m.guardCase = "rollback-pin"
            store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinType", "numbers")
            store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinSalt", string(32, "c"))
            store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinHash", userProfilePinHash(string(32, "c"), "5678"))
        else if m.guardCase = "rollback-role"
            store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
        else if m.guardCase = "rollback-key"
            m.registry.delete("connKey_slot-a")
        else if m.guardCase = "rollback-root"
            m.registry.write("connectionsV1", "")
        end if
        if m.guardCase = "rollback-pin" or m.guardCase = "rollback-role"
            m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
            ' A working import snapshot cannot replace original outgoing proof.
            m.profileSwitchContext.store = loadUserProfileStore(m.registry, "slot-a")
        end if
        m.registry.flush()
        beforeRoot = m.registry.read(userProfileStoreKey("slot-a"))
        ' Admission intentionally persists outgoing preferences before auth.
        ' Measure rollback preservation from the actual held-auth boundary.
        beforeSettings = m.registry.read("settingsV1")
        m.guardStage = "rollback"
        rollbackUserProfileSwitch("Synthetic fault verification")
        if m.guardCase = "rollback-unchanged"
            passed = m.activeUserScope <> invalid and m.profileSwitchContext = invalid and not m.profileGateCover.visible and not m.global.profilegateclosed
            if passed then passed = m.activeUserScope.profileId = m.guardSource and currentUserSessionId() <> m.guardSourceSession
        else
            passed = m.activeUserScope = invalid and m.profileSwitchContext = invalid and m.global.activeusersession = "" and m.global.profilegateclosed and m.profileGateCover.visible and not m.guide.active and m.profileUnlockGrant = invalid and m.userProfileRecoveryRequired
        end if
        m.guardEvidence = {admission: passed, roster_retained: m.registry.read(userProfileStoreKey("slot-a")) = beforeRoot, settings_retained: m.registry.read("settingsV1") = beforeSettings}
        reportSwitchFault(passed and m.registry.read(userProfileStoreKey("slot-a")) = beforeRoot and m.registry.read("settingsV1") = beforeSettings)
    else if phase = 2
        m.managementProbePhase = 3
    else if phase = 3
        if m.guardLateTask.state <> "stop" then return
        m.guardEvidence = {key_retained: m.apiKey = "synthetic-successor", no_actor: m.activeUserScope = invalid, context_retained: m.profileSwitchContext <> invalid, task_retained: m.profileSwitchTask <> invalid, nonce_retained: m.global.activeusersession = m.guardLateGlobal, gate_closed: m.global.profilegateclosed, covered: m.profileGateCover.visible, grant_retained: FormatJson(m.profileManagementGrant) = FormatJson(m.guardLateGrant), roster_retained: m.registry.read(userProfileStoreKey("slot-a")) = m.guardLateRoot, settings_retained: m.registry.read("settingsV1") = m.guardLateSettings}
        passed = m.apiKey = "synthetic-successor" and m.activeUserScope = invalid and m.profileSwitchContext <> invalid and m.profileSwitchTask <> invalid
        if passed then passed = m.profileSwitchContext.nonce = m.guardLateNonce and m.profileSwitchTask.isSameNode(m.guardLateTask)
        passed = passed and m.global.activeusersession = m.guardLateGlobal and m.global.profilegateclosed = m.guardLateGate and m.profileGateCover.visible = m.guardLateCover
        passed = passed and FormatJson(m.profileManagementGrant) = FormatJson(m.guardLateGrant)
        if m.guardCase = "unavailable-actor-state" then passed = passed and type(m.guardLateTask.result) <> "roAssociativeArray"
        passed = passed and m.registry.read(userProfileStoreKey("slot-a")) = m.guardLateRoot and m.registry.read("settingsV1") = m.guardLateSettings
        reportSwitchFault(passed)
    else if phase = 4
        if m.profileOwnSignInEmail <> invalid then return
        m.guardStage = "consent-continuation"
        passed = m.guardEmailRequested and m.profileOwnSignInDialog <> invalid and m.profileOwnSignInTask = invalid and m.profileOwnSignInContext <> invalid
        if passed then passed = m.profileOwnSignInContext.username = m.guardEmailUsername and m.profileOwnSignInContext.rokuEmailOffered = true
        if m.guardCase = "own-email-child"
            passed = passed and m.activeUserScope = invalid and m.apiKey = "" and not m.registry.exists("connKey_slot-a") and m.profileGateCover.visible
        else
            passed = passed and m.activeUserScope <> invalid
            if passed then passed = m.activeUserScope.profileId = m.guardSource and currentUserSessionId() = m.guardSourceSession
            passed = passed and m.registry.read("connKey_slot-a") = "synthetic-a"
        end if
        passed = passed and m.registry.read("settingsV1") = m.guardSettings
        m.guardEvidence = {requested: m.guardEmailRequested, username_retained: m.profileOwnSignInContext.username = m.guardEmailUsername, no_auth_task: m.profileOwnSignInTask = invalid}
        cancelUserProfileOwnSignIn()
        reportSwitchFault(passed and m.profileOwnSignInContext = invalid and m.profileOwnSignInEmail = invalid)
    end if
end sub

sub reportSwitchFault(passed as boolean)
    m.managementProbeClock.control = "stop"
    print "[switch-fault] "; FormatJson({kind: "result", case_name: m.guardCase, stage: m.guardStage, checks: m.guardEvidence, passed: passed, no_autoplay: m.playingChannel = invalid})
end sub
