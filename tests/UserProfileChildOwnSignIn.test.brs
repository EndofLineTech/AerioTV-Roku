sub main()
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 2)
    b = setCanonicalPreference(b, "isDefault", false)
    b = setCanonicalPreference(b, "role", "child")
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = b.id
    entry = normalizeConnectionEntry({id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "https://example.test", accountId: "7", accountUsername: "Alice", remember: true})
    own = {ok: true, apiKey: "synthetic-new-child", verifiedBaseUrl: entry.url, verifiedUser: {id: 88, username: "BOB", user_level: 1}}
    plan = userProfileOwnSignInPlan(entry, store, b.id, own, 100, true)
    check(plan.ok and plan.target.userId = 88 and plan.target.role = "child" and plan.store.active = b.id and plan.store.profiles[0].userId = 7, "active Child own login can recover a recreated own username without becoming the default or an adult")
    held = copyJson(store)
    held.profiles[1] = setCanonicalPreference(held.profiles[1], "addressHeld", true)
    plan = userProfileOwnSignInPlan(entry, held, b.id, own, 100, true)
    check(plan.ok and not plan.target.addressHeld and plan.target.role = "child", "admitted held-keyless Child own credentials lift only its own hold")
    stale = setCanonicalPreference(own, "verifiedBaseUrl", "https://old.test")
    check(not userProfileOwnSignInPlan(entry, held, b.id, stale, 100, true).ok, "Child own login must verify at the exact current address before recovering its data/key")
    noncanonical = setCanonicalPreference(own, "verifiedBaseUrl", entry.url + " ")
    check(not userProfileOwnSignInPlan(entry, store, b.id, noncanonical, 100, true).ok, "Child credential proof must carry the exact captured normalized URL, not a repaired or trimmed address")
    defaultStore = copyJson(store)
    defaultStore.profiles[0] = setCanonicalPreference(defaultStore.profiles[0], "role", "child")
    defaultStore.profiles[1] = setCanonicalPreference(defaultStore.profiles[1], "role", "user")
    defaultStore.active = a.id
    defaultOwn = {ok: true, apiKey: "synthetic-default-child", verifiedBaseUrl: entry.url, verifiedUser: {id: 7, username: "ALICE", user_level: 1}}
    check(not userProfileOwnSignInPlan(entry, defaultStore, a.id, defaultOwn, 100).ok, "ordinary default recovery remains fenced without explicit active-Child routing")
    plan = userProfileOwnSignInPlan(entry, defaultStore, a.id, defaultOwn, 100, true)
    check(plan.ok and plan.target.isDefault and plan.target.role = "child" and plan.target.id = a.id and plan.store.active = a.id, "default Child recovers only its existing own account while retaining Child role and local identity")
    wrong = copyJson(defaultOwn)
    wrong.verifiedUser.id = 77
    check(not userProfileOwnSignInPlan(entry, defaultStore, a.id, wrong, 100, true).ok, "same-name recreated default Child account cannot use identity replacement through its own form")
    wrong = copyJson(defaultOwn)
    wrong.verifiedUser.username = "OtherAlice"
    check(not userProfileOwnSignInPlan(entry, defaultStore, a.id, wrong, 100, true).ok, "a default Child can never sign in as another username")
    inactive = setCanonicalPreference(defaultStore, "active", b.id)
    check(not userProfileOwnSignInPlan(entry, inactive, a.id, defaultOwn, 100, true).ok, "active-Child recovery is not an inactive-target bypass")
    adult = copyJson(defaultStore)
    adult.profiles[0] = setCanonicalPreference(adult.profiles[0], "role", "user")
    check(not userProfileOwnSignInPlan(entry, adult, a.id, defaultOwn, 100, true).ok, "Child recovery mode cannot enable active-adult default replacement")
    nonce = "00000000-0000-4000-8000-000000000090"
    defaultStore.profiles[1] = setCanonicalPreference(defaultStore.profiles[1], "pinType", "numbers")
    defaultStore.profiles[1] = setCanonicalPreference(defaultStore.profiles[1], "pinSalt", string(32, "b"))
    defaultStore.profiles[1] = setCanonicalPreference(defaultStore.profiles[1], "pinHash", string(64, "a"))
    for each remember in [true, false]
        for each failure in [false, true]
            connection = setCanonicalPreference(entry, "remember", remember)
            registry = childOwnRegistry(connection, defaultStore)
            before = FormatJson(registry.values)
            registry.failOnce = failure
            saved = commitUserProfileOwnSignIn(registry, connection, defaultStore, a.id, defaultOwn, 100, nonce, nonce, true)
            if failure
                check(not saved.ok and not saved.recoveryRequired and FormatJson(registry.values) = before, "failed default Child own login restores exact roster, credentials and absent settings")
            else
                check(saved.ok and saved.store.active = a.id and saved.target.role = "child" and not registry.exists("settingsV1"), "default Child credential transaction retains its role/selection without inventing preferences or an authenticated scope")
                if remember
                    check(registry.read("connKey_slot-a") = defaultOwn.apiKey and not registry.exists(userProfileKeyName("slot-a", a.id)), "default Child saves only its own slot key, never a nondefault credential bucket")
                else
                    check(not registry.exists("connKey_slot-a") and not registry.exists(userProfileKeyName("slot-a", b.id)), "Remember-off Child own recovery keeps every same-slot credential session-only")
                end if
                check(registry.read("connKey_slot-b") = "synthetic-foreign-slot" and registry.flushes = 1, "Child recovery commits in one Flush and never touches another slot's credential")
            end if
        end for
    end for
    print "ALL TESTS PASSED"
end sub

function childOwnRegistry(connection as object, store as object) as object
    values = {connectionsV1: FormatJson({schema: 1, selected: connection.id, entries: [connection]})}
    values[userProfileStoreKey(connection.id)] = FormatJson(store)
    values[connectionRegistryKey(connection.id)] = "synthetic-old-child-key"
    values[userProfileKeyName(connection.id, store.profiles[1].id)] = "synthetic-other-profile"
    values["connKey_slot-b"] = "synthetic-foreign-slot"
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
