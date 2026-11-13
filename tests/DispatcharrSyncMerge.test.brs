sub main()
    store = syncMergeFixture()
    source = FormatJson(store)
    data = dispatcharrSyncRosterDecode({rows: [[7, "ALICE", "Alice remote", "numbers", string(64, "a"), string(32, "b"), "child", 200, {icon: "paw"}, 1], [8, "bob", "Bob remote", "none", "", "", "user", 50, {}, 0], [9, "new", "New", "none", "", "", "user", 100]]})
    plan = dispatcharrSyncRosterMerge(store, data, true, 300)
    check(plan.ok and plan.applied and plan.store.profiles.count() = 2 and plan.suggestions.count() = 1, "pull merges existing profiles and offers, never automatically adds, unknown user")
    alice = plan.store.profiles[0]
    check(alice.displayName = "Alice remote" and alice.role = "child" and alice.updatedAt = 200 and alice.order = 1 and alice.pinType = "numbers", "newer same-username row adopts PIN role order and exact remote stamp")
    check(plan.store.profiles[1].updatedAt = 100 and plan.store.profiles[1].displayName = "Bob remote", "older row cannot overwrite stamp but unclaimed name/avatar may be adopted")
    check(plan.store.pendingRoster and FormatJson(store) = source, "pending local edits and original store survive planning")
    clean = syncMergeFixture()
    clean.pendingRoster = false
    cleanPull = dispatcharrSyncRosterMerge(clean, data, true, 200)
    check(not cleanPull.store.pendingRoster, "importing a remote stamp equal to now is not a new local edit")
    store.profiles[0].userLevel = 10
    store.profiles[0].role = "admin"
    check(dispatcharrSyncRosterMerge(store, data, true, 300).store.profiles[0].role = "admin", "remote Child cannot demote verified server admin authority")
    store = syncMergeFixture()
    store.profiles[0].pinType = "numbers"
    store.profiles[0].pinHash = string(64, "c")
    store.profiles[0].pinSalt = string(32, "d")
    malformedPin = dispatcharrSyncRosterDecode({rows: [[7, "alice", "", "numbers", "bad", "bad", "user", 200]]})
    check(dispatcharrSyncRosterMerge(store, malformedPin, true, 300).store.profiles[0].pinHash = string(64, "c"), "malformed newer PIN never removes existing protection")
    store = syncMergeFixture()
    store.profiles[0].displayName = "Claimed"
    store.profiles[0].displayNameClaimed = true
    store.profiles[0].avatar = {icon: "star"}
    store.profiles[0].avatarClaimed = true
    check(dispatcharrSyncRosterMerge(store, dispatcharrSyncRosterDecode({rows: [[7, "alice", "Remote older", "none", "", "", "user", 50, {icon: "paw"}]]}), true, 300).store.profiles[0].displayName = "Claimed", "older row cannot overwrite explicitly claimed name")
    stripped = dispatcharrSyncRosterDecode({rows: [[7, "alice", "alice", "none", "", "", "user", 200, {}]]})
    store.pendingRoster = false
    repaired = dispatcharrSyncRosterMerge(store, stripped, true, 300)
    check(repaired.store.profiles[0].displayName = "Claimed" and repaired.store.profiles[0].updatedAt = 300 and repaired.store.pendingRoster, "recently stripped remote row repaired without losing local metadata")
    store = syncMergeFixture()
    store.profiles[0].updatedAt = 300
    olderRich = dispatcharrSyncRosterDecode({rows: [[7, "alice", "Rich name", "directions", string(64, "a"), string(32, "b"), "child", 200, {icon: "paw"}, 0]]})
    merged = dispatcharrSyncRosterMerge(store, olderRich, true, 400)
    check(merged.store.profiles[0].updatedAt = 200 and merged.store.profiles[0].pinType = "directions", "stripped local row takes rich remote row in full even when lowering stamp")
    store = syncMergeFixture()
    removed = dispatcharrSyncRosterDecode({rows: [], removed: [["alice", 500], ["bob", 500]]})
    plan = dispatcharrSyncRosterMerge(store, removed, true, 600)
    check(plan.store.profiles.count() = 1 and plan.store.profiles[0].isDefault and plan.removed.count() = 1 and not plan.needsDefaultSwitch, "tombstones remove eligible nondefault only without creating new tombstone")
    store.active = store.profiles[1].id
    plan = dispatcharrSyncRosterMerge(store, removed, true, 600)
    check(plan.needsDefaultSwitch and plan.store.active = store.profiles[0].id, "active removal requires authenticated default retirement before commit")
    store = syncMergeFixture()
    store.profiles[1].addressHeld = true
    plan = dispatcharrSyncRosterMerge(store, removed, true, 600)
    check(not plan.applied and plan.removed.count() = 0 and plan.suggestions.count() = 0, "any held profile pauses rows tombstones and suggestions")
    store = syncMergeFixture()
    store.profiles[1].addOrigin = "paused"
    plan = dispatcharrSyncRosterMerge(store, data, true, 300)
    check(plan.store.profiles[1].addOrigin = "roster" and plan.store.profiles[1].updatedAt = 50, "first applying pull settles paused add from its roster row")
    pausedStripped = dispatcharrSyncRosterDecode({rows: [[8, "bob", "bob", "none", "", "", "user", 200, {}]]})
    plan = dispatcharrSyncRosterMerge(store, pausedStripped, true, 300)
    check(plan.store.profiles[1].addOrigin = "roster" and plan.store.profiles[1].updatedAt = 200, "stripped repair cannot indefinitely postpone paused-add settlement")
    plan = dispatcharrSyncRosterMerge(store, dispatcharrSyncRosterDecode({rows: []}), true, 300)
    check(plan.store.profiles[1].addOrigin = "plain", "paused add without row becomes plain only after actual applying pull")
    check(not dispatcharrSyncRosterMerge(store, data, false, 300).applied, "Profiles-Off never applies")
    print "ALL TESTS PASSED"
end sub

function syncMergeFixture() as object
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    b.isDefault = false
    b.displayName = "Bob local"
    b.avatar = {icon: "star"}
    a.updatedAt = 100
    b.updatedAt = 100
    store = defaultUserProfileStore("slot-a")
    store.active = a.id
    store.profiles = [a, b]
    store.pendingRoster = true
    return store
end function

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
