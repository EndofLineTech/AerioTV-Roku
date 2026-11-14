sub main()
    child = {role: "child", isDefault: false, addressHeld: false}
    available = userProfileChildAccessPlan(child, true, false)
    check(available.retry and not available.signIn and available.manage and not available.setup, "available Child may retry only its own key and never general setup")
    missing = userProfileChildAccessPlan(child, false, false)
    check(not missing.retry and missing.signIn and missing.manage, "keyless Child may sign in only as its own saved identity")
    refused = userProfileChildAccessPlan(child, true, true)
    check(not refused.retry and not refused.signIn and refused.manage, "non-default refused Child gets neither requests nor an own-sign-in form")
    check(not userProfileChildAccessPlan(child, false, true).signIn, "deleting a rejected key cannot disguise refusal as keyless onboarding")
    child.isDefault = true
    check(userProfileChildAccessPlan(child, true, true).signIn, "default Child may recover its own refused login without changing account")
    child.isDefault = false
    child.addressHeld = true
    held = userProfileChildAccessPlan(child, true, false)
    check(not held.retry and not held.signIn and held.manage, "held Child stays active and cannot transmit its old key")
    check(userProfileChildAccessPlan(child, false, false).signIn, "held keyless Child still has its own identity-only sign-in route")
    check(not userProfileChildAccessPlan(invalid, true, false).retry, "malformed profile cannot become an unlocked setup decision")
    entry = {id: "slot-a", provider: "dispatcharr", url: "https://example.test", remember: true}
    own = {id: "00000000-0000-4000-8000-000000000002", playlistId: "slot-a", role: "child", isDefault: false, addressHeld: false}
    registry = {values: {}, read: function(key as string) as string
        if not m.values.doesExist(key) then return ""
        return m.values[key]
    end function}
    registry.values["connKey_slot-a"] = "synthetic-default"
    check(not userProfileChildKeyPresent(registry, entry, own, {}), "a nondefault Child's keyless policy never counts the default key")
    keyName = userProfileKeyName(entry.id, own.id)
    registry.values[keyName] = "synthetic-child"
    own.addressHeld = true
    check(userProfileChildKeyPresent(registry, entry, own, {}), "presence is independent of address admission, so a retained held key cannot masquerade as keyless")
    entry.remember = false
    check(not userProfileChildKeyPresent(registry, entry, own, {}), "Remember-off policy ignores any stale persisted credential")
    memory = {}
    memory[keyName] = "synthetic-memory-child"
    check(userProfileChildKeyPresent(registry, entry, own, memory), "an explicitly own-scoped memory credential still counts with Remember off")
    entry.remember = true
    own.isDefault = true
    check(userProfileChildCredentialName(entry, own) = "connKey_slot-a" and userProfileChildKeyPresent(registry, entry, own, {}), "a default Child's own credential is its slot key only")
    check(userProfileChildCredentialName(entry, invalid) = "", "invalid Child credential metadata has no registry name")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
