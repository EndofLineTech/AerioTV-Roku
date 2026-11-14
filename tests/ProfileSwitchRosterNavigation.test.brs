sub main()
    switchRosterControllerFixture()
    m.fixtureVerified.verifiedUser.user_level = 10
    authentication = m.profileSwitchTask
    onUserProfileSwitchResult(switchRosterControllerEvent(authentication, m.fixtureVerified))
    check(m.fixtureCommitAttempts = 0 and m.fixtureReads = 1 and m.fixtureLineups = 0 and m.profileSwitchContext.phase = "roster", "verify-only target proof reads own protection before any lineup or commit attempt")
    readTask = m.profileSwitchTask
    check(readTask.accountId = "8" and readTask.username = "bob" and readTask.apiKey = "synthetic-b" and readTask.authMode = "authorization" and m.global.authHeaderMode = "compatible", "incoming read carries only target identity/key/header mode without changing the outgoing global header context")
    onUserProfileSwitchResult(switchRosterControllerEvent(authentication, m.fixtureVerified))
    check(m.fixtureReads = 1 and m.fixtureCommitAttempts = 0 and m.registry.flushes = 0, "late authentication callback cannot donate another roster read or bypass staging")
    onUserProfileSwitchResult(switchRosterControllerEvent(readTask, m.fixtureRead))
    check(m.profilePinDialog <> invalid and m.global.profilegateclosed and m.fixtureLineups = 0 and m.fixtureCommitAttempts = 0, "newly imported PIN is required before acquiring target lineup")
    saved = loadUserProfileStore(m.registry, "slot-a")
    check(saved.active = m.fixtureOutgoing.profileId and saved.profiles[1].pinHash = string(64, "a") and saved.profiles[1].userLevel = 1 and saved.profiles[1].role = "user" and m.registry.flushes = 1, "changed PIN and latest read authority are stored before the stored-PIN verifier can admit it")
    m.profilePinDialog.textEditBox.text = "1234"
    onProfilePinSubmit(switchRosterControllerEvent(m.profilePinDialog, 0))
    check(m.fixtureLineups = 1 and m.fixtureCommitAttempts = 0 and m.profileSwitchContext.phase = "lineup" and m.profileSwitchTask.verifyOnly <> true, "fresh target PIN resumes staged own lineup, not a second outgoing flush or automatic adoption")
    check(userProfileSameSession(m.activeUserScope, m.fixtureOutgoing) and m.global.activeusersession = m.profileSwitchContext.nonce and m.profileGateCover.visible, "outgoing scope remains captured while incoming nonce owns the still-covered target reload")
    onUserProfileSwitchResult(switchRosterControllerEvent(readTask, m.fixtureRead))
    check(m.fixtureLineups = 1 and m.fixtureCommitAttempts = 0, "late read result cannot reapply protection during lineup staging")
    switchRosterControllerFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    m.fixtureRead.accountId = "80"
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    check(m.registry.flushes = 0 and m.fixtureLineups = 0 and m.fixtureCommitAttempts = 0 and m.profileSwitchContext = invalid, "foreign own-read identity refuses staging without storage mutation or target acquisition")
    switchRosterControllerFixture()
    m.registry.values[userProfileKeyName("slot-a", m.profileSwitchContext.target.id)] = ""
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    check(m.fixtureReads = 0 and m.registry.flushes = 0 and m.fixtureCommitAttempts = 0, "lost current own key refuses even the next App Data request")
    switchRosterControllerFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    m.fixtureRead.data.categories.profiles.data.rows.push([7, "alice", "Alice", "none", "", "", "child", 500])
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    check(m.activeUserScope = invalid and m.global.profilegateclosed and m.profilePinDialog = invalid and m.fixtureLineups = 0, "imported outgoing protection change stays covered before exposing another profile's PIN or content")
    switchRosterControllerFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    onProfilePinClosed(switchRosterControllerEvent(m.profilePinDialog, true))
    check(m.profileSwitchContext = invalid and m.fixtureLineups = 0 and m.activeUserScope.profileId = m.fixtureOutgoing.profileId and not m.global.profilegateclosed, "Back on the imported target PIN returns only to fresh unchanged outgoing admission")
    check(loadUserProfileStore(m.registry, "slot-a").profiles[1].pinHash = string(64, "a"), "cancelling the switch never undoes legitimately imported target protection")
    for each state in ["missing", "legacy"]
        switchRosterControllerFixture()
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
        m.fixtureRead.state = state
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
        check(m.fixtureLineups = 1 and m.registry.flushes = 0 and m.profilePinDialog = invalid and m.fixtureCommitAttempts = 0, "missing/legacy category keeps local protection without applying stray canonical data or migrating the wire")
    end for
    switchRosterControllerUnavailableFixture()
    m.activeUserScope = m.fixtureOutgoing
    m.apiKey = "synthetic-a"
    m.page = "guide"
    m.profileSwitchContext.outgoing = m.activeUserScope
    m.profileSwitchContext.unavailableChild = false
    m.profileSwitchContext.outgoingProtection = FormatJson(m.profileSwitchContext.store.profiles[0])
    store = m.profileSwitchContext.store
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinType", "numbers")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinHash", string(64, "c"))
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinSalt", string(32, "d"))
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.profileSwitchContext.store = loadUserProfileStore(m.registry, "slot-a")
    target = m.profileSwitchContext.store.profiles[1]
    m.profileSwitchContext.target = target
    m.profileSwitchContext.management = {slot: "slot-a", active: store.active, nonce: m.profileSwitchContext.managementNonce, purpose: "manage-profiles", kind: "pin", id: target.id, pinType: target.pinType, pinHash: target.pinHash, pinSalt: target.pinSalt}
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    check(m.profileSwitchContext = invalid and m.profilePinDialog = invalid and m.fixtureLineups = 0 and m.activeUserScope.profileId = m.fixtureOutgoing.profileId and loadUserProfileStore(m.registry, "slot-a").profiles[0].role = "child", "authenticated Child also loses stale adult-purpose admission BEFORE target PIN/name exposure after imported holder material changes")
    switchRosterControllerFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    m.fixtureRead.state = "missing"
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    m.registry.values[userProfileKeyName("slot-a", m.profileSwitchContext.target.id)] = ""
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    check(m.fixtureCommitAttempts = 0 and m.profileSwitchContext = invalid, "own key loss during target reload is rechecked before final adoption, not just acquisition")
    switchRosterControllerFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    m.fixtureRead.data = {}
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    check(m.registry.flushes = 0 and m.fixtureLineups = 0 and m.fixtureCommitAttempts = 0, "inconsistent ready-read payload fails retained instead of indexing malformed wire data")
    switchRosterControllerFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    m.profileSwitchContext.nonce = "00000000-0000-4000-8000-000000000099"
    m.global.activeusersession = m.profileSwitchContext.nonce
    m.profileUnlockGrant = {marker: "successor"}
    m.profilePinDialog.textEditBox.text = "1234"
    onProfilePinSubmit(switchRosterControllerEvent(m.profilePinDialog, 0))
    check(m.fixturePinChecks = 0 and m.registry.flushes = 1 and m.global.profilegateclosed and m.profileUnlockGrant.marker = "successor" and m.fixtureLineups = 0, "stale staged PIN cannot verify or open a successor gate")
    onProfilePinClosed(switchRosterControllerEvent(m.profilePinDialog, true))
    check(m.profileSwitchContext.nonce = "00000000-0000-4000-8000-000000000099" and m.global.activeusersession = m.profileSwitchContext.nonce and m.global.profilegateclosed and m.global.profileswitchpending, "stale staged pad closure does not cancel or replace the successor switch lifecycle")
    switchRosterControllerFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    changed = loadUserProfileStore(m.registry, "slot-a")
    changed.profiles[1].pinHash = string(64, "c")
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(changed)
    m.profilePinDialog.textEditBox.text = "1234"
    onProfilePinSubmit(switchRosterControllerEvent(m.profilePinDialog, 0))
    check(m.fixtureLineups = 0 and m.fixtureCommitAttempts = 0 and m.global.profilegateclosed and m.activeUserScope = invalid, "even an injected positive PIN verifier cannot bypass a newer stored target PIN or revive stale outgoing protection")
    switchRosterControllerFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    m.fixtureRead.state = "missing"
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    final = {ok: true, apiKey: "synthetic-b", accountId: "8", accountUsername: "bob", verifiedBaseUrl: "https://example.test", verifiedUser: {id: 8, username: "bob", user_level: 1}, channels: [], groups: [], scope: "own-lineup", generation: "own-generation", authModeUsed: "authorization"}
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, final))
    check(m.fixtureCommitAttempts = 1 and m.profileSwitchContext = invalid and m.activeUserScope.profileId = m.fixtureOutgoing.profileId, "fresh final own result reaches the existing atomic commit boundary; injected commit refusal retains only the outgoing holder")
    switchRosterControllerFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    pad = m.profilePinDialog
    pad.textEditBox.text = "9999"
    retireUserProfileSwitch()
    check(pad.close = true and pad.textEditBox.text = "" and m.profilePinDialog = invalid and m.profilePinContext = invalid and m.global.profilegateclosed and m.profileGateCover.visible, "retiring a switch closes and wipes its owned PIN widget without exposing its name or opening the next holder's gate")
    for each mismatch in ["nonce", "slot", "continuation"]
        switchRosterControllerFixture()
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
        pad = m.profilePinDialog
        pad.close = false
        pad.textEditBox.text = "8888"
        if mismatch = "nonce" then m.profilePinContext.resume = "successor"
        if mismatch = "slot" then m.profilePinContext.slot = "slot-b"
        if mismatch = "continuation" then m.profilePinContext.continuation = "own-signin"
        m.profileGateClock.control = "start"
        m.profileUnlockGrant = {marker: "successor"}
        retireUserProfileSwitch()
        check(not pad.close and pad.textEditBox.text = "8888" and m.profilePinDialog <> invalid and m.profilePinContext <> invalid and m.profileGateClock.control = "start" and m.profileUnlockGrant.marker = "successor" and m.global.profilegateclosed, "switch retirement leaves another nonce/slot/continuation PIN widget, timer and grant untouched")
    end for
    switchRosterControllerFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    m.profilePinContext.continuation = "switch"
    pad = m.profilePinDialog
    pad.textEditBox.text = "7777"
    retireUserProfileSwitch()
    check(pad.close = true and pad.textEditBox.text = "" and m.profilePinDialog = invalid and m.profileGateClock.control = "stop" and m.global.profilegateclosed, "legacy switch retirement also wipes only its captured PIN prompt without releasing the gate")
    switchRosterControllerUnavailableFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    check(m.fixtureReads = 1 and m.activeUserScope = invalid and m.apiKey = "", "unavailable Child target authentication reads own protection without fabricating an outgoing session")
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    check(m.profilePinDialog <> invalid and m.activeUserScope = invalid and m.global.profilegateclosed and loadUserProfileStore(m.registry, "slot-a").active = m.fixtureOutgoing.profileId, "current Device Admin purpose permits imported target PIN gate while Child remains active and unauthenticated")
    m.profilePinDialog.textEditBox.text = "1234"
    onProfilePinSubmit(switchRosterControllerEvent(m.profilePinDialog, 0))
    check(m.fixtureLineups = 1 and m.activeUserScope = invalid and m.apiKey = "" and m.profileGateCover.visible, "unavailable staged PIN admits only target lineup under incoming nonce, never a borrowed Child actor")
    switchRosterControllerUnavailableFixture()
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    onProfilePinClosed(switchRosterControllerEvent(m.profilePinDialog, true))
    check(m.profileSwitchContext = invalid and m.activeUserScope = invalid and m.apiKey = "" and m.global.activeusersession = "" and m.global.profilegateclosed and m.page = "profile-unavailable", "cancelling unavailable imported PIN returns only to its scope-free Child surface")
    for each grantOwner in ["own", "successor"]
        switchRosterControllerUnavailableFixture()
        store = m.profileSwitchContext.store
        store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinType", "numbers")
        store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinHash", string(64, "c"))
        store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinSalt", string(32, "d"))
        m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
        m.profileSwitchContext.store = loadUserProfileStore(m.registry, "slot-a")
        target = m.profileSwitchContext.store.profiles[1]
        m.profileSwitchContext.target = target
        m.profileSwitchContext.management = {slot: "slot-a", active: store.active, nonce: m.profileSwitchContext.managementNonce, purpose: "manage-profiles", kind: "pin", id: target.id, pinType: target.pinType, pinHash: target.pinHash, pinSalt: target.pinSalt}
        m.profileManagementNonce = m.profileSwitchContext.managementNonce
        m.profileManagementGrant = {marker: grantOwner}
        if grantOwner = "successor" then m.profileManagementNonce = "successor"
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
        check(m.profileSwitchContext = invalid and m.profilePinDialog = invalid and m.fixtureLineups = 0 and m.activeUserScope = invalid and m.global.profilegateclosed and loadUserProfileStore(m.registry, "slot-a").profiles[1].pinHash = string(64, "a"), "changed imported adult-purpose material returns to unavailable Child BEFORE exposing target PIN/name, retaining imported protection")
        if grantOwner = "own"
            check(m.profileManagementGrant = invalid and m.profileManagementNonce = "", "expired owned management grant is retired without minting a replacement")
        else
            check(m.profileManagementGrant.marker = "successor" and m.profileManagementNonce = "successor", "retired escape cannot erase a different management lifecycle's grant")
        end if
    end for
    switchRosterControllerUnavailableFixture()
    m.apiKey = "successor-key"
    nonce = m.profileSwitchContext.nonce
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, {ok: false}))
    onUserProfileSwitchState(switchRosterControllerEvent(m.profileSwitchTask, "done"))
    check(m.profileSwitchContext <> invalid and m.apiKey = "successor-key" and m.global.activeusersession = nonce and m.global.profileswitchpending and m.registry.flushes = 0, "late failure/state callbacks cannot roll back a no-session escape after its actual empty actor/key lifecycle has changed")
    for each unavailable in [false, true]
        if unavailable
            switchRosterControllerUnavailableFixture()
        else
            switchRosterControllerFixture()
        end if
        m.registry.values[userProfileKeyName("slot-a", m.profileSwitchContext.target.id)] = ""
        startUserProfileSwitchTask(m.profileSwitchContext.nonce)
        check(m.fixtureReads = 0 and m.fixtureLineups = 0 and m.fixtureInitialSaves = 0 and m.profileSwitchContext = invalid, "lost current target key during initial PIN wait refuses BEFORE outgoing teardown or even the first own authentication request")
    end for
    for each unavailable in [false, true]
        switchRosterControllerInactiveFixture(unavailable)
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
        check(m.profilePinDialog <> invalid and m.registry.flushes = 1 and m.fixtureLineups = 0 and not m.registry.exists(m.fixtureThirdKey) and not m.registry.exists(m.fixtureThirdBackoff), "explicit inactive cleanup atomically removes only tombstoned third holder before target stored-PIN admission")
        check(not m.profileSessionKeys.doesExist(m.fixtureThirdBucket) and m.profileSessionKeys.foreign = "foreign-memory" and m.registry.read("connKey_slot-a") = "synthetic-a", "incoming cleanup retires only removed holder's current memory lease without touching default/foreign keys")
        check(not m.preferenceStore.accounts.doesExist(m.fixtureThirdAccount), "staged cleanup publishes its committed strict preference root before any target PIN cancellation can revive outgoing writes")
        onProfilePinClosed(switchRosterControllerEvent(m.profilePinDialog, true))
        if not unavailable
            futureSave = userProfileSettingsCommitPlan(m.preferenceStore, m.activeUserScope.preferenceIdentity, normalizeAccountPreferences({favoriteIds: ["7"]}), normalizeDevicePreferences(m.preferenceStore.device))
            check(futureSave.ok and not futureSave.store.accounts.doesExist(m.fixtureThirdAccount), "outgoing save after cancelled switch cannot resurrect a cleaned holder's old preference blob")
        end if
    end for
    for each unavailable in [false, true]
        switchRosterControllerInactiveFixture(unavailable)
        store = m.profileSwitchContext.store
        store.profiles[0] = setCanonicalPreference(store.profiles[0], "isDefault", false)
        store.profiles[2] = setCanonicalPreference(store.profiles[2], "isDefault", true)
        m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
        m.registry.values[userProfileKeyName("slot-a", m.fixtureOutgoing.profileId)] = "synthetic-a"
        m.registry.values["connKey_slot-a"] = "synthetic-third"
        m.profileSwitchContext.store = loadUserProfileStore(m.registry, "slot-a")
        m.profileSwitchContext.target = m.profileSwitchContext.store.profiles[1]
        if not unavailable then m.profileSwitchContext.outgoingProtection = FormatJson(m.profileSwitchContext.store.profiles[0])
        targetId = m.profileSwitchContext.target.id
        targetAccount = preferenceScope(connectionPreferenceIdentity(m.profileSwitchContext.connection, "8"))
        targetBucket = preferenceScope(m.profileSwitchContext.connection.url + "|slot-a|" + targetId)
        targetBackoff = userProfilePinBackoffKey("slot-a", targetId)
        m.profileSessionKeys[targetBucket] = "synthetic-b"
        m.registry.values[targetBackoff] = "target-ledger"
        m.preferenceStore.accounts[targetAccount] = normalizeAccountPreferences({favoriteIds: ["8"]})
        m.registry.values["settingsV1"] = FormatJson(m.preferenceStore)
        m.fixtureRead.data.categories.profiles.data.rows = []
        m.fixtureRead.data.categories.profiles.data.removed = [["bob", CreateObject("roDateTime").asSeconds()]]
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
        context = m.profileSwitchContext
        readTask = m.profileSwitchTask
        onUserProfileSwitchResult(switchRosterControllerEvent(readTask, m.fixtureRead))
        check(m.profileSwitchContext = invalid and m.profilePinDialog = invalid and m.fixtureLineups = 0 and m.registry.flushes = 1 and readTask.cancelRequested and readTask.apiKey = "", "a tombstoned unadopted target closes/wipes its read Task and retires without any target PIN, lineup or active scope")
        check(not m.registry.exists(userProfileKeyName("slot-a", targetId)) and not m.registry.exists(targetBackoff) and not m.profileSessionKeys.doesExist(targetBucket) and not m.preferenceStore.accounts.doesExist(targetAccount) and m.registry.exists(m.fixtureThirdKey), "target retirement publishes cleaned roots and drops only removed target key/backoff/blob/memory, preserving unrelated third holder")
        check(context.key = "" and context.authentication.apiKey = "" and loadUserProfileStore(m.registry, "slot-a").active = m.fixtureOutgoing.profileId and m.registry.read("connKey_slot-a") = "synthetic-third", "no retired target credential survives in the controller, and the different default is preserved rather than replacing the genuine non-default outgoing holder")
        if unavailable
            check(m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.global.activeusersession = "" and m.page = "profile-unavailable", "unavailable Child target retirement returns only its real no-session Child surface")
        else
            check(m.activeUserScope.profileId = m.fixtureOutgoing.profileId and m.activeUserScope.sessionId <> m.fixtureOutgoing.sessionId and m.apiKey = "synthetic-a" and not m.global.profilegateclosed, "full-access target retirement resumes only fresh unchanged outgoing admission without autoplay")
        end if
    end for
    for each alsoTarget in [false, true]
        switchRosterControllerInactiveFixture(false)
        store = m.profileSwitchContext.store
        outgoing = setCanonicalPreference(store.profiles[0], "isDefault", false)
        target = store.profiles[1]
        third = setCanonicalPreference(store.profiles[2], "isDefault", true)
        store.profiles = [target, outgoing, third]
        m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
        m.registry.values[userProfileKeyName("slot-a", outgoing.id)] = "synthetic-a"
        m.registry.values["connKey_slot-a"] = "synthetic-third"
        m.profileSwitchContext.store = loadUserProfileStore(m.registry, "slot-a")
        m.profileSwitchContext.target = m.profileSwitchContext.store.profiles[0]
        m.profileSwitchContext.outgoingProtection = FormatJson(m.profileSwitchContext.store.profiles[1])
        removed = [["alice", CreateObject("roDateTime").asSeconds()]]
        if alsoTarget then removed.push(["bob", CreateObject("roDateTime").asSeconds()])
        m.fixtureRead.data.categories.profiles.data.rows = []
        m.fixtureRead.data.categories.profiles.data.removed = removed
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
        onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
        check(m.registry.flushes = 0 and m.activeUserScope = invalid and m.global.activeusersession = "" and m.global.profilegateclosed and m.userProfileRecoveryRequired and m.fixtureLineups = 0, "an actual outgoing tombstone, alone or alongside target removal, stays covered pending default retirement instead of reviving the removed actor")
    end for
    switchRosterControllerInactiveFixture(false)
    m.registry.values["settingsV1"] = "{malformed"
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureVerified))
    onUserProfileSwitchResult(switchRosterControllerEvent(m.profileSwitchTask, m.fixtureRead))
    check(m.registry.flushes = 0 and m.registry.read("settingsV1") = "{malformed" and m.activeUserScope = invalid and m.global.profilegateclosed and m.userProfileRecoveryRequired, "unreadable present preference root freezes cleanup/rollback admission so an outgoing save cannot overwrite it from stale memory")
    print "ALL TESTS PASSED"
