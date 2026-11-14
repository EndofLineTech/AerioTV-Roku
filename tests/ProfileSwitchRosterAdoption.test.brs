' Real controller + metadata + final storage adoption. Native nodes, PIN digest
' and runtime resource teardown are seams; this is not native acceptance.
sub main()
    for each protected in [false, true]
        rosterAdoptionFixture(protected)
        outgoing = m.activeUserScope
        nonce = m.profileSwitchContext.nonce
        target = m.profileSwitchContext.target.id
        onUserProfileSwitchResult(rosterAdoptionEvent(m.profileSwitchTask, m.verified))
        check(m.reads = 1 and m.lineups = 0 and m.registry.flushes = 0, "own authentication reaches only own roster read before any adoption")
        readTask = m.profileSwitchTask
        onUserProfileSwitchResult(rosterAdoptionEvent(readTask, m.readResult))
        if protected
            check(m.profilePinDialog <> invalid and m.lineups = 0 and loadUserProfileStore(m.registry, "slot-a").active = outgoing.profileId, "imported protection persists before PIN without target adoption")
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(rosterAdoptionEvent(m.profilePinDialog, 0))
        end if
        check(m.lineups = 1 and userProfileSameSession(m.activeUserScope, outgoing) and m.profileGateCover.visible, "full target lineup loads under cover while genuine outgoing scope remains captured")
        before = m.registry.flushes
        onUserProfileSwitchResult(rosterAdoptionEvent(m.profileSwitchTask, m.lineupResult))
        check(m.profileSwitchContext = invalid and m.activeUserScope.profileId = target and m.activeUserScope.sessionId = nonce and m.activeUserScope.sessionId <> outgoing.sessionId, "real final transaction adopts target under distinct incoming session")
        check(loadUserProfileStore(m.registry, "slot-a").active = target and m.registry.flushes = before + 1, "target active/settings/own key share the actual final registry transaction")
        check(m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", target)) = "synthetic-b", "successful target adoption never borrows or replaces default own key")
        check(m.accountPreferences.favoriteIds[0] = "22" and m.guide.config.accountId = "8" and m.guide.config.apiKey = "synthetic-b" and m.guide.config.aeriosession = nonce, "Guide and preferences receive only committed target identity/settings/session")
        check(m.resets = 1 and m.capabilityRefreshes = 1 and m.guide.active and not m.profileGateCover.visible and not m.global.profilegateclosed and not m.global.profileswitchpending, "cover opens only after committed runtime adoption without playback")
        finalFlushes = m.registry.flushes
        onUserProfileSwitchResult(rosterAdoptionEvent(readTask, m.readResult))
        check(m.registry.flushes = finalFlushes and m.activeUserScope.sessionId = nonce and m.resets = 1, "late own read cannot replay metadata or replace adopted runtime")
    end for
    rosterAdoptionUnavailableFixture()
    nonce = m.profileSwitchContext.nonce
    onUserProfileSwitchResult(rosterAdoptionEvent(m.profileSwitchTask, m.verified))
    onUserProfileSwitchResult(rosterAdoptionEvent(m.profileSwitchTask, m.readResult))
    check(m.profilePinDialog <> invalid and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed, "real unavailable adoption first persists target PIN while keeping actual Child actor absent")
    m.profilePinDialog.textEditBox.text = "1234"
    onProfilePinSubmit(rosterAdoptionEvent(m.profilePinDialog, 0))
    onUserProfileSwitchResult(rosterAdoptionEvent(m.profileSwitchTask, m.lineupResult))
    check(m.resets = 1 and m.activeUserScope.accountId = "8" and m.activeUserScope.sessionId = nonce and m.guide.config.aeriosession = nonce and m.apiKey = "synthetic-b" and not m.global.profilegateclosed, "real unavailable-Child final commit adopts only authenticated target via separate no-session API")
    check(loadUserProfileStore(m.registry, "slot-a").profiles[0].role = "child" and m.registry.read("connKey_slot-a") = "synthetic-a", "unavailable target adoption preserves original Child role and own/default key isolation")
    rosterAdoptionFixture(false)
    outgoing = m.activeUserScope
    onUserProfileSwitchResult(rosterAdoptionEvent(m.profileSwitchTask, m.verified))
    onUserProfileSwitchResult(rosterAdoptionEvent(m.profileSwitchTask, m.readResult))
    captured = FormatJson(m.registry.values)
    m.registry.failOnce = true
    onUserProfileSwitchResult(rosterAdoptionEvent(m.profileSwitchTask, m.lineupResult))
    check(FormatJson(m.registry.values) = captured and m.registry.flushes = 2 and m.resets = 0 and m.capabilityRefreshes = 0, "actual final Flush failure restores exact storage and never adopts target runtime")
    check(m.activeUserScope.profileId = outgoing.profileId and m.activeUserScope.sessionId <> outgoing.sessionId and m.apiKey = "synthetic-a" and m.profileSwitchContext = invalid, "failed adoption resumes only revalidated outgoing holder under fresh rollback session")
    print "ALL TESTS PASSED"
end sub

sub rosterAdoptionFixture(protected as boolean)
    entry = normalizeConnectionEntry({id: "slot-a", name: "Fixture", provider: "dispatcharr", url: "https://example.test", remember: true})
    a = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    b = userProfileFromVerified(entry.id, "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    b.isDefault = false
    store = defaultUserProfileStore(entry.id)
    store.profiles = [a, b]
    store.active = a.id
    m.registry = {values: {}, flushes: 0, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, write: function(key as string, value as string) as boolean
        m.values[key] = value
        return true
    end function, delete: function(key as string) as boolean
        m.values.delete(key)
        return true
    end function, flush: function() as boolean
        m.flushes++
        if m.failOnce = true
            m.failOnce = false
            return false
        end if
        return true
    end function}
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: entry.id, entries: [entry]})
    m.registry.values[userProfileStoreKey(entry.id)] = FormatJson(store)
    m.registry.values["connKey_slot-a"] = "synthetic-a"
    m.registry.values[userProfileKeyName(entry.id, b.id)] = "synthetic-b"
    preferences = defaultPreferenceStore()
    preferences.accounts[preferenceScope(connectionPreferenceIdentity(entry, "7"))] = {favoriteIds: ["11"]}
    preferences.accounts[preferenceScope(connectionPreferenceIdentity(entry, "8"))] = {favoriteIds: ["22"]}
    m.registry.values["settingsV1"] = FormatJson(preferences)
    ' Host interpreter lacks ParseJson's precision flag; no production bypass.
    m.profilePreferenceDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    m.connectionStore = loadConnectionStore(m.registry)
    m.userProfileStore = loadUserProfileStore(m.registry, entry.id)
    m.activeUserScope = userProfileSessionScope(entry, a.id, "7", "old", "00000000-0000-4000-8000-000000000090")
    m.selectedConnectionId = entry.id
    m.accountIdentity = m.activeUserScope.preferenceIdentity
    m.serverAccountId = "7"
    m.apiKey = "synthetic-a"
    m.fixtureSourceId = a.id
    m.fixtureSourceKey = m.apiKey
    m.fixtureSourceScope = m.activeUserScope
    m.profileSwitchRosterReady = true
    m.profileChildAccessReady = false
    m.profileSwitchContext = {phase: "authenticate", connection: entry, connectionRoot: m.registry.read("connectionsV1"), connectionRootPresent: true, store: m.userProfileStore, target: m.userProfileStore.profiles[1], key: "synthetic-b", outgoing: m.activeUserScope, outgoingProtection: FormatJson(m.userProfileStore.profiles[0]), nonce: "00000000-0000-4000-8000-000000000091", managementNonce: ""}
    m.global = {activeusersession: m.profileSwitchContext.nonce, profileswitchpending: true, profilegateclosed: false, authHeaderMode: "compatible"}
    m.profileSwitchTask = rosterAdoptionNode("authenticate")
    m.profileSwitchTask.aeriosession = m.profileSwitchContext.nonce
    m.verified = {ok: true, phase: "verified", apiKey: "synthetic-b", accountId: "8", accountUsername: "bob", verifiedBaseUrl: entry.url, verifiedUser: {id: 8, username: "bob", user_level: 1}, authModeUsed: "authorization"}
    m.readResult = {ok: true, state: "missing", allowWrite: false, accountId: "8", accountUsername: "bob", verifiedBaseUrl: entry.url, verifiedUser: m.verified.verifiedUser}
    if protected
        m.readResult.state = "ready"
        m.readResult.profilesState = "ready"
        m.readResult.data = {categories: {profiles: {data: {rows: [[8, "bob", "Bob", "numbers", string(64, "a"), string(32, "b"), "user", 500]]}}}}
    end if
    m.lineupResult = {ok: true, apiKey: "synthetic-b", accountId: "8", accountUsername: "bob", verifiedBaseUrl: entry.url, verifiedUser: m.verified.verifiedUser, channels: [], groups: [], generation: "own-generation", scope: "own-lineup", authModeUsed: "authorization"}
    m.reads = 0
    m.lineups = 0
    m.resets = 0
    m.capabilityRefreshes = 0
    m.profileSwitchReadTaskFactory = function() as object
        m.reads++
        return rosterAdoptionNode("read")
    end function
    m.profileSwitchTaskFactory = function() as object
        m.lineups++
        return rosterAdoptionNode("lineup")
    end function
    m.profilePinDialog = invalid
    m.profilePinContext = invalid
    m.profilePinDialogFactory = function() as object
        pad = rosterAdoptionNode("pin")
        pad.textEditBox = {text: "", hasField: function(name as string) as boolean
            return false
        end function}
        return pad
    end function
    m.profilePinVerifier = function(profile as object, entries as object) as object
        return {verified: true, recoveryRequired: false}
    end function
    m.top = {label: {}, findNode: function(id as string) as object
        return m.label
    end function, hasField: function(field as string) as boolean
        return false
    end function, getChildren: function(count as integer, first as integer) as object
        return []
    end function}
    m.profileGateCover = {visible: true}
    m.profileGateClock = {control: "stop"}
    m.guide = {active: false, config: {aeriosession: m.activeUserScope.sessionId}}
    m.banner = {}
    m.screen = {visible: false}
    m.capabilityClock = {control: "stop"}
    m.reminderClock = {control: "stop"}
    m.playingChannel = invalid
    m.userProfileRecoveryRequired = false
