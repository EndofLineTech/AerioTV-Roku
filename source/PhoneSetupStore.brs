' ifRegistrySection.Flush documents an atomic transaction for all preceding
' writes. Stage key + roster in that ONE transaction, then switch runtime only
' after success. A failed flush restores both cached values before returning.
function phoneSetupCommitConnection(registry as object, previous as object, staged as object, apiKey as string) as object
    failure = {ok: false, recoveryRequired: false, message: "Could not save setup. Previous connection retained."}
    if previous.readOnly = true or staged.readOnly = true then return failure
    before = normalizeConnectionStore(previous)
    cleaned = normalizeConnectionStore(staged)
    if before.readOnly = true or cleaned.readOnly = true then return failure
    entry = connectionStoreEntry(cleaned, cleaned.selected)
    if entry = invalid then return failure
    rosterBefore = registry.read("connectionsV1")
    if rosterBefore <> ""
        actual = normalizeConnectionStore(parseJson(rosterBefore))
        if actual.readOnly = true or formatJson(actual) <> formatJson(before) then return failure
    end if
    serialized = formatJson(cleaned)
    if preferenceByteBudget(serialized) > 5000 then return failure
    keyName = connectionRegistryKey(entry.id)
    if keyName = "" then return failure
    keyBefore = registry.read(keyName)
    legacyBefore = registry.read("apiKey")
    remember = entry.provider = "dispatcharr" and entry.remember
    if remember and apiKey = "" then return failure
    wrote = true
    if remember
        wrote = registry.write(keyName, apiKey)
    else if keyBefore <> ""
        wrote = registry.delete(keyName)
    end if
    if entry.id = "legacy" and legacyBefore <> "" then wrote = registry.delete("apiKey") and wrote
    wrote = registry.write("connectionsV1", serialized) and wrote
    if wrote
        if registry.flush() then return {ok: true, store: cleaned}
    end if
    restored = phoneSetupRestoreValue(registry, "connectionsV1", rosterBefore)
    restored = phoneSetupRestoreValue(registry, keyName, keyBefore) and restored
    if entry.id = "legacy" then restored = phoneSetupRestoreValue(registry, "apiKey", legacyBefore) and restored
    restored = registry.flush() and restored
    if not restored
        failure.recoveryRequired = true
        failure.message = "Storage recovery is required. Restart AerioTV before changing saved connections."
    end if
    return failure
end function

function phoneSetupRestoreValue(registry as object, key as string, value as string) as boolean
    if value <> "" then return registry.write(key, value)
    if registry.read(key) = "" then return true
    return registry.delete(key)
end function
