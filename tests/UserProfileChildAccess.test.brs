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
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
