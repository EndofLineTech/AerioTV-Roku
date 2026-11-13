sub main()
    child = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "child", user_level: 1}, 1)
    child.role = "child"
    adult = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "adult", user_level: 1}, 1)
    adult.isDefault = false
    adult.pinType = "numbers"
    adult.pinHash = string(64, "a")
    adult.pinSalt = string(32, "b")
    store = defaultUserProfileStore("slot-a")
    store.active = child.id
    store.profiles = [child, adult]
    nonce = "00000000-0000-4000-8000-000000000090"
    grant = {slot: "slot-a", active: child.id, nonce: nonce, purpose: "manage-profiles", kind: "pin", id: adult.id, pinType: adult.pinType, pinHash: adult.pinHash, pinSalt: adult.pinSalt}
    check(not userProfileManagementGrantMatches(store, invalid, invalid, nonce), "Child cannot manage or expose other identities without adult authority")
    check(userProfileManagementGrantMatches(store, invalid, grant, nonce), "fresh adult material authorizes only the current Child management context")
    check(not userProfileManagementGrantMatches(store, invalid, grant, "00000000-0000-4000-8000-000000000091"), "returning A/B/A cannot revive an old management grant")
    for each field in ["slot", "active", "purpose", "id", "pinSalt"]
        changed = copyJson(grant)
        changed = setCanonicalPreference(changed, field, "different")
        check(not userProfileManagementGrantMatches(store, invalid, changed, nonce), "changed scope/purpose/holder/PIN material refuses management")
    end for
    check(userProfileMayEditMetadata(store, child.id, "avatar", invalid, invalid, nonce), "Child may edit only its own avatar without an adult gate")
    check(not userProfileMayEditMetadata(store, adult.id, "avatar", invalid, invalid, nonce), "Child cannot edit another profile's avatar")
    check(not userProfileMayEditMetadata(store, child.id, "name", invalid, invalid, nonce), "Child cannot rename even its own record without adult authority")
    check(userProfileMayEditMetadata(store, adult.id, "name", invalid, grant, nonce), "verified adult gate may manage another profile's local metadata")
    check(not userProfileMayEditMetadata(store, adult.id, "reset-pin", invalid, grant, nonce), "metadata authority never enables salt-requiring PIN creation or reset")
    store.active = adult.id
    check(userProfileManagementGrantMatches(store, invalid, invalid, ""), "Standard already has full local management rights, not server-admin authority")
    check(not userProfileMayEditMetadata(store, child.id, "role", invalid, invalid, nonce), "role changes still require an adult PIN when any exists, even for Standard")
    check(not userProfileMayEditMetadata(store, child.id, "remove", invalid, invalid, nonce), "removing a Child cannot skip the protected adult gate")
    store.active = child.id
    fallback = {slot: "slot-a", active: child.id, nonce: nonce, purpose: "manage-profiles", kind: "stranded"}
    check(not userProfileManagementGrantMatches(store, invalid, fallback, nonce), "stranded fallback cannot ignore an existing numeric adult PIN")
    store.profiles[1].pinType = "directions"
    check(not userProfileManagementGrantMatches(store, invalid, fallback, nonce), "uncertified Directions still prevents no-PIN fallback")
    store.profiles[1].pinType = "none"
    store.profiles[1].pinHash = ""
    store.profiles[1].pinSalt = ""
    check(userProfileManagementGrantMatches(store, invalid, fallback, nonce), "explicit current-context fallback is available only when no exit PIN exists at all")
    admin = {pinType: "directions", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    check(not userProfileManagementGrantMatches(store, admin, fallback, nonce), "existing Device Admin PIN also prevents stranded fallback")
    grant.id = "device-admin"
    grant.pinType = "directions"
    check(userProfileManagementGrantMatches(store, admin, grant, nonce), "existing Device Admin material may authorize Child management")
    store.readOnly = true
    check(not userProfileManagementGrantMatches(store, admin, grant, nonce), "recovery state cannot inherit an old management grant")
    store = managementPolicyStoreFixture()
    child = store.profiles[0]
    adult = store.profiles[1]
    grant = {slot: "slot-a", active: child.id, nonce: nonce, purpose: "manage-profiles", kind: "pin", id: adult.id, pinType: adult.pinType, pinHash: adult.pinHash, pinSalt: adult.pinSalt}
    before = FormatJson(store)
    renamed = userProfileMetadataEditPlan(store, adult.id, "name", string(50, "A"), invalid, grant, nonce, 100)
    check(renamed.ok and renamed.store.profiles[1].displayName = string(40, "A") and renamed.store.profiles[1].displayNameClaimed and renamed.store.profiles[1].updatedAt = 100 and renamed.store.pendingRoster, "real rename is bounded, claimed and stamped for a later permitted roster write")
    check(FormatJson(store) = before and renamed.store.profiles[1].pinHash = adult.pinHash, "metadata plans never mutate the input or another protection field")
    avatarPlan = userProfileMetadataEditPlan(store, child.id, "avatar", {icon: "paw", color: "green"}, invalid, invalid, nonce, 101)
    check(avatarPlan.ok and avatarPlan.store.profiles[0].avatar.icon = "paw" and avatarPlan.store.profiles[0].avatarClaimed and avatarPlan.store.profiles[0].updatedAt = 101, "Child own-avatar edit is scoped and stamped without adult disclosure")
    noChild = userProfileMetadataEditPlan(store, child.id, "role", "user", invalid, grant, nonce, 102)
    check(noChild.ok and noChild.store.profiles[0].role = "user", "removing the final Child does not require creating a new PIN")
    kidOnly = userProfileMetadataEditPlan(store, adult.id, "role", "child", invalid, grant, nonce, 103)
    check(not kidOnly.ok and kidOnly.reason = "exit-pin-required", "import-only role changes cannot create a stranded kid-only device")
    existingAdmin = {pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    check(userProfileMetadataEditPlan(store, adult.id, "role", "child", existingAdmin, grant, nonce, 103).ok, "an already-existing Device Admin PIN can preserve the exit path without new salt")
    moved = userProfileMetadataEditPlan(store, adult.id, "order", 0, invalid, grant, nonce, 104)
    check(moved.ok and moved.store.profiles[0].id = adult.id and moved.store.profiles[0].updatedAt = 104, "authorized reorder uses deterministic stored positions and edit stamps")
    registry = managementPolicyRegistry(store)
    connection = {id: "slot-a", provider: "dispatcharr", remember: true}
    saved = commitUserProfileMetadataEdit(registry, connection, store, adult.id, "name", "Renamed", grant, nonce, nonce, 105)
    check(saved.ok and registry.flushes = 1 and loadUserProfileStore(registry, "slot-a").profiles[1].displayName = "Renamed", "metadata save rechecks authorization and commits one roster Flush")
    registry = managementPolicyRegistry(store)
    check(not commitUserProfileMetadataEdit(registry, connection, store, adult.id, "name", "Stale", grant, nonce, "00000000-0000-4000-8000-000000000091", 106).ok and registry.flushes = 0, "stale local management lifecycle refuses before any registry write")
    registry.failOnce = true
    saved = commitUserProfileMetadataEdit(registry, connection, store, adult.id, "name", "Failed", grant, nonce, nonce, 107)
    check(not saved.ok and registry.read(userProfileStoreKey("slot-a")) = FormatJson(store), "failed metadata Flush restores exact previous protection and names")
    print "ALL TESTS PASSED"
end sub

function managementPolicyStoreFixture() as object
    child = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "child", user_level: 1}, 1)
    child.role = "child"
    adult = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "adult", user_level: 1}, 1)
    adult.isDefault = false
    adult.pinType = "numbers"
    adult.pinHash = string(64, "a")
    adult.pinSalt = string(32, "b")
    store = defaultUserProfileStore("slot-a")
    store.active = child.id
    store.profiles = [child, adult]
    return normalizeUserProfileStore(store, "slot-a")
end function

function managementPolicyRegistry(store as object) as object
    values = {}
    values[userProfileStoreKey(store.playlistId)] = FormatJson(store)
    return {values: values, flushes: 0, failOnce: false
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            m.flushes++
            if m.failOnce
                m.failOnce = false
                return false
            end if
            return true
        end function
    }
end function

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