end sub

sub switchRosterControllerFixture()
    entry = normalizeConnectionEntry({id: "slot-a", name: "Fixture", provider: "dispatcharr", url: "https://example.test", remember: true})
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
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
        return true
    end function}
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: entry.id, entries: [entry]})
    m.registry.values[userProfileStoreKey(entry.id)] = FormatJson(store)
    m.registry.values["connKey_slot-a"] = "synthetic-a"
    m.registry.values[userProfileKeyName(entry.id, b.id)] = "synthetic-b"
    m.connectionStore = loadConnectionStore(m.registry)
    m.userProfileStore = loadUserProfileStore(m.registry, entry.id)
    m.fixtureOutgoing = userProfileSessionScope(entry, a.id, "7", "old", "00000000-0000-4000-8000-000000000090")
    m.activeUserScope = m.fixtureOutgoing
    m.selectedConnectionId = entry.id
    m.accountIdentity = m.fixtureOutgoing.preferenceIdentity
    m.serverAccountId = "7"
    m.apiKey = "synthetic-a"
    m.profileSwitchRosterReady = true
    m.profileChildAccessReady = false
    m.profileSwitchContext = {phase: "authenticate", connection: entry, connectionRoot: m.registry.read("connectionsV1"), connectionRootPresent: true, store: m.userProfileStore, target: m.userProfileStore.profiles[1], key: "synthetic-b", outgoing: m.activeUserScope, outgoingProtection: FormatJson(m.userProfileStore.profiles[0]), nonce: "00000000-0000-4000-8000-000000000091", managementNonce: ""}
    m.global = {activeusersession: m.profileSwitchContext.nonce, profileswitchpending: true, profilegateclosed: false, authHeaderMode: "compatible"}
    m.profileSwitchTask = switchRosterControllerNode("authenticate")
    m.profileSwitchTask.aeriosession = m.profileSwitchContext.nonce
    m.fixtureVerified = {ok: true, phase: "verified", apiKey: "synthetic-b", accountId: "8", accountUsername: "bob", verifiedBaseUrl: entry.url, verifiedUser: {id: 8, username: "bob", user_level: 1}, authModeUsed: "authorization"}
    wire = {rows: [[8, "bob", "Bob", "numbers", string(64, "a"), string(32, "b"), "user", 500]]}
    m.fixtureRead = {ok: true, state: "ready", profilesState: "ready", allowWrite: false, accountId: "8", accountUsername: "bob", verifiedBaseUrl: entry.url, verifiedUser: {id: 8, username: "bob", user_level: 1}, data: {categories: {profiles: {data: wire}}}}
    m.fixtureCommitAttempts = 0
    m.fixtureReads = 0
    m.fixtureLineups = 0
    m.fixturePinChecks = 0
    m.fixtureInitialSaves = 0
    m.profileSwitchReadTaskFactory = function() as object
        m.fixtureReads++
        return switchRosterControllerNode("roster")
    end function
    m.profileSwitchTaskFactory = function() as object
        m.fixtureLineups++
        return switchRosterControllerNode("lineup")
    end function
    m.profilePinDialog = invalid
    m.profilePinContext = invalid
    m.profilePinDialogFactory = function() as object
        dialog = switchRosterControllerNode("target-pin")
        dialog.textEditBox = {text: "", hasField: function(name as string) as boolean
            return false
        end function}
        return dialog
    end function
    m.profilePinVerifier = function(profile as object, entries as object) as object
        m.fixturePinChecks++
        return {verified: true, locked: false, recoveryRequired: false}
    end function
    m.profileGateCover = {visible: true}
    m.profileGateClock = {control: "stop"}
    m.guide = {active: false, config: {aeriosession: m.fixtureOutgoing.sessionId}}
    m.capabilityClock = {control: "stop"}
    m.reminderClock = {control: "stop"}
    m.top = {label: {}, findNode: function(id as string) as object
        return m.label
    end function, hasField: function(field as string) as boolean
        return false
    end function, getChildren: function(count as integer, first as integer) as object
        return []
    end function}
    m.recordTask = invalid
    m.recordSettlementTask = invalid
    m.playingChannel = invalid
    m.userProfileRecoveryRequired = false
