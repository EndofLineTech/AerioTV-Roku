sub main()
    original = {startupBehavior: "mini", vodEnabled: true, vodTmdbEnabled: false, dvrPreRollMinutes: 5, dvrPostRollMinutes: 10,
        favoriteIds: ["private"], recent: ["private"], lastWatched: "private", previous: "private", lastChannel: "private", group: "private",
        collections: [{id: "private"}], reminders: [{id: "private"}], dvrPositions: {"7": 50}, aacChannels: ["private"], videoAspects: {"7": "fill"},
        whatsNewVersion: "private", vod: {hidden: ["private"], progress: {"7": 99}}, vodRecent: ["private"], vodBrowse: {query: "private"}, futurePrivateData: "private",
        guide: {groupSort: "name", groupOrder: ["setting"], channelSort: "name", groupLayout: "rail", collectionsPosition: "top", historyDays: 3, futureDays: 7, badges: false,
            tmdbFallback: false, guideDensity: "basic", showLogos: false, showNumbers: false, showNames: false, showSubtitles: false,
            hiddenGroups: ["private"], favoriteOrder: ["private"], startupGroup: "private", futurePrivateGuide: "private"},
        profileSettings: {themePreset: "sunset", customAccent: "ABCDEF", audioMode: "aac", liveTransport: "hls", archiveSkipSeconds: 120, remoteMap: {private: true}, networkTimeoutSeconds: 10}}
    before = FormatJson(original)
    seeded = userProfileSeedAccountPreferences(original)
    check(seeded.startupBehavior = "mini" and seeded.vodEnabled and not seeded.vodTmdbEnabled and seeded.dvrPreRollMinutes = 5 and seeded.dvrPostRollMinutes = 10, "explicit account settings copied")
    check(seeded.guide.groupOrder[0] = "setting" and seeded.guide.historyDays = 3 and seeded.guide.futureDays = 7 and not seeded.guide.showLogos, "explicit guide settings copied")
    check(instr(1, FormatJson(seeded), "private") = 0, "no unknown/current account or guide data can seed another user")
    check(seeded.favoriteIds.count() = 0 and seeded.recent.count() = 0 and seeded.dvrPositions.count() = 0 and seeded.collections.count() = 0 and seeded.reminders.count() = 0, "all user data starts empty")
    check(seeded.profileSettings.themePreset = "sunset" and seeded.profileSettings.customAccent = "ABCDEF" and seeded.profileSettings.audioMode = "aac", "approved appearance/accent/player settings seed separately")
    check(not seeded.profileSettings.doesExist("remoteMap") and not seeded.profileSettings.doesExist("networkTimeoutSeconds"), "hardware/network/remote fields remain device local")
    seeded.guide.groupOrder.push("changed")
    seeded.profileSettings.themePreset = "light"
    check(FormatJson(original) = before, "seeding never mutates or shares nested arrays with default")
    malformed = userProfileSeedAccountPreferences({startupBehavior: "private", dvrPreRollMinutes: "private", profileSettings: {audioMode: "private", themePreset: "private"}})
    check(malformed.startupBehavior = "guide" and malformed.dvrPreRollMinutes = 0 and malformed.profileSettings.audioMode = "auto", "only validated normalized settings survive native aliases")
    check(instr(1, FormatJson(malformed), "private") = 0, "invalid known settings cannot retain an unnormalized alias")
    slot = normalizeConnectionEntry({id: "slot-a", name: "A", provider: "dispatcharr", url: "https://example.test", accountId: "7"})
    a = userProfileSessionScope(slot, "00000000-0000-4000-8000-000000000001", "7", "assignments-1", "00000000-0000-4000-8000-000000000010")
    b = userProfileSessionScope(slot, "00000000-0000-4000-8000-000000000002", "8", "assignments-1", "00000000-0000-4000-8000-000000000011")
    again = userProfileSessionScope(slot, "00000000-0000-4000-8000-000000000001", "7", "assignments-1", "00000000-0000-4000-8000-000000000012")
    check(a.preferenceIdentity = "https://example.test|7|slot-a" and a.preferenceIdentity <> b.preferenceIdentity, "default scope preserves existing account identity, other user isolated")
    check(not userProfileSameSession(a, b) and not userProfileSameSession(a, again), "late A callbacks cannot mutate B or a later A session")
    check(userProfileSameSession(a, copyJson(a)), "immutable equal callback context accepted")
    changed = copyJson(a)
    changed = setCanonicalPreference(changed, "authorizationGeneration", "assignments-2")
    check(not userProfileSameSession(a, changed), "revoked/different assignments retire old callbacks")
    slot.id = "slot-b"
    other = userProfileSessionScope(slot, a.profileId, "7", "assignments-1", a.sessionId)
    check(a.preferenceIdentity <> other.preferenceIdentity and not userProfileSameSession(a, other), "same server/user/content in two slots stays isolated")
    check(userProfileSessionScope(slot, "../invalid", "7", "assignments-1", a.sessionId) = invalid, "invalid local profile cannot form a session")
    check(userProfileSessionScope(slot, a.profileId, "0", "assignments-1", a.sessionId) = invalid, "unverified/invalid server ID cannot form a session")
    check(not userProfileSameSession(a, invalid) and not userProfileSameSession({}, {}), "missing scopes fail closed")
    malformedScope = setCanonicalPreference(a, "accountId", 7)
    check(not userProfileSameSession(a, malformedScope), "malformed callback fields fail closed without native mixed-type comparisons")
    legacy = normalizeDevicePreferences({themePreset: "sunset", appearanceMode: "dark", audioMode: "aac", clockFormat: "24", networkTimeoutSeconds: 10})
    preparedA = userProfilePrepareSettings({favoriteIds: ["alice-private"]}, legacy)
    check(preparedA.ok and preparedA.migrated and preparedA.preferences.favoriteIds[0] = "alice-private", "default settings migration preserves existing user data")
    check(preparedA.preferences.profileSettings.themePreset = "sunset" and preparedA.device.audioMode = "aac" and preparedA.device.clockFormat = "24", "legacy appearance/player settings copied once, hardware remains local")
    prefsB = userProfileSeedAccountPreferences(preparedA.preferences)
    prefsB = setCanonicalPreference(prefsB, "profileSettings", normalizeUserProfileSettings({themePreset: "forest", audioMode: "direct"}))
    preparedB = userProfilePrepareSettings(prefsB, legacy)
    againA = userProfilePrepareSettings(preparedA.preferences, preparedB.device)
    check(not preparedB.migrated and preparedB.device.themePreset = "forest" and againA.device.themePreset = "sunset", "A/B/A restores own appearance/player settings rather than outgoing device-effective values")
    check(not userProfilePrepareSettings({profileSettings: "malformed"}, legacy).ok, "present malformed settings cannot be silently replaced by legacy values")
    preferenceStore = defaultPreferenceStore()
    preferenceStore.device = legacy
    preferenceStore.accounts[preferenceScope(a.preferenceIdentity)] = preparedA.preferences
    preferenceStore.accounts[preferenceScope(b.preferenceIdentity)] = preparedB.preferences
    effectiveB = setCanonicalPreference(preparedB.device, "themePreset", "midnight")
    effectiveB = setCanonicalPreference(effectiveB, "clockFormat", "12")
    plan = userProfileSettingsCommitPlan(preferenceStore, b.preferenceIdentity, preparedB.preferences, effectiveB)
    check(plan.ok and plan.preferences.profileSettings.themePreset = "midnight", "profile change persists in target account only")
    check(plan.store.device.themePreset = "sunset" and plan.store.device.clockFormat = "12", "profile appearance never overwrites legacy migration baseline; hardware change stays device-local")
    check(plan.store.accounts[preferenceScope(a.preferenceIdentity)].profileSettings.themePreset = "sunset" and plan.store.accounts[preferenceScope(a.preferenceIdentity)].favoriteIds[0] = "alice-private", "target write leaves outgoing user data/settings intact")
    check(preferenceStore.device.clockFormat = "24", "preparation cannot adopt persistence before successful flush")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
