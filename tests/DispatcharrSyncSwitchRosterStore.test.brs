sub main()
    for each fault in ["", "write", "flush", "rollback"]
        switchDefaultRetirementFixture()
        m.registry.fault = fault
        before = FormatJson(m.registry.values)
        result = switchDefaultRetirementSelect()
        if fault = ""
            check(result.ok and result.selected and result.store.active = m.defaultId and result.scope = invalid and result.apiKey = invalid and result.pin = invalid, "system retirement selects actual default without authenticating it or inventing a PIN grant")
            check(result.store.profiles.count() = 3 and m.registry.exists(m.outgoingKey) and m.registry.exists(m.outgoingBackoff) and m.registry.read("settingsV1") = m.settings and m.registry.read("connKey_slot-a") = "synthetic-default", "default selection precedes deletion and retains old holder key/backoff/blob until runtime retirement")
            check(m.registry.flushes = 1 and m.outgoing.profileId <> result.store.active, "selection is one metadata transaction while captured outgoing admission remains explicit")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "failed system default selection restores exact metadata without touching any credentials or settings")
        end if
    end for
    for each change in ["key", "root", "nonce", "actor", "profiles-off", "target-only", "newer-readd", "held-source", "pending"]
        switchDefaultRetirementFixture()
        if change = "key" then m.registry.values[m.ownKeyName] = ""
        if change = "root" then m.registry.values["connectionsV1"] = ""
        if change = "nonce" then m.activeNonce = "00000000-0000-4000-8000-000000000099"
        if change = "actor" then m.outgoing = invalid
        if change = "profiles-off" then m.enabled = false
        if change = "target-only" then m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: [["bob", 500]]})
        if change = "newer-readd" then m.decoded = dispatcharrSyncRosterDecode({rows: [[7, "alice", "Alice", "none", "", "", "user", 501]], removed: [["alice", 500]]})
        if change = "held-source" then m.fixtureHeld = true
        if change = "pending"
            m.context.store = setCanonicalPreference(m.context.store, "pendingRoster", true)
            m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.context.store)
        end if
        before = FormatJson(m.registry.values)
        result = switchDefaultRetirementSelect()
        check(not result.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "system default selection refuses " + change + " without replacing the real actor or discarding data")
    end for
    switchDefaultRetirementFixture()
    m.registry.values.delete("connKey_slot-a")
    result = switchDefaultRetirementSelect()
    check(result.ok and result.store.active = m.defaultId and not m.registry.exists("connKey_slot-a") and result.scope = invalid, "missing default key cannot prevent local system default selection or authorize a borrowed-key request")
    for each fault in ["", "write", "flush", "rollback"]
        switchDefaultRetirementFixture()
        selected = switchDefaultRetirementSelect()
        m.registry.flushes = 0
        before = FormatJson(m.registry.values)
        denied = switchDefaultRetirementCleanup(selected)
        check(not denied.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "cleanup cannot delete an outgoing holder while its genuine authenticated runtime still exists")
        m.outgoing = invalid
        m.actorKey = ""
        m.registry.fault = fault
        result = switchDefaultRetirementCleanup(selected)
        if fault = ""
            check(result.ok and result.committed and result.store.active = m.defaultId and not m.registry.exists(m.outgoingKey) and not m.registry.exists(m.outgoingBackoff), "phase-two cleanup removes old key/backoff only AFTER default selection and actual runtime retirement")
            check(not result.preferenceStore.accounts.doesExist(m.outgoingAccount) and result.preferenceStore.accounts[m.foreignAccount].future = "foreign" and m.registry.read("connKey_slot-a") = "synthetic-default" and m.registry.read(m.ownKeyName) = "synthetic-b", "default retirement cleans only removed blobs and retains default, source and foreign ownership")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "phase-two write/flush faults retain selected default and restore exact remaining private data without reviving old actor")
        end if
    end for
    for each change in ["runtime-key", "nonce", "selected-root", "connection-root", "context-url", "source-key", "source-key-memory", "authority", "evidence", "settings"]
        switchDefaultRetirementFixture()
        selected = switchDefaultRetirementSelect()
        m.outgoing = invalid
        m.actorKey = ""
        if change = "runtime-key" then m.actorKey = "not-retired"
        if change = "nonce" then m.activeNonce = "00000000-0000-4000-8000-000000000099"
        if change = "selected-root" then m.registry.values[userProfileStoreKey("slot-a")] = "{malformed"
        if change = "connection-root" then m.registry.values["connectionsV1"] = ""
        if change = "context-url"
            m.context.connection.url = "https://foreign.test"
            m.verified.verifiedBaseUrl = "https://foreign.test"
        end if
        if change = "source-key" then m.registry.values[m.ownKeyName] = ""
        if change = "source-key-memory"
            m.registry.values.delete(m.ownKeyName)
            m.memory[m.ownKeyName] = "synthetic-b"
        end if
        if change = "authority" then m.verified.verifiedUser.user_level = 10
        if change = "evidence" then m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: []})
        if change = "settings" then m.registry.values["settingsV1"] = "{malformed"
        m.registry.flushes = 0
        before = FormatJson(m.registry.values)
        result = switchDefaultRetirementCleanup(selected)
        check(not result.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "phase-two retirement refuses changed " + change + " without deleting a successor or replacing unreadable data")
    end for
    for each changedGrant in [false, true]
        switchDefaultRetirementFixture()
        store = m.context.store
        store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
        m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
        m.context.store = loadUserProfileStore(m.registry, "slot-a")
        m.context.outgoing = invalid
        m.context.unavailableChild = true
        m.context.managementNonce = "00000000-0000-4000-8000-000000000093"
        holder = m.context.store.profiles[2]
        m.context.management = {slot: "slot-a", active: store.active, nonce: m.context.managementNonce, purpose: "manage-profiles", kind: "pin", id: holder.id, pinType: holder.pinType, pinHash: holder.pinHash, pinSalt: holder.pinSalt}
        m.outgoing = invalid
        m.actorKey = ""
        selected = switchDefaultRetirementSelect()
        check(selected.ok and selected.store.active = m.defaultId and selected.scope = invalid, "genuine unavailable Child selects actual default under current adult purpose without fabricating an outgoing scope")
        if changedGrant then m.context.managementNonce = "00000000-0000-4000-8000-000000000099"
        before = FormatJson(m.registry.values)
        m.registry.flushes = 0
        result = switchDefaultRetirementCleanup(selected)
        if changedGrant
            check(not result.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "expired Child adult-purpose admission cannot delete holder data after default metadata selection")
        else
            check(result.ok and result.store.active = m.defaultId and not m.registry.exists(m.outgoingKey), "current actual no-session Child completes cleanup without an authenticated Child or default actor")
        end if
    end for
    switchRosterStoreFixture()
    check(switchRosterStoreAccess() and m.registry.flushes = 0, "request preflight validates current own admission without a write or fabricated target scope")
    for each fault in ["", "write", "flush", "rollback"]
        switchRosterStoreFixture()
        m.registry.fault = fault
        before = FormatJson(m.registry.values)
        result = switchRosterStoreCommit()
        if fault = ""
            check(result.ok and result.applied and result.target.pinType = "numbers" and m.registry.flushes = 1, "one scoped transaction persists target protection before stored-PIN verification")
            saved = loadUserProfileStore(m.registry, "slot-a")
            check(saved.active = m.outgoing.profileId and saved.profiles[1].pinHash = string(64, "a"), "protection staging never makes the target active or authenticates a replacement session")
            check(m.registry.read("settingsV1") = m.settings and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(m.ownKeyName) = "synthetic-b", "metadata staging leaves private preferences and both own/default credentials exact")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "write/flush failure restores exact captured metadata without touching credentials or settings")
        end if
    end for
    for each change in ["key", "root", "roster", "nonce", "held"]
        switchRosterStoreFixture()
        if change = "key" then m.registry.values[m.ownKeyName] = ""
        if change = "root" then m.registry.values["connectionsV1"] = ""
        if change = "roster" then m.registry.values[userProfileStoreKey("slot-a")] = "{malformed"
        if change = "nonce" then m.activeNonce = "00000000-0000-4000-8000-000000000099"
        if change = "held" then m.fixtureHeld = true
        before = FormatJson(m.registry.values)
        check(not switchRosterStoreAccess(), "changed " + change + " refuses even the next target request preflight")
        result = switchRosterStoreCommit()
        check(not result.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "changed " + change + " cannot authorize staged protection through a captured proof")
    end for
    switchRosterStoreFixture()
    m.enabled = false
    result = switchRosterStoreCommit()
    check(result.ok and not result.applied and m.registry.flushes = 0, "Profiles-Off performs no metadata normalization write")
    switchRosterStoreFixture()
    m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: []})
    before = m.registry.read(userProfileStoreKey("slot-a"))
    result = switchRosterStoreCommit()
    check(result.ok and result.applied and not result.committed and m.registry.flushes = 0 and m.registry.read(userProfileStoreKey("slot-a")) = before, "an applying but unchanged roster does not rewrite sparse raw metadata")
    switchRosterStoreFixture()
    m.context.connection.remember = false
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: "slot-a", entries: [m.context.connection]})
    m.context.connectionRoot = m.registry.read("connectionsV1")
    result = switchRosterStoreCommit()
    check(not result.ok and m.registry.flushes = 0, "Remember-off cannot borrow a stale registry key for protection staging")
    m.memory[m.ownKeyName] = "synthetic-b"
    result = switchRosterStoreCommit()
    check(result.ok and result.applied and m.registry.read(m.ownKeyName) = "synthetic-b", "current own memory proof may stage metadata without using this transaction to repair or delete credential storage")
    switchRosterStoreFixture()
    c = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 9, username: "third", user_level: 1}, 1)
    c.isDefault = false
    m.context.store.profiles.push(c)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.context.store)
    m.context.store = loadUserProfileStore(m.registry, "slot-a")
    m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: [["third", 500]]})
    before = FormatJson(m.registry.values)
    result = switchRosterStoreCommit()
    check(not result.ok and result.reason = "cleanup-required" and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "metadata-only admission never silently deletes tombstoned holders without the explicit cleanup integration")
    for each fault in ["", "write", "flush", "rollback"]
        unavailableSwitchRosterStoreFixture()
        m.registry.fault = fault
        before = FormatJson(m.registry.values)
        check(unavailableSwitchRosterStoreAccess() and m.registry.flushes = 0, "unavailable Child preflight uses real empty actor plus current adult purpose without writing or inventing a scope")
        result = unavailableSwitchRosterStoreCommit()
        if fault = ""
            check(result.ok and result.committed and m.registry.flushes = 1 and result.store.active = m.context.store.active and result.target.pinHash = string(64, "a"), "separate unavailable admission persists imported target protection but retains Child active")
            check(m.registry.read("settingsV1") = m.settings and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(m.ownKeyName) = "synthetic-b" and m.outgoing = invalid, "no-session transaction never changes own/default settings/keys or fabricates a holder")
            m.context.store = result.store
            m.context.target = result.target
            check(not unavailableSwitchRosterStoreAccess(), "changed imported adult-holder PIN invalidates old management material before any following request")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "unavailable admission restores exact metadata on write/flush faults without changing actor or credentials")
        end if
    end for
    for each change in ["actor", "context-actor", "actor-key", "purpose", "grant", "management-nonce", "key", "root", "roster", "nonce", "held", "device-admin"]
        unavailableSwitchRosterStoreFixture()
        if change = "actor" then m.outgoing = {profileId: "not-unavailable"}
        if change = "context-actor" then m.context.outgoing = {profileId: "fabricated"}
        if change = "actor-key" then m.actorKey = "not-empty"
        if change = "purpose" then m.context.unavailableChild = false
        if change = "grant" then m.context.management.pinHash = string(64, "f")
        if change = "management-nonce" then m.context.managementNonce = "00000000-0000-4000-8000-000000000099"
        if change = "key" then m.registry.values[m.ownKeyName] = ""
        if change = "root" then m.registry.values["connectionsV1"] = ""
        if change = "roster" then m.registry.values[userProfileStoreKey("slot-a")] = "{malformed"
        if change = "nonce" then m.activeNonce = "00000000-0000-4000-8000-000000000099"
        if change = "held" then m.fixtureHeld = true
        if change = "device-admin" then m.registry.values[userProfileDeviceAdminKey("slot-a")] = "{malformed"
        before = FormatJson(m.registry.values)
        check(not unavailableSwitchRosterStoreAccess(), "unavailable preflight refuses changed " + change + " before another target request")
        result = unavailableSwitchRosterStoreCommit()
        check(not result.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "unavailable transaction refuses changed " + change + " without a fake authenticated bypass")
    end for
    unavailableSwitchRosterStoreFixture()
    check(not switchRosterStoreAccess() and not switchRosterStoreCommit().ok and m.registry.flushes = 0, "authenticated admission still refuses a genuine no-session Child instead of weakening its existing scope invariant")
    m.context.connection.remember = false
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: "slot-a", entries: [m.context.connection]})
    m.context.connectionRoot = m.registry.read("connectionsV1")
    check(not unavailableSwitchRosterStoreAccess(), "no-session admission with Remember-off cannot borrow retained persisted own bytes")
    m.memory[m.ownKeyName] = "synthetic-b"
    result = unavailableSwitchRosterStoreCommit()
    check(result.ok and m.registry.read(m.ownKeyName) = "synthetic-b", "current caller-owned target memory lease can stage metadata without credential repair/deletion")
    for each fault in ["", "write", "flush", "rollback"]
        switchRosterCleanupFixture()
        m.registry.fault = fault
        before = FormatJson(m.registry.values)
        result = switchRosterCleanupCommit()
        if fault = ""
            check(result.ok and result.committed and result.removed.count() = 1 and m.registry.flushes = 1 and result.store.active = m.context.store.active, "explicit inactive cleanup commits roster/removed key/backoff/preferences together without target activation")
            check(not m.registry.exists(m.thirdKey) and not m.registry.exists(m.thirdBackoff) and m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(m.ownKeyName) = "synthetic-b", "inactive cleanup removes only its own credential and local PIN ledger")
            saved = ParseJson(m.registry.read("settingsV1"))
            check(not saved.accounts.doesExist(m.thirdAccount) and saved.accounts[m.foreignAccount].future = "foreign" and saved.accounts[m.targetAccount].future = "target" and saved.futureRoot = "retain", "inactive cleanup prunes only the removed account blob and retains typed foreign/root extensions")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "inactive cleanup faults restore exact roster/settings/keys/backoff as one transaction")
        end if
    end for
    for each change in ["settings", "key", "root", "nonce", "target-tombstone", "outgoing-tombstone"]
        switchRosterCleanupFixture()
        if change = "settings" then m.registry.values["settingsV1"] = "{malformed"
        if change = "key" then m.registry.values[m.ownKeyName] = ""
        if change = "root" then m.registry.values["connectionsV1"] = ""
        if change = "nonce" then m.activeNonce = "00000000-0000-4000-8000-000000000099"
        if change = "target-tombstone" then m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: [["bob", 500]]})
        if change = "outgoing-tombstone"
            m.context.store.profiles[0] = setCanonicalPreference(m.context.store.profiles[0], "isDefault", false)
            m.context.store.profiles[2] = setCanonicalPreference(m.context.store.profiles[2], "isDefault", true)
            m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.context.store)
            m.context.store = loadUserProfileStore(m.registry, "slot-a")
            m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: [["alice", 500]]})
        end if
        before = FormatJson(m.registry.values)
        result = switchRosterCleanupCommit()
        check(not result.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "explicit inactive cleanup refuses changed " + change + " without deleting an actor or replacing unreadable data")
    end for
    for each unavailable in [false, true]
        switchRosterCleanupFixture()
        if unavailable
            store = m.context.store
            store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
            m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
            m.context.store = loadUserProfileStore(m.registry, "slot-a")
            m.context.target = m.context.store.profiles[1]
            m.context.outgoing = invalid
            m.context.unavailableChild = true
            m.outgoing = invalid
            m.actorKey = ""
            m.context.managementNonce = "00000000-0000-4000-8000-000000000093"
            admin = {pinType: "numbers", pinHash: string(64, "e"), pinSalt: string(32, "f")}
            m.registry.values[userProfileDeviceAdminKey("slot-a")] = FormatJson(admin)
            m.context.management = {slot: "slot-a", active: store.active, nonce: m.context.managementNonce, purpose: "manage-profiles", kind: "pin", id: "device-admin", pinType: admin.pinType, pinHash: admin.pinHash, pinSalt: admin.pinSalt}
        end if
        m.context.connection.remember = false
        m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: "slot-a", entries: [m.context.connection]})
        m.context.connectionRoot = m.registry.read("connectionsV1")
        check(not switchRosterCleanupCommit().ok and m.registry.flushes = 0, "explicit cleanup cannot use remembered target bytes after Remember-off")
        m.memory[m.ownKeyName] = "synthetic-b"
        result = switchRosterCleanupCommit()
        check(result.ok and not m.registry.exists(m.thirdKey) and m.registry.read(m.ownKeyName) = "synthetic-b" and m.registry.read("connKey_slot-a") = "synthetic-a", "current own memory admits inactive cleanup without using it to repair or delete unrelated persisted credentials")
    end for
    for each fault in ["", "write", "flush", "rollback"]
        switchRosterTargetRetirementFixture()
        m.registry.fault = fault
        before = FormatJson(m.registry.values)
        result = switchRosterTargetRetirementCommit()
        if fault = ""
            check(result.ok and result.targetRemoved and result.target = invalid and result.store.active = m.context.store.active and m.registry.flushes = 1, "tombstoned unadopted target retires atomically while the actual outgoing profile remains active")
            check(not m.registry.exists(m.ownKeyName) and not m.registry.exists(m.targetBackoff) and m.registry.read(m.thirdKey) = "synthetic-third" and m.registry.read("connKey_slot-a") = "synthetic-a", "target retirement deletes only its own key/backoff, never the default or unrelated third holder")
            saved = ParseJson(m.registry.read("settingsV1"))
            check(not saved.accounts.doesExist(m.targetAccount) and saved.accounts.doesExist(m.thirdAccount) and saved.accounts[m.foreignAccount].future = "foreign" and result.store.removed.count() = 0 and result.scope = invalid and result.apiKey = invalid, "retired target data leaves no new tombstone, credential or invented active target/default session")
        else
            check(not result.ok and result.recoveryRequired = (fault = "rollback") and FormatJson(m.registry.values) = before, "target retirement write/flush faults restore exact metadata/credentials/settings/backoff without actor replacement")
        end if
    end for
    for each change in ["key", "root", "nonce", "identity", "outgoing-tombstone", "child", "profiles-off", "newer-readd"]
        switchRosterTargetRetirementFixture()
        if change = "key" then m.registry.values[m.ownKeyName] = ""
        if change = "root" then m.registry.values["connectionsV1"] = ""
        if change = "nonce" then m.activeNonce = "00000000-0000-4000-8000-000000000099"
        if change = "identity" then m.verified.verifiedUser.id = 80
        if change = "outgoing-tombstone"
            m.context.store.profiles[0] = setCanonicalPreference(m.context.store.profiles[0], "isDefault", false)
            m.context.store.profiles[2] = setCanonicalPreference(m.context.store.profiles[2], "isDefault", true)
            m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.context.store)
            m.context.store = loadUserProfileStore(m.registry, "slot-a")
            m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: [["alice", 500], ["bob", 500]]})
        end if
        if change = "child"
            m.context.store.profiles[1] = setCanonicalPreference(m.context.store.profiles[1], "role", "child")
            m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.context.store)
            m.context.store = loadUserProfileStore(m.registry, "slot-a")
            m.context.target = m.context.store.profiles[1]
        end if
        if change = "profiles-off" then m.enabled = false
        if change = "newer-readd" then m.decoded = dispatcharrSyncRosterDecode({rows: [[8, "bob", "Bob", "none", "", "", "user", 501]], removed: [["bob", 500]]})
        before = FormatJson(m.registry.values)
        result = switchRosterTargetRetirementCommit()
        check(not result.ok and m.registry.flushes = 0 and FormatJson(m.registry.values) = before, "target retirement refuses " + change + " without deleting a live actor, paused category or intentionally newer target")
    end for
    print "ALL TESTS PASSED"
