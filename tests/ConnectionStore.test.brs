sub main()
    assertEqual(connectionWelcomeNeeded(defaultConnectionStore()), true, "new install opens welcome before setup")
    assertEqual(connectionWelcomeNeeded({schema: 2, selected: "", entries: [], readOnly: true}), false, "unreadable saved roster shows recovery setup instead")
    registry = {values: {serverUrl: "https://example.test", apiKey: "test-only", rememberApiKey: "true"}, read: function(key as string) as string
        value = m.values[key]
        if value = invalid then return ""
        return value
    end function, write: function(key as string, value as string) as boolean
        m.values[key] = value
        return true
    end function, delete: function(key as string) as boolean
        m.values.delete(key)
        return true
    end function, flush: function() as boolean
        return true
    end function}
    store = loadConnectionStore(registry)
    assertEqual(connectionWelcomeNeeded(store), false, "legacy remembered connection skips welcome")
    assertEqual(store.entries.count(), 1, "legacy connection migrates in memory")
    assertEqual(store.selected, "legacy", "legacy selection stays active")
    assertEqual(store.entries[0].remember, true, "legacy Remember setting retained")
    assertEqual(store.entries[0].authMode, "x-api-key", "legacy key now uses safe supported header")
    assertEqual(store.entries[0].apiKey, invalid, "key never copied into metadata")
    assertEqual(registry.read("connectionsV1"), "", "legacy registry untouched before successful migration")
    assertEqual(connectionPreferenceIdentity(store.entries[0], "9"), "https://example.test|9|legacy", "playlist scoped preferences")

    store = connectionStoreAdd(store, "slot-two", "Family")
    assertEqual(store.entries.count(), 2, "named slot added")
    assertEqual(store.entries[1].remember, false, "new slot defaults session-only")
    store = connectionStoreSelect(store, "slot-two")
    assertEqual(store.selected, "slot-two", "select slot without changing first account")
    store = connectionStoreRename(store, "slot-two", "Family TV")
    assertEqual(store.entries[1].name, "Family TV", "renaming preserves ID")
    store = connectionStoreMove(store, "slot-two", -1)
    assertEqual(store.entries[0].id, "slot-two", "reorder preserves selected ID")
    assertEqual(store.selected, "slot-two", "reorder preserves selection")
    configured = connectionStoreUpdate(store, "slot-two", {url: "https://family.example.test"})
    configured = connectionStoreUpdate(configured, "slot-two", {remember: true, accountId: "11", profileId: "4"})
    assertEqual(configured.entries[0].url, "https://family.example.test", "connection endpoint saved")
    assertEqual(configured.entries[0].remember, true, "explicit Remember can be enabled after endpoint validation")
    changedProfile = connectionStoreUpdate(configured, "slot-two", {profileId: "5"})
    assertEqual(changedProfile.entries[0].profileId, "5", "changing a previously selected profile updates the same slot")
    assertEqual(saveConnectionStore(registry, changedProfile), true, "changed profile persists")
    assertEqual(loadConnectionStore(registry).entries[0].profileId, "5", "relaunch restores newly selected profile ID")
    clearedProfile = connectionStoreUpdate(changedProfile, "slot-two", {profileId: ""})
    assertEqual(clearedProfile.entries[0].profileId, "", "switching back to server default clears profile ID")
    assertEqual(saveConnectionStore(registry, clearedProfile), true, "default profile selection persists")
    assertEqual(loadConnectionStore(registry).entries[0].profileId, "", "relaunch restores server default profile")
    rotated = connectionStoreUpdate(configured, "slot-two", {url: "https://other.example.test"})
    assertEqual(rotated.entries[0].remember, false, "changing host clears Remember")
    assertEqual(rotated.entries[0].accountId, "", "changing host drops old account identity")
    assertEqual(rotated.entries[0].profileId, "", "changing host drops old profile selection")
    assertEqual(connectionStoreUpdate(store, "slot-two", {url: "https://user:pass@host.test"}), invalid, "credentialed URL rejected")
    store = connectionStoreAdd(store, "third", "Third")
    store = connectionStoreAdd(store, "fourth", "Fourth")
    assertEqual(connectionStoreAdd(store, "fifth", "Too many"), invalid, "four-slot bound")
    assertEqual(connectionStoreAdd(store, "bad/id", "Invalid"), invalid, "unsafe registry key rejected")
    assertEqual(connectionStoreRename(store, "third", ""), invalid, "blank name rejected")
    store = connectionStoreRemove(store, "slot-two")
    assertEqual(store.entries.count(), 3, "remove only selected slot")
    assertEqual(store.selected <> "slot-two", true, "remove chooses remaining slot")

    malicious = {schema: 1, selected: "safe", entries: [{id: "safe", name: "Safe", provider: "dispatcharr", url: "https://example.test", remember: true, password: "must-not-store", apiKey: "must-not-store", accountId: "9"}]}
    cleaned = normalizeConnectionStore(malicious)
    assertEqual(cleaned.entries[0].password, invalid, "provider password excluded")
    assertEqual(cleaned.entries[0].apiKey, invalid, "API key excluded from JSON")
    assertEqual(saveConnectionStore(registry, cleaned), true, "bounded metadata persists")
    saved = registry.read("connectionsV1")
    assertEqual(instr(1, saved, "must-not-store"), 0, "no secret serialized")
    assertEqual(loadConnectionStore(registry).selected, "safe", "saved selection reloaded")
    assertEqual(normalizeConnectionStore({schema: 2, entries: []}).schema, 2, "newer schema read-only")
    assertEqual(saveConnectionStore(registry, {schema: 2, entries: []}), false, "newer format never overwritten")
    direct = connectionStoreAdd(defaultConnectionStore(), "playlist-one", "Live feed", "m3u")
    assertEqual(connectionWelcomeNeeded(direct), false, "session-only connection skips welcome on relaunch")
    assertEqual(direct.entries[0].provider, "m3u", "direct M3U slot selected")
    direct = connectionStoreUpdate(direct, "playlist-one", {url: "https://example.test/output/m3u/live", epgUrl: "https://example.test/output/epg/live", remember: true})
    direct = connectionStoreUpdate(direct, "playlist-one", {referer: "https://example.test"})
    assertEqual(direct.entries[0].referer, "https://example.test", "non-secret origin Referer scoped to playlist")
    assertEqual(connectionStoreUpdate(direct, "playlist-one", {referer: "https://other.test/path?token=private"}), invalid, "signed Referer rejected from roster")
    assertEqual(direct.entries[0].epgUrl, "https://example.test/output/epg/live", "XMLTV source bound to playlist")
    assertEqual(direct.entries[0].remember, false, "direct feed never stores a Dispatcharr key")
    changed = connectionStoreUpdate(direct, "playlist-one", {url: "https://other.test/playlist.m3u"})
    assertEqual(changed.entries[0].epgUrl, "", "new playlist endpoint drops old guide URL")
    assertEqual(changed.entries[0].referer, "", "changing source clears prior Referer")
    assertEqual(connectionStoreUpdate(direct, "playlist-one", {epgUrl: "https://user:pass@example.test/epg"}), invalid, "guide URL userinfo rejected")
    apiGuide = connectionStoreUpdate(configured, "slot-two", {epgUrl: "https://guide.example.test/export.xml"})
    assertEqual(connectionStoreEntry(apiGuide, "slot-two").epgUrl, "https://guide.example.test/export.xml", "Dispatcharr slot may choose an external XMLTV guide")
    assertEqual(connectionStoreEntry(apiGuide, "slot-two").remember, true, "guide-only change retains same-server Remember choice")
    assertEqual(connectionStoreEntry(connectionStoreUpdate(apiGuide, "slot-two", {url: "https://other.test"}), "slot-two").epgUrl, "", "changing Dispatcharr origin clears guide override")
    xc = connectionStoreAdd(defaultConnectionStore(), "xc-one", "Xtream live", "xtream")
    xc = connectionStoreUpdate(xc, "xc-one", {url: "https://example.test:9191", remember: true})
    assertEqual(xc.entries[0].provider, "xtream", "direct Xtream slot selected")
    assertEqual(xc.entries[0].remember, false, "provider credential never persisted through Remember")
    assertEqual(instr(1, FormatJson(xc), "password"), 0, "Xtream roster has no provider password")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
