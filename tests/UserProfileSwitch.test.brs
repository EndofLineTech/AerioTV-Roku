sub main()
    ' Host brs lacks ParseJson's precision flag; native builder removes this seam.
    m.profilePreferenceDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    b.isDefault = false
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    connection = {id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true}
    verified = {ok: true, apiKey: "bob-own-key", verifiedUser: {id: 8, username: "bob", user_level: 1}, accountId: "8", accountUsername: "bob", channels: [], groups: [], generation: "generation-b"}
    session = "00000000-0000-4000-8000-000000000090"
    planned = userProfileSwitchPlan(connection, store, b.id, verified, invalid, invalid, invalid, session, session)
    check(planned.ok and planned.store.active = b.id and planned.scope.profileId = b.id and planned.scope.accountId = "8", "own verified lineup stages a target-bound immutable scope")
    check(store.active = a.id and connection.accountId = "7", "switch planning never adopts early or replaces default connection identity")
    deferred = copyJson(store)
    deferred.profiles[1].addOrigin = "paused"
    check(not userProfileSwitchPlan(connection, deferred, b.id, verified, invalid, invalid, invalid, session, session).ok, "deferred Add cannot be activated from a verified lineup without settled protection")
    check(userProfileRemovalPlan(deferred, b.id, 3, "undo").ok, "deferred Add still permits local Undo")
    deferred.active = b.id
    check(not userProfileStartupGate(deferred, true).allowed, "cold or deep-linked launch cannot activate the deferred holder with a saved key")
    wrong = copyJson(verified)
    wrong.verifiedUser.id = 7
    check(not userProfileSwitchPlan(connection, store, b.id, wrong, invalid, invalid, invalid, session, session).ok, "a default credential cannot authenticate a non-default target")
    wrong = copyJson(verified)
    wrong.verifiedUser.username = "another"
    check(not userProfileSwitchPlan(connection, store, b.id, wrong, invalid, invalid, invalid, session, session).ok, "matching user ID does not excuse a changed username")
    check(not userProfileSwitchPlan(connection, store, b.id, verified, invalid, invalid, invalid, session, "00000000-0000-4000-8000-000000000091").ok, "retired staging lifecycle cannot commit after same-slot A/B/A")
    store.profiles[1].addressHeld = true
    check(not userProfileSwitchPlan(connection, store, b.id, verified, invalid, invalid, invalid, session, session).ok, "a held target requires a separate verified address-recovery transaction")
    store.profiles[1].addressHeld = false
    store.profiles[1].pinType = "numbers"
    store.profiles[1].pinHash = string(64, "a")
    store.profiles[1].pinSalt = string(32, "b")
    check(not userProfileSwitchPlan(connection, store, b.id, verified, invalid, invalid, invalid, session, session).ok, "lineup staging cannot bypass target PIN protection")
    pin = {slot: "slot-a", id: b.id, pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    check(userProfileSwitchPlan(connection, store, b.id, verified, pin, invalid, invalid, session, session).ok, "verified target material permits target PIN boundary")
    store.profiles[0].role = "child"
    check(not userProfileSwitchPlan(connection, store, b.id, verified, pin, invalid, invalid, session, session).ok, "a Child cannot leave through an incoming target PIN alone")
    adult = {slot: "slot-a", active: a.id, nonce: session, purpose: "manage-profiles", kind: "pin", id: b.id, pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    check(userProfileSwitchPlan(connection, store, b.id, verified, pin, invalid, adult, session, session, session).ok, "current adult-purpose authority independently permits leaving Child")
    nextAttempt = "00000000-0000-4000-8000-000000000092"
    nextPlan = userProfileSwitchPlan(connection, store, b.id, verified, pin, invalid, adult, nextAttempt, nextAttempt, session)
    check(nextPlan.ok and nextPlan.scope.sessionId = nextAttempt, "fresh switching attempt is independent of an existing adult-management UI lifecycle")
    wrong = copyJson(verified)
    wrong.profileId = "default-filter"
    check(not userProfileSwitchPlan(connection, store, b.id, wrong, pin, invalid, adult, nextAttempt, nextAttempt, session).ok, "non-default lineup cannot inherit default Channel Profile filters")
    store.profiles[0].role = "user"
    registry = switchRegistryFixture(connection, store)
    outgoing = userProfileSessionScope(connection, a.id, 7, "outgoing-generation", "00000000-0000-4000-8000-000000000093")
    committed = commitUserProfileSwitch(registry, connection, store, b.id, verified, pin, invalid, "", nextAttempt, nextAttempt, outgoing, outgoing)
    check(committed.ok and committed.scope.sessionId = nextAttempt and loadUserProfileStore(registry, "slot-a").active = b.id, "switch commits target activation only with current outgoing and incoming lifecycles")
    check(registry.flushes = 1 and registry.read("connKey_slot-a") = "default-key" and registry.read(userProfileKeyName("slot-a", b.id)) = "bob-own-key", "target active/settings/own key share one Flush and preserve the default key")
    check(committed.preferences.favoriteIds.count() = 0 and committed.preferences.profileSettings.themePreset = "forest", "incoming preferences are its own scope, never outgoing favorites or appearance")
    registry = switchRegistryFixture(connection, store)
    before = FormatJson(registry.values)
    registry.failOnce = true
    committed = commitUserProfileSwitch(registry, connection, store, b.id, verified, pin, invalid, "", nextAttempt, nextAttempt, outgoing, outgoing)
    check(not committed.ok and FormatJson(registry.values) = before and loadUserProfileStore(registry, "slot-a").active = a.id, "failed switch Flush restores prior active profile, all settings and all keys without runtime adoption")
    registry = switchRegistryFixture(connection, store)
    otherSession = userProfileSessionScope(connection, a.id, 7, "outgoing-generation", "00000000-0000-4000-8000-000000000094")
    committed = commitUserProfileSwitch(registry, connection, store, b.id, verified, pin, invalid, "", nextAttempt, nextAttempt, outgoing, otherSession)
    check(not committed.ok and registry.flushes = 0, "old A callback cannot commit after B then new A even when user/profile IDs match")
    registry = switchRegistryFixture(connection, store)
    registry.write("settingsV1", "not-json")
    committed = commitUserProfileSwitch(registry, connection, store, b.id, verified, pin, invalid, "", nextAttempt, nextAttempt, outgoing, outgoing)
    check(not committed.ok and registry.flushes = 0 and registry.read("settingsV1") = "not-json", "corrupt present preferences cannot be replaced by empty incoming settings")
    learned = normalizeUserProfileStore(store, "slot-a")
    learned.profiles[1] = setCanonicalPreference(learned.profiles[1], "pinLength", 4)
    check(userProfileSwitchAcceptPinStore(store, learned, b.id, pin), "successful target verification may update only its locally learned PIN length before staging")
    learned.profiles[0] = setCanonicalPreference(learned.profiles[0], "displayName", "Changed while waiting")
    check(not userProfileSwitchAcceptPinStore(store, learned, b.id, pin), "PIN wait cannot authorize an unrelated roster change or stale switch snapshot")
    returning = copyJson(store)
    returning.active = b.id
    returning.profiles[0] = setCanonicalPreference(returning.profiles[0], "preferenceAnchor", "https://old.test|7|slot-a")
    registry = switchRegistryFixture(connection, returning)
    prefs = ParseJson(registry.read("settingsV1"))
    currentKey = preferenceScope(connectionPreferenceIdentity(connection, "7"))
    prefs.accounts[preferenceScope("https://old.test|7|slot-a")] = prefs.accounts[currentKey]
    prefs.accounts.delete(currentKey)
    registry.write("settingsV1", FormatJson(prefs))
    outgoingB = userProfileSessionScope(connection, b.id, 8, "outgoing-b", session)
    defaultVerified = {ok: true, apiKey: "default-key", verifiedUser: {id: 7, username: "ALICE", user_level: 1}, accountId: "7", accountUsername: "alice", channels: [], groups: [], generation: "return-default"}
    committed = commitUserProfileSwitch(registry, connection, returning, a.id, defaultVerified, invalid, invalid, "", nextAttempt, nextAttempt, outgoingB, outgoingB)
    check(committed.ok and committed.store.doesExist("knownDefault") and committed.store["knownDefault"]["userId"] = 7, "returning to a verified default records its own identity in the atomic switch commit")
    check(committed.ok and committed.preferences.favoriteIds[0] = "outgoing-only" and not committed.preferenceStore.accounts.doesExist(preferenceScope("https://old.test|7|slot-a")), "default return reads its migrated original-address preferences instead of another user's blob or empty defaults")
    childStore = copyJson(store)
    childStore.active = b.id
    childStore.profiles[1] = setCanonicalPreference(childStore.profiles[1], "role", "child")
    childStore.profiles[0] = setCanonicalPreference(childStore.profiles[0], "pinType", "numbers")
    childStore.profiles[0] = setCanonicalPreference(childStore.profiles[0], "pinHash", string(64, "c"))
    childStore.profiles[0] = setCanonicalPreference(childStore.profiles[0], "pinSalt", string(32, "d"))
    childStore.pendingRoster = true
    targetPin = {slot: "slot-a", id: a.id, pinType: "numbers", pinHash: string(64, "c"), pinSalt: string(32, "d")}
    adultExit = {slot: "slot-a", active: b.id, nonce: session, purpose: "manage-profiles", kind: "pin", id: a.id, pinType: "numbers", pinHash: string(64, "c"), pinSalt: string(32, "d")}
    defaultProof = setCanonicalPreference(defaultVerified, "verifiedBaseUrl", connection.url)
    for each failFlush in [false, true]
        registry = switchRegistryFixture(connection, childStore)
        before = FormatJson(registry.values)
        registry.failOnce = failFlush
        escaped = commitUnavailableChildProfileSwitch(registry, connection, childStore, a.id, defaultProof, targetPin, adultExit, session, nextAttempt, nextAttempt)
        if failFlush
            check(not escaped.ok and FormatJson(registry.values) = before, "failed unavailable-Child escape restores its exact selection, private data, PINs and keys")
        else
            check(escaped.ok and escaped.store.active = a.id and escaped.scope.sessionId = nextAttempt and escaped.scope.accountId = "7", "PIN-authorized unavailable Child can activate a freshly verified target without inventing an outgoing authenticated scope")
            check(escaped.store.pendingRoster and escaped.store.profiles[1].role = "child" and registry.read("connKey_slot-a") = "default-key", "unavailable escape retains outgoing dirty work and Child protection; it does not clear pending sync or borrow its key")
        end if
    end for
    registry = switchRegistryFixture(connection, childStore)
    check(not commitUnavailableChildProfileSwitch(registry, connection, childStore, a.id, defaultProof, targetPin, invalid, session, nextAttempt, nextAttempt).ok and registry.flushes = 0, "a target PIN alone cannot bypass unavailable Child adult-purpose admission")
    staleProof = setCanonicalPreference(defaultProof, "verifiedBaseUrl", "https://stale.test")
    check(not commitUnavailableChildProfileSwitch(registry, connection, childStore, a.id, staleProof, targetPin, adultExit, session, nextAttempt, nextAttempt).ok and registry.flushes = 0, "foreign-address proof cannot authorize an unavailable escape")
    check(not commitUnavailableChildProfileSwitch(registry, connection, childStore, a.id, defaultProof, targetPin, adultExit, session, nextAttempt, session).ok and registry.flushes = 0, "retired unavailable-Child switch nonce cannot activate a target")
    check(not commitUnavailableChildProfileSwitch(registry, connection, store, a.id, defaultProof, targetPin, adultExit, session, nextAttempt, nextAttempt).ok and registry.flushes = 0, "unavailable-Child transaction is not an unauthenticated adult switch shortcut")
    check(not commitUnavailableChildProfileSwitch(registry, connection, childStore, a.id, defaultProof, invalid, adultExit, session, nextAttempt, nextAttempt).ok and registry.flushes = 0, "adult-purpose admission alone never substitutes for the target's own PIN")
    selected = defaultUserProfileStore(connection.id)
    protectedDefault = setCanonicalPreference(a, "pinType", "numbers")
    protectedDefault = setCanonicalPreference(protectedDefault, "pinHash", string(64, "e"))
    protectedDefault = setCanonicalPreference(protectedDefault, "pinSalt", string(32, "f"))
    selected.profiles = [protectedDefault]
    selected.active = a.id
    for each failFlush in [false, true]
        registry = switchRegistryFixture(connection, selected)
        current = loadUserProfileStore(registry, connection.id)
        receipt = {committed: true, needsDefaultSwitch: true, store: current, removed: [b]}
        context = {systemDefaultRetirement: true, nonce: nextAttempt, connection: connection, connectionRoot: registry.read("connectionsV1"), connectionRootPresent: true, store: current, storeRoot: registry.read(userProfileStoreKey(connection.id)), target: current.profiles[0], key: "default-key", retirement: receipt, retirementStoreRoot: FormatJson(current), retiredProfileId: b.id, authorizationSignature: dispatcharrAuthorizationSignature(defaultProof.verifiedUser)}
        before = FormatJson(registry.values)
        registry.failOnce = failFlush
        result = commitSystemDefaultProfileSwitch(registry, context, defaultProof, nextAttempt, invalid, "", {})
        if failFlush
            check(not result.ok and FormatJson(registry.values) = before, "system default adoption Flush failure restores exact selected-default state without reviving removed actor")
        else
            check(result.ok and result.scope.profileId = a.id and result.scope.accountId = "7" and result.scope.sessionId = nextAttempt and result.preferences.favoriteIds[0] = "outgoing-only", "completed system retirement can adopt freshly authenticated real default without a fabricated PIN ticket or outgoing scope")
            check(result.store.profiles[0].pinHash = string(64, "e") and result.store.profiles[0].pinLength = 0 and registry.read("connKey_slot-a") = "default-key", "system default bypass neither learns/changes stored PIN nor borrows or replaces the default's own key")
        end if
    end for
    for each change in ["purpose", "receipt", "removed", "active-actor", "runtime-key", "nonce", "root", "context-url", "roster", "key", "key-memory", "authority", "identity", "address"]
        registry = switchRegistryFixture(connection, selected)
        current = loadUserProfileStore(registry, connection.id)
        receipt = {committed: true, needsDefaultSwitch: true, store: current, removed: [b]}
        context = {systemDefaultRetirement: true, nonce: nextAttempt, connection: connection, connectionRoot: registry.read("connectionsV1"), connectionRootPresent: true, store: current, storeRoot: registry.read(userProfileStoreKey(connection.id)), target: current.profiles[0], key: "default-key", retirement: receipt, retirementStoreRoot: FormatJson(current), retiredProfileId: b.id, authorizationSignature: dispatcharrAuthorizationSignature(defaultProof.verifiedUser)}
        actor = invalid
        runtimeKey = ""
        liveNonce = nextAttempt
        proof = copyPreferenceValue(defaultProof)
        memory = {}
        if change = "purpose" then context.systemDefaultRetirement = false
        if change = "receipt" then context.retirement.committed = false
        if change = "removed" then context.retirement.removed = []
        if change = "active-actor" then actor = outgoingB
        if change = "runtime-key" then runtimeKey = "old-key"
        if change = "nonce" then liveNonce = session
        if change = "root" then registry.values["connectionsV1"] = ""
        if change = "context-url"
            context.connection = copyPreferenceValue(connection)
            context.connection.url = "https://foreign.test"
            check(not systemDefaultProfileAccessCurrent(registry, context, liveNonce, actor, runtimeKey, {}), "system default request preflight cannot forward its own key to a URL different from the captured saved connection")
        end if
        if change = "roster" then registry.values[userProfileStoreKey(connection.id)] = "{malformed"
        if change = "key" then registry.values["connKey_slot-a"] = "foreign-key"
        if change = "key-memory"
            registry.values.delete("connKey_slot-a")
            memory["connKey_slot-a"] = "default-key"
        end if
        if change = "authority" then proof.verifiedUser.user_level = 10
        if change = "identity" then proof.verifiedUser.id = 80
        if change = "address" then proof.verifiedBaseUrl = "https://foreign.test"
        before = FormatJson(registry.values)
        result = commitSystemDefaultProfileSwitch(registry, context, proof, liveNonce, actor, runtimeKey, memory)
        check(not result.ok and registry.flushes = 0 and FormatJson(registry.values) = before, "system default adoption refuses changed " + change + " without bypassing actual actor/receipt/proof ownership")
    end for
    ' Startup selection has no outgoing authenticated scope/key. It must never
    ' borrow the unavailable-Child or post-retirement admission wrappers.
    for each change in ["none", "actor", "runtime-key", "nonce", "purpose", "connection-root", "connection-url", "roster-root", "target", "child-source", "child-target", "ask-off", "key", "memory-borrow", "pin", "pin-material"]
        startup = startupSelectionFixture(connection, a, b, nextAttempt)
        registry = startup.registry
        context = startup.context
        actor = invalid
        runtimeKey = ""
        nonce = nextAttempt
        memory = {}
        if change = "actor" then actor = outgoing
        if change = "runtime-key" then runtimeKey = "default-key"
        if change = "nonce" then nonce = session
        if change = "purpose" then context.purpose = "unavailable-child"
        if change = "connection-root" then registry.write("connectionsV1", registry.read("connectionsV1") + " ")
        if change = "connection-url" then context.connection.url = "https://foreign.test"
        if change = "roster-root" then registry.write(userProfileStoreKey("slot-a"), registry.read(userProfileStoreKey("slot-a")) + " ")
        if change = "target" then context.target = context.store.profiles[0]
        if change = "child-source"
            context.store.profiles[0] = setCanonicalPreference(context.store.profiles[0], "role", "child")
            registry.write(userProfileStoreKey("slot-a"), FormatJson(context.store))
            context.storeRoot = registry.read(userProfileStoreKey("slot-a"))
        end if
        if change = "child-target"
            context.store.profiles[1] = setCanonicalPreference(context.store.profiles[1], "role", "child")
            context.target = context.store.profiles[1]
            registry.write(userProfileStoreKey("slot-a"), FormatJson(context.store))
            context.storeRoot = registry.read(userProfileStoreKey("slot-a"))
        end if
        if change = "ask-off"
            context.store = setCanonicalPreference(context.store, "askAtLaunch", false)
            registry.write(userProfileStoreKey("slot-a"), FormatJson(context.store))
            context.storeRoot = registry.read(userProfileStoreKey("slot-a"))
        end if
        if change = "key" then registry.write(userProfileKeyName("slot-a", b.id), "foreign-key")
        if change = "memory-borrow"
            registry.delete(userProfileKeyName("slot-a", b.id))
            memory[userProfileKeyName("slot-a", b.id)] = "bob-own-key"
        end if
        if change = "pin" then context.pin = invalid
        if change = "pin-material" then context.pin.pinHash = string(64, "f")
        before = FormatJson(registry.values)
        allowed = userProfileStartupSelectionCurrent(registry, context, nonce, actor, runtimeKey, memory, true)
        check(allowed = (change = "none"), "startup no-actor preflight independently checks " + change)
        check(registry.flushes = 0 and FormatJson(registry.values) = before, "startup preflight never changes active selection, settings, keys or dirty marks")
    end for
    startup = startupSelectionFixture(connection, a, b, nextAttempt)
    context = startup.context
    context.pin = invalid
    check(userProfileStartupSelectionCurrent(startup.registry, context, nextAttempt, invalid, "", {}, false), "PIN form admission resolves only the target's own key without granting transport")
    for each childReady in [invalid, false, "true", true]
        startup = startupSelectionFixture(connection, a, b, nextAttempt)
        context = startup.context
        context.store.profiles[1] = setCanonicalPreference(context.store.profiles[1], "role", "child")
        context.target = context.store.profiles[1]
        context.childAccessReady = childReady
        startup.registry.write(userProfileStoreKey("slot-a"), FormatJson(context.store))
        context.storeRoot = startup.registry.read(userProfileStoreKey("slot-a"))
        allowed = userProfileStartupSelectionCurrent(startup.registry, context, nextAttempt, invalid, "", {}, true)
        check(allowed = userProfileTrue(childReady), "Child startup admission requires explicit typed private readiness plus its own key and actual PIN")
        if userProfileTrue(childReady)
            context.readNonce = "00000000-0000-4000-8000-000000000097"
            read = {ok: true, state: "ready", profilesState: "ready", verifiedUser: {id: 8, username: "bob", user_level: 1}, verifiedBaseUrl: connection.url, accountId: "8", accountUsername: "bob", data: {categories: {profiles: {data: {rows: [[8, "bob", "Do not apply", "none", "", "", "user", 200, {}, 0]], removed: []}}}}}
            published = commitUserProfileStartupRosterPull(startup.registry, context, read, context.readNonce, true, 200, nextAttempt, invalid, "", {})
            check(published.ok and published.protectionReceipt <> invalid and published.context.target.role = "child" and published.context.target.pinHash = context.target.pinHash and published.context.target.displayName = context.target.displayName, "Child's own early read never applies roster role/name/PIN changes")
            context = published.context
            proof = {ok: true, apiKey: "bob-own-key", verifiedUser: {id: 8, username: "bob", user_level: 1}, verifiedBaseUrl: connection.url, accountId: "8", accountUsername: "bob", channels: [], groups: [], generation: "startup-child-generation"}
            adopted = commitUserProfileStartupSelection(startup.registry, context, proof, nextAttempt, invalid, "", {})
            check(adopted.ok and adopted.scope.profileId = b.id and adopted.store.profiles[1].role = "child" and startup.registry.read("connKey_slot-a") = "default-key", "Child own scope can be adopted without inventing an adult/default authenticated source")
        end if
    end for
    for each change in ["none", "flush", "missing-read", "read-nonce", "read-root", "read-key", "read-pin", "read-authority", "proof-url", "proof-identity", "proof-key", "proof-authority", "actor", "runtime-key", "pin"]
        startup = startupSelectionFixture(connection, a, b, nextAttempt)
        registry = startup.registry
        context = startup.context
        context.readNonce = "00000000-0000-4000-8000-000000000097"
        read = {ok: true, state: "missing", verifiedUser: {id: 8, username: "bob", user_level: 1}, verifiedBaseUrl: connection.url, accountId: "8", accountUsername: "bob"}
        context.protectionReceipt = userProfileStartupProtectionReceipt(context, read, context.readNonce)
        proof = {ok: true, apiKey: "bob-own-key", verifiedUser: {id: 8, username: "bob", user_level: 1}, verifiedBaseUrl: connection.url, accountId: "8", accountUsername: "bob", channels: [], groups: [], generation: "startup-generation"}
        actor = invalid
        runtimeKey = ""
        if change = "flush" then registry.failOnce = true
        if change = "missing-read" then context.protectionReceipt = invalid
        if change = "read-nonce" then context.readNonce = session
        if change = "read-root" then context.protectionReceipt.storeRoot = "different"
        if change = "read-key" then context.protectionReceipt.key = "foreign-key"
        if change = "read-pin" then context.protectionReceipt.target = "old-pin-record"
        if change = "read-authority" then context.protectionReceipt.authorizationSignature = "old-authority"
        if change = "proof-url" then proof.verifiedBaseUrl = "https://foreign.test"
        if change = "proof-identity" then proof.verifiedUser.id = 7
        if change = "proof-key" then proof.apiKey = "default-key"
        if change = "proof-authority" then proof.verifiedUser.user_level = 10
        if change = "actor" then actor = outgoing
        if change = "runtime-key" then runtimeKey = "default-key"
        if change = "pin" then context.pin = invalid
        before = FormatJson(registry.values)
        result = commitUserProfileStartupSelection(registry, context, proof, nextAttempt, actor, runtimeKey, {})
        if change = "none"
            check(result.ok and result.scope.profileId = b.id and result.scope.accountId = "8" and result.scope.sessionId = nextAttempt and result.store.active = b.id, "startup adoption creates only the independently verified target scope")
            check(registry.flushes = 1 and registry.read("connKey_slot-a") = "default-key" and result.preferences.profileSettings.themePreset = "forest" and result.store.pendingRoster, "startup selection/settings/own key use one Flush without borrowing source appearance/key or clearing pending intent")
        else
            check(not result.ok and FormatJson(registry.values) = before, "startup adoption refuses " + change + " with exact prior storage retained")
            if change <> "flush" then check(registry.flushes = 0, "invalid startup receipt never starts a transaction")
        end if
    end for
    for each change in ["failure", "foreign-url", "foreign-user", "foreign-name", "stale-read", "unknown-state", "invalid-profiles", "missing-pin", "changed-pin"]
        startup = startupSelectionFixture(connection, a, b, nextAttempt)
        context = startup.context
        context.readNonce = "00000000-0000-4000-8000-000000000097"
        read = {ok: true, state: "missing", verifiedUser: {id: 8, username: "bob", user_level: 1}, verifiedBaseUrl: connection.url, accountId: "8", accountUsername: "bob"}
        readNonce = context.readNonce
        if change = "failure" then read.ok = false
        if change = "foreign-url" then read.verifiedBaseUrl = "https://foreign.test"
        if change = "foreign-user" then read.verifiedUser.id = 7
        if change = "foreign-name" then read.accountUsername = "another"
        if change = "stale-read" then readNonce = session
        if change = "unknown-state" then read.state = "future"
        if change = "invalid-profiles"
            read.state = "ready"
            read.profilesState = "invalid"
        end if
        if change = "missing-pin" then context.pin = invalid
        if change = "changed-pin" then context.target = setCanonicalPreference(context.target, "pinHash", string(64, "c"))
        check(userProfileStartupProtectionReceipt(context, read, readNonce) = invalid, "startup protection receipt cannot be fabricated from " + change)
    end for
    for each mode in ["pin", "flush", "retire", "actor", "stale-read", "missing-pin", "retire-corrupt"]
        startup = startupSelectionFixture(connection, a, b, nextAttempt)
        context = startup.context
        registry = startup.registry
        context.readNonce = "00000000-0000-4000-8000-000000000097"
        rows = [[8, "bob", "Imported Bob", "numbers", string(64, "c"), string(32, "d"), "user", 200, {}, 0]]
        removed = []
        if mode = "retire" or mode = "retire-corrupt"
            context.store = setCanonicalPreference(context.store, "active", b.id)
            registry.write(userProfileStoreKey("slot-a"), FormatJson(context.store))
            context.storeRoot = registry.read(userProfileStoreKey("slot-a"))
            rows = []
            removed = [["bob", 300, 8]]
        end if
        read = {ok: true, state: "ready", profilesState: "ready", verifiedUser: {id: 8, username: "bob", user_level: 1}, verifiedBaseUrl: connection.url, accountId: "8", accountUsername: "bob", data: {categories: {profiles: {data: {rows: rows, removed: removed}}}}}
        registry.write(userProfilePinBackoffKey("slot-a", b.id), "private-backoff")
        registry.failOnce = mode = "flush"
        actor = invalid
        readNonce = context.readNonce
        if mode = "actor" then actor = outgoing
        if mode = "stale-read" then readNonce = session
        if mode = "missing-pin" then context.pin = invalid
        if mode = "retire-corrupt" then registry.write("settingsV1", "not-json")
        before = FormatJson(registry.values)
        published = commitUserProfileStartupRosterPull(registry, context, read, readNonce, true, 400, nextAttempt, actor, "", {})
        if mode = "flush"
            check(not published.ok and FormatJson(registry.values) = before, "startup fresh protection Flush failure restores exact original roots, keys and settings")
        else if mode = "actor" or mode = "stale-read" or mode = "missing-pin" or mode = "retire-corrupt"
            check(not published.ok and registry.flushes = 0 and FormatJson(registry.values) = before, "startup publication refuses invalid " + mode + " before any write")
        else if mode = "pin"
            check(published.ok and published.store.active = a.id and published.target.pinHash = string(64, "c") and published.requiresPin and published.protectionReceipt = invalid, "startup imported PIN is durable before continuation and cannot mint an old-PIN receipt")
            check(published.store.pendingRoster and registry.read("connKey_slot-a") = "default-key" and registry.read(userProfileKeyName("slot-a", b.id)) = "bob-own-key" and registry.read(userProfilePinBackoffKey("slot-a", b.id)) = "private-backoff", "read publication retains pending source edits, both own keys and target backoff")
        else
            check(published.ok and published.targetRemoved and published.sourceRemoved and published.store.active = a.id and published.protectionReceipt = invalid and published.scope = invalid, "no-runtime startup retirement selects retained default without creating an adoption receipt or fabricated scope")
            check(not registry.exists(userProfileKeyName("slot-a", b.id)) and not registry.exists(userProfilePinBackoffKey("slot-a", b.id)) and registry.read("connKey_slot-a") = "default-key", "actual absent actor permits own retired key/backoff cleanup, never default key deletion")
            prefs = ParseJson(registry.read("settingsV1"))
            check(not prefs.accounts.doesExist(preferenceScope(connectionPreferenceIdentity(connection, "8"))) and prefs.accounts.doesExist(preferenceScope(connectionPreferenceIdentity(connection, "7"))), "startup retirement removes only retired holder's scoped blob")
        end if
    end for
    startup = startupSelectionFixture(connection, a, b, nextAttempt)
    context = startup.context
    registry = startup.registry
    context.store.profiles[1] = setCanonicalPreference(context.store.profiles[1], "pinLength", 4)
    context.target = context.store.profiles[1]
    registry.write(userProfileStoreKey("slot-a"), FormatJson(context.store))
    context.storeRoot = registry.read(userProfileStoreKey("slot-a"))
    context.readNonce = "00000000-0000-4000-8000-000000000097"
    read = {ok: true, state: "missing", verifiedUser: {id: 8, username: "bob", user_level: 1}, verifiedBaseUrl: connection.url, accountId: "8", accountUsername: "bob"}
    published = commitUserProfileStartupRosterPull(registry, context, read, context.readNonce, true, 400, nextAttempt, invalid, "", {})
    check(published.ok and not published.requiresPin and published.protectionReceipt <> invalid, "native same-PIN publication preserves actual verified grant instead of changing its map semantics")
    check(userProfileStartupSelectionCurrent(registry, published.context, nextAttempt, invalid, "", {}, true), "learned-length post-read context retains the same actual PIN admission")
    print "ALL TESTS PASSED"
end sub

function startupSelectionFixture(connection as object, a as object, b as object, nonce as string) as object
    store = defaultUserProfileStore(connection.id)
    source = setCanonicalPreference(copyJson(a), "role", "user")
    target = setCanonicalPreference(copyJson(b), "role", "user")
    target = setCanonicalPreference(target, "pinType", "numbers")
    target = setCanonicalPreference(target, "pinHash", string(64, "a"))
    target = setCanonicalPreference(target, "pinSalt", string(32, "b"))
    target = setCanonicalPreference(target, "addressHeld", false)
    store.profiles = [source, target]
    store.active = source.id
    store = setCanonicalPreference(store, "askAtLaunch", true)
    store = setCanonicalPreference(store, "pendingRoster", true)
    store = normalizeUserProfileStore(store, connection.id)
    registry = switchRegistryFixture(connection, store)
    registry.write(userProfileKeyName(connection.id, target.id), "bob-own-key")
    pin = {slot: connection.id, id: target.id, pinType: target.pinType, pinHash: target.pinHash, pinSalt: target.pinSalt}
    context = {purpose: "startup-picker", nonce: nonce, connection: copyJson(connection), connectionRootPresent: true, connectionRoot: registry.read("connectionsV1"), store: store, storeRoot: registry.read(userProfileStoreKey(connection.id)), target: store.profiles[1], key: "bob-own-key", pin: pin}
    return {registry: registry, context: context}
end function

function switchRegistryFixture(connection as object, store as object) as object
    values = {}
    values["connectionsV1"] = FormatJson({schema: 1, selected: "slot-a", entries: [normalizeConnectionEntry(connection)]})
    values[userProfileStoreKey("slot-a")] = FormatJson(store)
    values["connKey_slot-a"] = "default-key"
    prefs = defaultPreferenceStore()
    prefs.accounts[preferenceScope(connectionPreferenceIdentity(connection, "7"))] = normalizeAccountPreferences({favoriteIds: ["outgoing-only"], profileSettings: {themePreset: "midnight"}})
    prefs.accounts[preferenceScope(connectionPreferenceIdentity(connection, "8"))] = normalizeAccountPreferences({profileSettings: {themePreset: "forest"}})
    values["settingsV1"] = FormatJson(prefs)
    return {values: values, flushes: 0, failOnce: false, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function, write: function(key as string, value as string) as boolean
        m.values[key] = value
        return true
    end function, delete: function(key as string) as boolean
        m.values.delete(key)
        return true
    end function, flush: function() as boolean
        m.flushes++
        if m.failOnce then m.failOnce = false : return false
        return true
    end function}
end function

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
