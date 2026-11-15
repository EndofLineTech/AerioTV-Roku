' Private existing-canonical profiles writer. Shipping opt-in remains off until
' Scene dirty/ack/protection settlement and native request-ledger tests qualify.
sub init()
    m.top.functionName = "writeDispatcharrSync"
    m.syncWriterReady = false
end sub

sub writeDispatcharrSync()
    m.key = m.top.apiKey
    m.requestMode = invalid
    if textValue(m.top.authMode) <> "" then m.requestMode = dispatcharrHeaderMode(m.top.authMode)
    denied = {ok: false, state: "disabled", submitted: false, allowWrite: false}
    if m.syncWriterReady <> true then finishDispatcharrSyncWrite(denied) : return
    m.writerRegistry = m.syncWriterRegistry
    if m.writerRegistry = invalid then m.writerRegistry = CreateObject("roRegistrySection", "AerioTV")
    if not syncWriterAccessCurrent() then finishDispatcharrSyncWrite({ok: false, state: "stale-context"}) : return
    me = syncWriterReadObject(m.top.baseUrl + "/api/accounts/users/me/", 65536)
    if not me.ok then finishDispatcharrSyncWrite(me) : return
    profile = m.writerProfile
    user = me.data
    if not dispatcharrAuthorityComparable(user) then finishDispatcharrSyncWrite({ok: false, state: "identity"}) : return
    if textValue(user.id) <> m.top.userScope.accountId or lcase(textValue(user.username)) <> lcase(profile.username)
        finishDispatcharrSyncWrite({ok: false, state: "identity"})
        return
    end if
    if textValue(m.top.expectedAuthorizationSignature) = "" then finishDispatcharrSyncWrite({ok: false, state: "authority"}) : return
    if dispatcharrAuthorizationSignature(user) <> m.top.expectedAuthorizationSignature
        finishDispatcharrSyncWrite({ok: false, state: "authority"})
        return
    end if
    key = dispatcharrSyncUserKey(user.username)
    m.writerOwnKey = key
    listing = syncWriterReadObject(m.top.baseUrl + "/api/accounts/users/me/app-data/", 65536)
    if not listing.ok then finishDispatcharrSyncWrite(listing) : return
    discovery = dispatcharrSyncReadPlan(key, listing.data)
    ' Missing canonical and legacy migration remain read-only, never empty-base
    ' creation. A listed canonical is independent of stranded legacy keys.
    if discovery.state <> "canonical" then finishDispatcharrSyncWrite({ok: false, state: discovery.state}) : return
    url = m.top.baseUrl + "/api/accounts/users/me/app-data/" + key + "/"
    latest = syncWriterReadObject(url, 131072)
    if not latest.ok then finishDispatcharrSyncWrite(latest) : return
    prepared = dispatcharrSyncPrepareProfilesWrite(latest.data, m.writerStore, m.top.profilesEnabled, CreateObject("roDateTime").asSeconds(), m.top.acknowledgedStamp, m.top.deviceId, m.top.appVersion)
    if not prepared.ok
        if type(prepared.localPlan) = "roAssociativeArray"
            finishDispatcharrSyncWrite(syncWriterLocalReadReceipt(latest.data, user))
        else
            finishDispatcharrSyncWrite(prepared)
        end if
        return
    end if
    if prepared.needsLocalCommit = true
        finishDispatcharrSyncWrite(syncWriterLocalReadReceipt(latest.data, user))
        return
    end if
    if not syncWriterAccessCurrent() then finishDispatcharrSyncWrite({ok: false, state: "stale-context"}) : return
    response = httpTransferOnce(url, invalid, "", 10000, 65536, "PUT", prepared.body)
    if not syncWriterAccessCurrent()
        finishDispatcharrSyncWrite({ok: false, state: "stale-context", submitted: true})
        return
    end if
    if response.error <> "" or response.status <> 200
        finishDispatcharrSyncWrite({ok: false, state: "pending", submitted: true})
        return
    end if
    finishDispatcharrSyncWrite({ok: true, state: "written", submitted: true, maximumSentStamp: prepared.maximumSentStamp, storeRoot: m.top.storeRoot, connectionRoot: m.top.connectionRoot, credentialHash: requestGateCredentialHash(m.key), scope: m.top.userScope})
end sub

