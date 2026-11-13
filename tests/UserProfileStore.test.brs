sub main()
    empty = defaultUserProfileStore("slot-a")
    profile = storeFixtureProfile(1)
    staged = userProfileEnsureDefault(empty, profile)
    check(staged <> invalid, "verified default candidate normalizes on native Roku")
    if staged = invalid
        print "[profile-probe] store-diagnostic default-type="; type(profile.isDefault); " dynamic-default-type="; type(profile["isDefault"]); " level-type="; type(profile.userLevel); " dynamic-level-type="; type(profile["userLevel"])
        return
    end if
    check(staged.profiles.count() = 1 and staged.active = profile.id, "first verified default becomes active")
    check(staged.profiles[0].updatedAt = 0, "migration does not stamp a roster edit")
    secondDefault = storeFixtureProfile(2)
    secondDefault.userId = profile.userId
    check(formatJson(userProfileEnsureDefault(staged, secondDefault)) = formatJson(staged), "repeated migration preserves original stable ID and default metadata")
    for each raw in [invalid, [], {}, {schema: 2}, {schema: "1"}, {schema: true}, {schema: 1, playlistId: 7}, {schema: 1, playlistId: "slot-a", profiles: []}]
        check(normalizeUserProfileStore(raw, "slot-a").readOnly, "malformed/present stores never become empty migration input")
    end for
    for each field in ["id", "username", "isDefault", "pinHash", "role", "userLevel"]
        bad = copyJson(staged)
        if field = "id"
            bad.profiles[0].id = "../bad"
        else if field = "username"
            bad.profiles[0].username = ""
        else if field = "isDefault"
            bad.profiles[0] = setCanonicalPreference(bad.profiles[0], "isDefault", false)
        else if field = "pinHash"
            bad.profiles[0] = setCanonicalPreference(bad.profiles[0], "pinType", "numbers")
            bad.profiles[0] = setCanonicalPreference(bad.profiles[0], "pinHash", "broken")
        else if field = "role"
            bad.profiles[0].role = "future"
        else
            bad.profiles[0] = setCanonicalPreference(bad.profiles[0], "userLevel", "10")
        end if
        check(normalizeUserProfileStore(bad, "slot-a").readOnly, "bad identity/authority/PIN/default does not downgrade protection")
    end for
    candidate = copyJson(staged)
    child = storeFixtureProfile(2)
    child.isDefault = false
    child.username = "child"
    child.role = "child"
    candidate.profiles.push(child)
    check(normalizeUserProfileStore(candidate, "slot-a").readOnly <> true, "valid Child metadata retained without granting access")
    duplicate = copyJson(candidate)
    duplicate.profiles[1].username = "ALICE"
    check(normalizeUserProfileStore(duplicate, "slot-a").readOnly, "case insensitive usernames cannot duplicate")
    duplicate = copyJson(candidate)
    duplicate.profiles[1].id = ucase(profile.id)
    check(normalizeUserProfileStore(duplicate, "slot-a").readOnly, "case insensitive IDs cannot duplicate")
    for i = 3 to 5
        extra = storeFixtureProfile(i)
        extra.isDefault = false
        extra.username = "user" + i.toStr()
        candidate.profiles.push(extra)
    end for
    check(normalizeUserProfileStore(candidate, "slot-a").readOnly, "local cap is four including default")
    for each failure in ["", "write", "flush", "rollback"]
        registry = storeRegistry()
        check(loadUserProfileStore(registry, "slot-a").readOnly <> true, "only absent key loads first-run empty")
        registry.failure = failure
        result = commitUserProfileStore(registry, empty, staged, {}, true)
        if failure = ""
            check(result.ok and registry.flushes = 1, "metadata creation commits with exactly one Flush")
            check(registry.durable["connKey_slot-a"] = "default-key", "migration never moves or replaces slot key")
            loaded = loadUserProfileStore(registry, "slot-a")
            check(loaded.readOnly <> true and loaded.profiles[0].id = profile.id, "valid store reloads")
            registry.values["userProfilesV1_slot-a"] = ""
            check(loadUserProfileStore(registry, "slot-a").readOnly, "present empty value is corruption, not absent")
        else
            check(not result.ok, "write/flush failure reported")
            check(result.recoveryRequired = (failure = "rollback"), "failed rollback explicitly requires recovery")
            check(not registry.values.doesExist("userProfilesV1_slot-a"), "failed creation restores absent key, not empty corrupt value")
        end if
    end for
    registry = storeRegistry()
    check(commitUserProfileStore(registry, empty, staged, {}, true).ok, "initial roster saved")
    candidate = copyJson(staged)
    other = storeFixtureProfile(2)
    other.isDefault = false
    other.username = "other"
    candidate.profiles.push(other)
    keys = {}
    keys[other.id] = "other-key"
    registry.failure = "flush"
    check(not commitUserProfileStore(registry, staged, candidate, keys, true).ok, "key and roster failed flush rolls back")
    check(registry.read(userProfileKeyName(other.id)) = "" and loadUserProfileStore(registry, "slot-a").profiles.count() = 1, "no mixed credential/metadata after rollback")
    registry.flushes = 0
    check(commitUserProfileStore(registry, staged, candidate, keys, true).ok and registry.flushes = 1, "profile key and roster share one successful flush")
    check(registry.durable[userProfileKeyName(other.id)] = "other-key", "nondefault key persists separately")
    registry.flushes = 0
    check(commitUserProfileStore(registry, candidate, candidate, {}, false).ok, "Remember off persists metadata but deletes nondefault keys")
    check(registry.flushes = 1 and registry.read(userProfileKeyName(other.id)) = "" and registry.read("connKey_slot-a") = "default-key", "transaction owns nondefault keys only; slot lifecycle owns default Remember")
    registry.flushes = 0
    check(not commitUserProfileStore(registry, staged, candidate, {}, true).ok and registry.flushes = 0, "stale metadata cannot overwrite later changes")
    keys = {}
    keys[profile.id] = "must-not-overwrite-default"
    check(not commitUserProfileStore(registry, candidate, candidate, keys, true).ok, "default cannot acquire a profKey alias")
    swapped = copyJson(candidate)
    swapped.profiles[0] = setCanonicalPreference(swapped.profiles[0], "isDefault", false)
    swapped.profiles[1] = setCanonicalPreference(swapped.profiles[1], "isDefault", true)
    check(not commitUserProfileStore(registry, candidate, swapped, {}, true).ok, "generic transaction cannot swap/remove the protected default")
    for each field in ["password", "apiKey", "futureHold"]
        bad = copyJson(candidate)
        bad.profiles[0][field] = "must-not-be-dropped"
        check(normalizeUserProfileStore(bad, "slot-a").readOnly, "unknown local state/credentials require recovery rather than silent erasure")
    end for
    print "ALL TESTS PASSED"
end sub

sub testProfileNativeStoreNames()
    profile = storeFixtureProfile(1)
    profile.displayName = string(36, "a") + "🦉"
    store = userProfileEnsureDefault(defaultUserProfileStore("slot-a"), profile)
    check(store <> invalid, "native store accepts a complete forty-byte Unicode display name")
end sub

function storeFixtureProfile(n as integer) as object
    return userProfileFromVerified("slot-a", "00000000-0000-4000-8000-00000000000" + n.toStr(), {id: n + 6, username: "Alice", user_level: 1}, 100)
end function

function storeRegistry() as object
    return {values: {"connKey_slot-a": "default-key"}, durable: {"connKey_slot-a": "default-key"}, failure: "", flushes: 0
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            if m.failure = "write"
                m.failure = ""
                return false
            end if
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            m.flushes++
            if m.failure = "rollback" then return false
            if m.failure = "flush"
                m.failure = ""
                return false
            end if
            m.durable = {}
            m.durable.append(m.values)
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
