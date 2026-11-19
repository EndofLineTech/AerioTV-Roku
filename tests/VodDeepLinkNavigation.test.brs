sub main()
    checkUnavailableSavedHolderDoesNotResolve()
    request = normalizeLaunchRequest({contentId: "12", mediaType: "movie", apiKey: "untrusted", url: "https://other.test"})
    fixture()
    m.global.profilegateclosed = true
    beginVodDeepLink(request)
    check(m.created = 0 and m.stops = 0, "closed profile cannot resolve or play")
    m.global.profilegateclosed = false
    m.profilePinDialog = {}
    beginVodDeepLink(request)
    check(m.created = 0, "visible PIN does not start the resolver")

    fixture()
    request.session = "other-session"
    beginVodDeepLink(request)
    check(m.created = 0, "queued request cannot cross sessions")
    request.session = ""
    request.profile = "other-profile"
    beginVodDeepLink(request)
    check(m.created = 0, "cold request cannot change restored profile")
    request.profile = ""
    m.apiKey = "default-key"
    beginVodDeepLink(request)
    check(m.created = 0, "non-default holder cannot borrow a saved default key")

    for each scenario in ["switch", "pin", "new-protection", "address", "key", "scope", "disabled", "page", "broker", "wrong-title", "missing"]
        fixture()
        beginVodDeepLink(request)
        task = m.vodDeepLinkTask
        check(task.apiKey = "own-key" and task.accountId = "8" and task.accountUsername = "bob" and task.baseUrl = m.baseUrl, "only own verified session supplies Task auth")
        check(task.aeriosession = currentUserSessionId() and task.operation = "deepLink" and m.stops = 0, "pending verification does not interrupt playback")
        result = movieResult()
        if scenario = "switch" then m.global.profileswitchpending = true
        if scenario = "pin" then m.profilePinDialog = {}
        if scenario = "new-protection"
            store = loadUserProfileStore(m.registry, "slot-a")
            store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinType", "numbers")
            store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinHash", string(64, "a"))
            store.profiles[1] = setCanonicalPreference(store.profiles[1], "pinSalt", string(32, "b"))
            m.registry.values[userProfileStoreKey("slot-a")] = FormatJson(store)
        end if
        if scenario = "address" then m.baseUrl = "https://other.test"
        if scenario = "key" then m.registry.values[m.ownKeyName] = "replacement"
        if scenario = "scope" then m.global.activeusersession = "replacement"
        if scenario = "disabled" then m.accountPreferences.vodEnabled = false
        if scenario = "page" then m.page = "settings"
        if scenario = "broker" then m.global.requestGateRequired = true
        if scenario = "wrong-title" then result.item.id = "13"
        if scenario = "missing" then result = {ok: false}
        onVodDeepLinkResult(linkEvent(task, result))
        check(m.mediaPlayer.request = invalid and m.stops = 0 and m.vodDeepLinkTask = invalid, "no playback after " + scenario)
    end for

    fixture()
    beginVodDeepLink(request)
    oldTask = m.vodDeepLinkTask
    cancelVodDeepLink()
    check(oldTask.cancelRequested and oldTask.detached, "replacement cancels Task and detaches the observer")
    beginVodDeepLink(request)
    task = m.vodDeepLinkTask
    onVodDeepLinkResult(linkEvent(oldTask, movieResult()))
    check(m.vodDeepLinkTask.tag = task.tag and m.mediaPlayer.request = invalid, "old node cannot settle or start its replacement")
    onVodDeepLinkResult(linkEvent(task, movieResult()))
    play = m.mediaPlayer.request
    check(m.stops = 1 and m.page = "onDemand" and m.mediaReturn = "guide" and not m.guide.visible and not m.vod.active, "verified link goes straight to playback, with no library/details screen")
    check(play.mode = "vod" and play.apiKey = "own-key" and play.resume = 85 and play.aeriosession = currentUserSessionId(), "native player request is bookmarked and account-scoped")
    check(instr(1, play.url, "https://example.test/proxy/vod/movie/movie-12/roku_") = 1, "playback URL uses verified UUID, never supplied link fields")
    onMediaClosed(linkEvent(m.mediaPlayer, userViewEvent({closed: true}, currentUserSessionId())))
    check(m.page = "guide" and m.guide.visible and m.guide.active, "Back returns linked playback to the guide")
    fixture()
    m.registry.values.delete(m.ownKeyName)
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    entry.remember = false
    m.registry.values["connectionsV1"] = FormatJson({schema: 1, selected: entry.id, entries: [entry]})
    beginVodDeepLink(request)
    check(m.created = 1 and m.vodDeepLinkTask.apiKey = "own-key", "Remember off uses the existing verified runtime credential without a disk key")
    print "ALL TESTS PASSED"
end sub

