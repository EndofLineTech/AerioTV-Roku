sub main()
    adult = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    child = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Bob", user_level: 1}, 2)
    child = setCanonicalPreference(child, "isDefault", false)
    child = setCanonicalPreference(child, "role", "child")
    store = defaultUserProfileStore("slot-a")
    store.profiles = [adult, child]
    store.active = child.id
    store.askAtLaunch = true
    check(not userProfileStartupGate(store, true).allowed, "shipping Child activation remains fenced until its access controller is qualified")
    check(userProfileStartupGate(store, true, true).allowed, "ready Child uses only its explicit own key and ignores the multi-profile launch picker")
    missing = userProfileStartupGate(store, false, true)
    check(not missing.allowed and missing.reason = "child-key", "ready keyless Child reaches its own unavailable path, never default credentials")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinType", "numbers")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinSalt", string(32, "b"))
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinHash", string(64, "a"))
    check(userProfileStartupGate(store, false, true).reason = "pin", "keyless protected Child still completes launch PIN before its own unavailable controls")
    check(userProfileStartupGate(store, true, true, true).allowed, "own PIN admission and own key can authorize a ready Child, not an adult/default scope")
    check(userProfileStartupGate(store, false, true, true).reason = "child-key", "own PIN admission cannot manufacture a missing credential")
    store.profiles[1] = setCanonicalPreference(store.profiles[1], "addressHeld", true)
    check(userProfileStartupGate(store, true, true, true).reason = "address-held", "even an admitted ready Child never sends its held key")
    single = defaultUserProfileStore("slot-a")
    single.profiles = [setCanonicalPreference(adult, "role", "child")]
    single.active = adult.id
    check(userProfileStartupGate(single, true, true).allowed and userProfileStartupGate(single, false, true).reason = "child-key", "default Child also needs its own explicitly available slot credential")
    adult = setCanonicalPreference(adult, "pinType", "numbers")
    adult = setCanonicalPreference(adult, "pinSalt", string(32, "b"))
    adult = setCanonicalPreference(adult, "pinHash", string(64, "a"))
    single.profiles = [adult]
    check(userProfileStartupGate(single, true, true, true).reason = "pin", "Child readiness/PIN flags never substitute for adult PIN admission")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
