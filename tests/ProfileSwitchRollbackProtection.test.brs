sub main()
    rollbackProtectionFixture()
    rollbackUserProfileSwitch("Cancelled")
    check(not m.global.profilegateclosed and m.guide.active and m.activeUserScope.sessionId <> m.fixtureOutgoing.sessionId, "unchanged saved outgoing protection permits a fresh rollback session")
    for each field in ["role", "pinHash", "username", "userId", "addressHeld"]
        rollbackProtectionFixture()
        store = loadUserProfileStore(m.registry, "slot-a")
        if field = "role" then store.profiles[1].role = "child"
        if field = "pinHash"
            store.profiles[1].pinType = "numbers"
            store.profiles[1].pinHash = string(64, "a")
            store.profiles[1].pinSalt = string(32, "b")
            store.profiles[1].pinLength = 4
        end if
        if field = "username" then store.profiles[1].username = "DifferentBob"
        if field = "userId" then store.profiles[1].userId = 80
        if field = "addressHeld" then store.profiles[1].addressHeld = true
        m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
        before = m.registry.values[userProfileStoreKey("slot-a")]
        rollbackUserProfileSwitch("Cancelled")
        checkRollbackCovered("changed outgoing " + field + " cannot revive captured authority")
        check(m.registry.values[userProfileStoreKey("slot-a")] = before, "rollback never rewrites changed protection as a repair")
    end for
    rollbackProtectionFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    store.profiles[1].role = "child"
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.profileSwitchContext.store = loadUserProfileStore(m.registry, "slot-a")
    rollbackUserProfileSwitch("Staged roster changed protection")
    checkRollbackCovered("updating a working import roster cannot bless changed outgoing protection for rollback")
    rollbackProtectionFixture()
    m.registry.values[userProfileKeyName("slot-a", m.fixtureOutgoing.profileId)] = ""
    rollbackUserProfileSwitch("Cancelled")
    checkRollbackCovered("deleted own key cannot borrow a default or cached key on rollback")
    check(m.registry.values["connKey_slot-a"] = "synthetic-a", "default key survives own credential refusal")
    rollbackProtectionFixture()
    m.registry.values[userProfileKeyName("slot-a", m.fixtureOutgoing.profileId)] = "replaced-key"
    rollbackUserProfileSwitch("Cancelled")
    checkRollbackCovered("replaced own key needs fresh own verification")
    rollbackProtectionFixture()
    entry = m.fixtureConnection
    entry.url = "https://changed.test"
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: "slot-a", entries: [entry]})
    rollbackUserProfileSwitch("Cancelled")
    checkRollbackCovered("changed current address cannot reopen the frozen old view")
    rollbackProtectionFixture()
    m.registry.values["connectionsV1"] = ""
    rollbackUserProfileSwitch("Cancelled")
    checkRollbackCovered("empty canonical connection root cannot be used as a legacy rollback escape")
    rollbackProtectionFixture()
    m.registry.values["connectionsV1"] = ""
    startUserProfileSwitchTask(m.profileSwitchContext.nonce)
    checkRollbackCovered("lost connection during admission cannot leave a live stale switch context")
    rollbackProtectionFixture()
    m.registry.values[userProfileStoreKey("slot-a")] = "{malformed"
    rollbackUserProfileSwitch("Cancelled")
    checkRollbackCovered("unreadable saved protection fails covered without treating it as empty")
    rollbackProtectionFixture()
    m.fixtureHeld = true
    rollbackUserProfileSwitch("Cancelled")
    checkRollbackCovered("a newly held outgoing key cannot be reauthorized by rollback")
    rollbackProtectionFixture()
    rollbackProtectionRememberOff()
    rollbackUserProfileSwitch("Cancelled")
    check(not m.global.profilegateclosed and m.guide.active, "Remember-off rollback uses only the current own slot/address/profile memory lease")
    rollbackProtectionFixture()
    rollbackProtectionRememberOff()
    m.profileSessionKeys = {}
    rollbackUserProfileSwitch("Cancelled")
    checkRollbackCovered("Remember-off rollback never falls back to a persisted key after its own memory lease retires")
    rollbackProtectionFixture()
    m.selectedConnectionId = "different-slot"
    m.activeUserScope = userProfileSessionScope({id: "different-slot", provider: "dispatcharr", url: "https://other.test"}, m.fixtureOutgoing.profileId, "8", "other", "00000000-0000-4000-8000-000000000099")
    current = m.activeUserScope
    beforeSession = m.global.activeusersession
    rollbackUserProfileSwitch("Cancelled")
    check(userProfileSameSession(m.activeUserScope, current) and m.global.activeusersession = beforeSession and m.global.profileswitchpending, "late rollback never changes a successor slot's authentication or lifecycle")
    rollbackProtectionFixture()
    m.activeUserScope = userProfileSessionScope(m.fixtureConnection, m.fixtureOutgoing.profileId, "8", "new-authority", "00000000-0000-4000-8000-000000000099")
    m.global.activeusersession = m.activeUserScope.sessionId
    current = m.activeUserScope
    rollbackUserProfileSwitch("Cancelled")
    check(userProfileSameSession(m.activeUserScope, current) and m.global.activeusersession = current.sessionId, "a stale switch cannot cover or replace a newer same-slot session")
    print "ALL TESTS PASSED"