end sub

sub switchDefaultRetirementFixture()
    switchRosterCleanupFixture()
    store = m.context.store
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "isDefault", false)
    store.profiles[2] = setCanonicalPreference(store.profiles[2], "isDefault", true)
    store.profiles[2] = setCanonicalPreference(store.profiles[2], "pinType", "numbers")
    store.profiles[2] = setCanonicalPreference(store.profiles[2], "pinHash", string(64, "e"))
    store.profiles[2] = setCanonicalPreference(store.profiles[2], "pinSalt", string(32, "f"))
    m.defaultId = store.profiles[2].id
    m.outgoingKey = userProfileKeyName("slot-a", store.active)
    m.outgoingBackoff = userProfilePinBackoffKey("slot-a", store.active)
    m.registry.values[m.outgoingKey] = "synthetic-a"
    m.registry.values[m.outgoingBackoff] = "outgoing-ledger"
    m.registry.values["connKey_slot-a"] = "synthetic-default"
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.context.store = loadUserProfileStore(m.registry, "slot-a")
    m.context.target = m.context.store.profiles[1]
    m.settings = m.registry.read("settingsV1")
    preferences = ParseJson(m.settings)
    m.outgoingAccount = preferenceScope(connectionPreferenceIdentity(m.context.connection, "7"))
    preferences.accounts[m.outgoingAccount] = {future: "outgoing"}
    m.settings = FormatJson(preferences)
    m.registry.values["settingsV1"] = m.settings
    m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: [["alice", 500]]})
