' Disposable capacity measurement. Never enumerate/read application sections.
' UUID namespacing prevents deleting any existing section; UUID is NOT entropy
' for a PIN salt, pairing key or other security function.
sub profileProbeRegistry()
    registry = CreateObject("roRegistry")
    sectionName = "AerioProfileProbe-" + CreateObject("roDeviceInfo").getRandomUUID()
    baseline = registry.getSpaceAvailable()
    fixtures = ParseJson(ReadAsciiFile("pkg:/profile-registry-fixtures.json"))
    print "[profile-probe] registry-baseline="; baseline
    for each fixture in fixtures
        section = CreateObject("roRegistrySection", sectionName)
        written = true
        for each key in fixture.values
            written = section.write(key, fixture.values[key]) and written
        end for
        flushed = section.flush()
        available = registry.getSpaceAvailable()
        verified = written and flushed
        if verified
            for each key in fixture.values
                if section.read(key) <> fixture.values[key] then verified = false
            end for
        end if
        print "[profile-probe] registry profiles-per-slot="; fixture.profilesPerSlot; " four-slots=true full-preferences=24000 saved="; verified; " available="; available
        ' Delete only this newly allocated probe section, even on write failure.
        section = invalid
        removed = registry.delete(sectionName)
        removed = registry.flush() and removed
        ' GetSpaceAvailable may change after registry recompression; prove
        ' cleanup by reading ONLY our disposable section's key list instead
        ' of assuming byte-for-byte accounting is stable across a flush.
        checkSection = CreateObject("roRegistrySection", sectionName)
        empty = checkSection.getKeyList().count() = 0
        checkSection = invalid
        removed = registry.delete(sectionName) and removed
        removed = registry.flush() and removed
        print "[profile-probe] registry-cleanup removed="; removed; " empty="; empty; " available="; registry.getSpaceAvailable()
        profileAssert(removed and empty, "registry-probe-section-deleted")
        if not removed then exit for
    end for
end sub

