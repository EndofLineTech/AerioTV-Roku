' Raw credential binding lives only on the active Scene, not in the broker,
' snapshots, tickets or diagnostics. A slot switch retires it on the next tick.
function unavailableRequestGateBinding(binding as dynamic, entry as object, store as object, nonce as string) as dynamic
    if type(binding) <> "roAssociativeArray" then return invalid
    if not CreateObject("roRegex", "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", "").isMatch(nonce) then return invalid
    if entry.provider <> "dispatcharr" or store.readOnly = true or store.playlistId <> entry.id then return invalid
    if binding.slot <> entry.id or binding.base <> entry.url then return invalid
    if textValue(binding.key) = "" or not requestGateDigestValid(textValue(binding.hash)) then return invalid
    if textValue(binding.profile) = "" or binding.profile <> store.active then return invalid
    if type(store.profiles) <> "roArray" then return invalid
    for each profile in store.profiles
        if profile.id = binding.profile
            if profile.addressHeld = true or textValue(profile.userId) <> binding.account then return invalid
            if textValue(profile.username) = "" or lcase(profile.username) <> lcase(textValue(binding.username)) then return invalid
            ' The nonce is a probe lifecycle only. Do not copy an authenticated
            ' session or synthesize one for this unavailable holder.
            return {slot: entry.id, base: entry.url, key: binding.key, hash: binding.hash, account: binding.account, username: profile.username, profile: profile.id, recoveryNonce: nonce}
        end if
    end for
    return invalid
end function

function currentRequestGateOwner(entry as object) as dynamic
    if entry.id <> m.selectedConnectionId then return invalid
    if normalizeBaseUrl(entry.url) <> normalizeBaseUrl(m.baseUrl) then return invalid
    if m.scopedPreferencesRequired <> true then return {account: textValue(entry.accountId), username: textValue(entry.accountUsername), profile: "", session: ""}
    scope = m.activeUserScope
    if type(scope) <> "roAssociativeArray" then return invalid
    if scope.playlistId <> entry.id then return invalid
    if type(scope.accountId) <> "String" and type(scope.accountId) <> "roString" then return invalid
    if scope.accountId = "" then return invalid
    if scope.preferenceIdentity <> connectionPreferenceIdentity(entry, scope.accountId) then return invalid
    if scope.sessionId = "" or scope.sessionId <> currentUserSessionId() then return invalid
    store = m.userProfileStore
    if type(store) <> "roAssociativeArray" then return invalid
    if store.readOnly = true or store.playlistId <> entry.id or store.active <> scope.profileId then return invalid
    if type(store.profiles) <> "roArray" then return invalid
    for each profile in store.profiles
        if profile.id = scope.profileId
            if textValue(profile.userId) <> scope.accountId then return invalid
            if type(profile.username) <> "String" and type(profile.username) <> "roString" then return invalid
            if profile.username = "" then return invalid
            return {account: scope.accountId, username: profile.username, profile: scope.profileId, session: scope.sessionId}
        end if
    end for
    return invalid
end function

function currentUnavailableRequestGateBinding() as dynamic
    binding = m.requestGateBinding
    if type(binding) <> "roAssociativeArray" or m.userProfileRecoveryRequired = true then return invalid
    nonce = textValue(binding.recoveryNonce)
    if m.global = invalid or nonce = "" then return invalid
    if nonce <> textValue(m.global.requestgaterecovery) then return invalid
    if textValue(m.global.activeusersession) <> "" then return invalid
    if m.activeUserScope <> invalid or m.apiKey <> "" then return invalid
    if m.page <> "setup" and m.page <> "profile-unavailable" then return invalid
    if m.profileOwnSignInContext <> invalid or m.profileSwitchContext <> invalid then return invalid
    if m.profilePinDialog <> invalid or m.adultPinDialog <> invalid or m.profileManagementDialog <> invalid then return invalid
    connections = loadConnectionStore(m.registry)
    if connections.readOnly = true or connections.selected <> m.selectedConnectionId then return invalid
    entry = connectionStoreEntry(connections, m.selectedConnectionId)
    if entry = invalid or normalizeBaseUrl(m.baseUrl) <> entry.url then return invalid
    store = loadUserProfileStore(m.registry, entry.id)
    return unavailableRequestGateBinding(binding, entry, store, nonce)
end function

sub rememberHeldRequestGateBinding()
    if userProfileGateClosed() or requestGateProfileSwitching() then return
    if m.requestGate = invalid or m.apiKey = "" then return
    entry = connectionStoreEntry(m.connectionStore, m.selectedConnectionId)
    if entry = invalid or entry.provider <> "dispatcharr" then return
    owner = currentRequestGateOwner(entry)
    if owner = invalid then retireProfileRequestBinding() : return
    state = m.requestGate.snapshot
    if type(state) <> "roAssociativeArray" then return
    hash = requestGateCredentialHash(m.apiKey)
    if not state.keys.doesExist(hash) then retireProfileRequestBinding() : return
    m.requestGateBinding = {slot: entry.id, base: m.baseUrl, key: m.apiKey, hash: hash, account: owner.account, username: owner.username, profile: owner.profile, session: owner.session}
    if not state.keys[hash].prompted and m.requestGatePrompt = invalid
        ticket = CreateObject("roSGNode", "RequestGateTicket")
        ticket.id = CreateObject("roDeviceInfo").getRandomUUID()
        ticket.action = "prompt"
        ticket.hash = hash
        ticket.observeField("result", "onRequestGatePrompt")
        m.requestGatePrompt = ticket
        m.requestGate.request = ticket
    end if
