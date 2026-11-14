' Internal manual-edit storage boundary only. The caller must fence outgoing
' traffic before invoking it and retire runtime/memory credentials on success.
' Setup payload matching and personal-data scope migration are separate work;
' no public URL handler calls this until those transition rules are integrated.
function commitUserProfileAddressChange(registry as object, connections as object, previous as object, nextUrl as string, captured as dynamic, active as dynamic) as object
    denied = {ok: false, recoveryRequired: false}
    ' Do not retire the only URL/account ownership evidence for an unscoped
    ' legacy value. Its verified migration must complete before an address edit.
    if registry.exists("preferences") then return denied
    if not userProfileSameSession(captured, active) then return denied
    if connections.readOnly = true or previous.readOnly = true then return denied
    previous = normalizeUserProfileStore(previous, captured.playlistId)
    if previous.readOnly = true then return denied
    if captured.playlistId <> previous.playlistId or captured.profileId <> previous.active then return denied
    if connections.selected <> previous.playlistId then return denied
    actual = loadConnectionStore(registry)
    expected = normalizeConnectionStore(connections)
    if actual.readOnly = true or expected.readOnly = true then return denied
    if FormatJson(actual) <> FormatJson(expected) then return denied
    connection = connectionStoreEntry(actual, previous.playlistId)
    if connection = invalid then return denied
    if captured.preferenceIdentity <> connectionPreferenceIdentity(connection, captured.accountId) then return denied
    owner = invalid
    for each profile in previous.profiles
        if profile.id = previous.active then owner = profile
    end for
    if owner = invalid then return denied
    if captured.accountId <> owner.userId.toStr() or not userProfileFullAccess(owner.role) then return denied
    nextUrl = normalizeBaseUrl(nextUrl)
    if nextUrl = "" or nextUrl = connection.url then return denied
    planned = userProfileAddressChangePlan(connection, previous, nextUrl)
    if not planned.ok then return denied
    updated = connectionStoreUpdate(actual, connection.id, {url: nextUrl, remember: false})
    if updated = invalid then return denied
    connectionText = FormatJson(updated)
    if preferenceByteBudget(connectionText) > 5000 then return denied
    prepared = userProfileStoreChanges(registry, previous, planned.store, {}, false)
    if not prepared.ok then return denied
    prepared.changes["connectionsV1"] = connectionText
    prepared.changes[connectionRegistryKey(connection.id)] = ""
    if connection.id = "legacy"
        prepared.changes["apiKey"] = ""
        prepared.changes["serverUrl"] = nextUrl
        prepared.changes["accountIdentity"] = ""
        prepared.changes["rememberApiKey"] = "false"
    end if
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if saved.ok
        saved.store = planned.store
        saved.connections = updated
        saved.changed = planned.changed
        saved.childDefault = planned.childDefault = true
    end if
    return saved
end function
