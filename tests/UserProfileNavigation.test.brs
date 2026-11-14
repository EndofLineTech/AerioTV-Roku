sub main()
    m.profilePreferenceDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    runLegacyOwnerMigrationChecks()
    runColdProfileRestoreChecks()
    parsedDevice = normalizeDevicePreferences(ParseJson("{}"))
    check(parsedDevice.networkTimeoutSeconds = 20 and parsedDevice.refreshSeconds = 300, "parsed empty device settings provide runtime timeout and refresh defaults")
    parsedAccount = normalizeAccountPreferences(ParseJson("{}"))
    check(type(parsedAccount.favoriteIds) = "roArray" and parsedAccount.startupBehavior = "guide", "parsed empty own account provides runtime data and startup defaults")
    resetProfileNavigation()
    check(ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "legacy replacement fixture establishes old holder")
    m.registry.values["preferences"] = FormatJson({favoriteIds: ["old-private"]})
    m.registry.values["accountIdentity"] = "https://example.test|7"
    snapshot = FormatJson(m.registry.values)
    check(not ensureConnectedUserProfile({phase: "verified", accountId: "7", accountUsername: "DifferentAlice", verifiedUser: {id: 7, username: "DifferentAlice", user_level: 1}}, "", 101), "same-ID replacement refuses while unscoped legacy personal data has no safe migrated owner")
    check(FormatJson(m.registry.values) = snapshot, "legacy replacement refusal preserves all old private bytes and creates no empty canonical root")
    resetProfileNavigation()
    m.connectionStore.entries[0].id = "legacy"
    m.selectedConnectionId = "legacy"
    m.connectionStore.selected = "legacy"
    check(ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "slot-less replacement fixture establishes old holder")
    m.registry.values["serverUrl"] = "https://example.test"
    m.registry.values["accountIdentity"] = "https://example.test|7"
    priorSettings = {schema: 1, device: {}, accounts: {}}
    priorSettings.accounts[preferenceScope("https://example.test|7")] = {FuturePrivate: {retained: true}}
    m.registry.values["settingsV1"] = FormatJson(priorSettings)
    snapshot = FormatJson(m.registry.values)
    check(not ensureConnectedUserProfile({phase: "verified", accountId: "7", accountUsername: "DifferentAlice", verifiedUser: {id: 7, username: "DifferentAlice", user_level: 1}}, "", 101) and FormatJson(m.registry.values) = snapshot, "slot-less legacy private data cannot survive replacement as an importable old-owner source")
    resetProfileNavigation()
    check(selectedUserProfileGate().allowed, "absent roster permits verified legacy migration")
    check(userProfileConnectionSetupAllowed(), "absent roster retains first-time setup")
    m.userProfileRecoveryRequired = true
    check(not selectedUserProfileGate().allowed, "failed rollback remains fenced until process recovery")
    m.userProfileRecoveryRequired = false
    m.registry.values["userProfilesV1_slot-a"] = ""
    check(not selectedUserProfileGate().allowed, "present empty roster fences connection before a request")
    before = m.registry.flushes
    check(not ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "corruption cannot be replaced with an unrestricted default after authentication")
    check(m.registry.flushes = before, "recovery refusal writes nothing")
    resetProfileNavigation()
    check(ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "verified default migration persists")
    check(m.userProfileStore.profiles[0].username = "Alice" and m.userProfileStore.profiles[0].updatedAt = 0, "migration uses verified identity and stays unstamped")
    known = loadUserProfileStore(m.registry, "slot-a")
    check(known.doesExist("knownDefault") and known["knownDefault"]["userId"] = 7 and known["knownDefault"]["username"] = "Alice", "successful default verification records its own identity in the migration Flush")
    anchored = copyJson(known)
    anchored.profiles[0] = setCanonicalPreference(anchored.profiles[0], "preferenceAnchor", "https://old.test|7|slot-a")
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(anchored))
    preferences = {schema: 1, device: {}, accounts: {}}
    preferences.accounts[preferenceScope("https://old.test|7|slot-a")] = {favoriteIds: ["default-only"], futureField: {value: 9}}
    preferences.accounts["foreign"] = {favoriteIds: ["foreign-only"]}
    m.registry.write("settingsV1", FormatJson(preferences))
    beforeMigration = FormatJson(m.registry.values)
    m.registry.failFlush = true
    check(not ensureConnectedUserProfile(profileResult(), "", 100) and FormatJson(m.registry.values) = beforeMigration, "failed default data migration restores its old anchor, old blob and exact settings bytes")
    before = m.registry.flushes
    check(ensureConnectedUserProfile(profileResult(), "", 100), "verified same default migrates its anchored data to the current address")
    migrated = ParseJson(m.registry.read("settingsV1"))
    newKey = preferenceScope(connectionPreferenceIdentity(m.connectionStore.entries[0], "7"))
    check(m.registry.flushes = before + 1 and not migrated.accounts.doesExist(preferenceScope("https://old.test|7|slot-a")) and migrated.accounts[newKey].favoriteIds[0] = "default-only" and migrated.accounts.foreign.favoriteIds[0] = "foreign-only", "default anchor migration moves only its own blob in the same metadata Flush")
    check(userProfileConnectionSetupAllowed(), "Standard can configure its selected connection")
    m.profileOwnSignInContext = {nonce: "pending-own-sign-in"}
    check(not userProfileConnectionSetupAllowed(), "general setup cannot replace a pending own-profile credential form")
    m.profileOwnSignInContext = invalid
    m.global = {profilegateclosed: true}
    check(not userProfileConnectionSetupAllowed(), "closed profile gates refuse setup even for a saved Standard role")
    m.global = invalid
    childStore = copyJson(m.userProfileStore)
    childStore.profiles[0] = setCanonicalPreference(childStore.profiles[0], "role", "child")
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(childStore))
    check(not userProfileConnectionSetupAllowed(), "persisted Child cannot open general setup without an active authenticated scope")
    m.profileManagementGrant = {kind: "pin", purpose: "manage-profiles"}
    check(not userProfileConnectionSetupAllowed(), "adult management authority never grants Child general setup or receiver access")
    m.registry.write(userProfileStoreKey("slot-a"), "not-json")
    check(not userProfileConnectionSetupAllowed(), "corrupt persisted authority cannot become an unrestricted setup form")
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(m.userProfileStore))
    check(m.registry.read("connKey_slot-a") = "default-key", "migration cannot move the default key")
    check(ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000002", 101), "reconnect preserves default identity")
    check(m.userProfileStore.profiles[0].id = "00000000-0000-4000-8000-000000000001", "reconnect does not create another UUID")
    frozen = setCanonicalPreference(m.userProfileStore, "knownDefault", {userId: 70, username: "FrozenDefault"})
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 8, username: "Bob", user_level: 1}, 1)
    b.isDefault = false
    b.addressHeld = true
    frozen.profiles.push(b)
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(frozen))
    check(ensureConnectedUserProfile(profileResult(), "", 102), "default verification may continue while another profile is held")
    known = loadUserProfileStore(m.registry, "slot-a")
    check(known["knownDefault"]["userId"] = 70 and known.profiles[1]["defaultIdentityTag"]["userId"] = 70, "ordinary default reconnect freezes the old identity and migrates legacy held tags from that record")
    frozen = setCanonicalPreference(frozen, "addressChangeSnapshot", {userId: 70, username: "FrozenDefault"})
    frozen.profiles.pop()
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(frozen))
    check(ensureConnectedUserProfile(profileResult(), "", 103), "default verification retains a pending address-change snapshot even when no non-default profile remains")
    check(loadUserProfileStore(m.registry, "slot-a")["knownDefault"]["userId"] = 70, "a default /me from the same pending address change cannot record the new user over its own comparison baseline")
    resetProfileNavigation()
    wrong = profileResult()
    wrong.verifiedUser.id = 8
    check(not ensureConnectedUserProfile(wrong, "00000000-0000-4000-8000-000000000001", 100) and m.registry.flushes = 0, "task identity mismatch cannot be committed")
    resetProfileNavigation()
    m.registry.failFlush = true
    check(not ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "failed migration does not authorize runtime")
    check(not m.registry.exists("userProfilesV1_slot-a"), "failed migration restores absence")
    for each failReplacement in [false, true]
        resetProfileNavigation()
        ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100)
        previousId = m.userProfileStore.active
        staged = copyJson(m.userProfileStore)
        staged.profiles[0] = setCanonicalPreference(staged.profiles[0], "preferenceAnchor", "https://old.test|7|slot-a")
        b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 8, username: "Bob", user_level: 1}, 1)
        b.isDefault = false
        b.addressHeld = true
        staged.profiles.push(b)
        staged = setCanonicalPreference(staged, "addressChangeSnapshot", {userId: 7, username: "Alice"})
        m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(staged)
        prefs = {schema: 1, device: {}, accounts: {}}
        oldKey = preferenceScope("https://old.test|7|slot-a")
        prefs.accounts[oldKey] = {startupBehavior: "mini", favoriteIds: ["alice-only"], recent: ["private-history"], futurePrivate: true, guide: {groupSort: "name", hiddenGroups: ["private-group"], startupGroup: "private-group"}, profileSettings: {themePreset: "forest"}}
        prefs.accounts["foreign"] = {favoriteIds: ["foreign-only"]}
        m.registry.values["settingsV1"] = FormatJson(prefs)
        memoryKey = preferenceScope(m.connectionStore.entries[0].url + "|slot-a|" + previousId)
        foreignMemory = preferenceScope("https://other.test|slot-b|" + previousId)
        m.profileSessionKeys = {}
        m.profileSessionKeys[memoryKey] = "synthetic-old-default"
        m.profileSessionKeys[foreignMemory] = "synthetic-foreign"
        snapshot = FormatJson(m.registry.values)
        m.registry.failFlush = failReplacement
        replaced = ensureConnectedUserProfile({phase: "verified", accountId: "70", accountUsername: "NewAlice", verifiedUser: {id: 70, username: "NewAlice", user_level: 1}}, "", 101)
        if failReplacement
            check(not replaced and FormatJson(m.registry.values) = snapshot, "failed default replacement restores the exact old identity, snapshot and private blobs")
            check(m.profileSessionKeys[memoryKey] = "synthetic-old-default", "failed default replacement retains the old holder's memory credential")
        else
            check(replaced and m.userProfileStore.active = previousId and m.userProfileStore.profiles[0].userId = 70 and m.userProfileStore["knownDefault"]["userId"] = 7 and m.userProfileStore.profiles[1].addressHeld, "verified slot replacement keeps local default identity and frozen holds while rebuilding server identity")
            loaded = ParseJson(m.registry.read("settingsV1"))
            newKey = preferenceScope(connectionPreferenceIdentity(m.connectionStore.entries[0], "70"))
            own = loaded.accounts[newKey]
            check(own.favoriteIds.count() = 0 and own.recent.count() = 0 and not own.doesExist("futurePrivate") and own.guide.hiddenGroups.count() = 0 and own.profileSettings.themePreset = "forest" and own.startupBehavior = "mini", "a rebuilt default gets only the approved Copy settings and no old holder personal or unknown data")
            check(loaded.accounts[oldKey].favoriteIds[0] = "alice-only" and loaded.accounts.foreign.favoriteIds[0] = "foreign-only", "replacement preserves old and foreign blobs instead of moving private data to the new holder")
            check(not m.registry.exists("connKey_slot-a") and not m.profileSessionKeys.doesExist(memoryKey) and m.profileSessionKeys[foreignMemory] = "synthetic-foreign", "rebuilt default cannot inherit the old default's stored or memory key while another slot's key remains untouched")
            lateSnapshot = FormatJson(m.registry.values)
            check(not ensureConnectedUserProfile({accountId: "71", accountUsername: "Unexpected", verifiedUser: {id: 71, username: "Unexpected", user_level: 1}}, "", 102) and FormatJson(m.registry.values) = lateSnapshot, "a late full-lineup /me identity change cannot skip the new holder's early roster and protection read")
        end if
    end for
    resetProfileNavigation()
    m.connectionStore.entries[0].provider = "xtream"
    check(selectedUserProfileGate().allowed, "XC/M3U never acquire a profile gate")
    m.connectionStore = {}
    check(not userProfileConnectionSetupAllowed(), "malformed connection authority cannot grant setup access")
    resetProfileNavigation()
    check(ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "nondefault reconnect fixture establishes default")
    previous = copyJson(m.userProfileStore)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 8, username: "Bob", user_level: 1}, 1)
    b.isDefault = false
    previous.profiles.push(b)
    previous.active = b.id
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(previous)
    m.registry.values[userProfileKeyName("slot-a", b.id)] = "synthetic-b"
    beforeDefault = FormatJson(previous.profiles[0])
    beforeReconnect = FormatJson(m.registry.values)
    m.registry.failFlush = true
    check(not ensureConnectedUserProfile({ok: true, phase: "verified", accountId: "8", accountUsername: "BOB", verifiedUser: {id: 8, username: "BOB", user_level: 1}}, "", 101) and FormatJson(m.registry.values) = beforeReconnect, "failed nondefault reconnect metadata Flush retains its exact prior roster and credentials")
    check(ensureConnectedUserProfile({ok: true, phase: "verified", accountId: "8", accountUsername: "BOB", verifiedUser: {id: 8, username: "BOB", user_level: 1}}, "", 101), "selected nondefault reconnect validates its own existing identity without replacing the default")
    check(m.userProfileStore.active = b.id and FormatJson(m.userProfileStore.profiles[0]) = beforeDefault and m.userProfileStore["knownDefault"]["userId"] = 7, "nondefault reconnect preserves default metadata, selection and recorded default authority")
    before = FormatJson(m.registry.values)
    check(not ensureConnectedUserProfile({ok: true, phase: "verified", accountId: "88", accountUsername: "Bob", verifiedUser: {id: 88, username: "Bob", user_level: 1}}, "", 102) and FormatJson(m.registry.values) = before, "saved-key reconnect cannot adopt a recreated nondefault ID; only its own form may migrate it")
    print "ALL TESTS PASSED"
