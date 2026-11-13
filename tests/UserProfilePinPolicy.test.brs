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
    adultB = {id: "00000000-0000-4000-8000-000000000002", role: "user", pinType: "directions", pinHash: string(64, "a"), pinSalt: string(32, "b")}
    adultPins = userProfileAdultPinHolders([profile, adultB], invalid)
    check(adultPins.count() = 2, "adult gate counts numeric and Directions holders without disclosing names")
    states = {}
    states[holder] = {failures: 0, round: 1, until: 430}
    planned = userProfileAdultPinPlan(adultPins, states, ["1", "2", "3", "4"], "numbers", 400)
    check(not planned.locked and planned.typeLocked and planned.remaining = 30 and planned.writes.count() = 0, "numeric lock is not an all-holder lock while a Directions holder is unlocked")
    states[adultB.id] = {failures: 0, round: 1, until: 420}
    callsBefore = m.digestCalls
    planned = userProfileAdultPinPlan(adultPins, states, ["1", "2", "3", "4"], "numbers", 400)
    check(planned.locked and planned.remaining = 20 and m.digestCalls = callsBefore, "all-holder lock uses first expiry and never digests")
    planned = userProfileAdultPinPlan(adultPins, {}, ["1", "2", "3", "4"], "numbers", 500)
    check(planned.verified and planned.holder = holder and planned.writes.count() = 1, "valid adult PIN resets only its matching holder")
    check(userProfileAdultPinPlan([], {}, [], "numbers", 500).noPins, "stranded-Child fallback is distinct from wrong or locked PINs")
    deviceHolders = userProfileAdultPinHolders([{id: "child", role: "child", pinType: "numbers", pinHash: record.pinHash, pinSalt: record.pinSalt}], record)
    check(deviceHolders.count() = 1 and deviceHolders[0].id = "device-admin", "Device Admin is reserved per-slot authority and Child PINs do not count")
    check(userProfileAdultPinPlan(deviceHolders, {}, ["1", "2", "3", "4"], "numbers", 500).holder = "device-admin", "existing Device Admin PIN satisfies the same adult verification policy")
    states = {}
    states[holder] = {failures: 4, round: 0, until: 0}
    planned = userProfileAdultPinPlan(adultPins, states, ["9", "9", "9", "9"], "numbers", 500)
    check(not planned.locked and planned.typeLocked and planned.writes[holder].until = 530 and not planned.writes.doesExist(adultB.id), "wrong numeric attempt counts only numeric holders, never an untried Directions PIN")
    badState = {}
    badState[holder] = {failures: "bad", round: 0, until: 0}
    planned = userProfileAdultPinPlan(adultPins, badState, ["1", "2", "3", "4"], "numbers", 500)
    check(planned.recoveryRequired and not planned.noPins and planned.writes.count() = 0, "corrupt adult holder state cannot trigger stranded-Child fallback")
    malformedAdult = {id: holder, role: "user", pinType: "numbers", pinHash: "bad", pinSalt: "bad"}
    check(userProfileAdultPinPlan(userProfileAdultPinHolders([malformedAdult], invalid), {}, [], "numbers", 500).recoveryRequired, "malformed present adult protection is not treated as absent")
    capturedStore = loadUserProfileStore(registry, "slot-a")
    adultChecked = userProfileAdultPinAttemptStored(registry, "slot-a", capturedStore, invalid, ["1", "2", "3", "4"], "numbers", 600)
    check(adultChecked.verified and adultChecked.holder = holder, "adult gate persists matching own holder reset before granting")
    registry.failOnce = true
    adultChecked = userProfileAdultPinAttemptStored(registry, "slot-a", loadUserProfileStore(registry, "slot-a"), invalid, ["1", "2", "3", "4"], "numbers", 601)
    check(not adultChecked.verified and adultChecked.recoveryRequired, "adult gate cannot grant on a failed shared transaction")
    adminKey = userProfileDeviceAdminKey("slot-a")
    registry.write(adminKey, FormatJson(record))
    admin = userProfileLoadDeviceAdminPin(registry, "slot-a")
    check(admin.ok and admin.record.pinLength = 0, "existing Device Admin record loads locally with unknown length")
    capturedStore = loadUserProfileStore(registry, "slot-a")
    capturedStore.profiles[0] = setCanonicalPreference(capturedStore.profiles[0], "pinHash", string(64, "c"))
    registry.write(userProfileStoreKey("slot-a"), FormatJson(capturedStore))
    adultChecked = userProfileAdultPinAttemptStored(registry, "slot-a", capturedStore, admin.record, ["1", "2", "3", "4"], "numbers", 602)
    check(adultChecked.verified and adultChecked.holder = "device-admin" and userProfileLoadDeviceAdminPin(registry, "slot-a").record.pinLength = 4, "Device Admin success learns its own length without altering a profile PIN")
    registry.write(adminKey, "not-json")
    check(userProfileAdultPinAttemptStored(registry, "slot-a", capturedStore, admin.record, [], "numbers", 603).recoveryRequired, "corrupt present Device Admin record never becomes no-PIN fallback")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
