' Private app fixture: actual manual handler, new HTTP origin, then verified
' default reconnect. No owner registry/cache or production provider is used.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.activeUserScope = invalid or m.page <> "guide" then return
        m.addressReplaceDefault = OWN_ADDRESS_REPLACE
        m.addressOldEntry = connectionStoreEntry(m.connectionStore, "slot-a")
        m.addressOldSession = currentUserSessionId()
        m.addressOldProfile = m.activeUserScope.profileId
        m.accountPreferences.favoriteIds = ["default-private"]
        m.addressPassed = persistCurrentUserProfilePreferences()
        store = loadUserProfileStore(m.registry, "slot-a")
        b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
        b.isDefault = false
        b.order = 1
        store.profiles.push(b)
        recorded = userProfileRecordDefaultIdentity(store, false)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(recorded.store))
        m.registry.write(userProfileKeyName("slot-a", b.id), "synthetic-b")
        m.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(m.addressOldEntry, "8"))] = {favoriteIds: ["bob-private"]}
        savePreferenceStore(m.registry, m.preferenceStore)
        m.profileSessionKeys = {}
        for each profile in store.profiles
            m.profileSessionKeys[preferenceScope(m.addressOldEntry.url + "|slot-a|" + profile.id)] = "synthetic-old-memory"
        end for
        m.addressBeforeSettings = m.registry.read("settingsV1")
        m.addressBeforeStore = m.registry.read(userProfileStoreKey("slot-a"))
        m.addressInnerRegistry = m.registry
        m.registry = {inner: m.addressInnerRegistry, flushes: 0, read: function(key as string) as string
            return m.inner.read(key)
        end function, exists: function(key as string) as boolean
            return m.inner.exists(key)
        end function, write: function(key as string, value as string) as boolean
            return m.inner.write(key, value)
        end function, delete: function(key as string) as boolean
            return m.inner.delete(key)
        end function, flush: function() as boolean
            m.flushes++
            if m.failOnce = true then m.failOnce = false : return false
            return m.inner.flush()
        end function}
        m.managementProbePhase = 1
    else if phase = 1
        beforeConnection = m.registry.read("connectionsV1")
        m.registry.failOnce = true
        updateConnectionUrl(OWN_ADDRESS_NEW_URL)
        rollback = m.registry.read("connectionsV1") = beforeConnection and m.registry.read(userProfileStoreKey("slot-a")) = m.addressBeforeStore and m.registry.read("settingsV1") = m.addressBeforeSettings and m.registry.read("connKey_slot-a") = "synthetic-a" and currentUserSessionId() = m.addressOldSession and m.apiKey = "synthetic-a" and m.profileSessionKeys.count() = 2
        if not rollback
            m.managementProbeClock.control = "stop"
            print "[profile-address] "; FormatJson({kind: "result", passed: false, rollback: rollback, connection_same: m.registry.read("connectionsV1") = beforeConnection, store_same: m.registry.read(userProfileStoreKey("slot-a")) = m.addressBeforeStore, settings_same: m.registry.read("settingsV1") = m.addressBeforeSettings, slot_old: m.registry.read("connKey_slot-a") = "synthetic-a", session_same: currentUserSessionId() = m.addressOldSession, api_old: m.apiKey = "synthetic-a", memory_count: m.profileSessionKeys.count(), flushes: m.registry.flushes})
            return
        end if
        m.registry.flushes = 0
        updateConnectionUrl(OWN_ADDRESS_NEW_URL)
        store = loadUserProfileStore(m.registry, "slot-a")
        entry = connectionStoreEntry(loadConnectionStore(m.registry), "slot-a")
        atomic = m.registry.flushes = 1 and entry.url = OWN_ADDRESS_NEW_URL and not entry.remember and store.active = store.profiles[0].id and store.profiles[1].addressHeld and store["addressChangeSnapshot"]["userId"] = 7
        retired = m.activeUserScope = invalid and m.apiKey = "" and m.profileSessionKeys.count() = 0 and not m.registry.exists("connKey_slot-a") and not m.registry.exists(userProfileKeyName("slot-a", store.profiles[1].id))
        preserved = m.registry.read("settingsV1") = m.addressBeforeSettings and store.profiles[1]["preferenceAnchor"] = connectionPreferenceIdentity(m.addressOldEntry, "8")
        m.addressPassed = m.addressPassed and atomic and retired and preserved
        if not m.addressPassed
            m.managementProbeClock.control = "stop"
            print "[profile-address] "; FormatJson({kind: "result", passed: false, atomic: atomic, retired: retired, preserved: preserved})
            return
        end if
        m.apiKey = "synthetic-new-default"
        m.authMode = "key"
        m.remember = false
        connectServer(true)
        m.managementProbePhase = 2
    else if phase = 2
        if m.busy then return
        m.managementProbeClock.control = "stop"
        store = loadUserProfileStore(m.registry, "slot-a")
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        preferences = ParseJson(m.registry.read("settingsV1"), "d")
        own = m.page = "guide" and m.activeUserScope <> invalid
        if own
            if m.addressReplaceDefault
                own = m.activeUserScope.accountId = "70" and currentUserSessionId() <> m.addressOldSession and m.accountPreferences.favoriteIds.count() = 0 and store.profiles[0].id = m.addressOldProfile and store.profiles[0].updatedAt = 0 and store.profiles[0].order = -1
            else
                own = m.activeUserScope.accountId = "7" and currentUserSessionId() <> m.addressOldSession and m.accountPreferences.favoriteIds[0] = "default-private"
            end if
        end if
        if m.addressReplaceDefault
            isolated = preferences.accounts[preferenceScope(connectionPreferenceIdentity(m.addressOldEntry, "7"))].favoriteIds[0] = "default-private" and preferences.accounts.doesExist(preferenceScope(connectionPreferenceIdentity(entry, "70")))
            if isolated then isolated = preferences.accounts[preferenceScope(connectionPreferenceIdentity(entry, "70"))].favoriteIds.count() = 0
        else
            isolated = not preferences.accounts.doesExist(preferenceScope(connectionPreferenceIdentity(m.addressOldEntry, "7"))) and preferences.accounts[preferenceScope(connectionPreferenceIdentity(entry, "7"))].favoriteIds[0] = "default-private"
        end if
        isolated = isolated and preferences.accounts[preferenceScope(connectionPreferenceIdentity(m.addressOldEntry, "8"))].favoriteIds[0] = "bob-private"
        lifted = not store.profiles[1].addressHeld and not store.doesExist("addressChangeSnapshot") and store["knownDefault"]["userId"] = 7
        holdsCorrect = lifted
        if m.addressReplaceDefault then holdsCorrect = store.profiles[1].addressHeld and store.doesExist("addressChangeSnapshot") and store["knownDefault"]["userId"] = 7
        print "[profile-address] "; FormatJson({kind: "result", passed: m.addressPassed and own and isolated and holdsCorrect and m.playingChannel = invalid, own: own, isolated: isolated, lifted: lifted, holds_correct: holdsCorrect, no_autoplay: m.playingChannel = invalid, status: m.status, page: m.page, closed: userProfileGateClosed(), pending: userProfileUiClosed(), recovery: m.userProfileRecoveryRequired = true})
    end if
end sub