end sub

sub rosterAdoptionUnavailableFixture()
    rosterAdoptionFixture(true)
    store = m.profileSwitchContext.store
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.profileSwitchContext.store = loadUserProfileStore(m.registry, "slot-a")
    m.profileSwitchContext.outgoing = invalid
    m.profileSwitchContext.unavailableChild = true
    m.profileSwitchContext.managementNonce = "00000000-0000-4000-8000-000000000093"
    admin = {pinType: "numbers", pinHash: string(64, "e"), pinSalt: string(32, "f")}
    m.registry.values[userProfileDeviceAdminKey("slot-a")] = FormatJson(admin)
    m.profileSwitchContext.management = {slot: "slot-a", active: store.active, nonce: m.profileSwitchContext.managementNonce, purpose: "manage-profiles", kind: "pin", id: "device-admin", pinType: admin.pinType, pinHash: admin.pinHash, pinSalt: admin.pinSalt}
    m.activeUserScope = invalid
    m.apiKey = ""
    m.page = "profile-unavailable"
    m.fixtureSourceKey = ""
    m.fixtureSourceScope = invalid
end sub

function rosterAdoptionNode(id as string) as object
    return {id: id, isSameNode: function(other as object) as boolean
        return m.id = other.id
    end function, observeField: sub(field as string, callback as string)
    end sub, unobserveField: sub(field as string)
    end sub, setFocus: sub(focus as boolean)
    end sub}
end function

function rosterAdoptionEvent(node as object, value as dynamic) as object
    return {node: node, value: value, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as dynamic
        return m.value
    end function}
end function

sub resetConnectionRuntime()
    actorMatches = m.fixtureSourceScope = invalid and m.activeUserScope = invalid
    if m.fixtureSourceScope <> invalid then actorMatches = userProfileSameSession(m.fixtureSourceScope, m.activeUserScope)
    check(loadUserProfileStore(m.registry, "slot-a").active <> m.fixtureSourceId and actorMatches and m.apiKey = m.fixtureSourceKey and m.profileSwitchContext = invalid and m.profileGateCover.visible, "outgoing teardown is called only after committed active change while genuine preceding actor/key and cover are still intact")
    m.resets++
end sub

sub applyDevicePreferences()
end sub

sub refreshCapabilities()
    m.capabilityRefreshes++
end sub

function currentUserSettingsRole() as string
    return "user"
end function

sub showNotice(message as string)
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
