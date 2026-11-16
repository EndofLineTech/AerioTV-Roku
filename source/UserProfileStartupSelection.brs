' Startup picker admission is neither an authenticated chosen switch nor an
' unavailable-Child escape. No outgoing actor/key exists, and this preflight
' neither selects a persisted holder nor creates a session or a PIN grant.
function userProfileStartupSelectionCurrent(registry as object, context as object, activeNonce as string, activeScope as dynamic, activeKey as string, memoryKeys as object, requirePin as boolean) as boolean
    if not userProfileStartupSelectionStorageCurrent(registry, context, activeNonce, activeScope, activeKey, memoryKeys, requirePin) then return false
    return requestGateAccessAllowed(context.connection.url, context.key)
end function

' Ownership of an already-completed failure is not permission to start another
' request. A key hold/429 can close transport while its own result still needs
' consuming. Only failure handling uses this broker-independent boundary.
function userProfileStartupSelectionStorageCurrent(registry as object, context as object, activeNonce as string, activeScope as dynamic, activeKey as string, memoryKeys as object, requirePin as boolean) as boolean
    if activeScope <> invalid or activeKey <> "" then return false
    if context.purpose <> "startup-picker" then return false
    if userProfileLocalId(textValue(context.nonce)) = "" or context.nonce <> activeNonce then return false
    if type(context.connection) <> "roAssociativeArray" or type(context.store) <> "roAssociativeArray" or type(context.target) <> "roAssociativeArray" then return false
    connection = context.connection
    if connection.provider <> "dispatcharr" or connection.id <> context.store.playlistId then return false
    if GetInterface(context.connectionRoot, "ifString") = invalid or GetInterface(context.storeRoot, "ifString") = invalid then return false
    if context.connectionRootPresent <> registry.exists("connectionsV1") or context.connectionRoot <> registry.read("connectionsV1") then return false
    connections = loadConnectionStore(registry)
    if connections.readOnly = true or connections.selected <> connection.id then return false
    currentConnection = connectionStoreEntry(connections, connection.id)
    if currentConnection = invalid then return false
    if FormatJson(currentConnection) <> FormatJson(normalizeConnectionEntry(connection)) then return false
    rootKey = userProfileStoreKey(connection.id)
    if not registry.exists(rootKey) or registry.read(rootKey) <> context.storeRoot then return false
    store = loadUserProfileStore(registry, connection.id)
    if store.readOnly = true or FormatJson(store) <> FormatJson(context.store) then return false
    if store.askAtLaunch <> true or store.profiles.count() < 2 then return false
    restored = invalid
    target = invalid
    for each profile in store.profiles
        if profile.id = store.active then restored = profile
        if profile.id = context.target.id then target = profile
    end for
    if restored = invalid or target = invalid then return false
    if not userProfileFullAccess(restored.role) then return false
    if FormatJson(target) <> FormatJson(context.target) or target.addressHeld then return false
    ' Incoming Child activation remains separately fenced until its picker
    ' admission and changed-protection continuations have native qualification.
    if not userProfileFullAccess(target.role) then return false
    if requirePin and target.pinType <> "none"
        if not userProfilePinGrantMatches(context.pin, connection.id, target) then return false
    end if
    selected = setCanonicalPreference(store, "active", target.id)
    memory = memoryKeys
    if connection.remember then memory = {}
    credential = userProfileCredential(registry, connection, selected, memory)
    if not credential.ok or credential.profileId <> target.id then return false
    if credential.key <> context.key then return false
    if connection.remember
        if not registry.exists(credential.keyName) or registry.read(credential.keyName) <> credential.key then return false
    end if
    return true
end function

