' Local management authority is not Dispatcharr server-admin authority. A Child
' grant belongs to one exact local UI lifecycle and never borrows a holder key.
function userProfileManagementGrantMatches(store as object, deviceAdmin as dynamic, grant as dynamic, accessNonce as string, pinRequired = false as boolean) as boolean
    if store.readOnly = true then return false
    cleaned = normalizeUserProfileStore(store, store.playlistId)
    if cleaned.readOnly = true then return false
    active = invalid
    for each profile in cleaned.profiles
        if profile.id = cleaned.active then active = profile
    end for
    if active = invalid then return false
    fullAccess = userProfileFullAccess(active.role)
    if fullAccess and not pinRequired then return true
    if not fullAccess and active.role <> "child" then return false
    holders = userProfileAdultPinHolders(cleaned.profiles, deviceAdmin)
    if type(holders) <> "roArray" then return false
    if fullAccess and holders.count() = 0 then return true
    if type(grant) <> "roAssociativeArray" then return false
    if userProfileLocalId(accessNonce) = "" then return false
    for each field in ["slot", "active", "nonce", "purpose", "kind"]
        if type(grant[field]) <> "String" and type(grant[field]) <> "roString" then return false
    end for
    if grant.slot <> cleaned.playlistId or grant.active <> cleaned.active or grant.nonce <> accessNonce or grant.purpose <> "manage-profiles" then return false
    if grant.kind = "stranded" then return holders.count() = 0
    if grant.kind <> "pin" then return false
    for each holder in holders
        if holder.id = grant.id
            record = holder.record
            if holder.id = "device-admin"
                record = {id: "device-admin", pinType: record.pinType, pinHash: record.pinHash, pinSalt: record.pinSalt}
            end if
            return userProfilePinGrantMatches(grant, cleaned.playlistId, record)
        end if
    end for
    return false
end function

function userProfileMayEditMetadata(store as object, targetId as string, operation as string, deviceAdmin as dynamic, grant as dynamic, accessNonce as string) as boolean
    allowed = false
    for each candidate in ["name", "avatar", "role", "order", "remove"]
        if operation = candidate then allowed = true
    end for
    if not allowed or store.readOnly = true then return false
    cleaned = normalizeUserProfileStore(store, store.playlistId)
    if cleaned.readOnly = true then return false
    found = false
    target = invalid
    active = invalid
    for each profile in cleaned.profiles
        if profile.id = targetId
            found = true
            target = profile
        end if
        if profile.id = cleaned.active then active = profile
    end for
    if not found or active = invalid then return false
    if active.role = "child" and operation = "avatar" and targetId = active.id then return true
    pinRequired = operation = "role" or (operation = "remove" and target.role = "child")
    return userProfileManagementGrantMatches(cleaned, deviceAdmin, grant, accessNonce, pinRequired)
end function

