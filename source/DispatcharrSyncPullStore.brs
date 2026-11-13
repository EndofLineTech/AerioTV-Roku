' Commit a captured own-session read plan atomically with scoped key/blob
' cleanup. Active removal is refused until the controller authenticates and
' commits the default switch, then re-plans against that new active store.
function commitDispatcharrRosterPull(registry as object, connection as object, previous as object, decoded as object, enabled as boolean, now as integer, captured as dynamic, active as dynamic) as object
    denied = {ok: false, recoveryRequired: false, needsDefaultSwitch: false}
    if not userProfileSameSession(captured, active) then return denied
    if connection.provider <> "dispatcharr" or connection.id <> previous.playlistId then return denied
    if captured.playlistId <> connection.id or captured.profileId <> previous.active then return denied
    owner = invalid
    for each profile in previous.profiles
        if profile.id = previous.active then owner = profile
    end for
    if owner = invalid then return denied
    if captured.accountId <> owner.userId.toStr() or captured.preferenceIdentity <> connectionPreferenceIdentity(connection, owner.userId.toStr()) then return denied
    plan = dispatcharrSyncRosterMerge(previous, decoded, enabled, now)
    if not plan.ok then return denied
    if plan.needsDefaultSwitch
        denied.needsDefaultSwitch = true
        return denied
    end if
    if not plan.applied then return {ok: true, applied: false, recoveryRequired: false, needsDefaultSwitch: false, store: previous, suggestions: []}
    prepared = userProfileStoreChanges(registry, previous, plan.store, {}, connection.remember)
    if not prepared.ok then return denied
    for each profile in plan.removed
        pinHold = userProfilePinBackoffKey(connection.id, profile.id)
        if registry.exists(pinHold) then prepared.changes[pinHold] = ""
    end for
    preferences = defaultPreferenceStore()
    if registry.exists("settingsV1")
        preferences = loadStrictPreferenceStore(registry)
        if preferences.readOnly = true then return denied
        if type(preferences) <> "roAssociativeArray" then return denied
        if not userProfileInteger(preferences.schema) then return denied
        if preferences.schema <> 1 or type(preferences.accounts) <> "roAssociativeArray" or type(preferences.device) <> "roAssociativeArray" then return denied
        for each profile in plan.removed
            identity = userProfilePreferenceIdentity(connection, profile)
            if identity = "" then return denied
            preferences.accounts.delete(preferenceScope(identity))
        end for
        encoded = strictJsonEncode(preferences)
        if not encoded.ok then return denied
        text = encoded.text
        if preferenceByteBudget(text) > 24000 then return denied
        if plan.removed.count() > 0 then prepared.changes["settingsV1"] = text
    end if
    result = userProfileRegistryTransaction(registry, prepared.changes)
    result.needsDefaultSwitch = false
    if result.ok
        result.applied = true
        result.store = plan.store
        result.preferences = preferences
        result.suggestions = plan.suggestions
    end if
    return result
end function
