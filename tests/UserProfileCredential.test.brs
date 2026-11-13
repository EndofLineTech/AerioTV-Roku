sub main()
    a = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    b = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    b.isDefault = false
    store = defaultUserProfileStore("slot-a")
    store.profiles = [a, b]
    store.active = a.id
    connection = {id: "slot-a", provider: "dispatcharr", remember: true}
    registry = {values: {}, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function}
    registry.values["connKey_slot-a"] = "default-key"
    check(userProfileCredential(registry, connection, defaultUserProfileStore("slot-a"), {}).key = "default-key", "missing-store migration may verify the default slot identity")
    check(userProfileCredential(registry, connection, userProfileStoreRecovery("slot-a"), {}).key = "", "present/corrupt empty metadata cannot borrow migration access")
    check(userProfileCredential(registry, connection, store, {}).key = "default-key", "default owns slot key")
    store.active = b.id
    check(userProfileCredential(registry, connection, store, {}).key = "", "keyless non-default never borrows slot key")
    ownKey = userProfileKeyName("slot-a", b.id)
    registry.values[ownKey] = "bob-key"
    check(userProfileCredential(registry, connection, store, {}).key = "bob-key", "non-default uses only its own namespaced key")
    connection.remember = false
    check(userProfileCredential(registry, connection, store, {}).key = "", "Remember-off ignores all registry credentials")
    memory = {}
    memory[ownKey] = "session-bob-key"
    check(userProfileCredential(registry, connection, store, memory).key = "session-bob-key", "verified in-memory own credential works with Remember off")
    store.profiles[1].addressHeld = true
    check(userProfileCredential(registry, connection, store, memory).reason = "address-held", "held profile refuses even an available own key")
    store.readOnly = true
    check(userProfileCredential(registry, connection, store, memory).reason = "recovery", "corrupt store never resolves a slot fallback")
    store.delete("readOnly")
    store.profiles[1].addressHeld = false
    registry.exists = function(key as string) as boolean
        return m.values.doesExist(key)
    end function
    registry.write = function(key as string, value as string) as boolean
        m.values[key] = value
        return true
    end function
    registry.delete = function(key as string) as boolean
        m.values.delete(key)
        return true
    end function
    registry.flush = function() as boolean
        return true
    end function
    registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
    revoked = revokeUserProfileCredential(registry, connection, loadUserProfileStore(registry, "slot-a"))
    check(revoked.ok and not revoked.isDefault and not registry.exists(ownKey) and registry.read("connKey_slot-a") = "default-key", "refused non-default key deletion cannot touch the default holder")
    check(registry.read(userProfileStoreKey("slot-a")) = FormatJson(store), "credential refusal retains profile identity and protection verbatim")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
