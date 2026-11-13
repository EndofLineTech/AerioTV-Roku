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

' Rejection invalidates only the currently selected holder's persisted key.
' It never converts a non-default/Child refusal into default-account setup.
function revokeUserProfileCredential(registry as object, connection as object, previous as object) as object
    denied = {ok: false, recoveryRequired: false, isDefault: false, profileId: ""}
    if connection.provider <> "dispatcharr" or previous.readOnly = true then return denied
    if previous.playlistId <> connection.id then return denied
    actual = loadUserProfileStore(registry, connection.id)
    if actual.readOnly = true then return denied
    if FormatJson(actual) <> FormatJson(previous) then return denied
    keyName = connectionRegistryKey(connection.id)
    isDefault = true
    profileId = ""
    for each profile in actual.profiles
        if profile.id = actual.active
            profileId = profile.id
            isDefault = profile.isDefault
            if not isDefault then keyName = userProfileKeyName(connection.id, profile.id)
        end if
    end for
    if actual.profiles.count() > 0 and profileId = "" then return denied
    if keyName = "" then return denied
    changes = {}
    changes[keyName] = ""
    if isDefault and connection.id = "legacy" then changes["apiKey"] = ""
    saved = userProfileRegistryTransaction(registry, changes)
    saved.isDefault = isDefault
    saved.profileId = profileId
    return saved
end function
