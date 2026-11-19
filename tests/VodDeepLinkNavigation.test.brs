sub main()
    checkUnavailableSavedHolderDoesNotResolve()
    checkAacWaitDuringVodLink()
    checkAacExpiryDuringVodDenial()
    checkColdVodContinuation()
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

sub checkColdVodContinuation()
    for each path in ["ready", "missing", "timeout", "late-result", "stale"]
        fixture()
        m.page = "guide"
        m.coldPlaybackClock = {control: "stop"}
        request = coldPlaybackLaunchRequest({contentID: "12", mediaType: "movie"}, true)
        beginColdPlayback(request)
        beginVodDeepLink(request)
        task = m.vodDeepLinkTask
        result = movieResult()
        if path = "missing" then result = {ok: false}
        if path = "timeout" or path = "late-result"
            m.coldPlayback.clock = {totalMilliseconds: function() as integer
                return 60000
            end function}
            if path = "timeout"
                checkColdPlayback()
                check(m.coldPlaybackOutcome.result = "timeout" and task.cancelRequested and task.detached, "resolver deadline cancels the exact task")
            end if
        else if path = "stale"
            cancelVodDeepLink()
            successor = coldPlaybackLaunchRequest({contentID: "12", mediaType: "movie"}, true)
            beginColdPlayback(successor)
            ' The adapter's serial is per fixture, not per request.
            beginVodDeepLink(successor)
        end if
        onVodDeepLinkResult(linkEvent(task, result))
        if path = "ready"
            play = m.mediaPlayer.request
            check(play.coldToken = request.coldToken and m.coldPlayback.identity = play.identity, "verified result transfers the exact token to the media player")
            onMediaClosed(linkEvent(m.mediaPlayer, userViewEvent({closed: true, coldToken: request.coldToken, identity: "stale-renderer", coldResult: "denied"}, currentUserSessionId())))
            check(m.page = "onDemand" and m.coldPlayback <> invalid, "a stale close cannot displace the current renderer")
            onMediaClosed(linkEvent(m.mediaPlayer, userViewEvent({closed: true, coldToken: request.coldToken, identity: play.identity, coldResult: "denied"}, currentUserSessionId())))
            check(m.page = "guide" and m.guide.active and m.coldPlaybackOutcome.result = "denied", "the exact no-session denial restores the Guide before settling")
        else if path = "missing"
            check(m.coldPlaybackOutcome.result = "unavailable" and m.page = "guide", "missing title settles on the existing Guide")
        else if path = "stale"
            check(m.coldPlayback.token = successor.coldToken and m.mediaPlayer.request = invalid, "a replaced resolver cannot affect its same-title successor")
        else
            check(m.mediaPlayer.request = invalid and m.page = "guide" and m.coldPlaybackOutcome.result = "timeout", "late timed-out resolver cannot displace the Guide")
        end if
    end for
    m.coldPlayback = invalid
end sub

sub checkAacExpiryDuringVodDenial()
    for each order in ["expired-before-result", "expired-before-timer", "released-before-expiry"]
        for each denial in ["missing", "wrong-title"]
            fixture()
            deferRequiredAacTune({uuid: "old-live"}, false, false, false)
            beginVodDeepLink(normalizeLaunchRequest({contentId: "12", mediaType: "movie"}))
            task = m.vodDeepLinkTask
            m.aacProfile = {id: "7"}
            clock = {elapsed: 20000, totalMilliseconds: function() as integer
                return m.elapsed
            end function}
            m.pendingAacTune.clock = clock
            if order = "released-before-expiry" then clock.elapsed = 19999
            if order = "expired-before-timer" then processAacWait()
            result = movieResult()
            if denial = "missing" then result = {ok: false} else result.item.id = "13"
            onVodDeepLinkResult(linkEvent(task, result))
            clock.elapsed = 20000
            processAacWait()
            check(m.pendingAacTune = invalid and m.failures = 0 and m.starts = 0 and m.stops = 0, "expired held AAC never restarts or shows a dialog after " + denial + ": " + order)
        end for
    end for
