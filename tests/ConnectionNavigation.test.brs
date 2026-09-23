sub main()
    m.registry = {
        values: {serverUrl: "https://example.test", accountIdentity: "https://example.test|7", apiKey: "old-key", rememberApiKey: "true"}
        failKeyWrite: false
        read: function(key as string) as string
            value = m.values[key]
            if value = invalid then return ""
            return value
        end function
        write: function(key as string, value as string) as boolean
            if m.failKeyWrite and left(key, 8) = "connKey_" then return false
            m.values[key] = value
            return true
        end function
        delete: function(key as string) as boolean
            m.values.delete(key)
            return true
        end function
        flush: function() as boolean
            return true
        end function
    }
    m.connectionStore = loadConnectionStore(m.registry)
    m.selectedConnectionId = "legacy"
    m.apiKey = "new-key"
    m.remember = true
    assertEqual(legacyConnectionPreferencesMatch(m.registry, "https://example.test", "7"), true, "same legacy server and account can migrate preferences")
    assertEqual(legacyConnectionPreferencesMatch(m.registry, "https://other.test", "7"), false, "edited server cannot inherit old preferences")
    assertEqual(legacyConnectionPreferencesMatch(m.registry, "https://example.test", "8"), false, "new account cannot inherit old preferences")
    assertEqual(rememberConnectedAccount("7"), true, "legacy verified key migrates to its own slot")
    assertEqual(m.registry.read("apiKey"), "", "old single-slot key removed")
    assertEqual(m.registry.read("connKey_legacy"), "new-key", "verified key saved to selected slot")
    assertEqual(m.connectionStore.entries[0].accountId, "7", "verified account saved")

    m.registry.failKeyWrite = true
    m.apiKey = "replacement-key"
    assertEqual(rememberConnectedAccount("8"), false, "failed replacement key write is reported")
    assertEqual(m.registry.read("connKey_legacy"), "", "prior account key cannot survive a failed switch")
    assertEqual(m.connectionStore.entries[0].accountId, "7", "failed switch does not save new account metadata")
    assertEqual(m.registry.read("apiKey"), "", "legacy fallback stays removed")

    ' Queued events from the detached Guide must not write the next account's
    ' preferences after a connection switch.
    m.accountIdentity = "https://example.test|8|legacy"
    m.accountPreferences = normalizeAccountPreferences(invalid)
    m.guide = {isSameNode: function(node as object) as boolean
        return node.tag = "current"
    end function}
    staleEvent = {getRoSGNode: function() as object
        return {tag: "old"}
    end function, getData: function() as object
        return {favoriteIds: ["foreign-channel"]}
    end function}
    onPreferences(staleEvent)
    assertEqual(m.accountPreferences.favoriteIds.count(), 0, "old guide cannot alter new account preferences")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
