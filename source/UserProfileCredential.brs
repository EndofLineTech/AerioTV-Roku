' Resolve only the selected profile's credential. A non-default profile can
' never borrow the slot/default key, including while held or Remember is off.
function userProfileCredential(registry as object, connection as object, store as object, memoryKeys as object) as object
    denied = {ok: false, key: "", keyName: "", profileId: "", isDefault: false, reason: "recovery"}
    if connection.provider <> "dispatcharr" or connection.id <> store.playlistId then return denied
    if store.readOnly = true then return denied
    cleaned = normalizeUserProfileStore(store, connection.id)
    ' Only the loader's exact missing-store migration value may be empty.
    ' A present empty/corrupt value has already been marked read-only above.
    if FormatJson(store) = FormatJson(defaultUserProfileStore(connection.id)) then cleaned = store
    if cleaned.readOnly = true then return denied
    profile = invalid
    for each candidate in cleaned.profiles
        if candidate.id = cleaned.active then profile = candidate
    end for
    keyName = connectionRegistryKey(connection.id)
    profileId = ""
    isDefault = true
    if profile <> invalid
        profileId = profile.id
        isDefault = profile.isDefault
        if profile.addressHeld then return {ok: false, key: "", keyName: "", profileId: profileId, isDefault: false, reason: "address-held"}
        if not isDefault then keyName = userProfileKeyName(connection.id, profileId)
    end if
    if keyName = "" then return denied
    key = ""
    if memoryKeys.doesExist(keyName) then key = textValue(memoryKeys[keyName])
    if key = "" and connection.remember = true
        key = registry.read(keyName)
        if key = "" and isDefault and connection.id = "legacy" then key = registry.read("apiKey")
    end if
    reason = ""
    if key = "" then reason = "sign-in"
    return {ok: key <> "", key: key, keyName: keyName, profileId: profileId, isDefault: isDefault, reason: reason}
end function
