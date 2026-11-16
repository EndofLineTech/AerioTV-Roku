sub main()
    entry = normalizeConnectionEntry({id: "slot-a", name: "Import", provider: "dispatcharr", url: "https://example.test", accountId: "1", accountUsername: "Alice", remember: true})
    ids = {defaultId: "00000000-0000-4000-8000-000000000001", byUsername: {bob: "00000000-0000-4000-8000-00000000000b", kid: "00000000-0000-4000-8000-00000000000c"}}
    pin = {pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    adult = {username: "Bob", displayName: "Living Room", role: "user", order: 1, id: ucase(ids.byUsername.bob), avatar: {icon: "rocket", color: "purple"}}
    adult.append(pin)
    defaultRow = {username: "Alice", displayName: "Home", role: "user", isDefault: true, order: 0}
    defaultRow.append(pin)
    child = {username: "Kid", displayName: "Kids", role: "child", order: 0, pinType: "none"}
    rows = [child, adult, defaultRow]
    proofs = {}
    for each pair in [["Alice", 1], ["Bob", 2], ["Kid", 3]]
        proofs[lcase(pair[0])] = {ok: true, verifiedBaseUrl: entry.url, apiKey: pair[0] + "-own-key", verifiedUser: {id: pair[1], username: pair[0], user_level: 1}}
    end for
    empty = defaultUserProfileStore(entry.id)
    bootstrap = phoneSetupProfileBatchPlan(entry, empty, [], proofs, ids, 100)
    check(bootstrap.ok and bootstrap.store.profiles[0].updatedAt = 0 and not bootstrap.store.pendingRoster, "ordinary default bootstrap stays unstamped instead of creating a remote roster edit")
    planned = phoneSetupProfileBatchPlan(entry, empty, rows, proofs, ids, 100)
    check(planned.ok and planned.store.profiles.count() = 3 and planned.store.active = ids.defaultId, "handoff creates default and verified chosen users without selecting another holder")
    check(planned.store.profiles[0].username = "Alice" and planned.store.profiles[1].username = "Bob" and planned.store.profiles[2].role = "child", "default then all non-Child then Child, not merely order or input order")
    check(planned.store.profiles[1].id = ids.byUsername.bob and planned.store.profiles[1].avatar.icon = "rocket", "free incoming UUID is lowercased and metadata is applied")
    check(planned.store.profiles[0].pinLength = 0 and planned.store.profiles[1].pinType = "numbers" and planned.store.pendingRoster, "existing valid PIN material imports with unknown length and roster intent")
    check(not planned.keys.doesExist(ids.defaultId) and planned.keys[ids.byUsername.bob] = "Bob-own-key", "profile batch never writes a default-holder key or password")
    existing = planned.store
    repeated = phoneSetupProfileBatchPlan(entry, existing, rows, proofs, ids, 101)
    check(repeated.ok and repeated.store.profiles.count() = 3 and repeated.keys.count() = 0 and repeated.skipped.count() = 2, "existing nondefault usernames skip idempotently instead of replacing their keys")
    unprotected = copyJson(defaultRow)
    unprotected = setCanonicalPreference(unprotected, "pinType", "none")
    unprotected = setCanonicalPreference(unprotected, "pinHash", "")
    unprotected = setCanonicalPreference(unprotected, "pinSalt", "")
    unsafe = phoneSetupProfileBatchPlan(entry, empty, [child, adult, unprotected], proofs, ids, 100)
    check(unsafe.ok and unsafe.store.profiles.count() = 2 and unsafe.skipped.count() = 1, "import-only phase skips unsafe Child instead of inventing a new adult PIN")
    missing = {}
    missing.append(proofs)
    missing.delete("bob")
    partial = phoneSetupProfileBatchPlan(entry, empty, rows, missing, ids, 100)
    check(partial.ok and partial.store.profiles.count() = 2 and partial.keys.doesExist(ids.byUsername.kid), "one missing own proof is skipped while other protected entries finish")
    check(phoneSetupProfileSyncOffer({provider: "dispatcharr", enabled: true}, {enabled: false, declined: false}), "eligible handoff requests a separate explicit sync offer")
    check(not phoneSetupProfileSyncOffer({provider: "dispatcharr", enabled: true}, {enabled: false, declined: true}), "prior decline is honored without auto-enabling sync")
    registry = {values: {}, flushes: 0, read: function(key as string) as string
        if m.values.doesExist(key) then return m.values[key]
        return ""
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
    registry.values["connectionsV1"] = FormatJson({schema: 1, selected: entry.id, entries: [entry]})
    registry.values["connKey_slot-a"] = "default-slot-key"
    registry.values["settingsV1"] = "untouched-private-root"
    nonce = "00000000-0000-4000-8000-000000000090"
    context = {nonce: nonce, connection: entry, connectionRoot: registry.read("connectionsV1"), store: empty, rows: rows, proofs: proofs, ids: ids, deviceAdmin: invalid}
    saved = commitPhoneSetupProfileBatch(registry, context, 100, nonce)
    check(saved.ok and registry.flushes = 1 and registry.read("connKey_slot-a") = "default-slot-key" and registry.read("settingsV1") = "untouched-private-root", "second Flush atomically adds roster/own keys without touching committed slot credential or personal data")
    check(not commitPhoneSetupProfileBatch(registry, context, 101, nonce).ok and registry.flushes = 1, "old batch cannot overwrite a successor roster")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