function userProfileMetadataEditPlan(store as object, targetId as string, operation as string, value as dynamic, deviceAdmin as dynamic, grant as dynamic, accessNonce as string, now as integer) as object
    denied = {ok: false, changed: false, reason: "not-authorized"}
    if now <= 0 or not userProfileMayEditMetadata(store, targetId, operation, deviceAdmin, grant, accessNonce) then return denied
    cleaned = normalizeUserProfileStore(store, store.playlistId)
    nextStore = copyJson(cleaned)
    index = -1
    for i = 0 to nextStore.profiles.count() - 1
        if nextStore.profiles[i].id = targetId then index = i
    end for
    if index < 0 then return denied
    profile = nextStore.profiles[index]
    wireChanged = false
    if operation = "name"
        if type(value) <> "String" and type(value) <> "roString" then return denied
        name = userProfileDisplayName(userProfileTrim(value))
        if name = "" then return {ok: false, changed: false, reason: "name-required"}
        wireChanged = name <> profile.displayName
        profile = setCanonicalPreference(profile, "displayName", name)
        profile = setCanonicalPreference(profile, "displayNameClaimed", true)
    else if operation = "avatar"
        if type(value) <> "roAssociativeArray" then return denied
        avatar = userProfileNormalizeAvatar(value)
        wireChanged = FormatJson(profile.avatar) <> FormatJson(avatar)
        profile = setCanonicalPreference(profile, "avatar", avatar)
        profile = setCanonicalPreference(profile, "avatarClaimed", true)
    else if operation = "role"
        if type(value) <> "String" and type(value) <> "roString" then return denied
        if value <> "user" and value <> "child" then return denied
        if profile.userLevel >= 10 then return {ok: false, changed: false, reason: "server-admin-role"}
        wireChanged = profile.role <> value
        profile = setCanonicalPreference(profile, "role", value)
        nextStore.profiles[index] = profile
        children = 0
        adults = 0
        missingAdultPin = false
        for each candidate in nextStore.profiles
            if candidate.role = "child" then children++
            if userProfileFullAccess(candidate.role)
                adults++
                if not userProfilePinRecordValid(candidate) then missingAdultPin = true
            end if
        end for
        if children > 0 and missingAdultPin then return {ok: false, changed: false, reason: "adult-pin-required"}
        if children > 0 and adults = 0 and not userProfilePinRecordValid(deviceAdmin)
            return {ok: false, changed: false, reason: "exit-pin-required"}
        end if
    else if operation = "order"
        if not userProfileInteger(value) then return denied
        moved = userProfileMove(nextStore.profiles, targetId, value, now)
        if moved = invalid then return denied
        wireChanged = FormatJson(nextStore.profiles) <> FormatJson(moved)
        for each changedProfile in moved
            for each previousProfile in cleaned.profiles
                if previousProfile.id = changedProfile.id and previousProfile.order <> changedProfile.order
                    if now <= previousProfile.updatedAt then return {ok: false, changed: false, reason: "clock-not-ready"}
                end if
            end for
        end for
        nextStore.profiles = moved
    else
        ' Removal has scoped key/blob/tombstone work in UserProfileCleanup.
        return denied
    end if
    if operation <> "order"
        if wireChanged
            if now <= profile.updatedAt then return {ok: false, changed: false, reason: "clock-not-ready"}
            profile = setCanonicalPreference(profile, "updatedAt", now)
        end if
        nextStore.profiles[index] = profile
    end if
    if wireChanged then nextStore = setCanonicalPreference(nextStore, "pendingRoster", true)
    checked = normalizeUserProfileStore(nextStore, store.playlistId)
    if checked.readOnly = true then return denied
    return {ok: true, changed: FormatJson(cleaned) <> FormatJson(checked), store: checked, reason: ""}
end function

function commitUserProfileMetadataEdit(registry as object, connection as object, previous as object, targetId as string, operation as string, value as dynamic, grant as dynamic, capturedNonce as string, activeNonce as string, now as integer) as object
    denied = {ok: false, recoveryRequired: false, reason: "stale-context"}
    if userProfileLocalId(capturedNonce) = "" or capturedNonce <> activeNonce then return denied
    if connection.provider <> "dispatcharr" or connection.id <> previous.playlistId then return denied
    admin = userProfileLoadDeviceAdminPin(registry, connection.id)
    if not admin.ok then return {ok: false, recoveryRequired: true, reason: "recovery"}
    planned = userProfileMetadataEditPlan(previous, targetId, operation, value, admin.record, grant, activeNonce, now)
    if not planned.ok then return {ok: false, recoveryRequired: false, reason: planned.reason}
    prepared = userProfileStoreChanges(registry, previous, planned.store, {}, connection.remember)
    if not prepared.ok then return denied
    if not planned.changed then return {ok: true, changed: false, recoveryRequired: false, store: planned.store}
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if saved.ok
        saved.store = planned.store
        saved.changed = true
    end if
    return saved
end function