' Exercise the real registry with the production store, not only fixture JSON.
' This section is newly named and contains public synthetic values exclusively.
sub profileProbeStoreRegistry()
    registry = CreateObject("roRegistry")
    sectionName = "AerioProfileStoreProbe-" + CreateObject("roDeviceInfo").getRandomUUID()
    section = CreateObject("roRegistrySection", sectionName)
    slot = "slot-a"
    ready = section.write("connKey_slot-a", "synthetic-default-key") and section.flush()
    before = loadUserProfileStore(section, slot)
    first = userProfileFromVerified(slot, "00000000-0000-4000-8000-000000000001", {id: "2147483648", username: "Alice", user_level: 1}, 100)
    staged = userProfileEnsureDefault(before, first)
    if ready and staged <> invalid
        saved = commitUserProfileStore(section, before, staged, {}, true)
        ready = saved.ok
    else
        ready = false
    end if
    profileAssert(ready, "native-registry-default-migration")
    if ready
        loaded = loadUserProfileStore(section, slot)
        ready = loaded.readOnly <> true
        if ready
            ready = loaded.profiles[0].id = first.id and loaded.profiles[0].userId = 2147483648& and loaded.profiles[0].updatedAt = 0
        end if
        profileAssert(ready, "native-registry-default-id-and-unstamped-roundtrip")
        if ready
            other = userProfileFromVerified(slot, "00000000-0000-4000-8000-000000000002", {id: 9, username: "other", user_level: 1}, 101)
            other.isDefault = false
            candidate = copyJson(loaded)
            candidate.profiles.push(other)
            keys = {}
            keys[other.id] = "synthetic-other-key"
            saved = commitUserProfileStore(section, loaded, candidate, keys, true)
            profileAssert(saved.ok and section.read(userProfileKeyName(slot, other.id)) = "synthetic-other-key", "native-registry-own-key-with-roster")
            saved = commitUserProfileStore(section, candidate, candidate, {}, false)
            profileAssert(saved.ok and not section.exists(userProfileKeyName(slot, other.id)), "native-registry-remember-off-deletes-own-key")
            profileAssert(section.read("connKey_slot-a") = "synthetic-default-key", "native-registry-default-key-untouched")
            connections = connectionStoreAdd(defaultConnectionStore(), slot, "Synthetic")
            connections = connectionStoreUpdate(connections, slot, {url: "https://example.test", accountId: "2147483648"})
            preferences = defaultPreferenceStore()
            preferences.accounts[preferenceScope("https://example.test|2147483648|slot-a")] = {favoriteIds: ["synthetic"]}
            preferences.accounts[preferenceScope("https://example.test|9|slot-a")] = {favoriteIds: ["synthetic-other"]}
            seeded = section.write("connectionsV1", FormatJson(connections))
            seeded = section.write("settingsV1", FormatJson(preferences)) and seeded
            seeded = section.write(userProfileKeyName("slot-b", other.id), "synthetic-other-slot-key") and seeded
            seeded = section.flush() and seeded
            if seeded
                activeScope = userProfileSessionScope(connectionStoreEntry(connections, slot), loaded.active, "2147483648", "synthetic-authority", "00000000-0000-4000-8000-000000000090")
                effective = normalizeDevicePreferences({themePreset: "forest", clockFormat: "24"})
                scoped = commitUserProfilePreferences(section, preferences, preferences.accounts[preferenceScope(activeScope.preferenceIdentity)], effective, activeScope, activeScope)
                profileAssert(scoped.ok, "native-registry-scoped-settings-transaction")
                if scoped.ok
                    roundtrip = loadPreferenceStore(section)
                    account = roundtrip.accounts[preferenceScope(activeScope.preferenceIdentity)]
                    profileAssert(account.profileSettings.themePreset = "forest" and account.favoriteIds[0] = "synthetic" and roundtrip.accounts.count() = 2, "native-registry-scoped-settings-preserve-own-data-and-other-user")
                    newer = setCanonicalPreference(activeScope, "sessionId", "00000000-0000-4000-8000-000000000091")
                    before = section.read("settingsV1")
                    stale = commitUserProfilePreferences(section, scoped.store, scoped.preferences, effective, activeScope, newer)
                    profileAssert(not stale.ok and before = section.read("settingsV1"), "native-registry-stale-scoped-write-refused")
                end if
                if scoped.ok
                    snapshots = {}
                    snapshots[userProfileStoreKey(slot)] = section.read(userProfileStoreKey(slot))
                    snapshots["settingsV1"] = section.read("settingsV1")
                    otherKey = userProfileKeyName(slot, other.id)
                    section.write(otherKey, "synthetic-other-pull-key")
                    section.flush()
                    snapshots[otherKey] = section.read(otherKey)
                    tombstones = dispatcharrSyncRosterDecode({rows: [], removed: [[other.username, 200]]})
                    pulled = commitDispatcharrRosterPull(section, connectionStoreEntry(connections, slot), candidate, tombstones, true, 300, activeScope, activeScope)
                    profileAssert(pulled.ok and not section.exists(otherKey) and pulled.store.profiles.count() = 1, "native-registry-roster-pull-key-and-metadata-cleanup")
                    if pulled.ok then profileAssert(pulled.preferences.accounts.count() = 1 and section.read("connKey_" + slot) = "synthetic-default-key", "native-registry-roster-pull-preserves-default-scope-and-key")
                    restoredPull = userProfileRegistryTransaction(section, snapshots)
                    profileAssert(restoredPull.ok, "native-registry-roster-pull-fixture-restored-for-lifecycle-checks")
                end if
                removal = removeUserProfile(section, connectionStoreEntry(connections, slot), candidate, other.id, 200, "normal")
                profileAssert(removal.ok, "native-registry-profile-removal")
                if removal.ok then profileAssert(removal.preferences.accounts.count() = 1, "native-registry-only-target-scope-removed")
                forgotten = forgetUserProfileConnection(section, connections, slot)
                profileAssert(forgotten.ok and not section.exists(userProfileStoreKey(slot)) and not section.exists("connKey_slot-a"), "native-registry-atomic-slot-forget")
                profileAssert(section.read(userProfileKeyName("slot-b", other.id)) = "synthetic-other-slot-key", "native-registry-forget-preserves-other-slot-key")
            else
                profileAssert(false, "native-registry-forget-fixture-ready")
            end if
        end if
    end if
    section = invalid
    removed = registry.delete(sectionName)
    removed = registry.flush() and removed
    own = CreateObject("roRegistrySection", sectionName)
    empty = own.getKeyList().count() = 0
    own = invalid
    removed = registry.delete(sectionName) and removed
    removed = registry.flush() and removed
    profileAssert(removed and empty, "native-registry-store-probe-cleaned")
end sub
