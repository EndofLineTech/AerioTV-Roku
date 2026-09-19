sub main()
    store = defaultPreferenceStore()
    assertEqual(store.device.channelDirection, "apple", "approved new default")
    assertEqual(normalizeDevicePreferences({videoScale: "wrong"}).videoScale, "fit", "invalid scale fallback")
    assertEqual(normalizeAccountPreferences({videoAspects: {a: "4:3", b: "invalid"}}).videoAspects.count(), 1, "only valid per-channel aspect overrides survive")
    assertEqual(normalizePreferenceStore({schema: 2}).schema, 2, "newer schema is not downgraded")
    assertEqual(normalizePreferenceStore("bad").schema, 1, "corrupt root fallback")
    legacy = {favoriteIds: [1, "2", "2"], group: "group:3", lastChannel: "a"}
    a = accountPreferences(store, "url|A", "url|A", legacy)
    assertEqual(a.favoriteIds.count(), 2, "legacy favorites dedup")
    assertEqual(a.group, "group:3", "legacy selected group")
    assertEqual(accountPreferences(store, "url|B", "url|A", legacy).favoriteIds.count(), 0, "legacy isolation")
    assertEqual(preferenceScope("url|A") <> preferenceScope("url|a"), true, "case sensitive identity")
    a = recordWatched(a, "a")
    a = recordWatched(a, "b")
    assertEqual(a.previous, "a", "actual previous channel")
    assertEqual(previousWatched(a, "b"), "a", "zap back")
    assertEqual(previousWatched(a, "failed-pending"), "b", "failed tune does not become watched")
    a = recordWatched(a, "b")
    assertEqual(a.previous, "a", "pause/resume does not overwrite previous")
    a = recordWatched(a, "a")
    assertEqual(a.previous, "b", "repeated zap toggles")
    assertEqual(a.recent.count(), 2, "recent dedup")
    for i = 1 to 40
        a = recordWatched(a, "c" + i.toStr())
    end for
    assertEqual(a.recent.count(), 25, "bounded recent ring")
    assertEqual(a.recent[0], "c40", "most recent first")
    a = reconcileWatchHistory(a, [{uuid: "c40"}, {uuid: "c37"}])
    assertEqual(a.recent.count(), 2, "removed/denied channels pruned")
    assertEqual(a.previous, "", "removed previous cleared")
    store.accounts[preferenceScope("url|A")] = a
    assertEqual(accountPreferences(store, "url|B").recent.count(), 0, "account separation")
    merged = mergeAccountPreferences(a, {group: "favorites"})
    assertEqual(merged.recent.count(), 2, "guide updates preserve history")
    assertEqual(a.group, "group:3", "merge does not mutate original")
    registry = {
        data: "original", failWrite: false, failFlush: false
        read: function(key as string) as string
            return m.data
        end function
        write: function(key as string, value as string) as boolean
            if m.failWrite then return false
            m.data = value
            return true
        end function
        flush: function() as boolean
            return not m.failFlush
        end function
    }
    assertEqual(savePreferenceStore(registry, store, 10), false, "quota fails before replacing data")
    assertEqual(registry.data, "original", "oversize leaves persisted record")
    registry.failWrite = true
    assertEqual(savePreferenceStore(registry, store), false, "write failure is visible")
    registry.failWrite = false
    registry.failFlush = true
    assertEqual(savePreferenceStore(registry, store), false, "flush failure is visible")
    assertEqual(registry.data, "original", "flush failure rolls back")
    registry.failFlush = false
    assertEqual(savePreferenceStore(registry, store), true, "valid save")
    assertEqual(loadPreferenceStore(registry).accounts[preferenceScope("url|A")].recent.count(), 2, "reload history")
    assertEqual(savePreferenceStore(registry, normalizePreferenceStore({schema: 2})), false, "future schema write refused")
    policy = {
        values: {}, failFlush: false
        read: function(key as string) as string
            if m.values.doesExist(key) then return m.values[key]
            return ""
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
            return not m.failFlush
        end function
    }
    assertEqual(loadRememberPolicy(policy), true, "legacy default preserves existing opt-in behavior")
    policy.values.apiKey = "test-key"
    assertEqual(saveRememberPolicy(policy, false), true, "save Off")
    assertEqual(policy.read("apiKey"), "", "Off deletes previously saved key immediately")
    assertEqual(loadRememberPolicy(policy), false, "Off survives independent reload")
    policy.values.rememberApiKey = "corrupt"
    assertEqual(loadRememberPolicy(policy), false, "malformed policy does not opt in")
    assertEqual(saveRememberPolicy(policy, true), true, "save On without credential")
    assertEqual(policy.read("apiKey"), "", "On does not persist unvalidated credentials")
    policy.failFlush = true
    assertEqual(saveRememberPolicy(policy, false), false, "policy flush failure surfaced")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