sub checkUnavailableSavedHolderDoesNotResolve()
    for each variant in ["missing-key", "address-held"]
        fixture()
        request = normalizeLaunchRequest({contentId: "12", mediaType: "movie"})
        entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
        store = loadUserProfileStore(m.registry, entry.id)
        original = store.active
        if variant = "missing-key"
            m.registry.values.delete(m.ownKeyName)
        else
            store.profiles[1] = setCanonicalPreference(store.profiles[1], "addressHeld", true)
            m.registry.values[userProfileStoreKey(entry.id)] = FormatJson(store)
        end if
        m.activeUserScope = invalid
        session = currentUserSessionId()
        m.global.activeusersession = ""
        check(prepareUserProfileLaunchRestore(entry), "local startup restoration succeeds for " + variant)
        bindStartupVodDeepLink(request, entry)
        store = loadUserProfileStore(m.registry, entry.id)
        check(request.profile = original and store.active <> original, "saved holder is stamped even after fallback for " + variant)
        m.global.activeusersession = session
        m.activeUserScope = userProfileSessionScope(entry, store.active, "7", "verified", session)
        m.serverAccountId = "7"
        m.accountIdentity = m.activeUserScope.preferenceIdentity
        m.apiKey = "default-key"
        m.guide.config = userViewEvent({providerType: "dispatcharr", accountId: "7", apiKey: m.apiKey, baseUrl: m.baseUrl}, currentUserSessionId())
        check(vodDeepLinkOwner() <> invalid, "fallback default has a usable authenticated guide")
        beginVodDeepLink(request)
        check(m.created = 0 and m.stops = 0, "fallback default never resolves original holder's title for " + variant)
    end for
end sub

sub fixture()
    slot = "slot-a"
    alice = userProfileFromVerified(slot, "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
    bob = userProfileFromVerified(slot, "00000000-0000-4000-8000-000000000002", {id: 8, username: "bob", user_level: 1}, 1)
    bob = setCanonicalPreference(bob, "isDefault", false)
    store = defaultUserProfileStore(slot)
    store.profiles = [alice, bob]
    store.active = bob.id
    entry = normalizeConnectionEntry({id: slot, name: "Synthetic", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true})
    values = {}
    values["connectionsV1"] = FormatJson({schema: 1, selected: slot, entries: [entry]})
    values[userProfileStoreKey(slot)] = FormatJson(store)
    values[connectionRegistryKey(slot)] = "default-key"
    m.ownKeyName = userProfileKeyName(slot, bob.id)
    values[m.ownKeyName] = "own-key"
    m.registry = {values: values, exists: function(key as string) as boolean
        return m.values.doesExist(key)
    end function, read: function(key as string) as string
        if m.values.doesExist(key) then return m.values[key]
        return ""
    end function, write: function(key as string, value as string) as boolean
        m.values[key] = value
        return true
    end function, delete: function(key as string) as boolean
        m.values.delete(key)
        return true
    end function, flush: function() as boolean
        return true
    end function}
    m.connectionStore = loadConnectionStore(m.registry)
    m.selectedConnectionId = slot
    m.baseUrl = entry.url
    m.apiKey = "own-key"
    m.serverAccountId = "8"
    session = "00000000-0000-4000-8000-000000000003"
    m.activeUserScope = userProfileSessionScope(entry, bob.id, "8", "verified", session)
    m.accountIdentity = m.activeUserScope.preferenceIdentity
    m.accountPreferences = {vodEnabled: true, vod: [], vodRecent: []}
    m.global = {profilegateclosed: false, activeusersession: session}
    m.top = {dialog: invalid}
    m.screen = {visible: false}
    m.guide = {config: userViewEvent({providerType: "dispatcharr", accountId: "8", apiKey: "own-key", baseUrl: entry.url}, session), visible: false, active: false}
    m.vod = {active: false}
    m.mediaPlayer = {tag: "media", request: invalid, isSameNode: function(other as object) as boolean
        return other.tag = m.tag
    end function}
    m.page = "player"
    m.stops = 0
    m.created = 0
    m.profilePinDialog = invalid
    m.startupVodFallbackHolder = invalid
    m.vodDeepLinkTaskFactory = function() as object
        m.created++
        return {tag: m.created, isSameNode: function(other as object) as boolean
            return other.tag = m.tag
        end function, observeField: sub(field as string, callback as string)
        end sub, unobserveField: sub(field as string)
            m.detached = true
        end sub}
    end function
end sub

function movieResult() as object
    item = vodNormalize({id: 12, uuid: "movie-12", name: "Movie", container_extension: "mp4"}, "movie")
    item.accountScope = "https://example.test|8"
    item.resume = 85
    return {ok: true, item: item}
end function

function linkEvent(node as object, data as object) as object
    return {node: node, data: data, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return m.data
    end function}
end function

sub stopPlayback()
    m.stops++
end sub

function persistAccountPreferences() as boolean
    return true
end function

sub showNotice(message as string)
end sub

sub recordDiagnostic(stage as string, code as integer, message as string)
end sub

sub check(passed as boolean, message as string)
    if not passed then print "FAIL: "; message : stop
end sub
