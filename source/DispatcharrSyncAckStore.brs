' Local roster write highwater only. Never a credential, PIN grant, wire
' category, active selection or permission to replay a previously checked body.
function ensureDispatcharrSyncDeviceIdentity(registry as object, candidate as string) as object
    denied = {ok: false, recoveryRequired: false, id: ""}
    key = "dispatcharrSyncDeviceV1"
    if registry.exists(key)
        existing = registry.read(key)
        if userProfileLocalId(existing) = "" then return {ok: false, recoveryRequired: true, id: ""}
        return {ok: true, recoveryRequired: false, id: existing}
    end if
    id = userProfileLocalId(candidate)
    if id = "" then return denied
    changes = {}
    changes[key] = id
    saved = userProfileRegistryTransaction(registry, changes)
    if not saved.ok then return saved
    return {ok: true, recoveryRequired: false, id: id}
end function

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

' Only the actual still-current writer's successful PUT or exact unchanged GET
' acknowledgement may clear the exact
' captured dirty snapshot. New edits, successors and changed credentials retain
' pending data, even when an older PUT happened to succeed on the server.
function commitDispatcharrSyncRosterAck(registry as object, connection as object, previous as object, receipt as object, activeScope as dynamic, activeKey as string, memoryKeys as object) as object
    denied = {ok: false, recoveryRequired: false}
    if receipt.ok <> true then return denied
    if receipt.state = "written"
        if receipt.submitted <> true then return denied
    else if receipt.state = "unchanged"
        if not userProfileBoolean(receipt.submitted) then return denied
        if receipt.submitted then return denied
        if not userProfileInteger(receipt.readStatus) then return denied
        if receipt.readStatus <> 200 then return denied
    else
        return denied
    end if
    access = dispatcharrSyncOwnReceiptAccess(registry, connection, previous, receipt, activeScope, activeKey, memoryKeys)
    if not access.ok then return denied
    actual = access.store
    entry = access.connection
    if not userProfileInteger(receipt.maximumSentStamp) then return denied
    if receipt.maximumSentStamp < 0 or receipt.maximumSentStamp > 9007199254740991& then return denied
    old = loadDispatcharrSyncRosterAck(registry, entry)
    if not old.ok then return denied
    stamp = receipt.maximumSentStamp
    if old.stamp > stamp then stamp = old.stamp
    staged = setCanonicalPreference(actual, "pendingRoster", false)
    ' This exact snapshot was carried in the checked plan (or superseded or
    ' expired during merge). Never clear intent from a newer roster root.
    staged = setCanonicalPreference(staged, "removed", [])
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

' Shared current-own-storage proof; neither read publication nor successful PUT
' acknowledgement may substitute a target/default scope or cached credential.
function dispatcharrSyncOwnReceiptAccess(registry as object, connection as object, previous as object, receipt as object, activeScope as dynamic, activeKey as string, memoryKeys as object, requirePending = true as boolean) as object
    denied = {ok: false}
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
    if actual.readOnly = true or previous.readOnly = true then return denied
    if requirePending and actual.pendingRoster <> true then return denied
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
    return {ok: true, store: actual, connection: entry}
end function

' A fresh successful GET may import protection/metadata before a separate fresh
' re-read and PUT. It never clears dirty intent or manufactures a 200 write ack.
function commitDispatcharrSyncRosterRead(registry as object, connection as object, previous as object, receipt as object, activeScope as dynamic, activeKey as string, memoryKeys as object, authorizationSignature as string, enabled as boolean, now as integer) as object
    denied = {ok: false, recoveryRequired: false}
    access = dispatcharrSyncOwnReadAccess(registry, connection, previous, receipt, activeScope, activeKey, memoryKeys, authorizationSignature, enabled, now)
    if not access.ok then return denied
    decoded = access.decoded
    plan = dispatcharrSyncRosterMerge(access.store, decoded, enabled, now)
    if not plan.ok then return denied
    saved = commitDispatcharrRosterPull(registry, access.connection, access.store, decoded, enabled, now, receipt.scope, activeScope)
    if saved.ok
        saved.readCommitted = true
        saved.removed = plan.removed
        if registry.exists("settingsV1") then saved.preferenceStore = saved.preferences
    end if
    return saved
end function

function dispatcharrSyncOwnReadAccess(registry as object, connection as object, previous as object, receipt as object, activeScope as dynamic, activeKey as string, memoryKeys as object, authorizationSignature as string, enabled as boolean, now as integer) as object
    denied = {ok: false}
    if receipt.state <> "local-commit" or not enabled or now <= 0 then return denied
    if not userProfileBoolean(receipt.ok) or not userProfileBoolean(receipt.submitted) then return denied
    if receipt.ok or receipt.submitted then return denied
    if not userProfileInteger(receipt.readStatus) then return denied
    if receipt.readStatus <> 200 then return denied
    if authorizationSignature = "" or GetInterface(receipt.authorizationSignature, "ifString") = invalid then return denied
    if receipt.authorizationSignature <> authorizationSignature then return denied
    access = dispatcharrSyncOwnReceiptAccess(registry, connection, previous, receipt, activeScope, activeKey, memoryKeys, false)
    if not access.ok then return denied
    decoded = dispatcharrSyncRosterDecode(receipt.profileData)
    if not decoded.ok then return denied
    access.decoded = decoded
    return access
