' Private cleanup -> imported PIN cancellation -> real outgoing settings write.
sub onManagementProbeTick()
    if m.managementProbePhase = 0
        if m.busy or m.page <> "guide" or m.activeUserScope = invalid or m.capabilityTask <> invalid then return
        m.guardCase = OWN_FAULT_CASE
        m.guardStage = "seed"
        m.guardSource = m.activeUserScope.profileId
        m.guardSourceSession = currentUserSessionId()
        store = loadUserProfileStore(m.registry, "slot-a")
        target = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 2)
        target.isDefault = false
        if m.guardCase = "adult-purpose-change"
            target.pinType = "numbers"
            target.pinSalt = string(32, "b")
            target.pinHash = userProfilePinHash(target.pinSalt, "1234")
            store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
        end if
        third = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 9, username: "Synthetic9", user_level: 1}, 2)
        third.isDefault = false
        store.profiles.push(target)
        store.profiles.push(third)
        m.guardThird = third.id
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        m.guardThirdAccount = preferenceScope(connectionPreferenceIdentity(entry, "9"))
        m.guardForeignAccount = preferenceScope("https://foreign.test|99|slot-b")
        m.preferenceStore.accounts[m.guardThirdAccount] = normalizeAccountPreferences({favoriteIds: ["99"]})
        m.preferenceStore.accounts[m.guardForeignAccount] = {future: "retain"}
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.write(userProfileKeyName("slot-a", target.id), "synthetic-b")
        m.registry.write(userProfileKeyName("slot-a", third.id), "synthetic-third")
        m.registry.write(userProfilePinBackoffKey("slot-a", third.id), FormatJson({failures: 1, round: 0, until: 0}))
        m.registry.write("settingsV1", FormatJson(m.preferenceStore))
        m.registry.flush()
        if not m.registry.exists(userProfileKeyName("slot-a", third.id)) or not m.preferenceStore.accounts.doesExist(m.guardThirdAccount)
            reportSwitchFault(false)
            return
        end if
        if m.guardCase = "adult-purpose-change"
            m.guardStage = "adult-purpose"
            openUserProfileManagement()
            if m.adultPinDialog = invalid
                reportSwitchFault(false)
                return
            end if
            m.adultPinDialog.textEditBox.text = "1234"
            onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 0))
            if not managementProbeChoose("edit", target.id) or not managementProbeChoose("switch")
                reportSwitchFault(false)
                return
            end if
            if m.profilePinDialog = invalid
                reportSwitchFault(false)
                return
            end if
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        else
            if not beginUserProfileSwitch(target.id)
                reportSwitchFault(false)
                return
            end if
        end if
        m.managementProbePhase = 1
    else
        if m.guardCase = "adult-purpose-change"
            if m.profileSwitchContext <> invalid then return
            m.guardStage = "purpose-retired"
            current = loadUserProfileStore(m.registry, "slot-a")
            target = current.profiles[1]
            passed = target.pinHash = userProfilePinHash(target.pinSalt, "5678") and target.pinType = "numbers"
            passed = passed and m.profilePinDialog = invalid and m.profileManagementGrant = invalid
            passed = passed and m.activeUserScope <> invalid and not m.global.profilegateclosed and not m.profileGateCover.visible
            if passed then passed = m.activeUserScope.profileId = m.guardSource and currentUserSessionId() <> m.guardSourceSession
            passed = passed and current.profiles[0].role = "child"
            reportSwitchFault(passed)
            return
        end if
        if m.profilePinDialog = invalid then return
        m.guardStage = "imported-pin"
        cleaned = ParseJson(m.registry.read("settingsV1"), "d")
        passed = not cleaned.accounts.doesExist(m.guardThirdAccount) and not m.preferenceStore.accounts.doesExist(m.guardThirdAccount)
        passed = passed and not m.registry.exists(userProfileKeyName("slot-a", m.guardThird)) and not m.registry.exists(userProfilePinBackoffKey("slot-a", m.guardThird))
        passed = passed and m.global.profilegateclosed and m.profileGateCover.visible and m.activeUserScope.profileId = m.guardSource
        if m.guardCase = "roster-stale-pin"
            pad = m.profilePinDialog
            root = m.registry.read(userProfileStoreKey("slot-a"))
            settings = m.registry.read("settingsV1")
            successor = CreateObject("roDeviceInfo").getRandomUUID()
            m.profileSwitchContext.nonce = successor
            m.profileUnlockGrant = {marker: "successor"}
            nonce = m.global.activeusersession
            pad.textEditBox.text = "5678"
            onProfilePinSubmit(managementProbeEvent(pad, 0))
            passed = passed and m.profileSwitchContext.nonce = successor and m.profileUnlockGrant.marker = "successor" and m.profileSwitchTask = invalid and pad.textEditBox.text = ""
            onProfilePinClosed(managementProbeEvent(pad, 0))
            passed = passed and m.profilePinDialog = invalid and m.top.dialog = invalid and m.profileSwitchContext.nonce = successor
            passed = passed and m.global.activeusersession = nonce and m.global.profilegateclosed and m.profileGateCover.visible and m.profileUnlockGrant.marker = "successor"
            passed = passed and root = m.registry.read(userProfileStoreKey("slot-a")) and settings = m.registry.read("settingsV1")
            passed = passed and not m.registry.exists(userProfilePinBackoffKey("slot-a", m.profileSwitchContext.target.id))
            reportSwitchFault(passed)
            return
        end if
        onProfilePinClosed(managementProbeEvent(m.profilePinDialog, 0))
        m.guardStage = "rollback-write"
        passed = passed and m.profileSwitchContext = invalid and m.activeUserScope <> invalid and not m.global.profilegateclosed
        if passed then passed = currentUserSessionId() <> m.guardSourceSession and m.activeUserScope.profileId = m.guardSource
        if passed then passed = persistCurrentUserProfilePreferences()
        finalSettings = ParseJson(m.registry.read("settingsV1"), "d")
        passed = passed and not finalSettings.accounts.doesExist(m.guardThirdAccount) and finalSettings.accounts[m.guardForeignAccount].future = "retain"
        passed = passed and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read("profKey_slot-a_00000000-0000-4000-8000-000000000002") = "synthetic-b"
        reportSwitchFault(passed)
    end if
end sub