end sub

function switchDefaultRetirementSelect() as object
    return commitDispatcharrDefaultRetirementSelection(m.registry, m.context, m.verified, m.decoded, m.enabled, 600, m.activeNonce, m.outgoing, textValue(m.actorKey), m.memory)
end function

function switchDefaultRetirementCleanup(selected as object) as object
    return commitDispatcharrDefaultRetirementCleanup(m.registry, m.context, selected, m.verified, m.decoded, m.enabled, 600, m.activeNonce, m.outgoing, textValue(m.actorKey), m.memory)
end function

sub switchRosterStoreFixture()
    entry = normalizeConnectionEntry({id: "slot-a", name: "Fixture", provider: "dispatcharr", url: "https://example.test", remember: true})
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    b.isDefault = false
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    m.registry = {values: {}, fault: "", flushes: 0, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function, write: function(key as string, value as string) as boolean
        m.values[key] = value
        if m.fault = "write" then m.fault = "" : return false
        return true
    end function, delete: function(key as string) as boolean
        m.values.delete(key)
        return true
    end function, flush: function() as boolean
        m.flushes++
        if m.fault = "rollback" then return false
        if m.fault = "flush" then m.fault = "" : return false
        return true
    end function}
    m.settings = "{" + chr(34) + "private" + chr(34) + ":12345.67890123456}"
    m.registry.values["settingsV1"] = m.settings
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: entry.id, entries: [entry]})
    m.registry.values[userProfileStoreKey(entry.id)] = FormatJson(store)
    m.registry.values["connKey_slot-a"] = "synthetic-a"
    m.ownKeyName = userProfileKeyName(entry.id, b.id)
    m.registry.values[m.ownKeyName] = "synthetic-b"
    m.outgoing = userProfileSessionScope(entry, a.id, "7", "old", "00000000-0000-4000-8000-000000000090")
    m.context = {connection: entry, connectionRoot: m.registry.read("connectionsV1"), connectionRootPresent: true, store: loadUserProfileStore(m.registry, entry.id), target: b, key: "synthetic-b", outgoing: m.outgoing, nonce: "00000000-0000-4000-8000-000000000091"}
    m.activeNonce = m.context.nonce
    m.verified = {ok: true, phase: "verified", apiKey: "synthetic-b", accountId: "8", accountUsername: "bob", verifiedBaseUrl: entry.url, verifiedUser: {id: 8, username: "bob", user_level: 1}}
    m.decoded = dispatcharrSyncRosterDecode({rows: [[8, "bob", "Bob", "numbers", string(64, "a"), string(32, "b"), "user", 500]]})
    m.enabled = true
    m.memory = {}
    m.fixtureHeld = false
