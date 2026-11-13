sub main()
    connection = normalizeConnectionEntry({id: "slot-a", name: "A", provider: "dispatcharr", url: "https://example.test", accountId: "7"})
    scope = userProfileSessionScope(connection, "00000000-0000-4000-8000-000000000001", "7", "generation-1", "00000000-0000-4000-8000-000000000010")
    store = defaultPreferenceStore()
    prefs = normalizeAccountPreferences({favoriteIds: ["own-private"]})
    effective = normalizeDevicePreferences({themePreset: "forest"})
    for each failure in ["", "write", "flush", "rollback"]
        registry = scopeRegistry(FormatJson(store), failure)
        before = registry.read("settingsV1")
        saved = commitUserProfilePreferences(registry, store, prefs, effective, scope, scope)
        if failure = ""
            check(saved.ok and registry.flushes = 1 and saved.store.accounts.count() = 1, "scoped settings and device state share exactly one successful Flush")
            check(saved.preferences.favoriteIds[0] = "own-private" and saved.preferences.profileSettings.themePreset = "forest", "own settings/data persist under captured immutable identity")
        else
            check(not saved.ok and saved.recoveryRequired = (failure = "rollback"), "write/Flush/rollback failures have explicit recovery outcome")
            check(registry.read("settingsV1") = before, "failed transaction restores exact previous preference blob")
        end if
    end for
    registry = scopeRegistry(FormatJson(store), "")
    newer = setCanonicalPreference(scope, "sessionId", "00000000-0000-4000-8000-000000000011")
    check(not commitUserProfilePreferences(registry, store, prefs, effective, scope, newer).ok and registry.flushes = 0, "late outgoing write cannot enter a new A session even with same account")
    newer = setCanonicalPreference(scope, "accountId", "8")
    check(not commitUserProfilePreferences(registry, store, prefs, effective, scope, newer).ok and registry.flushes = 0, "late outgoing write cannot enter another user's scope")
    prefs.futureData = string(30000, "x")
    check(not commitUserProfilePreferences(registry, store, prefs, effective, scope, scope).ok and registry.flushes = 0, "oversized scoped write refuses without eviction or partial persistence")
    print "ALL TESTS PASSED"
end sub

function scopeRegistry(text as string, failure as string) as object
    values = {}
    values["settingsV1"] = text
    return {values: values, flushes: 0, failure: failure
        exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function
        read: function(key as string) as string
            if not m.values.doesExist(key) then return ""
            return m.values[key]
        end function
        write: function(key as string, value as string) as boolean
            m.values[key] = value
            if m.failure = "write"
                m.failure = ""
                return false
            end if
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
