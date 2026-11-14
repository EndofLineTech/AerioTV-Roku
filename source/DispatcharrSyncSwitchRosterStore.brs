' Internal metadata-only switch admission. Actual auth/read node ownership and
' the incoming scrim belong to the controller; this never fabricates a target
' session, writes App Data, changes credentials, or performs tombstone cleanup.
function commitDispatcharrSwitchRosterPull(registry as object, context as object, verified as object, decoded as object, enabled as boolean, now as integer, activeNonce as string, activeOutgoing as dynamic, memoryKeys as object) as object
    denied = {ok: false, applied: false, committed: false, recoveryRequired: false, reason: "stale-context", needsDefaultSwitch: false}
    if type(context.connection) <> "roAssociativeArray" or type(context.store) <> "roAssociativeArray" or type(context.target) <> "roAssociativeArray" then return denied
    if GetInterface(context.connectionRoot, "ifString") = invalid then return denied
    if context.connectionRoot <> registry.read("connectionsV1") or context.connectionRootPresent <> registry.exists("connectionsV1") then return denied
    connections = loadConnectionStore(registry)
    if connections.readOnly = true or connections.selected <> context.connection.id then return denied
    entry = connectionStoreEntry(connections, context.connection.id)
    if entry = invalid then return denied
    if FormatJson(entry) <> FormatJson(normalizeConnectionEntry(context.connection)) then return denied
    plan = dispatcharrSyncSwitchRosterPlan(entry, context.store, context.target.id, verified, decoded, enabled, now, context.nonce, activeNonce, context.outgoing, activeOutgoing)
    if not plan.ok
        denied.reason = plan.reason
        denied.needsDefaultSwitch = plan.needsDefaultSwitch
        return denied
    end if
    actual = loadUserProfileStore(registry, entry.id)
    if actual.readOnly = true or FormatJson(actual) <> FormatJson(context.store) then return denied
    selected = copyJson(actual)
    selected.active = context.target.id
    memory = memoryKeys
    if entry.remember then memory = {}
    credential = userProfileCredential(registry, entry, selected, memory)
    if not credential.ok or credential.profileId <> context.target.id then return denied
    if credential.key <> context.key or credential.key <> verified.apiKey then return denied
    ' A remembered canonical key disappearing cannot fall back to legacy or
    ' cached bytes. Remember-off uses only the caller's current own memory map.
    if entry.remember
        if not registry.exists(credential.keyName) or registry.read(credential.keyName) <> credential.key then return denied
    end if
    if not requestGateAccessAllowed(entry.url, credential.key) then return denied
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
