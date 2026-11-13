' Own username/password recovery is distinct from validating a saved key:
' a recreated non-default username may have a new integer user ID. This plan
' never activates or persists; scoped data must move in the credential commit.
function userProfileOwnSignInPlan(connection as object, previous as object, targetId as string, verified as dynamic, now as integer) as object
    denied = {ok: false, reason: "login-refused"}
    if connection.provider <> "dispatcharr" or connection.id <> previous.playlistId then return denied
    if previous.readOnly = true or now <= 0 then return denied
    store = normalizeUserProfileStore(previous, connection.id)
    if store.readOnly = true then return denied
    target = invalid
    index = -1
    for i = 0 to store.profiles.count() - 1
        if store.profiles[i].id = targetId
            target = store.profiles[i]
            index = i
        end if
    end for
    if target = invalid then return denied
    ' Default recovery is storage-only and limited to the existing inactive
    ' full-access holder. Identity replacement/runtime adoption remain fenced.
    if target.isDefault
        if store.active = targetId or not userProfileFullAccess(target.role) then return {ok: false, reason: "default-recovery-not-ready"}
    end if
    if target.addressHeld then return {ok: false, reason: "address-recovery-not-ready"}
    if type(verified) <> "roAssociativeArray" then return denied
    if verified.ok <> true then return denied
    if type(verified.apiKey) <> "String" and type(verified.apiKey) <> "roString" then return {ok: false, reason: "api-access-required"}
    if verified.apiKey = "" or len(verified.apiKey) > 512 then return {ok: false, reason: "api-access-required"}
    identity = userProfileFromVerified(connection.id, targetId, verified.verifiedUser, now)
    if identity = invalid then return denied
    if target.isDefault
        if identity.userId <> target.userId or lcase(identity.username) <> lcase(target.username) then return {ok: false, reason: "default-recovery-not-ready"}
        if not userProfileDefaultOwnIdentityMatches(connection, store, verified.verifiedUser) then return denied
    end if
    if lcase(identity.username) <> lcase(target.username) then return denied
    for each profile in store.profiles
        if profile.id <> targetId
            if profile.userId = identity.userId or lcase(profile.username) = lcase(identity.username) then return {ok: false, reason: "duplicate-user"}
        end if
    end for
    oldIdentity = userProfilePreferenceIdentity(connection, target)
    oldRole = target.role
    changed = target.userId <> identity.userId
    for each field in ["userId", "userLevel", "isStaff", "isSuperuser"]
        target = setCanonicalPreference(target, field, identity[field])
    end for
    target = setCanonicalPreference(target, "role", userProfileResolveRole(identity.userLevel, oldRole))
    if target.doesExist("preferenceAnchor") then target = setCanonicalPreference(target, "preferenceAnchor", connectionPreferenceIdentity(connection, identity.userId.toStr()))
    if changed or target.role <> oldRole
        if now <= target.updatedAt then return {ok: false, reason: "clock-not-ready"}
        target = setCanonicalPreference(target, "updatedAt", now)
        store.pendingRoster = true
    end if
    store.profiles[index] = target
    store = normalizeUserProfileStore(store, connection.id)
    if store.readOnly = true then return denied
    return {ok: true, reason: "", store: store, target: target, oldIdentity: oldIdentity, newIdentity: connectionPreferenceIdentity(connection, target.userId.toStr())}
end function

' Storage only. The controller still owes target PIN/Child admission, outgoing
' retirement and fresh runtime scope adoption. No password enters this boundary.
function commitUserProfileOwnSignIn(registry as object, connection as object, previous as object, targetId as string, verified as object, now as integer, capturedNonce as string, activeNonce as string) as object
    denied = {ok: false, recoveryRequired: false, reason: "stale-context", preferencesMoved: false}
    if userProfileLocalId(capturedNonce) = "" or capturedNonce <> activeNonce then return denied
    connections = loadConnectionStore(registry)
    if connections.readOnly = true or connections.selected <> connection.id then return denied
    current = connectionStoreEntry(connections, connection.id)
    if current = invalid then return denied
    if FormatJson(current) <> FormatJson(normalizeConnectionEntry(connection)) then return denied
    planned = userProfileOwnSignInPlan(connection, previous, targetId, verified, now)
    if not planned.ok
        denied.reason = planned.reason
        return denied
    end if
    if planned.target.isDefault
        changingAddress = planned.store.doesExist("addressChangeSnapshot")
        checked = userProfileDefaultAddressCheck(connection, planned.store, verified)
        if not checked.ok then return denied
        recorded = userProfileRecordDefaultIdentity(checked.store, changingAddress)
        if not recorded.ok then return denied
        planned.store = recorded.store
    end if
    keys = {}
    if not planned.target.isDefault then keys[targetId] = verified.apiKey
    prepared = userProfileStoreChanges(registry, previous, planned.store, keys, connection.remember)
    if not prepared.ok then return denied
    if planned.target.isDefault
        key = ""
        if connection.remember then key = verified.apiKey
        prepared.changes[connectionRegistryKey(connection.id)] = key
        if connection.id = "legacy" then prepared.changes["apiKey"] = ""
    end if
    moved = false
    settings = invalid
    if planned.oldIdentity <> planned.newIdentity and registry.exists("settingsV1")
        if m.profileOwnSignInSettingsDecoder <> invalid
            settings = m.profileOwnSignInSettingsDecoder(registry.read("settingsV1"))
        else
            settings = ParseJson(registry.read("settingsV1"), "d")
        end if
        if type(settings) <> "roAssociativeArray" then return denied
        if not userProfileInteger(settings.schema) then return denied
        if settings.schema <> 1 or type(settings.device) <> "roAssociativeArray" or type(settings.accounts) <> "roAssociativeArray" then return denied
        oldKey = preferenceScope(planned.oldIdentity)
        newKey = preferenceScope(planned.newIdentity)
        if settings.accounts.doesExist(oldKey)
            own = settings.accounts[oldKey]
            if type(own) <> "roAssociativeArray" then return denied
            if settings.accounts.doesExist(newKey)
                existingText = strictJsonEncode(settings.accounts[newKey])
                ownText = strictJsonEncode(own)
                if not existingText.ok or not ownText.ok then return denied
                if existingText.text <> ownText.text
                    denied.reason = "scope-conflict"
                    return denied
                end if
            end if
            settings.accounts[newKey] = own
            settings.accounts.delete(oldKey)
            encoded = strictJsonEncode(settings)
            if not encoded.ok then return denied
            if preferenceByteBudget(encoded.text) > 24000 then return denied
            prepared.changes["settingsV1"] = encoded.text
            moved = true
        end if
    end if
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    saved.preferencesMoved = moved and saved.ok
    if saved.ok
        saved.store = planned.store
        saved.target = planned.target
        saved.oldIdentity = planned.oldIdentity
        saved.newIdentity = planned.newIdentity
        if type(settings) = "roAssociativeArray" then saved.preferenceStore = settings
    end if
    return saved
end function