end function

' Distinct ACTUAL-own admission. Never borrow the staged incoming target's key,
' invent an outgoing scope, or turn a GET into a successful write receipt.
function commitDispatcharrOwnRetirementSelection(registry as object, connection as object, previous as object, receipt as object, activeScope as dynamic, activeKey as string, memoryKeys as object, authorizationSignature as string, enabled as boolean, now as integer, intentId as string) as object
    denied = {ok: false, selected: false, recoveryRequired: false}
    if userProfileLocalId(intentId) = "" then return denied
    access = dispatcharrSyncOwnReadAccess(registry, connection, previous, receipt, activeScope, activeKey, memoryKeys, authorizationSignature, enabled, now)
    if not access.ok then return denied
    if intentId = activeScope.sessionId then return denied
    plan = dispatcharrSyncRosterMerge(access.store, access.decoded, enabled, now)
    selected = dispatcharrSyncDefaultRetirementSelectedStore(access.store, plan)
    if selected = invalid then return denied
    if selected.active = access.store.active then return denied
    journal = userProfilePrepareRetirementJournal(access.connection, access.store, access.decoded, plan, intentId)
    if not journal.ok then return denied
    root = FormatJson(selected)
    if userProfileUtf8ByteCount(root) > 8192 then return denied
    changes = {}
    changes[userProfileStoreKey(connection.id)] = root
    changes[userProfileRetirementKey(connection.id)] = journal.root
    saved = userProfileRegistryTransaction(registry, changes)
    if not saved.ok then return saved
    return {ok: true, selected: true, store: selected, selectionRoot: root, journalRoot: journal.root, outgoingId: previous.active, defaultId: selected.active, plannedAt: now, nonce: intentId, sourceRoster: FormatJson(previous), sourceReceipt: FormatJson(receipt)}
end function

' Live-only settlement of an already committed actual-own intent. Cold recovery
' deliberately uses resumeUserProfileRetirement directly and grants no adoption.
function commitDispatcharrOwnRetirementCleanup(registry as object, connection as object, previous as object, selection as object, receipt as object, activeScope as dynamic, activeKey as string, memoryKeys as object, authorizationSignature as string, enabled as boolean, now as integer, intentId as string) as object
    denied = {ok: false, committed: false, recoveryRequired: false}
    if activeScope <> invalid or activeKey <> "" or not enabled then return denied
    if selection.ok <> true or selection.selected <> true then return denied
    if userProfileLocalId(intentId) = "" or selection.nonce <> intentId then return denied
    if not userProfileInteger(selection.plannedAt) then return denied
    if selection.plannedAt <= 0 or selection.plannedAt > now then return denied
    if selection.sourceRoster <> FormatJson(previous) or selection.sourceReceipt <> FormatJson(receipt) then return denied
    if receipt.authorizationSignature <> authorizationSignature or authorizationSignature = "" then return denied
    if receipt.connectionRoot <> registry.read("connectionsV1") then return denied
    original = normalizeUserProfileStore(ParseJson(receipt.storeRoot), connection.id)
    if original.readOnly = true or FormatJson(original) <> FormatJson(normalizeUserProfileStore(previous, connection.id)) then return denied
    credential = userProfileCredential(registry, connection, original, memoryKeys)
    if not credential.ok then return denied
    if requestGateCredentialHash(credential.key) <> receipt.credentialHash then return denied
    if connection.remember
        if not registry.exists(credential.keyName) or registry.read(credential.keyName) <> credential.key then return denied
    end if
    if not requestGateAccessAllowed(connection.url, credential.key) then return denied
    decoded = dispatcharrSyncRosterDecode(receipt.profileData)
    plan = dispatcharrSyncRosterMerge(original, decoded, enabled, selection.plannedAt)
    expected = dispatcharrSyncDefaultRetirementSelectedStore(original, plan)
    if expected = invalid then return denied
    if selection.outgoingId <> original.active or selection.defaultId <> expected.active then return denied
    if FormatJson(expected) <> selection.selectionRoot or FormatJson(selection.store) <> selection.selectionRoot then return denied
    if registry.read(userProfileStoreKey(connection.id)) <> selection.selectionRoot then return denied
    journal = userProfilePrepareRetirementJournal(connection, original, decoded, plan, intentId)
    if not journal.ok then return denied
    if journal.root <> selection.journalRoot or registry.read(userProfileRetirementKey(connection.id)) <> selection.journalRoot then return denied
    saved = resumeUserProfileRetirement(registry, connection, invalid, "")
    if not saved.ok then return saved
    saved.committed = true
    saved.needsDefaultSwitch = true
    saved.removed = plan.removed
    return saved
end function
