' This is an authorization continuation, not a library selection. Recheck the
' same local holder, credential and protection at both ends of the Task.
function vodDeepLinkOwner() as dynamic
    if userProfileUiClosed() or m.userProfileRecoveryRequired = true then return invalid
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid then return invalid
    if m.profileSwitchContext <> invalid or m.profileOwnSignInContext <> invalid then return invalid
    if m.page <> "guide" and m.page <> "player" then return invalid
    if m.accountPreferences.vodEnabled = false or m.apiKey = "" then return invalid
    if m.top.dialog <> invalid or m.phoneProfileOnboarding <> invalid then return invalid
    scope = m.activeUserScope
    if type(scope) <> "roAssociativeArray" then return invalid
    if scope.sessionId = "" or scope.sessionId <> currentUserSessionId() then return invalid
    if scope.preferenceIdentity <> m.accountIdentity or scope.accountId <> m.serverAccountId or scope.playlistId <> m.selectedConnectionId then return invalid
    if m.guide.config = invalid then return invalid
    if m.guide.config.providerType <> "dispatcharr" or m.guide.config.accountId <> scope.accountId or userViewSession(m.guide.config) <> scope.sessionId then return invalid
    if m.guide.config.apiKey <> m.apiKey or m.guide.config.baseUrl <> m.baseUrl then return invalid
    connections = loadConnectionStore(m.registry)
    if connections.readOnly = true or connections.selected <> scope.playlistId then return invalid
    entry = connectionStoreEntry(connections, scope.playlistId)
    if entry = invalid then return invalid
    if entry.provider <> "dispatcharr" or entry.url <> m.baseUrl then return invalid
    if scope.preferenceIdentity <> connectionPreferenceIdentity(entry, scope.accountId) then return invalid
    store = loadUserProfileStore(m.registry, entry.id)
    if store.readOnly = true or store.active <> scope.profileId then return invalid
    for each profile in store.profiles
        if profile.id = scope.profileId
            if profile.addressHeld = true or profile.addOrigin = "paused" then return invalid
            if textValue(profile.userId) <> scope.accountId or profile.username = "" then return invalid
            ' Remember-off uses only the already authenticated in-memory session
            ' key. Remembered profiles must still own the corresponding key.
            if entry.remember = true
                own = userProfileCredential(m.registry, entry, store, {})
                if not own.ok or own.profileId <> scope.profileId or own.key <> m.apiKey then return invalid
            end if
            return {scope: scope, page: m.page, base: entry.url, key: m.apiKey, username: profile.username, protection: userProfileSwitchProtectionSnapshot(profile)}
        end if
    end for
    return invalid
end function

sub bindStartupVodDeepLink(request as dynamic, entry as dynamic)
    if request = invalid or entry = invalid then return
    if request.kind = "live" or entry.provider <> "dispatcharr" then return
    request.playlist = entry.id
    request.base = entry.url
    original = m.startupVodFallbackHolder
    if original <> invalid
        if original.playlist = entry.id and original.base = entry.url
            request.profile = original.profile
            request.account = original.account
            return
        end if
    end if
    store = loadUserProfileStore(m.registry, entry.id)
    for each profile in store.profiles
        if profile.id = store.active
            request.profile = profile.id
            request.account = textValue(profile.userId)
        end if
    end for
end sub

sub resumePendingVodDeepLink()
    if m.pendingLaunch = invalid then return
    if m.pendingLaunch.kind <> "live" then handlePendingLaunch()
end sub

sub beginVodDeepLink(request as object)
    owner = vodDeepLinkOwner()
    if owner = invalid
        showVodDeepLinkUnavailable()
        return
    end if
    if textValue(request.session) <> "" and request.session <> owner.scope.sessionId then return
    if textValue(request.playlist) <> "" and (request.playlist <> owner.scope.playlistId or request.base <> owner.base) then return
    if textValue(request.profile) <> "" and (request.profile <> owner.scope.profileId or request.account <> owner.scope.accountId)
        showVodDeepLinkUnavailable()
        return
    end if
    task = invalid
    if m.vodDeepLinkTaskFactory <> invalid then task = m.vodDeepLinkTaskFactory()
    if task = invalid then task = CreateObject("roSGNode", "VodTask")
    tagTaskForCurrentUser(task)
    task.baseUrl = owner.base
    task.apiKey = owner.key
    task.accountId = owner.scope.accountId
    task.accountUsername = owner.username
    task.operation = "deepLink"
    task.kind = request.kind
    task.itemId = request.id
    task.savedState = vodState(m.accountPreferences.vod)
    owner.request = request
    m.vodDeepLinkOwner = owner
    m.vodDeepLinkTask = task
    task.observeField("result", "onVodDeepLinkResult")
    task.control = "RUN"
end sub

sub cancelVodDeepLink()
    if m.vodDeepLinkTask <> invalid
        m.vodDeepLinkTask.unobserveField("result")
        cancelNetworkTask(m.vodDeepLinkTask)
    end if
    m.vodDeepLinkTask = invalid
    m.vodDeepLinkOwner = invalid
end sub

sub onVodDeepLinkResult(event as object)
    task = m.vodDeepLinkTask
    if task = invalid or event.getRoSGNode() = invalid then return
    if not task.isSameNode(event.getRoSGNode()) then return
    owner = m.vodDeepLinkOwner
    task.unobserveField("result")
    m.vodDeepLinkTask = invalid
    m.vodDeepLinkOwner = invalid
    if not taskUserSessionCurrent(task) then return
    current = vodDeepLinkOwner()
    if current = invalid or owner = invalid then return
    if not userProfileSameSession(current.scope, owner.scope) then return
    if current.page <> owner.page or current.base <> owner.base or current.key <> owner.key or current.protection <> owner.protection then return
    result = event.getData()
    if type(result) = "roAssociativeArray"
        item = result.item
        if result.ok = true and type(item) = "roAssociativeArray"
            request = owner.request
            matches = item.kind = request.kind and item.id = request.id
            if request.kind = "series" then matches = item.kind = "episode" and item.seriesId = request.id
            if matches and not vodItemHidden(m.accountPreferences.vod, item) and requestGateAccessAllowed(current.base, current.key)
                if startVodPlayback(item, "guide") then return
            end if
        end if
    end if
    showVodDeepLinkUnavailable()
end sub

sub showVodDeepLinkUnavailable()
    showNotice("This title is not available to your current profile.")
end sub