end sub

sub switchRosterControllerUnavailableFixture()
    switchRosterControllerFixture()
    store = m.userProfileStore
    store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.profileSwitchContext.store = loadUserProfileStore(m.registry, "slot-a")
    m.profileSwitchContext.unavailableChild = true
    m.profileSwitchContext.outgoing = invalid
    m.profileSwitchContext.managementNonce = "00000000-0000-4000-8000-000000000093"
    admin = {pinType: "numbers", pinHash: string(64, "e"), pinSalt: string(32, "f")}
    m.registry.values[userProfileDeviceAdminKey("slot-a")] = FormatJson(admin)
    m.profileSwitchContext.management = {slot: "slot-a", active: store.active, nonce: m.profileSwitchContext.managementNonce, purpose: "manage-profiles", kind: "pin", id: "device-admin", pinType: admin.pinType, pinHash: admin.pinHash, pinSalt: admin.pinSalt}
    m.activeUserScope = invalid
    m.apiKey = ""
    m.page = "profile-unavailable"
end sub

function showUnavailableChildProfile() as boolean
    return true
end function

sub switchRosterControllerInactiveFixture(unavailable as boolean)
    if unavailable
        switchRosterControllerUnavailableFixture()
    else
        switchRosterControllerFixture()
    end if
    store = m.profileSwitchContext.store
    third = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 9, username: "third", user_level: 1}, 1)
    third = setCanonicalPreference(third, "isDefault", false)
    store.profiles.push(third)
    m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
    m.profileSwitchContext.store = loadUserProfileStore(m.registry, "slot-a")
    m.fixtureThirdKey = userProfileKeyName("slot-a", third.id)
    m.fixtureThirdBackoff = userProfilePinBackoffKey("slot-a", third.id)
    m.fixtureThirdBucket = preferenceScope(m.profileSwitchContext.connection.url + "|slot-a|" + third.id)
    m.registry.values[m.fixtureThirdKey] = "synthetic-third"
    m.registry.values[m.fixtureThirdBackoff] = "private-ledger"
    preferences = defaultPreferenceStore()
    m.fixtureThirdAccount = preferenceScope(connectionPreferenceIdentity(m.profileSwitchContext.connection, "9"))
    preferences.accounts[m.fixtureThirdAccount] = normalizeAccountPreferences({favoriteIds: ["99"]})
    m.registry.values["settingsV1"] = FormatJson(preferences)
    m.preferenceStore = preferences
    m.profilePreferenceDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    m.profileSessionKeys = {foreign: "foreign-memory"}
    m.profileSessionKeys[m.fixtureThirdBucket] = "synthetic-third"
    m.fixtureRead.data.categories.profiles.data.removed = [["third", CreateObject("roDateTime").asSeconds()]]
