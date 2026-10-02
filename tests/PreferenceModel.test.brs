sub main()
    positions = normalizeDvrPositions({"12": 420, "13": -1, "14/15": 60, "16": 999999})
    if positions.count() <> 1 or positions["12"] <> 420 then stop
    store = defaultPreferenceStore()
    assertEqual(store.device.channelDirection, "apple", "approved new default")
    assertEqual(store.device.liveStartupRetries, 1, "existing startup retry budget remains the default")
    assertEqual(normalizeDevicePreferences({liveStartupRetries: 0}).liveStartupRetries, 0, "zero retries is an explicit choice")
    assertEqual(normalizeDevicePreferences({liveStartupRetries: 3}).liveStartupRetries, 3, "three retries persist")
    assertEqual(normalizeDevicePreferences({liveStartupRetries: 4}).liveStartupRetries, 1, "unbounded retry count is rejected")
    assertEqual(store.device.archiveSkipSeconds, 60, "minute-window skip default")
    assertEqual(normalizeDevicePreferences({archiveSkipSeconds: 120}).archiveSkipSeconds, 120, "supported skip survives")
    assertEqual(normalizeDevicePreferences({archiveSkipSeconds: 15}).archiveSkipSeconds, 60, "unsupported sub-minute skip rejected")
    assertEqual(normalizeDevicePreferences({archiveSkipSeconds: "300"}).archiveSkipSeconds, 60, "malformed stored skip rejected")
    assertEqual(normalizeDevicePreferences({videoScale: "wrong"}).videoScale, "fit", "invalid scale fallback")
    device = normalizeDevicePreferences(invalid)
    assertEqual(resolveRemoteAction(device.remoteMap, "guide", "replay"), "jumpToNow", "guide replay default")
    assertEqual(resolveRemoteAction(device.remoteMap, "player", "replay"), "recentChannels", "player replay default")
    assertEqual(device.networkTimeoutSeconds, 20, "safe request timeout default")
    assertEqual(device.refreshSeconds, 300, "safe active refresh default")
    assertEqual(device.infoHints, true, "overlay hints default on")
    wrongCase = {}
    wrongCase.setModeCaseSensitive()
    wrongCase.audioGuide = false
    wrongCase.audioguide = true
    wrongCase.themePreset = "aerio"
    wrongCase.themepreset = "lavender"
    repaired = normalizeDevicePreferences(wrongCase)
    assertEqual(repaired.audioGuide, true, "displayed Audio Guide choice migrates to runtime field")
    assertEqual(repaired.themePreset, "lavender", "displayed theme choice migrates to runtime field")
    migratedRemote = normalizeDevicePreferences({guideReplayAction: "options", playerReplayAction: "rewind"})
    assertEqual(migratedRemote.guideReplayAction, invalid, "legacy guide preference removed")
    assertEqual(resolveRemoteAction(migratedRemote.remoteMap, "guide", "replay"), "openOptions", "legacy guide preference migrates")
    assertEqual(resolveRemoteAction(migratedRemote.remoteMap, "player", "replay"), "rewindHistory", "legacy player preference migrates")
    assertEqual(normalizeDevicePreferences({remoteMap: {version: 1, preset: "custom", player: {replay: "none"}}}).remoteMap.preset, "custom", "custom remote map persists")
    assertEqual(normalizeAccountPreferences({videoAspects: {a: "4:3", b: "invalid"}}).videoAspects.count(), 1, "only valid per-channel aspect overrides survive")
    assertEqual(normalizePreferenceStore({schema: 2}).schema, 2, "newer schema is not downgraded")
    assertEqual(normalizePreferenceStore("bad").schema, 1, "corrupt root fallback")
    legacy = {favoriteIds: [1, "2", "2"], group: "group:3", lastChannel: "a"}
    a = accountPreferences(store, "url|A", "url|A", legacy)
    assertEqual(a.favoriteIds.count(), 2, "legacy favorites dedup")
    assertEqual(a.group, "group:3", "legacy selected group")
    assertEqual(a.startupBehavior, "guide", "guide no-autoplay default")
    assertEqual(a.whatsNewVersion, "", "what's new starts unread")
    assertEqual(normalizeAccountPreferences({startupBehavior: "mini", whatsNewVersion: "0.3.29"}).startupBehavior, "mini", "valid mini startup survives")
    assertEqual(normalizeAccountPreferences({dvrPreRollMinutes: 10, dvrPostRollMinutes: 15}).dvrPostRollMinutes, 15, "bounded account DVR padding survives")
    assertEqual(normalizeAccountPreferences({dvrPreRollMinutes: 999}).dvrPreRollMinutes, 0, "invalid DVR padding rejected")
    wrongAccount = {}
    wrongAccount.setModeCaseSensitive()
    wrongAccount.startupBehavior = "guide"
    wrongAccount.startupbehavior = "mini"
    wrongAccount.vodEnabled = true
    wrongAccount.vodenabled = false
    repairedAccount = normalizeAccountPreferences(wrongAccount)
    assertEqual(repairedAccount.startupBehavior, "mini", "displayed startup choice migrates")
    assertEqual(repairedAccount.vodEnabled, false, "displayed VOD choice migrates")
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
    curatedStore = defaultPreferenceStore()
    curated = vodNormalize({id: 301, uuid: "saved", name: "Saved"}, "movie")
    curated.authorization = "A"
    entries = vodStateUpdate([], curated, {watchlist: true, hidden: true})
    for i = 1 to 30
        episode = vodNormalize({id: i, uuid: "ep-" + i.toStr(), name: "Episode"}, "episode")
        entries = vodStateUpdate(entries, episode, {position: 100, duration: 1000})
    end for
    curatedStore.accounts[preferenceScope("url|A")] = {vod: entries}
    other = vodNormalize({id: 302, uuid: "other", name: "Other"}, "movie")
    other.authorization = "B"
    curatedStore.accounts[preferenceScope("url|B")] = {vod: vodStateUpdate([], other, {watchlist: true})}
    assertEqual(savePreferenceStore(registry, curatedStore), true, "bounded curation saved to account registry")
    restored = loadPreferenceStore(registry)
    assertEqual(restored.accounts[preferenceScope("url|A")].vod.count(), 21, "curation and recent progress reload")
    assertEqual(vodStateEntry(restored.accounts[preferenceScope("url|A")].vod, curated).hidden, true, "older explicit choice survives relaunch")
    assertEqual(vodShelfEntries(restored.accounts[preferenceScope("url|A")].vod, "hidden", {movies: "allowed", series: "allowed", authorization: "A"}).count(), 1, "saved choice appears after relaunch")
    assertEqual(vodShelfEntries(restored.accounts[preferenceScope("url|B")].vod, "watchlist", {movies: "allowed", series: "allowed", authorization: "A"}).count(), 0, "another account cannot see this shelf")
    assertEqual(vodShelfEntries(restored.accounts[preferenceScope("url|B")].vod, "watchlist", {movies: "allowed", series: "allowed", authorization: "B"}).count(), 1, "second account sees its own shelf")
    assertEqual(vodStateEntry(restored.accounts[preferenceScope("url|B")].vod, curated).watchlist, false, "account choices isolated")
    replacement = vodNormalize({id: 303, uuid: "replace", name: "Replace"}, "movie")
    curatedStore.accounts[preferenceScope("url|A")].vod = vodStateUpdate(entries, replacement, {hidden: true})
    registry.failWrite = true
    assertEqual(savePreferenceStore(registry, curatedStore), false, "new curation write failure reported")
    registry.failWrite = false
    assertEqual(vodStateEntry(loadPreferenceStore(registry).accounts[preferenceScope("url|A")].vod, replacement).hidden, false, "failed write leaves prior choices")
    registry.failFlush = true
    assertEqual(savePreferenceStore(registry, curatedStore), false, "new curation flush failure reported")
    registry.failFlush = false
    assertEqual(vodStateEntry(loadPreferenceStore(registry).accounts[preferenceScope("url|A")].vod, replacement).hidden, false, "failed flush restores prior choices")
    assertEqual(savePreferenceStore(registry, curatedStore, 10), false, "curation quota failure reported")
    assertEqual(vodStateEntry(loadPreferenceStore(registry).accounts[preferenceScope("url|A")].vod, curated).watchlist, true, "quota failure leaves prior choices")
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