' Called only for the actual current read Task after retained protection has
' been published and the target PIN still matches. The Scene owns readNonce:
' a changed/imported PIN must retire the old read and perform a new one.
' Receipt and key are memory-only; neither is registry or App Data metadata.
function userProfileStartupProtectionReceipt(context as object, read as object, readNonce as string) as dynamic
    if context.purpose <> "startup-picker" then return invalid
    if userProfileLocalId(textValue(context.nonce)) = "" then return invalid
    if userProfileLocalId(readNonce) = "" or readNonce <> textValue(context.readNonce) then return invalid
    if read.ok <> true then return invalid
    if read.state <> "missing" and read.state <> "legacy" and read.state <> "ready" then return invalid
    if read.state = "ready" and read.profilesState <> "ready" and read.profilesState <> "absent" then return invalid
    if not dispatcharrAuthorityComparable(read.verifiedUser) then return invalid
    if read.verifiedBaseUrl <> context.connection.url then return invalid
    target = context.target
    if type(target) <> "roAssociativeArray" then return invalid
    if textValue(read.accountId) <> target.userId.toStr() or textValue(read.verifiedUser.id) <> target.userId.toStr() then return invalid
    if lcase(textValue(read.accountUsername)) <> lcase(target.username) or lcase(textValue(read.verifiedUser.username)) <> lcase(target.username) then return invalid
    if target.pinType <> "none"
        if not userProfilePinGrantMatches(context.pin, context.connection.id, target) then return invalid
    end if
    if textValue(context.key) = "" or textValue(context.storeRoot) = "" then return invalid
    return {purpose: "startup-protection", nonce: context.nonce, readNonce: readNonce, storeRoot: context.storeRoot, target: FormatJson(target), key: context.key, authorizationSignature: dispatcharrAuthorizationSignature(read.verifiedUser)}
end function

' The target is published only after its own completed protection read AND full
' verified lineup. Reuse content/settings transaction mechanics, never the
' chosen-switch, unavailable-Child or system-retirement admission wrappers.
function commitUserProfileStartupSelection(registry as object, context as object, verified as object, activeNonce as string, activeScope as dynamic, activeKey as string, memoryKeys as object) as object
    denied = {ok: false, recoveryRequired: false, reason: "startup-selection-context"}
    if not userProfileStartupSelectionCurrent(registry, context, activeNonce, activeScope, activeKey, memoryKeys, true) then return denied
    receipt = context.protectionReceipt
    if type(receipt) <> "roAssociativeArray" then return denied
    if receipt.purpose <> "startup-protection" or receipt.nonce <> context.nonce then return denied
    if userProfileLocalId(textValue(context.readNonce)) = "" or receipt.readNonce <> context.readNonce then return denied
    if receipt.storeRoot <> context.storeRoot or receipt.target <> FormatJson(context.target) or receipt.key <> context.key then return denied
    if verified.verifiedBaseUrl <> context.connection.url or verified.apiKey <> context.key then return denied
    if not dispatcharrAuthorityComparable(verified.verifiedUser) then return denied
    if textValue(receipt.authorizationSignature) = "" or receipt.authorizationSignature <> dispatcharrAuthorizationSignature(verified.verifiedUser) then return denied
    planned = userProfileVerifiedSwitchContentPlan(context.connection, context.store, context.target.id, verified, context.nonce)
    if not planned.ok then return {ok: false, recoveryRequired: false, reason: planned.reason}
    return commitPlannedUserProfileSwitchState(registry, context.connection, context.store, context.target.id, verified, planned)
end function

