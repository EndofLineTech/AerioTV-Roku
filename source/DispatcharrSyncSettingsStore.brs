' Device-wide explicit choices, never an account/profile sync category or an
' implicit opt-in. Read without rewriting sparse roots or malformed values.
' Local-only baseline retains dirty roster intent; it never acknowledges it.
function dispatcharrSyncLocalPendingAllowed(registry as object, context as object) as boolean
    if not userProfileTrue(context.localOnly) then return false
    settings = loadDispatcharrSyncSettings(registry)
    return settings.ok and not settings.enabled
end function

function loadDispatcharrSyncSettings(registry as object) as object
    denied = {ok: false, enabled: false, profiles: true, favorites: false}
    store = loadStrictPreferenceStore(registry)
    if store.readOnly = true then return denied
    ' Favorites is an explicit opt-in: missing means Off.
    result = {ok: true, enabled: false, profiles: true, favorites: false, store: store}
    for each field in ["dispatcharrSyncEnabled", "dispatcharrSyncProfiles", "dispatcharrSyncFavorites"]
        count = 0
        value = invalid
        for each key in store.device
            if lcase(key) = lcase(field)
                count++
                value = store.device[key]
            end if
        end for
        if count > 1 then result.ok = false
        if count = 1
            if not userProfileBoolean(value)
                result.ok = false
            else
                if field = "dispatcharrSyncEnabled" then result.enabled = value
                if field = "dispatcharrSyncProfiles" then result.profiles = value
                if field = "dispatcharrSyncFavorites" then result.favorites = value
            end if
        end if
    end for
    if not result.ok
        result.enabled = false
        result.favorites = false
    end if
    return result
end function

' This is local Settings admission, not a fabricated Task/read receipt. The
' controller supplies its actually adopted scope/key and captured exact roots.
function dispatcharrSyncSettingsAccess(registry as object, context as object, activeScope as dynamic, activeKey as string, memoryKeys as object) as object
    denied = {ok: false, recoveryRequired: false}
    if not userProfileSameSession(context.scope, activeScope) then return denied
    if type(context.connection) <> "roAssociativeArray" then return denied
    for each field in ["connectionRoot", "storeRoot", "settingsRoot"]
        if GetInterface(context[field], "ifString") = invalid then return denied
    end for
    if not userProfileBoolean(context.settingsPresent) then return denied
    if context.connectionRoot <> registry.read("connectionsV1") then return denied
    if context.storeRoot <> registry.read(userProfileStoreKey(context.connection.id)) then return denied
    if context.settingsRoot <> registry.read("settingsV1") or context.settingsPresent <> registry.exists("settingsV1") then return denied
    connections = loadConnectionStore(registry)
    if connections.readOnly = true or connections.selected <> context.connection.id then return denied
    entry = connectionStoreEntry(connections, context.connection.id)
    if entry = invalid then return denied
    if entry.provider <> "dispatcharr" or FormatJson(entry) <> FormatJson(normalizeConnectionEntry(context.connection)) then return denied
    store = loadUserProfileStore(registry, entry.id)
    if store.readOnly = true or store.active <> activeScope.profileId then return denied
    own = invalid
    for each profile in store.profiles
        if profile.id = store.active then own = profile
    end for
    if own = invalid then return denied
    if own.addressHeld or not userProfileFullAccess(own.role) then return denied
    expected = userProfileSessionScope(entry, own.id, own.userId, activeScope.authorizationGeneration, activeScope.sessionId)
    if not userProfileSameSession(expected, activeScope) then return denied
    if not requestGateDigestValid(textValue(context.credentialHash)) or activeKey = "" then return denied
    if requestGateCredentialHash(activeKey) <> context.credentialHash then return denied
    memory = memoryKeys
    if entry.remember then memory = {}
    credential = userProfileCredential(registry, entry, store, memory)
    if not credential.ok then return denied
    if credential.key <> activeKey then return denied
    if entry.remember
        if not registry.exists(credential.keyName) or registry.read(credential.keyName) <> activeKey then return denied
    end if
    if not requestGateAccessAllowed(entry.url, activeKey) then return denied
    return {ok: true, connection: entry, store: store}
end function

' An omitted Favorites choice keeps the stored member untouched.
function commitDispatcharrSyncSettings(registry as object, context as object, activeScope as dynamic, activeKey as string, memoryKeys as object, enabled as dynamic, profiles as dynamic, favorites = invalid as dynamic) as object
    denied = {ok: false, recoveryRequired: false}
    if not userProfileBoolean(enabled) or not userProfileBoolean(profiles) then return denied
    if favorites <> invalid and not userProfileBoolean(favorites) then return denied
    access = dispatcharrSyncSettingsAccess(registry, context, activeScope, activeKey, memoryKeys)
    if not access.ok then return denied
    settings = loadDispatcharrSyncSettings(registry)
    if not settings.ok then return denied
    staged = settings.store
    device = setCanonicalPreference(staged.device, "dispatcharrSyncEnabled", enabled)
    device = setCanonicalPreference(device, "dispatcharrSyncProfiles", profiles)
    if favorites <> invalid then device = setCanonicalPreference(device, "dispatcharrSyncFavorites", favorites)
    staged = setCanonicalPreference(staged, "device", device)
    encoded = strictJsonEncode(staged)
    if not encoded.ok then return denied
    if preferenceByteBudget(encoded.text) > 24000 then return denied
    changes = {}
    changes["settingsV1"] = encoded.text
    saved = userProfileRegistryTransaction(registry, changes)
    if not saved.ok then return saved
    saved.preferenceStore = staged
    if favorites = invalid then favorites = settings.favorites
    saved.settings = {enabled: enabled, profiles: profiles, favorites: favorites}
    saved.settingsRoot = encoded.text
    return saved
end function
