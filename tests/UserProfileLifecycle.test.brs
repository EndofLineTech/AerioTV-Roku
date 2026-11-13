sub main()
    a = lifeProfile(1, "Alice", true)
    b = lifeProfile(2, "Bob", false)
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    store = normalizeUserProfileStore(store, "slot-a")
    denied = userProfileRemovalPlan(store, a.id, 200, "normal")
    check(not denied.ok and not denied.needsDefaultSwitch, "default cannot be removed")
    removed = userProfileRemovalPlan(store, b.id, 200, "normal")
    check(removed.ok and removed.pushRequired and removed.store.profiles.count() = 1, "plain removal creates a pending tombstone")
    check(removed.store.removed[0][0] = "bob" and removed.store.removed[0][1] = 200 and removed.store.removed[0].count() = 2, "own tombstone is lower username/time without userId")
    for each origin in ["roster", "paused"]
        seeded = copyJson(store)
        seeded.profiles[1] = setCanonicalPreference(seeded.profiles[1], "addOrigin", origin)
        undo = userProfileRemovalPlan(seeded, b.id, 200, "undo")
        check(undo.ok and not undo.pushRequired and undo.store.removed.count() = 0, "roster/paused add undo stays local")
    end for
    held = copyJson(store)
    held.profiles[1] = setCanonicalPreference(held.profiles[1], "addressHeld", true)
    check(not userProfileRemovalPlan(held, b.id, 200, "normal").pushRequired, "held removal never writes a tombstone")
    active = copyJson(store)
    active.active = b.id
    denied = userProfileRemovalPlan(active, b.id, 200, "pull")
    check(not denied.ok and denied.needsDefaultSwitch, "active target requires staged default switch before key/data removal")
    check(not userProfileRemovalPlan(store, b.id, 0, "normal").ok, "plain removal requires a real timestamp")
    check(userProfileRemovalPlan(store, b.id, 200, "pull").store.removed.count() = 0, "pulled tombstone cleanup does not manufacture another deletion")
    union = userProfileTombstones([["Bob", 200], ["stale", 1]], [["bob", 201, 9], ["other", 202]], 7776100)
    check(union.count() = 2 and union[0][0] = "bob" and union[0][1] = 201 and union[0][2] = 9, "tombstone union keeps newest and optional existing userId, expires ninety days")
    check(userProfileTombstoneRemoves([["bob", 200]], b), "tombstone at or above row stamp wins")
    b.updatedAt = 201
    check(not userProfileTombstoneRemoves([["bob", 200]], b), "intentional newer re-add wins")
    check(not userProfileTombstoneRemoves([["alice", 200]], a), "default is never tombstoned locally")
    check(userProfileStartupGate(store).allowed, "unprotected default retains normal single-user startup")
    active.profiles[1].role = "child"
    check(not userProfileStartupGate(active).allowed, "Child never falls back to default during interim integration")
    locked = copyJson(store)
    locked.profiles[0] = setCanonicalPreference(locked.profiles[0], "pinType", "numbers")
    locked.profiles[0] = setCanonicalPreference(locked.profiles[0], "pinHash", string(64, "a"))
    locked.profiles[0] = setCanonicalPreference(locked.profiles[0], "pinSalt", string(32, "b"))
    check(not userProfileStartupGate(locked).allowed, "protected default never connects before gate is delivered")
    check(not userProfileStartupGate(userProfileStoreRecovery("slot-a")).allowed, "corrupt roster never connects")
    invalidDefaultHold = copyJson(store)
    invalidDefaultHold.profiles[0] = setCanonicalPreference(invalidDefaultHold.profiles[0], "addressHeld", true)
    check(not userProfileStartupGate(invalidDefaultHold).allowed, "impossible default hold cannot silently bypass recovery")
    print "ALL TESTS PASSED"
end sub

function lifeProfile(n as integer, username as string, isDefault as boolean) as object
    profile = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-00000000000" + n.toStr(), {id: n, username: username, user_level: 1}, 100)
    profile.isDefault = isDefault
    return profile
end function

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