end sub

function persistCurrentUserProfilePreferences() as boolean
    m.fixtureInitialSaves++
    return false
end function

function switchRosterControllerNode(id as string) as object
    return {id: id, cancelRequested: false, isSameNode: function(other as object) as boolean
        return m.id = other.id
    end function, observeField: sub(field as string, callback as string)
    end sub, unobserveField: sub(field as string)
    end sub, setFocus: sub(focus as boolean)
    end sub}
end function

function switchRosterControllerEvent(node as object, value as dynamic) as object
    return {node: node, value: value, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as dynamic
        return m.value
    end function}
end function

function commitUserProfileSwitch(registry as object, connection as object, previous as object, targetId as string, verified as object, pin as dynamic, management as dynamic, managementNonce as string, nonce as string, activeNonce as string, outgoing as dynamic, activeOutgoing as dynamic) as object
    m.fixtureCommitAttempts++
    return {ok: false, recoveryRequired: false}
end function

' This controller fixture injects PIN verification, so no learned-length write
' occurs. The real policy/length transaction is exercised by UserProfileSwitch.
function userProfileSwitchAcceptPinStore(previous as object, current as object, targetId as string, grant as dynamic) as boolean
    if FormatJson(previous) <> FormatJson(current) then return false
    for each profile in current.profiles
        if profile.id = targetId then return userProfilePinGrantMatches(grant, current.playlistId, profile)
    end for
    return false
end function

sub showNotice(message as string)
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
