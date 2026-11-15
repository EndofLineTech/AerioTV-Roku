' Local roster write highwater only. Never a credential, PIN grant, wire
' category, active selection or permission to replay a previously checked body.
function loadDispatcharrSyncRosterAck(registry as object, connection as object) as object
    denied = {ok: false, stamp: 0}
    key = userProfileSyncAckKey(connection.id)
    if key = "" then return denied
    if not registry.exists(key) then return {ok: true, stamp: 0}
    raw = registry.read(key)
    if raw = "" or userProfileUtf8ByteCount(raw) > 4096 then return denied
    ack = userProfileCanonicalFields(ParseJson(raw), ["schema", "playlistId", "baseUrl", "maximumSentStamp"])
    if ack = invalid then return denied
    if not userProfileInteger(ack.schema) then return denied
    if ack.schema <> 1 then return denied
    if GetInterface(ack.playlistId, "ifString") = invalid or GetInterface(ack.baseUrl, "ifString") = invalid then return denied
    if ack.playlistId <> connection.id then return denied
    if normalizeBaseUrl(ack.baseUrl) = "" or normalizeBaseUrl(ack.baseUrl) <> ack.baseUrl then return denied
    if not userProfileInteger(ack.maximumSentStamp) then return denied
    if ack.maximumSentStamp < 0 or ack.maximumSentStamp > 9007199254740991& then return denied
    if ack.baseUrl <> connection.url then return {ok: true, stamp: 0}
    return {ok: true, stamp: ack.maximumSentStamp}
end function

' Only the actual still-current writer's successful 200 may clear the exact
' captured dirty snapshot. New edits, successors and changed credentials retain
' pending data, even when an older PUT happened to succeed on the server.
function commitDispatcharrSyncRosterAck(registry as object, connection as object, previous as object, receipt as object, activeScope as dynamic, activeKey as string, memoryKeys as object) as object
    denied = {ok: false, recoveryRequired: false}
    if receipt.ok <> true or receipt.submitted <> true or receipt.state <> "written" then return denied
    if not userProfileSameSession(receipt.scope, activeScope) then return denied
    if connection.provider <> "dispatcharr" or previous.playlistId <> connection.id then return denied
    if GetInterface(receipt.connectionRoot, "ifString") = invalid or GetInterface(receipt.storeRoot, "ifString") = invalid then return denied
    if receipt.connectionRoot <> registry.read("connectionsV1") then return denied
    if receipt.storeRoot <> registry.read(userProfileStoreKey(connection.id)) then return denied
    connections = loadConnectionStore(registry)
    if connections.readOnly = true or connections.selected <> connection.id then return denied
    entry = connectionStoreEntry(connections, connection.id)
    if entry = invalid then return denied
    if FormatJson(entry) <> FormatJson(normalizeConnectionEntry(connection)) then return denied
    actual = loadUserProfileStore(registry, connection.id)
    if actual.readOnly = true or previous.readOnly = true or actual.pendingRoster <> true then return denied
    if FormatJson(actual) <> FormatJson(normalizeUserProfileStore(previous, connection.id)) then return denied
    target = invalid
    for each profile in actual.profiles
        if profile.addressHeld then return denied
        if profile.id = actual.active then target = profile
    end for
    if target = invalid then return denied
    if target.role <> "admin" and target.role <> "user" then return denied
    expected = userProfileSessionScope(entry, target.id, target.userId, textValue(activeScope.authorizationGeneration), textValue(activeScope.sessionId))
    if not userProfileSameSession(activeScope, expected) then return denied
    if not requestGateDigestValid(textValue(receipt.credentialHash)) then return denied
    if activeKey = "" or requestGateCredentialHash(activeKey) <> receipt.credentialHash then return denied
    memory = memoryKeys
    if entry.remember then memory = {}
    credential = userProfileCredential(registry, entry, actual, memory)
    if not credential.ok then return denied
    if credential.key <> activeKey then return denied
    if entry.remember
        if not registry.exists(credential.keyName) or registry.read(credential.keyName) <> activeKey then return denied
    end if
    if not requestGateAccessAllowed(entry.url, activeKey) then return denied
    if not userProfileInteger(receipt.maximumSentStamp) then return denied
    if receipt.maximumSentStamp < 0 or receipt.maximumSentStamp > 9007199254740991& then return denied
    old = loadDispatcharrSyncRosterAck(registry, entry)
    if not old.ok then return denied
    stamp = receipt.maximumSentStamp
    if old.stamp > stamp then stamp = old.stamp
    staged = setCanonicalPreference(actual, "pendingRoster", false)
    prepared = userProfileStoreChanges(registry, actual, staged, {}, true)
    if not prepared.ok then return denied
    ack = ParseJson("{}")
    ack["schema"] = 1
    ack["playlistId"] = entry.id
    ack["baseUrl"] = entry.url
    ack["maximumSentStamp"] = stamp
    encoded = strictJsonEncode(ack)
    if not encoded.ok then return denied
    prepared.changes[userProfileSyncAckKey(entry.id)] = encoded.text
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if not saved.ok then return saved
    saved.store = normalizeUserProfileStore(staged, entry.id)
    saved.acknowledgedStamp = stamp
    return saved
end function
