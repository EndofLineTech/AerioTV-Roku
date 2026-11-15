' Startup picker admission is neither an authenticated chosen switch nor an
' unavailable-Child escape. No outgoing actor/key exists, and this preflight
' neither selects a persisted holder nor creates a session or a PIN grant.
function userProfileStartupSelectionCurrent(registry as object, context as object, activeNonce as string, activeScope as dynamic, activeKey as string, memoryKeys as object, requirePin as boolean) as boolean
    if activeScope <> invalid or activeKey <> "" then return false
    if context.purpose <> "startup-picker" then return false
    if userProfileLocalId(textValue(context.nonce)) = "" or context.nonce <> activeNonce then return false
    if type(context.connection) <> "roAssociativeArray" or type(context.store) <> "roAssociativeArray" or type(context.target) <> "roAssociativeArray" then return false
    connection = context.connection
    if connection.provider <> "dispatcharr" or connection.id <> context.store.playlistId then return false
    if GetInterface(context.connectionRoot, "ifString") = invalid or GetInterface(context.storeRoot, "ifString") = invalid then return false
    if context.connectionRootPresent <> registry.exists("connectionsV1") or context.connectionRoot <> registry.read("connectionsV1") then return false
    connections = loadConnectionStore(registry)
    if connections.readOnly = true or connections.selected <> connection.id then return false
    currentConnection = connectionStoreEntry(connections, connection.id)
    if currentConnection = invalid then return false
    if FormatJson(currentConnection) <> FormatJson(normalizeConnectionEntry(connection)) then return false
    rootKey = userProfileStoreKey(connection.id)
    if not registry.exists(rootKey) or registry.read(rootKey) <> context.storeRoot then return false
    store = loadUserProfileStore(registry, connection.id)
    if store.readOnly = true or FormatJson(store) <> FormatJson(context.store) then return false
    if store.askAtLaunch <> true or store.profiles.count() < 2 then return false
    restored = invalid
    target = invalid
    for each profile in store.profiles
        if profile.id = store.active then restored = profile
        if profile.id = context.target.id then target = profile
    end for
    if restored = invalid or target = invalid then return false
    if not userProfileFullAccess(restored.role) then return false
    if FormatJson(target) <> FormatJson(context.target) or target.addressHeld then return false
    ' Incoming Child activation remains separately fenced until its picker
    ' admission and changed-protection continuations have native qualification.
    if not userProfileFullAccess(target.role) then return false
    if requirePin and target.pinType <> "none"
        if not userProfilePinGrantMatches(context.pin, connection.id, target) then return false
    end if
    selected = setCanonicalPreference(store, "active", target.id)
    memory = memoryKeys
    if connection.remember then memory = {}
    credential = userProfileCredential(registry, connection, selected, memory)
    if not credential.ok or credential.profileId <> target.id then return false
    if credential.key <> context.key then return false
    if connection.remember
        if not registry.exists(credential.keyName) or registry.read(credential.keyName) <> credential.key then return false
    end if
    return requestGateAccessAllowed(connection.url, credential.key)
end function
