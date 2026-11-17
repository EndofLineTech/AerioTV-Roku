sub main()
    ' Host parser cannot preserve the Roku double option.
    m.profilePreferenceDecoder = function(raw as string) as dynamic
        return ParseJson(raw)
    end function
    registry = {values: {}, flushes: 0, read: function(key as string) as string
        if m.values.doesExist(key) then return m.values[key]
        return ""
    end function, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, write: function(key as string, value as string) as boolean
        m.values[key] = value
        return true
    end function, delete: function(key as string) as boolean
        m.values.delete(key)
        return true
    end function, flush: function() as boolean
        m.flushes++
        return true
    end function}
    registry.values["settingsV1"] = FormatJson({schema: 1, device: {futureChoice: "keep", dispatcharrSyncProfiles: false}, accounts: {private: {favoriteIds: ["keep-private"]}}})
    root = registry.read("settingsV1")
    choice = phoneSetupSyncOfferChoice(registry)
    check(choice.ok and not choice.enabled and not choice.declined, "absent decline retains explicit-off offer eligibility")
    saved = phoneSetupDeclineSyncOffer(registry, root)
    check(saved.ok and registry.flushes = 1, "Not Now records only explicit device-local decline")
    settings = ParseJson(registry.read("settingsV1"))
    check(settings.device.dispatcharrSyncOfferDeclined and settings.device.dispatcharrSyncEnabled = invalid and not settings.device.dispatcharrSyncProfiles, "decline never enables Sync or resets category choices")
    check(settings.device.futureChoice = "keep" and settings.accounts.private.favoriteIds[0] = "keep-private", "decline preserves unknown choices and every account's private data")
    check(phoneSetupSyncOfferChoice(registry).declined, "prior explicit decline suppresses later payload offers")
    check(not phoneSetupDeclineSyncOffer(registry, root).ok and registry.flushes = 1, "stale offer cannot overwrite successor settings")
    registry.values["settingsV1"] = "{bad"
    check(not phoneSetupSyncOfferChoice(registry).ok and not phoneSetupDeclineSyncOffer(registry, "{bad").ok, "unreadable choices refuse without rewriting settings")
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