end sub

sub rollbackProtectionRememberOff()
    entry = m.profileSwitchContext.connection
    entry.remember = false
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: entry.id, entries: [entry]})
    m.profileSwitchContext.connectionRoot = m.registry.read("connectionsV1")
    m.profileSessionKeys = {}
    m.profileSessionKeys[preferenceScope(entry.url + "|" + entry.id + "|" + m.fixtureOutgoing.profileId)] = "synthetic-b"
end sub

sub rollbackProtectionFixture()
    entry = normalizeConnectionEntry({id: "slot-a", provider: "dispatcharr", url: "https://example.test", name: "Fixture", remember: true})
    a = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    b = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 2)
    b.isDefault = false
    store = defaultUserProfileStore(entry.id)
    store.profiles = [a, b]
    store.active = b.id
    m.registry = {values: {}, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function}
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: entry.id, entries: [entry]})
    m.registry.values[userProfileStoreKey(entry.id)] = FormatJson(store)
    m.registry.values["connKey_slot-a"] = "synthetic-a"
    m.registry.values[userProfileKeyName(entry.id, b.id)] = "synthetic-b"
    m.userProfileStore = loadUserProfileStore(m.registry, entry.id)
    outgoing = userProfileSessionScope(entry, b.id, "8", "authority", "00000000-0000-4000-8000-000000000090")
    m.fixtureOutgoing = outgoing
    m.fixtureConnection = copyJson(entry)
    m.profileSwitchContext = {nonce: "00000000-0000-4000-8000-000000000091", connection: entry, connectionRoot: m.registry.read("connectionsV1"), connectionRootPresent: true, store: m.userProfileStore, outgoing: outgoing, outgoingProtection: FormatJson(m.userProfileStore.profiles[1])}
    m.profileSwitchTask = invalid
    m.recordTask = invalid
    m.selectedConnectionId = entry.id
    m.activeUserScope = outgoing
    m.apiKey = "synthetic-b"
    m.accountIdentity = outgoing.preferenceIdentity
    m.serverAccountId = "8"
    m.fixtureHeld = false
    m.global = {profilegateclosed: false, profileswitchpending: true, activeusersession: m.profileSwitchContext.nonce}
    m.profileGateCover = {visible: true}
    m.guide = {active: false, config: {aeriosession: outgoing.sessionId}}
    m.capabilityClock = {control: "stop"}
    m.reminderClock = {control: "stop"}
    m.top = {label: {}, findNode: function(id as string) as object
        return m.label
    end function}
    m.userProfileRecoveryRequired = false
end sub

function requestGateAccessAllowed(url as string, key as string) as boolean
    return not m.fixtureHeld
end function

sub preserveSubmittedRecording()
end sub

sub requestGateFenceRenderers(root as object)
end sub

sub showNotice(message as string)
end sub

sub checkRollbackCovered(message as string)
    check(m.global.profilegateclosed and m.profileGateCover.visible and not m.guide.active and m.activeUserScope = invalid and m.global.activeusersession = "" and m.profileUnlockGrant = invalid, message)
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