end sub

function switchRosterStoreCommit() as object
    return commitDispatcharrSwitchRosterPull(m.registry, m.context, m.verified, m.decoded, m.enabled, 600, m.activeNonce, m.outgoing, m.memory)
end function

function switchRosterStoreAccess() as boolean
    return dispatcharrSyncSwitchRosterAccessCurrent(m.registry, m.context, m.verified, 600, m.activeNonce, m.outgoing, m.memory)
end function

sub unavailableSwitchRosterStoreFixture()
    switchRosterStoreFixture()
    store = m.context.store
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinType", "numbers")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinHash", string(64, "c"))
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinSalt", string(32, "d"))
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.context.store = loadUserProfileStore(m.registry, "slot-a")
    m.context.target = m.context.store.profiles[1]
    m.outgoing = invalid
    m.context.outgoing = invalid
    m.context.unavailableChild = true
    m.actorKey = ""
    m.context.managementNonce = "00000000-0000-4000-8000-000000000092"
    target = m.context.target
    m.context.management = {slot: "slot-a", active: store.active, nonce: m.context.managementNonce, purpose: "manage-profiles", kind: "pin", id: target.id, pinType: target.pinType, pinHash: target.pinHash, pinSalt: target.pinSalt}
end sub

function unavailableSwitchRosterStoreAccess() as boolean
    return dispatcharrSyncUnavailableChildRosterAccessCurrent(m.registry, m.context, m.verified, 600, m.activeNonce, m.outgoing, m.actorKey, m.memory)
