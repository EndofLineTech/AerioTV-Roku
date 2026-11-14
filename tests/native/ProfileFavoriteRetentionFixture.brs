' Numeric channel IDs: explicit own Guide edits must retain unavailable favorites.
sub onManagementProbeTick()
    phase = m.managementProbePhase
    if phase = 0
        if m.busy or m.page <> "guide" or m.capabilityTask <> invalid then return
        m.favoriteProfile = m.activeUserScope.profileId
        m.favoriteSession = currentUserSessionId()
        m.favoriteRoster = m.registry.read(userProfileStoreKey("slot-a"))
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        m.favoriteOther = strictJsonEncode(m.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(entry, "7"))]).text
        view = m.guide.callFunc("profileFavoriteProbe", "inspect")
        m.favoritePassed = m.activeUserScope.accountId = "8" and view.selected8 and not view.selected99
        m.guide.callFunc("profileFavoriteProbe", "edit")
        m.managementProbePhase = 1
    else if phase = 1
        retained = FormatJson(m.accountPreferences.favoriteIds) = FormatJson(["99", "8"])
        m.favoritePassed = m.favoritePassed and retained
        print "[profile-management] "; FormatJson({kind: "favorite-edit", passed: m.favoritePassed, retained: retained})
        if not m.favoritePassed
            m.managementProbeClock.control = "stop"
            print "[profile-management] "; FormatJson({kind: "result", passed: false})
            return
        end if
        print "[profile-management] "; FormatJson({kind: "favorite-return-ready"})
        m.managementProbePhase = 2
    else if phase = 2
        refreshChannelLineup()
        m.managementProbePhase = 3
    else if phase = 3
        if m.busy or m.refreshTask <> invalid or m.capabilityTask <> invalid then return
        view = m.guide.callFunc("profileFavoriteProbe", "inspect")
        returned = view.selected8 and view.selected99 and FormatJson(m.accountPreferences.favoriteIds) = FormatJson(["99", "8"]) and currentUserSessionId() = m.favoriteSession
        m.favoritePassed = m.favoritePassed and returned
        print "[profile-management] "; FormatJson({kind: "favorite-returned", passed: returned})
        m.guide.callFunc("profileFavoriteProbe", "untoggle")
        m.managementProbePhase = 4
    else if phase = 4
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        raw = loadStrictPreferenceStore(m.registry).accounts[preferenceScope(connectionPreferenceIdentity(entry, "8"))]
        aliases = 0
        for each field in raw.keys()
            if lcase(field) = "favoriteids" then aliases++
        end for
        m.favoriteCanonical = aliases = 1
        m.profileRefreshReload = true
        connectServer(true)
        m.managementProbePhase = 5
    else
        if m.busy or m.capabilityTask <> invalid or m.page <> "guide" then return
        m.managementProbeClock.control = "stop"
        view = m.guide.callFunc("profileFavoriteProbe", "inspect")
        own = m.activeUserScope <> invalid
        if own then own = m.activeUserScope.profileId = m.favoriteProfile and m.activeUserScope.accountId = "8" and not m.profileGateCover.visible
        toggled = not view.selected8 and view.selected99 and FormatJson(m.accountPreferences.favoriteIds) = FormatJson(["99"])
        entry = connectionStoreEntry(m.connectionStore, "slot-a")
        other = strictJsonEncode(m.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(entry, "7"))]).text = m.favoriteOther and m.registry.read(userProfileStoreKey("slot-a")) = m.favoriteRoster
        keys = m.registry.read("connKey_slot-a") = "synthetic-a" and m.registry.read(userProfileKeyName("slot-a", m.favoriteProfile)) = "synthetic-b"
        reloaded = currentUserSessionId() <> m.favoriteSession
        print "[profile-management] "; FormatJson({kind: "result", passed: m.favoritePassed and own and toggled and other and keys and m.favoriteCanonical and reloaded and m.playingChannel = invalid, own: own, explicit_toggle: toggled, canonical: m.favoriteCanonical, reloaded: reloaded, other_preserved: other, keys_preserved: keys, no_autoplay: m.playingChannel = invalid})
    end if
end sub
