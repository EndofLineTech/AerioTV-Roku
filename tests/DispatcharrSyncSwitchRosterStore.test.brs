sub main()
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
    print "ALL TESTS PASSED"
end sub

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

function requestGateAccessAllowed(url as string, key as string) as boolean
    return not m.fixtureHeld
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
