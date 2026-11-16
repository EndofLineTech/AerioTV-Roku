sub main()
    switchRollbackFixture()
    store = loadUserProfileStore(m.registry, "slot-a")
    child = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Child", user_level: 1}, 2)
    child.isDefault = false
    child.role = "child"
    child.pinType = "numbers"
    child.pinSalt = string(32, "b")
    child.pinHash = string(64, "a")
    store.profiles.push(child)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.registry.values[userProfileKeyName("slot-a", child.id)] = "child-own-key"
    m.connectionStore = loadConnectionStore(m.registry)
    m.profileSwitchContext = invalid
    m.profileChildAccessReady = false
    check(not beginUserProfileSwitch(child.id), "shipping-unready Child live selection stays refused")
    m.profileChildAccessReady = true
    check(beginUserProfileSwitch(child.id) and m.livePinRequested and m.profileSwitchContext.key = "child-own-key", "developer-ready Child selection opens target PIN under only its own key")
    check(m.apiKey = "synthetic-a" and m.activeUserScope.accountId = "7", "Child PIN staging cannot prematurely adopt target or borrow default")
    switchRollbackFixture()
    oldSession = m.profileSwitchContext.outgoing.sessionId
    rollbackUserProfileSwitch("Rejected own key")
    check(m.profileSwitchContext = invalid and not m.profileGateCover.visible and not m.global.profilegateclosed and m.guide.active, "ordinary cancellation returns to previous guide without autoplay")
    check(m.activeUserScope.profileId = "00000000-0000-4000-8000-000000000001" and m.activeUserScope.sessionId <> oldSession and m.guide.config.aeriosession = m.activeUserScope.sessionId, "rollback rebuilds previous scope with a fresh UUID and rebinds its view")
    switchRollbackFixture()
    m.userProfileRecoveryRequired = true
    rollbackUserProfileSwitch("Registry rollback failed")
    check(m.profileGateCover.visible and m.global.profilegateclosed and not m.guide.active and m.activeUserScope = invalid and m.global.activeusersession = "", "failed registry rollback must stay covered, never revive potentially stale protection")
    switchRollbackFixture()
    m.profileSwitchContext.unavailableChild = true
    m.profileSwitchContext.outgoing = invalid
    m.activeUserScope = invalid
    rollbackUserProfileSwitch("Target key rejected")
    check(m.profileSwitchContext = invalid and m.activeUserScope = invalid and m.global.activeusersession = "" and m.global.profilegateclosed and m.profileGateCover.visible and not m.guide.active, "unavailable Child cancellation stays unavailable without fabricating an outgoing authenticated session")
    check(m.page = "profile-unavailable" and not m.busy and not m.global.profileswitchpending and m.childSurfaceRestored, "unavailable escape failure restores only the Child surface, never default setup or guide")
    print "ALL TESTS PASSED"
end sub

function beginProfilePinGate(profile as object, continuation as string, resume as dynamic) as boolean
    m.livePinRequested = profile.role = "child" and continuation = "switch"
    return true
end function

sub showUnavailableChildProfile()
    m.childSurfaceRestored = true
end sub

sub switchRollbackFixture()
    connection = normalizeConnectionEntry({id: "slot-a", provider: "dispatcharr", name: "Fixture", url: "https://example.test", remember: true})
    outgoing = userProfileSessionScope(connection, "00000000-0000-4000-8000-000000000001", 7, "old-generation", "00000000-0000-4000-8000-000000000090")
    store = defaultUserProfileStore(connection.id)
    store.profiles = [userProfileFromVerified(connection.id, outgoing.profileId, {id: 7, username: "Alice", user_level: 1}, 1)]
    store.active = outgoing.profileId
    m.registry = {values: {}, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function}
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: connection.id, entries: [connection]})
    m.registry.values[userProfileStoreKey(connection.id)] = FormatJson(store)
    m.registry.values["connKey_slot-a"] = "synthetic-a"
    saved = loadUserProfileStore(m.registry, connection.id)
    m.profileSwitchContext = {nonce: "staging-session", connection: connection, connectionRoot: m.registry.read("connectionsV1"), connectionRootPresent: true, store: saved, outgoing: outgoing, outgoingProtection: FormatJson(saved.profiles[0])}
    m.selectedConnectionId = "slot-a"
    m.global = {profilegateclosed: false, profileswitchpending: true, activeusersession: "staging-session"}
    m.profileGateCover = {visible: true}
    m.guide = {active: false, config: {aeriosession: outgoing.sessionId}}
    m.capabilityClock = {control: "stop"}
    m.reminderClock = {control: "stop"}
    m.top = {label: {}, findNode: function(id as string) as object
        return m.label
    end function}
    m.activeUserScope = outgoing
    m.accountIdentity = outgoing.preferenceIdentity
    m.serverAccountId = "7"
    m.apiKey = "synthetic-a"
    m.userProfileRecoveryRequired = false
end sub

sub showNotice(message as string)
    m.notice = message
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
