sub main()
    resetScopedNavigation()
    check(prepareUserProfileConnectionSettings(m.connection, {accountId: "7", generation: "g1"}, "00000000-0000-4000-8000-000000000010"), "verified connection activates settings only after persisted migration")
    check(m.activeUserScope.accountId = "7" and m.devicePreferences.themePreset = "sunset" and m.accountPreferences.favoriteIds[0] = "own", "activation preserves own default state and legacy appearance")
    check(m.registry.flushes = 1 and m.presentationChanges = 1, "activation uses one Flush and applies presentation once")
    m.devicePreferences = setCanonicalPreference(m.devicePreferences, "themePreset", "forest")
    check(persistCurrentUserProfilePreferences(), "current scoped settings persist")
    check(m.preferenceStore.device.themePreset = "sunset" and m.accountPreferences.profileSettings.themePreset = "forest", "effective player/appearance choices cannot leak into legacy/device baseline")
    old = setCanonicalPreference(m.activeUserScope, "sessionId", "00000000-0000-4000-8000-000000000011")
    before = m.registry.flushes
    check(not persistCurrentUserProfilePreferences(old) and m.registry.flushes = before, "stale captured session cannot persist into active session")
    resetScopedNavigation()
    m.preferenceStore.device = ParseJson("{}")
    check(prepareUserProfileConnectionSettings(m.connection, {accountId: "7", generation: "g1"}, "00000000-0000-4000-8000-000000000010"), "strict migrated root with sparse device baseline activates safely")
    check(m.devicePreferences.networkTimeoutSeconds = 20 and m.devicePreferences.refreshSeconds = 300, "raw migrated device root gains runtime defaults before presentation")
    resetScopedNavigation()
    m.registry.failFlush = true
    check(not prepareUserProfileConnectionSettings(m.connection, {accountId: "7", generation: "g1"}, "00000000-0000-4000-8000-000000000010"), "failed migration never activates a scoped session")
    check(m.activeUserScope = invalid and m.presentationChanges = 0, "failed write does not adopt theme or session")
    resetScopedNavigation()
    check(not prepareUserProfileConnectionSettings(m.connection, {accountId: "8", generation: "g1"}, "00000000-0000-4000-8000-000000000010") and m.registry.flushes = 0, "mismatched saved profile identity refuses settings activation")
    print "ALL TESTS PASSED"
end sub

sub resetScopedNavigation()
    m.connection = normalizeConnectionEntry({id: "slot-a", name: "A", provider: "dispatcharr", url: "https://example.test", accountId: "7"})
    m.accountIdentity = "https://example.test|7|slot-a"
    m.preferenceStore = defaultPreferenceStore()
    m.preferenceStore.device = normalizeDevicePreferences({themePreset: "sunset"})
    m.devicePreferences = m.preferenceStore.device
    m.accountPreferences = normalizeAccountPreferences({favoriteIds: ["own"]})
    profile = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {id: 7, username: "Alice", user_level: 1}, 1)
    m.userProfileStore = {active: profile.id, profiles: [profile]}
    m.activeUserScope = invalid
    m.userProfileRecoveryRequired = false
    m.presentationChanges = 0
    values = {}
    values["settingsV1"] = FormatJson(m.preferenceStore)
    m.registry = {values: values, flushes: 0, failFlush: false
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
            if m.failFlush
                m.failFlush = false
                return false
            end if
            return true
        end function
    }
end sub

sub applyDevicePreferences()
    m.presentationChanges++
end sub

sub check(passed as boolean, message as string)
    if not passed
        print "FAIL: "; message
        stop
    end if
end sub