' Retained protection publication BEFORE startup adoption. Unlike a live switch,
' there is no authenticated actor to tear down or flush. Exact absent actor/key
' admission therefore permits atomic removed-holder cleanup in this transaction.
' The returned context/receipt is memory-only and must replace the captured one
' only after success. A changed PIN needs a real new PIN and another readNonce.
function commitUserProfileStartupRosterPull(registry as object, context as object, read as object, readNonce as string, enabled as boolean, now as integer, activeNonce as string, activeScope as dynamic, activeKey as string, memoryKeys as object) as object
    denied = {ok: false, recoveryRequired: false, reason: "startup-roster-context"}
    if now <= 0 then return denied
    if not userProfileStartupSelectionCurrent(registry, context, activeNonce, activeScope, activeKey, memoryKeys, true) then return denied
    if userProfileStartupProtectionReceipt(context, read, readNonce) = invalid then return denied
    working = normalizeUserProfileStore(context.store, context.connection.id)
    facts = userProfileFromVerified(context.connection.id, context.target.id, read.verifiedUser, now)
    if facts = invalid then return denied
    for i = 0 to working.profiles.count() - 1
        profile = working.profiles[i]
        if profile.id = context.target.id
            role = userProfileResolveRole(facts.userLevel, profile.role)
            if role <> profile.role
                if now <= profile.updatedAt then return denied
                profile = setCanonicalPreference(profile, "updatedAt", now)
                working = setCanonicalPreference(working, "pendingRoster", true)
            end if
            for each field in ["userLevel", "isStaff", "isSuperuser"]
                profile = setCanonicalPreference(profile, field, facts[field])
            end for
            profile = setCanonicalPreference(profile, "role", role)
            working.profiles[i] = profile
        end if
    end for
    if context.target.isDefault
        checked = userProfileDefaultAddressCheck(context.connection, working, read)
        if not checked.ok then return denied
        recorded = userProfileRecordDefaultIdentity(checked.store, working.doesExist("addressChangeSnapshot"))
        if not recorded.ok then return denied
        working = recorded.store
    end if
    plan = {ok: true, store: working, removed: [], suggestions: []}
    if read.state = "ready" and read.profilesState = "ready"
        decoded = dispatcharrSyncRosterDecode(read.data["categories"]["profiles"]["data"])
        if not decoded.ok then return denied
        ' The reader's role controls import, not the restored selection's role.
        staging = setCanonicalPreference(working, "active", context.target.id)
        plan = dispatcharrSyncRosterMerge(staging, decoded, enabled, now)
        if not plan.ok then return denied
    end if
    sourceRemoved = false
    targetRemoved = false
    for each profile in plan.removed
        if profile.isDefault then return denied
        if profile.id = context.store.active then sourceRemoved = true
        if profile.id = context.target.id then targetRemoved = true
    end for
    selectedId = context.store.active
    if sourceRemoved
        for each profile in plan.store.profiles
            if profile.isDefault then selectedId = profile.id
        end for
    end if
    candidate = setCanonicalPreference(plan.store, "active", selectedId)
    candidate = setCanonicalPreference(candidate, "pendingRoster", context.store.pendingRoster or candidate.pendingRoster)
    ' A read may learn protection, not acknowledge the captured writer's local
    ' tombstones or pending intent. Those require its actual write settlement.
    candidate = setCanonicalPreference(candidate, "removed", context.store.removed)
    candidate = normalizeUserProfileStore(candidate, context.connection.id)
    if candidate.readOnly = true then return denied
    prepared = userProfileStoreChanges(registry, context.store, candidate, {}, true)
    if not prepared.ok then return denied
    for each profile in plan.removed
        holdKey = userProfilePinBackoffKey(context.connection.id, profile.id)
        if registry.exists(holdKey) then prepared.changes[holdKey] = ""
    end for
    if plan.removed.count() > 0 and registry.exists("settingsV1")
        preferences = loadStrictPreferenceStore(registry)
        if preferences.readOnly = true then return denied
        if not userProfileInteger(preferences.schema) then return denied
        if preferences.schema <> 1 or type(preferences.accounts) <> "roAssociativeArray" or type(preferences.device) <> "roAssociativeArray" then return denied
        for each profile in plan.removed
            identity = userProfilePreferenceIdentity(context.connection, profile)
            if identity = "" then return denied
            preferences.accounts.delete(preferenceScope(identity))
        end for
        encoded = strictJsonEncode(preferences)
        if not encoded.ok then return denied
        if preferenceByteBudget(encoded.text) > 24000 then return denied
        prepared.changes["settingsV1"] = encoded.text
    end if
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if not saved.ok then return saved
    target = invalid
    sourceChild = false
    for each profile in candidate.profiles
        if profile.id = context.target.id then target = profile
        if profile.id = candidate.active then sourceChild = profile.role = "child"
    end for
    result = {ok: true, recoveryRequired: false, store: candidate, target: target, removed: plan.removed, suggestions: plan.suggestions, targetRemoved: targetRemoved, sourceRemoved: sourceRemoved, sourceChild: sourceChild, requiresPin: false, protectionReceipt: invalid}
    if target = invalid then return result
    nextContext = copyPreferenceValue(context)
    ' A native verified grant is an opaque case-insensitive runtime proof, not
    ' settings JSON. Deep-copying its literal keys into a case-sensitive AA
    ' changes bracket lookup semantics and must not replace the actual grant.
    nextContext.pin = context.pin
    nextContext.store = candidate
    nextContext.storeRoot = registry.read(userProfileStoreKey(context.connection.id))
    nextContext.target = target
    nextContext.protectionReceipt = invalid
    result.context = nextContext
    if target.pinType <> "none" then result.requiresPin = not userProfilePinGrantMatches(context.pin, context.connection.id, target)
    if not sourceRemoved and not result.requiresPin and not sourceChild and userProfileFullAccess(target.role)
        result.protectionReceipt = userProfileStartupProtectionReceipt(nextContext, read, readNonce)
        result.context.protectionReceipt = result.protectionReceipt
    end if
    return result
end function
