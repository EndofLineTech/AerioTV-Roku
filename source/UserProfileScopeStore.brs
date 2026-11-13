' One captured immutable scope authorizes the whole settingsV1 transaction.
' No caller supplies a replacement account identity separately from that scope.
function commitUserProfilePreferences(registry as object, store as object, preferences as object, effectiveDevice as object, captured as dynamic, active as dynamic) as object
    denied = {ok: false, recoveryRequired: false}
    if not userProfileSameSession(captured, active) then return denied
    if not userProfileInteger(store.schema) then return denied
    if store.schema <> 1 then return denied
    prepared = userProfileSettingsCommitPlan(store, captured.preferenceIdentity, preferences, effectiveDevice)
    if not prepared.ok then return denied
    text = FormatJson(prepared.store)
    if text = "" or preferenceByteBudget(text) > 24000 then return denied
    changes = {}
    changes["settingsV1"] = text
    saved = userProfileRegistryTransaction(registry, changes)
    if saved.ok
        saved.store = prepared.store
        saved.preferences = prepared.preferences
    end if
    return saved
end function
