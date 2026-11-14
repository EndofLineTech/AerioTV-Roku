' Internal metadata-only switch admission. Actual auth/read node ownership and
' the incoming scrim belong to the controller; this never fabricates a target
' session, writes App Data, changes credentials, or performs tombstone cleanup.
function commitDispatcharrSwitchRosterPull(registry as object, context as object, verified as object, decoded as object, enabled as boolean, now as integer, activeNonce as string, activeOutgoing as dynamic, memoryKeys as object) as object
    denied = {ok: false, applied: false, committed: false, recoveryRequired: false, reason: "stale-context", needsDefaultSwitch: false}
    if type(context.connection) <> "roAssociativeArray" or type(context.store) <> "roAssociativeArray" or type(context.target) <> "roAssociativeArray" then return denied
    if GetInterface(context.nonce, "ifString") = invalid then return denied
    entry = context.connection
    plan = dispatcharrSyncSwitchRosterPlan(entry, context.store, context.target.id, verified, decoded, enabled, now, context.nonce, activeNonce, context.outgoing, activeOutgoing)
    if not plan.ok
        denied.reason = plan.reason
        denied.needsDefaultSwitch = plan.needsDefaultSwitch
        return denied
    end if
    if not dispatcharrSyncSwitchRosterAccessCurrent(registry, context, verified, now, activeNonce, activeOutgoing, memoryKeys) then return denied
    return dispatcharrSyncCommitSwitchRosterMetadata(registry, context, plan)
end function

' A selected target is not the active actor during early own-roster discovery.
' Retiring that target therefore preserves the actual outgoing holder; only an
' actual outgoing tombstone needs a default switch first. No target scope/PIN
' grant is fabricated to authorize its key/backoff/preference cleanup.
function commitDispatcharrSwitchTargetRetirement(registry as object, context as object, verified as object, decoded as object, enabled as boolean, now as integer, activeNonce as string, activeOutgoing as dynamic, activeKey as string, memoryKeys as object) as object
    denied = {ok: false, applied: false, committed: false, recoveryRequired: false, reason: "stale-context", needsDefaultSwitch: false}
    if type(context.connection) <> "roAssociativeArray" or type(context.store) <> "roAssociativeArray" or type(context.target) <> "roAssociativeArray" then return denied
    if context.unavailableChild = true
        if not dispatcharrSyncUnavailableChildRosterAccessCurrent(registry, context, verified, now, activeNonce, activeOutgoing, activeKey, memoryKeys) then return denied
    else
        if not dispatcharrSyncSwitchRosterAccessCurrent(registry, context, verified, now, activeNonce, activeOutgoing, memoryKeys) then return denied
    end if
    working = normalizeUserProfileStore(context.store, context.connection.id)
    if working.readOnly = true then return denied
    plan = dispatcharrSyncSwitchRosterContentPlan(context.connection, working, context.target.id, verified, decoded, enabled, now, true)
    if not plan.ok
        denied.reason = plan.reason
        denied.needsDefaultSwitch = plan.needsDefaultSwitch
        return denied
    end if
    if not plan.applied or plan.targetRemoved <> true then return denied
    prepared = dispatcharrSyncPrepareSwitchRosterCleanup(registry, context.connection, context.store, plan)
    if not prepared.ok
        denied.recoveryRequired = prepared.recoveryRequired = true
        if prepared.reason = "preferences" then denied.reason = "preferences"
        return denied
    end if
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if not saved.ok
        denied.reason = "storage"
        denied.recoveryRequired = saved.recoveryRequired
        return denied
    end if
    plan.committed = true
    plan.recoveryRequired = false
    if type(prepared.preferenceStore) = "roAssociativeArray" then plan.preferenceStore = prepared.preferenceStore
    return plan
end function