end sub

sub checkAacWaitDuringVodLink()
    for each path in ["plays", "missing", "denied-admission", "replacement", "cancel", "changed-page", "changed-session", "newer-tune", "elapsed", "broker-denied", "page-after-release"]
        fixture()
        request = normalizeLaunchRequest({contentId: "12", mediaType: "movie"})
        check(deferRequiredAacTune({uuid: "old-live"}, false, false, false), "real AAC path is pending before the link")
        if path = "denied-admission" then request.session = "different-session"
        beginVodDeepLink(request)
        task = m.vodDeepLinkTask
        m.aacProfile = {id: "7"}
        processAacWait()
        if path = "denied-admission"
            check(task = invalid and m.starts = 1 and m.stops = 0, "unadmitted link leaves the existing live intent alone")
        else
            check(task <> invalid and m.starts = 0 and m.stops = 0, "admitted link holds old AAC continuation without stopping current playback")
            if path = "changed-page" then m.page = "settings"
            if path = "changed-session" then m.global.activeusersession = "replaced"
            if path = "newer-tune"
                cancelVodDeepLink()
                m.aacProfile = invalid
                deferRequiredAacTune({uuid: "new-live"}, false, false, false)
            end if
            if path = "elapsed"
                m.pendingAacTune.clock = {totalMilliseconds: function() as integer
                    return 20000
                end function}
                processAacWait()
                check(m.pendingAacTune = invalid and m.failures = 0, "superseded AAC reaches its original deadline silently")
            end if
            result = movieResult()
            if path = "missing" or path = "page-after-release" then result = {ok: false}
            if path = "broker-denied" then m.global.requestGateRequired = true
            if path = "cancel" or path = "replacement"
                cancelVodDeepLink(path = "replacement")
                check(task.cancelRequested and task.detached, "cancelled task detaches and stops cooperatively")
                if path = "replacement" then beginVodDeepLink(request)
                onVodDeepLinkResult(linkEvent(task, movieResult()))
                if path = "replacement"
                    processAacWait()
                    check(m.starts = 0 and m.stops = 0, "old result cannot release replacement's hold")
                    task = m.vodDeepLinkTask
                end if
            end if
            onVodDeepLinkResult(linkEvent(task, result))
            if path = "page-after-release" then m.page = "settings"
            m.aacProfile = {id: "7"}
            processAacWait()
            if path = "plays" or path = "replacement" or path = "elapsed"
                check(m.stops = 1 and m.starts = 0 and m.page = "onDemand", "only the admitted movie takes over playback: " + path)
            else if path = "missing" or path = "newer-tune"
                expected = "old-live"
                if path = "newer-tune" then expected = "new-live"
                check(m.stops = 0 and m.starts = 1 and m.startedChannel = expected, "only the still-valid live intent resumes: " + path)
            else
                check(m.stops = 0 and m.starts = 0 and m.pendingAacTune = invalid, "stale VOD and held live tune are both discarded: " + path)
            end if
        end if
    end for
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
    m.starts = 0
    m.failures = 0
    m.pendingAacTune = invalid
    m.aacWaitTimer = {control: "stop"}
    m.noticeTimer = {control: "stop"}
    m.devicePreferences = {audioMode: "aac"}
    m.aacProfile = invalid
    m.aacDiscoveryState = "pending"
    m.capabilityTask = {}
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
    cancelAacWait()
end sub

sub startPlayback(channel as object, force as boolean, useAac as boolean, preserveBudget as boolean, tuneStartedAt as integer)
    m.starts++
    m.startedChannel = channel.uuid
    m.page = "player"
end sub

sub refreshCapabilities()
end sub

sub showAacUnavailable(request as object, message as string)
    m.failures++
end sub

sub hideNotice()
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