end sub

sub runLegacyOwnerMigrationChecks()
    for each failFlush in [false, true]
        resetProfileNavigation()
        m.connectionStore.entries[0].id = "legacy"
        m.connectionStore.selected = "legacy"
        m.selectedConnectionId = "legacy"
        m.registry.values["serverUrl"] = "https://example.test"
        m.registry.values["accountIdentity"] = "https://example.test|7"
        m.registry.values["preferences"] = FormatJson({favoriteIds: ["legacy-private"], FutureCase: {retained: true}})
        settings = {schema: 1, device: {}, accounts: {}, FutureRoot: {retained: true}}
        settings.accounts.foreign = {favoriteIds: ["foreign-private"]}
        settings.accounts[preferenceScope("https://example.test|7")] = {guide: {showLogos: false}}
        m.registry.values["settingsV1"] = FormatJson(settings)
        snapshot = FormatJson(m.registry.values)
        m.registry.failFlush = failFlush
        migrated = ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100)
        if failFlush
            check(not migrated and FormatJson(m.registry.values) = snapshot, "failed owner migration restores legacy bytes, canonical root and absent roster atomically")
        else
            check(migrated and not m.registry.exists("preferences") and m.registry.flushes = 1, "verified original holder retires legacy data only in the canonical-data and roster Flush")
            saved = ParseJson(m.registry.read("settingsV1"))
            own = saved.accounts[preferenceScope("https://example.test|7|legacy")]
            check(own.favoriteIds[0] = "legacy-private" and own.FutureCase.retained and not own.guide.showLogos, "owner migration reconciles non-overlapping legacy sources without normalizing private extensions")
            check(saved.accounts.foreign.favoriteIds[0] = "foreign-private" and saved.FutureRoot.retained and not saved.accounts.doesExist(preferenceScope("https://example.test|7")), "owner migration preserves unrelated data and retires only its scoped predecessor")
            check(m.preferenceStore.accounts[preferenceScope("https://example.test|7|legacy")].favoriteIds[0] = "legacy-private", "controller adopts exact committed migration root for subsequent writes")
        end if
    end for
    for each variant in ["foreign-slot", "wrong-server", "wrong-account", "corrupt", "conflict", "empty", "oversize"]
        resetProfileNavigation()
        m.connectionStore.entries[0].id = "legacy"
        m.connectionStore.selected = "legacy"
        m.selectedConnectionId = "legacy"
        m.registry.values["serverUrl"] = "https://example.test"
        m.registry.values["accountIdentity"] = "https://example.test|7"
        m.registry.values["preferences"] = FormatJson({favoriteIds: ["legacy-private"]})
        if variant = "foreign-slot"
            m.connectionStore.entries[0].id = "slot-a"
            m.selectedConnectionId = "slot-a"
        end if
        if variant = "wrong-server" then m.registry.values["serverUrl"] = "https://old.test"
        if variant = "wrong-account" then m.registry.values["accountIdentity"] = "https://example.test|8"
        if variant = "corrupt" then m.registry.values["preferences"] = "not-json"
        if variant = "empty" then m.registry.values["preferences"] = ""
        if variant = "oversize" then m.registry.values["preferences"] = FormatJson({futurePrivate: string(25000, "x")})
        if variant = "conflict"
            settings = {schema: 1, device: {}, accounts: {}}
            settings.accounts[preferenceScope("https://example.test|7|legacy")] = {favoriteIds: ["canonical-private"]}
            m.registry.values["settingsV1"] = FormatJson(settings)
        end if
        originalLegacy = m.registry.read("preferences")
        originalSettings = m.registry.read("settingsV1")
        migrated = ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100)
        check(m.registry.exists("preferences") and m.registry.read("preferences") = originalLegacy and m.registry.read("settingsV1") = originalSettings, "unproven/malformed/conflicting/oversize legacy migration retains all private sources: " + variant)
        if variant = "corrupt" or variant = "conflict" or variant = "empty" or variant = "oversize" then check(not migrated and m.registry.flushes = 0, "unsafe owner reconciliation refuses before writes: " + variant)
    end for
