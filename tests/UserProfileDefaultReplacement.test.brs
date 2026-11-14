sub main()
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 10)
    a.displayName = "Old private label"
    a.displayNameClaimed = true
    a.avatar = {icon: "star", color: "teal"}
    a.avatarClaimed = true
    a.order = 2
    a.updatedAt = 99
    a.pinType = "numbers"
    a.pinHash = string(64, "a")
    a.pinSalt = string(32, "b")
    a.pinLength = 4
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 10)
    b.isDefault = false
    b.addressHeld = true
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    store = setCanonicalPreference(store, "knownDefault", {userId: 7, username: "Alice"})
    store = setCanonicalPreference(store, "addressChangeSnapshot", {userId: 7, username: "Alice"})
    original = FormatJson(store)
    verified = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000009", {id: 70, username: "NewAlice", user_level: 1}, 100)
    verified.displayName = "Unrelated label"
    verified.avatar = {icon: "star", color: "teal"}
    verified.order = 5
    check(userProfileEnsureDefault(store, verified) = invalid, "ordinary ensure-default callers still refuse identity replacement unless the slot verification explicitly authorizes it")
    replaced = userProfileEnsureDefault(store, verified, true)
    check(replaced <> invalid and replaced.profiles[0].id = a.id and replaced.active = a.id, "explicit verified slot replacement retains the local default UUID and active selection")
    target = replaced.profiles[0]
    check(target.userId = 70 and target.username = "NewAlice" and target.displayName = "NewAlice", "replacement rebuilds authoritative identity and default label from the new verified account")
    check(target.order = -1 and target.updatedAt = 0 and target.avatar.count() = 0 and not target.displayNameClaimed and not target.avatarClaimed, "new default clears old avatar, ordering, claims and wire stamp without removing its local record")
    check(target.pinHash = a.pinHash and target.pinSalt = a.pinSalt and target.pinType = a.pinType and target.pinLength = 4, "replacement preserves the exact existing local PIN and learned length without creating new salt")
    check(replaced.removed.count() = 0 and replaced.profiles[1].addressHeld and replaced["knownDefault"]["userId"] = 7 and replaced["addressChangeSnapshot"]["userId"] = 7, "replacement emits no tombstone and cannot rewrite another holder's hold or frozen identity")
    check(FormatJson(store) = original, "replacement never mutates the caller's old identity or roster")
    child = copyJson(store)
    child.profiles[0] = setCanonicalPreference(child.profiles[0], "role", "child")
    replaced = userProfileEnsureDefault(child, verified, true)
    check(replaced <> invalid and replaced.profiles[0].role = "child" and replaced.profiles[0].pinHash = a.pinHash, "a rebuilt non-admin default retains Child restriction and its exit protection")
    admin = userProfileFromVerified("slot-a", verified.id, {id: 70, username: "NewAlice", user_level: 10}, 100)
    check(userProfileEnsureDefault(child, admin, true).profiles[0].role = "admin", "verified server admin authority resolves the rebuilt Child default to Admin")
    duplicate = userProfileFromVerified("slot-a", verified.id, {id: 8, username: "Bob", user_level: 1}, 100)
    check(userProfileEnsureDefault(store, duplicate, true) = invalid, "replacement cannot silently take another local profile's identity or data")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