' Explicit inactive-only cleanup after the metadata-only path reports
' cleanup-required. Active/target/default retirement is never authorized here.
function commitDispatcharrSwitchRosterCleanup(registry as object, context as object, verified as object, decoded as object, enabled as boolean, now as integer, activeNonce as string, activeOutgoing as dynamic, activeKey as string, memoryKeys as object) as object
    denied = {ok: false, applied: false, committed: false, recoveryRequired: false, reason: "stale-context", needsDefaultSwitch: false}
    if type(context.connection) <> "roAssociativeArray" or type(context.store) <> "roAssociativeArray" or type(context.target) <> "roAssociativeArray" then return denied
    if GetInterface(context.nonce, "ifString") = invalid then return denied
    if context.unavailableChild = true
        if not dispatcharrSyncUnavailableChildRosterAccessCurrent(registry, context, verified, now, activeNonce, activeOutgoing, activeKey, memoryKeys) then return denied
        admin = userProfileLoadDeviceAdminPin(registry, context.connection.id)
        if not admin.ok then return denied
        plan = dispatcharrSyncUnavailableChildRosterPlan(context.connection, context.store, context.target.id, verified, decoded, enabled, now, context.nonce, activeNonce, activeOutgoing, activeKey, admin.record, context.management, textValue(context.managementNonce))
    else
        if not dispatcharrSyncSwitchRosterAccessCurrent(registry, context, verified, now, activeNonce, activeOutgoing, memoryKeys) then return denied
        plan = dispatcharrSyncSwitchRosterPlan(context.connection, context.store, context.target.id, verified, decoded, enabled, now, context.nonce, activeNonce, context.outgoing, activeOutgoing)
    end if
    if not plan.ok
        denied.reason = plan.reason
        denied.needsDefaultSwitch = plan.needsDefaultSwitch
        return denied
    end if
    if not plan.applied or plan.removed.count() = 0 then return denied
    for each profile in plan.removed
        if profile.isDefault or profile.id = context.store.active or profile.id = context.target.id then return denied
    end for
    prepared = dispatcharrSyncPrepareSwitchRosterCleanup(registry, context.connection, context.store, plan)
    if not prepared.ok
        denied.recoveryRequired = prepared.recoveryRequired = true
        if prepared.reason = "preferences" then denied.reason = "preferences"
        return denied
    end if
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if not saved.ok
        denied.reason = "storage"
        denied.recoveryRequired = saved.recoveryRequired
        return denied
    end if
    plan.committed = true
    plan.recoveryRequired = false
    if type(prepared.preferenceStore) = "roAssociativeArray" then plan.preferenceStore = prepared.preferenceStore
    return plan
end function

' Prepare only removed holders' keys, backoff and preference blobs. Remember
' policy repair is deliberately NOT part of an incoming own-roster cleanup.
function dispatcharrSyncPrepareSwitchRosterCleanup(registry as object, connection as object, previous as object, plan as object) as object
    denied = {ok: false}
    if plan.store.active <> previous.active then return denied
    prepared = userProfileStoreChanges(registry, previous, plan.store, {}, true)
    if not prepared.ok then return denied
    for each profile in plan.removed
        if profile.isDefault or profile.id = previous.active then return denied
        pinHold = userProfilePinBackoffKey(connection.id, profile.id)
        if registry.exists(pinHold) then prepared.changes[pinHold] = ""
    end for
    if registry.exists("settingsV1")
        unreadable = {ok: false, recoveryRequired: true, reason: "preferences"}
        preferences = loadStrictPreferenceStore(registry)
        if preferences.readOnly = true then return unreadable
        if type(preferences) <> "roAssociativeArray" then return unreadable
        if not userProfileInteger(preferences.schema) then return unreadable
        if preferences.schema <> 1 or type(preferences.accounts) <> "roAssociativeArray" or type(preferences.device) <> "roAssociativeArray" then return unreadable
        for each profile in plan.removed
            identity = userProfilePreferenceIdentity(connection, profile)
            if identity = "" then return denied
            preferences.accounts.delete(preferenceScope(identity))
        end for
        encoded = strictJsonEncode(preferences)
        if not encoded.ok then return unreadable
        if preferenceByteBudget(encoded.text) > 24000 then return unreadable
        prepared.changes["settingsV1"] = encoded.text
        prepared.preferenceStore = preferences
    end if
    return prepared
end function

' Separate no-session boundary. The caller supplies the ACTUAL current actor/key;
' no outgoing scope is fabricated to pass authenticated-switch persistence.
' Used only by the private staged unavailable-Child controller.
function commitDispatcharrUnavailableChildRosterPull(registry as object, context as object, verified as object, decoded as object, enabled as boolean, now as integer, activeNonce as string, activeOutgoing as dynamic, activeKey as string, memoryKeys as object) as object
    denied = {ok: false, applied: false, committed: false, recoveryRequired: false, reason: "stale-context", needsDefaultSwitch: false}
    if type(context.connection) <> "roAssociativeArray" or type(context.store) <> "roAssociativeArray" or type(context.target) <> "roAssociativeArray" then return denied
    if GetInterface(context.nonce, "ifString") = invalid then return denied
    if context.unavailableChild <> true or context.outgoing <> invalid then return denied
    admin = userProfileLoadDeviceAdminPin(registry, context.connection.id)
    if not admin.ok then return denied
    plan = dispatcharrSyncUnavailableChildRosterPlan(context.connection, context.store, context.target.id, verified, decoded, enabled, now, context.nonce, activeNonce, activeOutgoing, activeKey, admin.record, context.management, textValue(context.managementNonce))
    if not plan.ok
        denied.reason = plan.reason
        denied.needsDefaultSwitch = plan.needsDefaultSwitch
        return denied
    end if
    if not dispatcharrSyncUnavailableChildRosterAccessCurrent(registry, context, verified, now, activeNonce, activeOutgoing, activeKey, memoryKeys) then return denied
    return dispatcharrSyncCommitSwitchRosterMetadata(registry, context, plan)
end function

