sub main()
    state = userProfilePinBackoffDefault()
    for i = 1 to 4
        state = userProfilePinBackoffResult(state, false, 100)
        check(state.failures = i and state.until = 0, "first four wrong entries do not lock")
    end for
    state = userProfilePinBackoffResult(state, false, 100)
    check(state.failures = 0 and state.round = 1 and state.until = 130, "fifth wrong entry locks 30 seconds and resets count")
    before = FormatJson(state)
    check(FormatJson(userProfilePinBackoffResult(state, false, 120)) = before, "locked entries do not count")
    for i = 1 to 5
        state = userProfilePinBackoffResult(state, false, 130)
    end for
    check(state.round = 2 and state.until = 190, "next five-failure round doubles lock")
    for round = 3 to 14
        now = state.until
        for i = 1 to 5
            state = userProfilePinBackoffResult(state, false, now)
        end for
    end for
    check(state.round = 11 and state.until - now = 30720, "lock exponent capped at two to ten")
    check(userProfilePinBackoffResult(state, true, state.until).round = 0, "success resets all failure history after lock")
    check(userProfilePinBackoffResult({failures: "bad", round: 0, until: 0}, false, 100) = invalid, "corrupt failure state is recovery, not a reset")
    record = {pinType: "numbers", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    m.digestCalls = 0
    m.pinPolicyDigest = function(salt as string, normalized as string) as string
        m.digestCalls++
        if normalized = "1234" then return string(64, "a")
        return string(64, "c")
    end function
    checked = userProfilePinVerifyAttempt(record, {failures: 0, round: 1, until: 130}, ["1", "2", "3", "4"], 120)
    check(not checked.verified and checked.locked and checked.remaining = 10 and m.digestCalls = 0, "lock checked before digest and even correct input cannot bypass it")
    checked = userProfilePinVerifyAttempt(record, userProfilePinBackoffDefault(), ["1", "2"], 130)
    check(not checked.validInput and checked.state.failures = 0 and m.digestCalls = 0, "invalid length does not submit or count an attempt")
    checked = userProfilePinVerifyAttempt(record, userProfilePinBackoffDefault(), ["9", "9", "9", "9"], 130)
    check(not checked.verified and checked.state.failures = 1 and m.digestCalls = 1, "wrong valid input counts once")
    checked = userProfilePinVerifyAttempt(record, checked.state, ["1", "2", "3", "4"], 131)
    check(checked.verified and checked.state.failures = 0 and checked.state.round = 0, "verified PIN clears holder state")
    adult = {role: "user", pinType: "directions", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    check(userProfileHasExitPin([adult], invalid), "Directions PIN counts as an exit PIN even if public certification is pending")
    adult.role = "child"
    check(not userProfileHasExitPin([adult], invalid), "Child PIN is not adult escape authority")
    check(userProfileHasExitPin([], record), "existing device-local admin PIN can be exit authority")
    registry = {values: {}, flushes: 0, failOnce: false
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
    holder = "00000000-0000-4000-8000-000000000001"
    for i = 1 to 5
        checked = userProfilePinAttemptStored(registry, "slot-a", holder, record, ["9", "9", "9", "9"], 200)
    end for
    check(checked.locked and registry.flushes = 5, "holder lock survives independent stored attempts")
    before = registry.flushes
    checked = userProfilePinAttemptStored(registry, "slot-a", holder, record, ["1", "2", "3", "4"], 210)
    check(checked.locked and registry.flushes = before, "reload during lock neither verifies nor writes")
    checked = userProfilePinAttemptStored(registry, "slot-b", holder, record, ["1", "2", "3", "4"], 210)
    check(checked.verified, "same holder ID in another slot has independent lock state")
    registry.failOnce = true
    checked = userProfilePinAttemptStored(registry, "slot-a", holder, record, ["1", "2", "3", "4"], 230)
    check(not checked.verified and checked.recoveryRequired, "correct PIN cannot unlock before successful failure-state persistence")
    corruptKey = userProfilePinBackoffKey("slot-a", holder)
    registry.values[corruptKey] = "not-json"
    checked = userProfilePinAttemptStored(registry, "slot-a", holder, record, ["1", "2", "3", "4"], 230)
    check(not checked.verified and checked.recoveryRequired, "corrupt stored backoff never silently resets")
    registry.delete(corruptKey)
    profile = userProfileFromVerified("slot-a", holder, {id: 7, username: "alice", user_level: 1}, 1)
    for each field in ["pinType", "pinHash", "pinSalt"]
        profile = setCanonicalPreference(profile, field, record[field])
    end for
    store = defaultUserProfileStore("slot-a")
    store.active = holder
    store.profiles = [profile]
    registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
    checked = userProfilePinAttemptStored(registry, "slot-a", holder, profile, ["1", "2", "3", "4"], 300)
    check(checked.verified and loadUserProfileStore(registry, "slot-a").profiles[0].pinLength = 4, "correct entry persists known dot count with backoff reset in the same transaction")
    changed = setCanonicalPreference(profile, "pinSalt", string(32, "e"))
    check(not userProfilePinAttemptStored(registry, "slot-a", holder, changed, ["1", "2", "3", "4"], 301).verified, "stale dialog PIN material cannot verify against a changed live holder")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