end sub

' Bindings contain raw keys and must not outlive a profile/connection lifecycle.
' Re-login may explicitly carry its own default-holder hold across its reset;
' a switch never inherits that exception.
sub retireProfileRequestBinding()
    if m.global <> invalid
        if type(m.global) = "roAssociativeArray"
            m.global.requestgaterecovery = ""
        else if m.global.hasField("requestgaterecovery")
            m.global.requestgaterecovery = ""
        end if
    end if
    if m.requestGatePrompt <> invalid then m.requestGatePrompt.unobserveField("result")
    m.requestGatePrompt = invalid
    if m.requestGateRecheck <> invalid
        m.requestGateRecheck.unobserveField("result")
        cancelNetworkTask(m.requestGateRecheck)
    end if
    m.requestGateRecheck = invalid
    m.requestGateBinding = invalid
end sub

sub onRequestGatePrompt(event as object)
    if not isCurrentTaskEvent(event, m.requestGatePrompt) then return
    m.requestGatePrompt.unobserveField("result")
    m.requestGatePrompt = invalid
    result = event.getData()
    if result.show <> true or m.requestGateBinding = invalid then return
    binding = m.requestGateBinding
    if binding.slot <> m.selectedConnectionId or binding.base <> m.baseUrl then return
    entry = connectionStoreEntry(m.connectionStore, binding.slot)
    if entry = invalid then return
    message = "Dispatcharr no longer accepts the API key for " + entry.name + ". It may have been changed on the server. Sign in with your Dispatcharr username and password to reconnect."
    openConnectionDialog("API key no longer valid", message, [{title: "Not Now", action: "cancel"}])
end sub

sub onRequestGateTick()
    if m.requestGateBinding = invalid or m.requestGate = invalid then return
    binding = m.requestGateBinding
    recovery = textValue(binding.recoveryNonce) <> ""
    if recovery
        if m.profileOwnSignInContext <> invalid or m.profileSwitchContext <> invalid or m.profilePinDialog <> invalid or m.adultPinDialog <> invalid or m.profileManagementDialog <> invalid then return
        if currentUnavailableRequestGateBinding() = invalid then retireProfileRequestBinding() : return
    else
        if userProfileGateClosed() then return
    end if
    if binding.slot <> m.selectedConnectionId or binding.base <> m.baseUrl or (m.apiKey <> "" and m.apiKey <> binding.key)
        m.requestGateBinding = invalid
        if m.requestGateRecheck <> invalid then m.requestGateRecheck.cancelRequested = true
        return
    end if
    if m.requestGateRecheck <> invalid then return
    if binding.account = "" then return
    state = m.requestGate.snapshot
    if type(state) <> "roAssociativeArray" then return
    if not state.keys.doesExist(binding.hash)
        m.requestGateBinding = invalid
        return
    end if
    due = requestGatePermit(state, requestGateServer(binding.base), binding.hash, uiNow(), true)
    if not due.allowed then return
    task = CreateObject("roSGNode", "RequestGateRecheckTask")
    tagTaskForCurrentUser(task)
    if recovery
        task.recoveryNonce = binding.recoveryNonce
    end if
    task.baseUrl = binding.base
    task.apiKey = binding.key
    task.accountId = binding.account
    task.expectedUsername = textValue(binding.username)
    task.observeField("result", "onRequestGateRecheck")
    m.requestGateRecheck = task
    task.control = "RUN"
end sub

sub onRequestGateRecheck(event as object)
    if m.requestGateRecheck = invalid then return
    if not m.requestGateRecheck.isSameNode(event.getRoSGNode()) then return
    recovery = textValue(m.requestGateRecheck.recoveryNonce) <> ""
    if recovery
        binding = currentUnavailableRequestGateBinding()
        if binding = invalid then retireProfileRequestBinding() : return
        if binding.recoveryNonce <> m.requestGateRecheck.recoveryNonce then return
    else
        if not isCurrentTaskEvent(event, m.requestGateRecheck) then return
    end if
    m.requestGateRecheck.unobserveField("result")
    m.requestGateRecheck = invalid
    result = event.getData()
    if result.ok = true
        if recovery
            if type(m.profileSessionKeys) <> "roAssociativeArray" then m.profileSessionKeys = {}
            m.profileSessionKeys[preferenceScope(binding.base + "|" + binding.slot + "|" + binding.profile)] = binding.key
            retireProfileRequestBinding()
            store = loadUserProfileStore(m.registry, binding.slot)
            child = false
            for each profile in store.profiles
                if profile.id = binding.profile then child = profile.role = "child"
            end for
            if child
                m.childRejectedIdentity = ""
                showUnavailableChildProfile()
                showNotice("Dispatcharr accepts this profile's API key again.")
                return
            end if
            closeActiveUserProfileRecoveryPrompt()
            m.apiKey = binding.key
            m.scopedPreferencesRequired = true
            m.global.profilegateclosed = false
            m.profileGateCover.visible = false
            m.profileRefreshReload = true
            connectServer(true)
            return
        end if
        if m.requestGateBinding <> invalid
            binding = m.requestGateBinding
            if binding.slot = m.selectedConnectionId and binding.base = m.baseUrl and m.apiKey = "" then m.apiKey = binding.key
        end if
        m.requestGateBinding = invalid
        showNotice("Dispatcharr accepts the API key again. Reconnect when ready.")
    end if
end sub