end function

function unavailableSwitchRosterStoreCommit() as object
    return commitDispatcharrUnavailableChildRosterPull(m.registry, m.context, m.verified, m.decoded, m.enabled, 600, m.activeNonce, m.outgoing, m.actorKey, m.memory)
end function

sub switchRosterCleanupFixture()
    switchRosterStoreFixture()
    m.actorKey = "synthetic-a"
    third = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 9, username: "third", user_level: 1}, 1)
    third = setCanonicalPreference(third, "isDefault", false)
    m.context.store.profiles.push(third)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(m.context.store)
    m.context.store = loadUserProfileStore(m.registry, "slot-a")
    m.thirdKey = userProfileKeyName("slot-a", third.id)
    m.thirdBackoff = userProfilePinBackoffKey("slot-a", third.id)
    m.registry.values[m.thirdKey] = "synthetic-third"
    m.registry.values[m.thirdBackoff] = "private-ledger"
    m.thirdAccount = preferenceScope(connectionPreferenceIdentity(m.context.connection, "9"))
    m.foreignAccount = preferenceScope("https://other.test|9|slot-b")
    m.targetAccount = preferenceScope(connectionPreferenceIdentity(m.context.connection, "8"))
    settings = defaultPreferenceStore()
    settings.accounts[m.thirdAccount] = {future: "removed"}
    settings.accounts[m.foreignAccount] = {future: "foreign"}
    settings.accounts[m.targetAccount] = {future: "target"}
    settings.futureRoot = "retain"
    m.registry.values["settingsV1"] = FormatJson(settings)
    m.profilePreferenceDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: [["third", 500]]})
end sub

function switchRosterCleanupCommit() as object
    return commitDispatcharrSwitchRosterCleanup(m.registry, m.context, m.verified, m.decoded, true, 600, m.activeNonce, m.outgoing, textValue(m.actorKey), m.memory)
end function

sub switchRosterTargetRetirementFixture()
    switchRosterCleanupFixture()
    m.targetBackoff = userProfilePinBackoffKey("slot-a", m.context.target.id)
    m.registry.values[m.targetBackoff] = "target-private-ledger"
    m.decoded = dispatcharrSyncRosterDecode({rows: [], removed: [["bob", 500]]})
end sub

function switchRosterTargetRetirementCommit() as object
    return commitDispatcharrSwitchTargetRetirement(m.registry, m.context, m.verified, m.decoded, m.enabled, 600, m.activeNonce, m.outgoing, textValue(m.actorKey), m.memory)
end function

function requestGateAccessAllowed(url as string, key as string) as boolean
    return not m.fixtureHeld
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