' Every request rechecks exact saved roots, actual selected holder, own key,
' current adopted request nonce and broker. No default/target scope is invented.
function syncWriterAccessCurrent() as boolean
    if m.top.cancelRequested or m.top.profilesEnabled <> true then return false
    if type(m.top.userScope) <> "roAssociativeArray" then return false
    scope = m.top.userScope
    if userProfileLocalId(textValue(scope.sessionId)) = "" then return false
    if textValue(m.top.aeriosession) <> scope.sessionId or not requestGateTaskSessionCurrent() then return false
    if m.key = "" or m.writerRegistry = invalid then return false
    if m.writerRegistry.read("connectionsV1") <> m.top.connectionRoot then return false
    connections = loadConnectionStore(m.writerRegistry)
    if connections.readOnly = true or connections.selected <> scope.playlistId then return false
    entry = connectionStoreEntry(connections, scope.playlistId)
    if entry = invalid then return false
    if entry.provider <> "dispatcharr" or entry.url <> m.top.baseUrl then return false
    if m.writerRegistry.read(userProfileStoreKey(entry.id)) <> m.top.storeRoot then return false
    store = loadUserProfileStore(m.writerRegistry, entry.id)
    if store.readOnly = true or store.active <> scope.profileId or store.pendingRoster <> true then return false
    target = invalid
    for each profile in store.profiles
        if profile.addressHeld then return false
        if profile.id = store.active then target = profile
    end for
    if target = invalid then return false
    if target.role <> "admin" and target.role <> "user" then return false
    expected = userProfileSessionScope(entry, target.id, target.userId, textValue(scope.authorizationGeneration), scope.sessionId)
    if not userProfileSameSession(scope, expected) then return false
    memory = {}
    name = userProfileKeyName(entry.id, target.id)
    if target.isDefault then name = connectionRegistryKey(entry.id)
    if not entry.remember then memory[name] = m.key
    credential = userProfileCredential(m.writerRegistry, entry, store, memory)
    if not credential.ok then return false
    if credential.key <> m.key then return false
    if entry.remember
        if not m.writerRegistry.exists(name) or m.writerRegistry.read(name) <> m.key then return false
    end if
    if not requestGateAccessAllowed(entry.url, m.key) then return false
    m.writerStore = store
    m.writerProfile = target
    return true
end function

function syncWriterLocalReadReceipt(value as object, user as object) as object
    denied = {ok: false, state: "invalid", submitted: false}
    if not syncWriterAccessCurrent() then return denied
    read = dispatcharrSyncEnvelopeRead(value)
    if not read.ok or read.malformedCategories.count() > 0 then return denied
    data = {rows: []}
    if read.profilesState = "ready" then data = value["categories"]["profiles"]["data"]
    return {ok: false, state: "local-commit", submitted: false, readStatus: 200, profileData: data, authorizationSignature: dispatcharrAuthorizationSignature(user), storeRoot: m.top.storeRoot, connectionRoot: m.top.connectionRoot, credentialHash: requestGateCredentialHash(m.key), scope: m.top.userScope}
end function

function syncWriterReadObject(url as string, maxBytes as integer) as object
    denied = {ok: false, state: "unavailable"}
    if not syncWriterAccessCurrent() then return denied
    response = httpTransferOnce(url, invalid, "", 10000, maxBytes)
    if not syncWriterAccessCurrent() then return denied
    if response.error <> "" or response.status <> 200 then return denied
    if not CreateObject("roRegex", "^\s*\{", "").isMatch(response.body) then return denied
    value = invalid
    if m.syncJsonParser <> invalid
        value = m.syncJsonParser(response.body)
    else
        value = ParseJson(response.body, "d")
    end if
    if type(value) <> "roAssociativeArray" then return denied
    return {ok: true, data: value}
end function

sub finishDispatcharrSyncWrite(result as object)
    submitted = result.submitted = true
    if m.top.cancelRequested or not requestGateTaskSessionCurrent() then result = {ok: false, state: "stale", submitted: submitted}
    result.allowWrite = false
    result.submitted = submitted
    m.key = ""
    m.top.apiKey = ""
    m.writerStore = invalid
    m.writerProfile = invalid
    m.writerOwnKey = ""
    m.writerRegistry = invalid
    m.requestMode = invalid
    m.top.result = result
end sub
