' Qualified own-canonical profiles writer. Explicit user consent and live
' Scene dirty/ack/protection/request gates remain mandatory.
sub init()
    m.top.functionName = "writeDispatcharrSync"
    m.syncWriterReady = false
    if userProfileReleaseFeaturesReady() then m.syncWriterReady = true
    if CreateObject("roAppInfo").getValue("aeriotv_profiles_baseline") = "1" then m.syncWriterReady = true
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
    me = syncWriterReadObject(m.top.baseUrl + "/api/accounts/users/me/", 65536, false, "me")
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
    listing = syncWriterReadObject(m.top.baseUrl + "/api/accounts/users/me/app-data/", 65536, false, "list")
    if not listing.ok then finishDispatcharrSyncWrite(listing) : return
    discovery = dispatcharrSyncReadPlan(key, listing.data)
    ' Legacy-only discovery stays read-only. A fresh typed key-not-found response
    ' may start a new canonical only when this same list proves NO legacy keys.
    if discovery.state <> "canonical" and discovery.state <> "missing" then finishDispatcharrSyncWrite({ok: false, state: discovery.state}) : return
    url = m.top.baseUrl + "/api/accounts/users/me/app-data/" + key + "/"
    latest = syncWriterReadObject(url, 131072, discovery.legacy.count() = 0)
    if not latest.ok then finishDispatcharrSyncWrite(latest) : return
    if latest.state = "missing" and m.top.creationBlocked = true and m.top.pullOnly <> true
        finishDispatcharrSyncWrite({ok: false, state: "storage-full", phase: "create-blocked", submitted: false})
        return
    end if
    if latest.state = "missing" then latest.data = syncWriterMissingEnvelope()
    if m.top.pullOnly = true
        finishDispatcharrSyncWrite(syncWriterLocalReadReceipt(latest.data, user))
        return
    end if
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
    if prepared.unchanged = true
        finishDispatcharrSyncWrite({ok: true, state: "unchanged", submitted: false, readStatus: 200, maximumSentStamp: prepared.maximumSentStamp, storeRoot: m.top.storeRoot, connectionRoot: m.top.connectionRoot, credentialHash: requestGateCredentialHash(m.key), scope: m.top.userScope})
        return
    end if
    budget = dispatcharrSyncWriteBudget(listing.data, key, prepared.bytes)
    if not budget.ok then finishDispatcharrSyncWrite(budget) : return
    response = httpTransferOnce(url, invalid, "", 10000, 65536, "PUT", prepared.body)
    failure = invalid
    if response.status = 409 then failure = syncWriterResponseFailure("put", response)
    if failure <> invalid and failure.creationBlocked = true
        ' A confirmed max_apps applies to the own account, not the submitted
        ' roster bytes. This failure receipt is never a write acknowledgement.
        if syncWriterAccessCurrent(false)
            if dispatcharrSyncUserKey(m.writerProfile.username) = key
                failure.scope = m.top.userScope
                failure.connectionRoot = m.top.connectionRoot
                failure.credentialHash = requestGateCredentialHash(m.key)
                failure.canonicalKey = key
                finishDispatcharrSyncWrite(failure)
                return
            end if
        end if
        finishDispatcharrSyncWrite({ok: false, state: "stale-context", submitted: true})
        return
    end if
    if not syncWriterAccessCurrent()
        finishDispatcharrSyncWrite({ok: false, state: "stale-context", submitted: true})
        return
    end if
    if response.error <> "" or response.status <> 200
        if failure = invalid then failure = syncWriterResponseFailure("put", response)
        finishDispatcharrSyncWrite(failure)
        return
    end if
    finishDispatcharrSyncWrite({ok: true, state: "written", submitted: true, maximumSentStamp: prepared.maximumSentStamp, storeRoot: m.top.storeRoot, connectionRoot: m.top.connectionRoot, credentialHash: requestGateCredentialHash(m.key), scope: m.top.userScope})
end sub

' Every request rechecks exact saved roots, actual selected holder, own key,
' current adopted request nonce and broker. No default/target scope is invented.
function syncWriterAccessCurrent(requireRosterSnapshot = true as boolean) as boolean
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
    if requireRosterSnapshot and m.writerRegistry.read(userProfileStoreKey(entry.id)) <> m.top.storeRoot then return false
    store = loadUserProfileStore(m.writerRegistry, entry.id)
    if store.readOnly = true or store.active <> scope.profileId then return false
    if requireRosterSnapshot and m.top.pullOnly <> true
        if store.rosterPullRequired = true or store.pendingRoster <> true then return false
    end if
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

function syncWriterReadObject(url as string, maxBytes as integer, allowMissing = false as boolean, phase = "key" as string) as object
    denied = {ok: false, state: "unavailable"}
    if not syncWriterAccessCurrent() then return denied
    response = httpTransferOnce(url, invalid, "", 10000, maxBytes)
    if not syncWriterAccessCurrent() then return denied
    if response.error <> "" then return syncWriterResponseFailure(phase, response)
    if response.status <> 200 and (response.status <> 404 or not allowMissing) then return syncWriterResponseFailure(phase, response)
    if not CreateObject("roRegex", "^\s*\{", "").isMatch(response.body) then return denied
    value = invalid
    if m.syncJsonParser <> invalid
        value = m.syncJsonParser(response.body)
    else
        value = ParseJson(response.body, "d")
    end if
    if type(value) <> "roAssociativeArray" then return denied
    if response.status = 404
        if GetInterface(value["code"], "ifString") = invalid then return denied
        if value["code"] <> "key_not_found" then return denied
        return {ok: true, state: "missing"}
    end if
    return {ok: true, data: value}
end function

function syncWriterResponseFailure(phase as string, response as object) as object
    code = ""
    if CreateObject("roRegex", "^\s*\{", "").isMatch(response.body)
        value = invalid
        if m.syncJsonParser <> invalid
            value = m.syncJsonParser(response.body)
        else
            value = ParseJson(response.body, "d")
        end if
        if type(value) = "roAssociativeArray"
            if GetInterface(value["code"], "ifString") <> invalid then code = value["code"]
        end if
    end if
    return dispatcharrSyncFailure(phase, response.status, code, textValue(response.error))
end function

' Used only AFTER this own session's successful no-legacy list and typed 404.
' Never substitutes for an unreadable registry root, failed GET or legacy data.
function syncWriterMissingEnvelope() as object
    clock = CreateObject("roDateTime")
    value = ParseJson("{}")
    value["schemaVersion"] = 3
    value["deviceId"] = m.top.deviceId
    value["platform"] = "roku"
    value["appVersion"] = m.top.appVersion
    value["updatedAt"] = left(clock.toISOString(), 19) + "Z"
    value["categories"] = ParseJson("{}")
    return value
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