' Shared metadata-only transaction AFTER one of the separate admission checks.
function dispatcharrSyncCommitSwitchRosterMetadata(registry as object, context as object, plan as object) as object
    denied = {ok: false, applied: false, committed: false, recoveryRequired: false, reason: "stale-context", needsDefaultSwitch: false}
    entry = context.connection
    actual = loadUserProfileStore(registry, entry.id)
    if actual.readOnly = true or FormatJson(actual) <> FormatJson(context.store) then return denied
    if plan.removed.count() > 0
        denied.reason = "cleanup-required"
        return denied
    end if
    plan.committed = false
    if not plan.applied
        plan.store = actual
        plan.recoveryRequired = false
        return plan
    end if
    if plan.store.active <> actual.active then return denied
    text = FormatJson(plan.store)
    if text = FormatJson(actual)
        plan.store = actual
        plan.recoveryRequired = false
        return plan
    end if
    if userProfileUtf8ByteCount(text) > 8192 then return denied
    changes = {}
    changes[userProfileStoreKey(entry.id)] = text
    saved = userProfileRegistryTransaction(registry, changes)
    if not saved.ok
        denied.recoveryRequired = saved.recoveryRequired
        denied.reason = "storage"
        return denied
    end if
    plan.recoveryRequired = false
    plan.committed = true
    return plan
end function

' Read-only preflight for each subsequent target-owned request. The incoming
' nonce is a request lifecycle, never a fabricated active target session.
function dispatcharrSyncSwitchRosterAccessCurrent(registry as object, context as object, verified as object, now as integer, activeNonce as string, activeOutgoing as dynamic, memoryKeys as object) as boolean
    if type(context.connection) <> "roAssociativeArray" or type(context.store) <> "roAssociativeArray" or type(context.target) <> "roAssociativeArray" then return false
    if GetInterface(context.nonce, "ifString") = invalid then return false
    proof = dispatcharrSyncSwitchRosterPlan(context.connection, context.store, context.target.id, verified, {ok: true, rows: [], removed: []}, false, now, context.nonce, activeNonce, context.outgoing, activeOutgoing)
    if not proof.ok then return false
    for each profile in context.store.profiles
        if profile.id = context.store.active and profile.role = "child"
            admin = userProfileLoadDeviceAdminPin(registry, context.connection.id)
            if not admin.ok then return false
            if not userProfileManagementGrantMatches(context.store, admin.record, context.management, textValue(context.managementNonce)) then return false
        end if
    end for
    return dispatcharrSyncSwitchRosterStorageCurrent(registry, context, verified.apiKey, memoryKeys)
end function

function dispatcharrSyncUnavailableChildRosterAccessCurrent(registry as object, context as object, verified as object, now as integer, activeNonce as string, activeOutgoing as dynamic, activeKey as string, memoryKeys as object) as boolean
    if type(context.connection) <> "roAssociativeArray" or type(context.store) <> "roAssociativeArray" or type(context.target) <> "roAssociativeArray" then return false
    if GetInterface(context.nonce, "ifString") = invalid then return false
    if context.unavailableChild <> true or context.outgoing <> invalid then return false
    admin = userProfileLoadDeviceAdminPin(registry, context.connection.id)
    if not admin.ok then return false
    proof = dispatcharrSyncUnavailableChildRosterPlan(context.connection, context.store, context.target.id, verified, {ok: true, rows: [], removed: []}, false, now, context.nonce, activeNonce, activeOutgoing, activeKey, admin.record, context.management, textValue(context.managementNonce))
    if not proof.ok then return false
    return dispatcharrSyncSwitchRosterStorageCurrent(registry, context, verified.apiKey, memoryKeys)
end function

' Shared write-free current connection/roster/own-key checks. Admission remains
' the responsibility of the authenticated or no-session wrapper above.
function dispatcharrSyncSwitchRosterStorageCurrent(registry as object, context as object, expectedKey as string, memoryKeys as object) as boolean
    if GetInterface(context.connectionRoot, "ifString") = invalid or GetInterface(context.nonce, "ifString") = invalid then return false
    if context.connectionRoot <> registry.read("connectionsV1") or context.connectionRootPresent <> registry.exists("connectionsV1") then return false
    connections = loadConnectionStore(registry)
    if connections.readOnly = true or connections.selected <> context.connection.id then return false
    entry = connectionStoreEntry(connections, context.connection.id)
    if entry = invalid then return false
    if FormatJson(entry) <> FormatJson(normalizeConnectionEntry(context.connection)) then return false
    actual = loadUserProfileStore(registry, entry.id)
    if actual.readOnly = true or FormatJson(actual) <> FormatJson(context.store) then return false
    selected = copyJson(actual)
    selected.active = context.target.id
    memory = memoryKeys
    if entry.remember then memory = {}
    credential = userProfileCredential(registry, entry, selected, memory)
    if not credential.ok or credential.profileId <> context.target.id then return false
    if credential.key <> context.key or credential.key <> expectedKey then return false
    ' A missing remembered canonical key must not revive a legacy/cached value.
    if entry.remember
        if not registry.exists(credential.keyName) or registry.read(credential.keyName) <> credential.key then return false
    end if
    return requestGateAccessAllowed(entry.url, credential.key)
end function
