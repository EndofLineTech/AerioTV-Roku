' Whole-slot Forget is local recovery, not a roster deletion broadcast. Keys
' are slot-namespaced so a malformed profile roster cannot strand credentials
' or require reading another slot's credential values to discover ownership.
function forgetUserProfileConnection(registry as object, connections as object, slotId as string) as object
    denied = {ok: false, recoveryRequired: false}
    prefix = userProfileKeyPrefix(slotId)
    if prefix = "" then return denied
    actual = loadConnectionStore(registry)
    if actual.readOnly = true or connections.readOnly = true then return denied
    expected = normalizeConnectionStore(connections)
    if expected.readOnly = true then return denied
    if FormatJson(actual) <> FormatJson(expected) then return denied
    entry = connectionStoreEntry(actual, slotId)
    if entry = invalid then return denied
    nextConnections = connectionStoreRemove(actual, slotId)
    if nextConnections = invalid then return denied
    preferences = defaultPreferenceStore()
    if registry.exists("settingsV1")
        preferences = loadStrictPreferenceStore(registry)
        if preferences.readOnly = true then return denied
        if type(preferences) <> "roAssociativeArray" then return denied
        if not userProfileInteger(preferences.schema) then return denied
        if preferences.schema <> 1 then return denied
        if type(preferences.device) <> "roAssociativeArray" or type(preferences.accounts) <> "roAssociativeArray" then return denied
    end if
    ' All existing user scopes encode the terminal |slotId. This also cleans
    ' older URLs/users and an unreadable roster without guessing a user ID.
    suffix = mid(preferenceScope("|" + slotId), len("account_") + 1)
    for each scope in preferences.accounts.keys()
        if right(scope, len(suffix)) = suffix then preferences.accounts.delete(scope)
    end for
    if slotId = "legacy" and entry.accountId <> "" then preferences.accounts.delete(preferenceScope(entry.url + "|" + entry.accountId))
    changes = {}
    changes["connectionsV1"] = FormatJson(nextConnections)
    if registry.exists("settingsV1")
        encoded = strictJsonEncode(preferences)
        if not encoded.ok then return denied
        if preferenceByteBudget(encoded.text) > 24000 then return denied
        changes["settingsV1"] = encoded.text
    end if
    changes[connectionRegistryKey(slotId)] = ""
    changes[userProfileStoreKey(slotId)] = ""
    for each key in registry.getKeyList()
        if left(key, len(prefix)) = prefix then changes[key] = ""
        if left(key, len("pinHold_" + slotId + "_")) = "pinHold_" + slotId + "_" then changes[key] = ""
    end for
    adminKey = userProfileDeviceAdminKey(slotId)
    if registry.exists(adminKey) then changes[adminKey] = ""
    if slotId = "legacy"
        for each key in ["serverUrl", "apiKey", "accountIdentity", "preferences"]
            changes[key] = ""
        end for
    end if
    result = userProfileRegistryTransaction(registry, changes)
    if result.ok
        result.connections = nextConnections
        result.preferences = preferences
    end if
    return result
end function

' Caller must retire the active target first; the plan refuses to remove it.
' The returned preferences/store are adopted only after this transaction lands.
function removeUserProfile(registry as object, connection as object, store as object, id as string, now as integer, reason as string) as object
    denied = {ok: false, recoveryRequired: false, needsDefaultSwitch: false}
    if connection.provider <> "dispatcharr" or connection.id <> store.playlistId then return denied
    plan = userProfileRemovalPlan(store, id, now, reason)
    if not plan.ok
        denied.needsDefaultSwitch = plan.needsDefaultSwitch
        return denied
    end if
    prepared = userProfileStoreChanges(registry, store, plan.store, {}, connection.remember)
    if not prepared.ok then return denied
    pinHold = userProfilePinBackoffKey(connection.id, id)
    if registry.exists(pinHold) then prepared.changes[pinHold] = ""
    preferences = defaultPreferenceStore()
    if registry.exists("settingsV1")
        preferences = loadStrictPreferenceStore(registry)
        if preferences.readOnly = true then return denied
        if type(preferences) <> "roAssociativeArray" then return denied
        if not userProfileInteger(preferences.schema) then return denied
        if preferences.schema <> 1 or type(preferences.accounts) <> "roAssociativeArray" then return denied
        identity = connectionPreferenceIdentity(connection, plan.removedProfile.userId.toStr())
        if identity = "" then return denied
        preferences.accounts.delete(preferenceScope(identity))
        encoded = strictJsonEncode(preferences)
        if not encoded.ok then return denied
        if preferenceByteBudget(encoded.text) > 24000 then return denied
        prepared.changes["settingsV1"] = encoded.text
    end if
    result = userProfileRegistryTransaction(registry, prepared.changes)
    result.needsDefaultSwitch = false
    if result.ok
        result.store = plan.store
        result.preferences = preferences
        result.pushRequired = plan.pushRequired
    end if
    return result
end function