end sub

sub runColdProfileRestoreChecks()
    for each variant in ["remembered", "keyless", "held", "child", "failed-flush"]
        resetProfileNavigation()
        check(ensureConnectedUserProfile(profileResult(), "00000000-0000-4000-8000-000000000001", 100), "restore fixture establishes default")
        store = copyJson(m.userProfileStore)
        own = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 1)
        own.isDefault = false
        own.addressHeld = false
        if variant = "held" then own.addressHeld = true
        if variant = "child" then own.role = "child"
        store.active = own.id
        store.profiles.push(own)
        m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
        entry = m.connectionStore.entries[0]
        entry.remember = variant = "remembered" or variant = "held"
        if entry.remember then m.registry.values[userProfileKeyName(entry.id, own.id)] = "synthetic-own"
        before = FormatJson(m.registry.values)
        beforeFlush = m.registry.flushes
        m.registry.failFlush = variant = "failed-flush"
        restored = prepareUserProfileLaunchRestore(entry)
        if variant = "failed-flush"
            check(not restored and m.userProfileRecoveryRequired and FormatJson(m.registry.values) = before, "failed launch fallback rolls back exact active holder and requests process recovery")
        else
            check(restored, "cold launch restore policy accepts valid roster: " + variant)
            loaded = loadUserProfileStore(m.registry, entry.id)
            fallback = variant = "keyless" or variant = "held"
            if fallback
                check(loaded.active = loaded.profiles[0].id and m.registry.flushes = beforeFlush + 1, "unavailable full-access restore selects default atomically before any credential read: " + variant)
            else
                check(loaded.active = own.id and FormatJson(m.registry.values) = before and m.registry.flushes = beforeFlush, "remembered own holder and unavailable Child never silently become adult default: " + variant)
            end if
            check(loaded.profiles[1].addressHeld = own.addressHeld and m.registry.read("connKey_slot-a") = "default-key", "restore preserves own holds and independent default credential: " + variant)
        end if
    end for
end sub

function profileResult() as object
    return {accountId: "7", accountUsername: "Alice", verifiedUser: {id: 7, username: "Alice", user_level: 1}}
end function

sub resetProfileNavigation()
    m.connectionStore = connectionStoreAdd(defaultConnectionStore(), "slot-a", "Synthetic")
    m.connectionStore = connectionStoreUpdate(m.connectionStore, "slot-a", {url: "https://example.test", accountId: "7"})
    m.selectedConnectionId = "slot-a"
    m.registry = {values: {}, flushes: 0, failFlush: false
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            m.flushes++
            if m.failFlush
                m.failFlush = false
                return false
            end if
            return true
        end function
    }
    m.registry.values["connKey_slot-a"] = "default-key"
    m.userProfileStore = invalid
    m.userProfileRecoveryRequired = false
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
