' Internal storage foundation only. Callers must not connect/expose switching
' until the slot's store has loaded successfully and all authorization gates pass.
function userProfileStoreKey(slotId as string) as string
    if connectionRegistryKey(slotId) = "" then return ""
    return "userProfilesV1_" + slotId
end function

function userProfilePinBackoffKey(slotId as string, holder as string) as string
    if connectionRegistryKey(slotId) = "" then return ""
    if holder <> "device-admin" and userProfileLocalId(holder) = "" then return ""
    return "pinHold_" + slotId + "_" + lcase(holder)
end function

function userProfileDeviceAdminKey(slotId as string) as string
    if connectionRegistryKey(slotId) = "" then return ""
    return "deviceAdminPinV1_" + slotId
end function

function defaultUserProfileStore(slotId as string) as object
    return {schema: 1, playlistId: slotId, active: "", askAtLaunch: false, profiles: [], removed: [], pendingRoster: false}
end function

function userProfileStoreRecovery(slotId as string) as object
    result = defaultUserProfileStore(slotId)
    result.readOnly = true
    return result
end function

' An empty store is valid ONLY before first verified migration. A present empty
' registry value, missing default, unknown schema/fields or bad PIN is recovery,
' never a reason to synthesize an unrestricted replacement.
function normalizeUserProfileStore(raw as dynamic, slotId as string) as object
    failure = userProfileStoreRecovery(slotId)
    if userProfileStoreKey(slotId) = "" then return failure
    raw = userProfileCanonicalFields(raw, ["schema", "playlistId", "active", "askAtLaunch", "profiles", "removed", "pendingRoster", "knownDefault", "addressChangeSnapshot"])
    if raw = invalid then return failure
    if not userProfileInteger(raw.schema) then return failure
    if raw.schema <> 1 then return failure
    if type(raw.playlistId) <> "String" and type(raw.playlistId) <> "roString" then return failure
    if raw.playlistId <> slotId then return failure
    if not userProfileBoolean(raw.askAtLaunch) or type(raw.profiles) <> "roArray" then return failure
    if raw.profiles.count() < 1 or raw.profiles.count() > 4 then return failure
    result = defaultUserProfileStore(slotId)
    ids = {}
    usernames = {}
    users = {}
    defaults = 0
    for each entry in raw.profiles
        profile = normalizeUserProfileRecord(entry, slotId)
        if profile = invalid then return failure
        username = lcase(profile.username)
        userId = profile.userId.toStr()
        if ids.doesExist(profile.id) or usernames.doesExist(username) or users.doesExist(userId) then return failure
        ids[profile.id] = true
        usernames[username] = true
        users[userId] = true
        if profile.isDefault then defaults++
        result.profiles.push(profile)
    end for
    active = userProfileLocalId(raw.active)
    if defaults <> 1 or not ids.doesExist(active) then return failure
    result.active = active
    result.askAtLaunch = raw.askAtLaunch
    for each field in ["knownDefault", "addressChangeSnapshot"]
        if raw.doesExist(field)
            identity = normalizeUserProfileAddressIdentity(raw[field])
            if identity = invalid then return failure
            result = setCanonicalPreference(result, field, identity)
        end if
    end for
    if raw.doesExist("removed")
        removed = userProfileNormalizeTombstones(raw.removed)
        if removed = invalid then return failure
        result.removed = removed
    end if
    if raw.doesExist("pendingRoster")
        if not userProfileBoolean(raw.pendingRoster) then return failure
        result.pendingRoster = raw.pendingRoster
    end if
    return result
end function

' Native literals and ParseJson maps differ in case sensitivity. Canonicalize
' recognized keys explicitly before dynamic field lookup, preserving values
' while refusing case-colliding keys rather than choosing one arbitrarily.
function userProfileCanonicalFields(raw as dynamic, allowed as object) as dynamic
    if not userProfileFields(raw, allowed) then return invalid
    result = ParseJson("{}")
    for each key in raw
        for each name in allowed
            if lcase(key) = lcase(name) then result[name] = raw[key]
        end for
    end for
    return result
end function

function userProfileFields(raw as dynamic, allowed as object) as boolean
    if type(raw) <> "roAssociativeArray" then return false
    seen = {}
    for each key in raw
        canonical = lcase(key)
        if seen.doesExist(canonical) then return false
        seen[canonical] = true
        found = false
        for each name in allowed
            if lcase(key) = lcase(name) then found = true
        end for
        if not found then return false
    end for
    return true
end function

function userProfileBoolean(value as dynamic) as boolean
    return type(value) = "Boolean" or type(value) = "roBoolean"
end function

' Local server-address trust only; never part of the shared profiles category.
function normalizeUserProfileAddressIdentity(raw as dynamic) as dynamic
    raw = userProfileCanonicalFields(raw, ["userId", "username"])
    if raw = invalid then return invalid
    if not userProfileInteger(raw.userId) then return invalid
    id = userProfileUserId(raw.userId)
    if id = invalid then return invalid
    if type(raw.username) <> "String" and type(raw.username) <> "roString" then return invalid
    if raw.username.trim() = "" or userProfileUtf8ByteCount(raw.username) > 256 then return invalid
    if CreateObject("roRegex", "[\x00-\x1F\x7F]", "").isMatch(raw.username) then return invalid
    result = ParseJson("{}")
    result["userId"] = id
    result["username"] = raw.username
    return result
end function

function normalizeUserProfileRecord(raw as dynamic, slotId as string) as dynamic
    fields = ["id", "playlistId", "userId", "username", "displayName", "isDefault", "role", "userLevel", "isStaff", "isSuperuser", "order", "createdAt", "updatedAt", "avatar", "pinType", "pinHash", "pinSalt", "pinLength", "addOrigin", "addressHeld", "displayNameClaimed", "avatarClaimed", "defaultIdentityTag"]
    raw = userProfileCanonicalFields(raw, fields)
    if raw = invalid then return invalid
    id = userProfileLocalId(raw.id)
    if id = "" then return invalid
    if type(raw.playlistId) <> "String" and type(raw.playlistId) <> "roString" then return invalid
    if raw.playlistId <> slotId then return invalid
    if not userProfileInteger(raw.userId) then return invalid
    userId = userProfileUserId(raw.userId)
    if userId = invalid then return invalid
    for each field in ["username", "displayName", "role", "pinType", "pinHash", "pinSalt"]
        if type(raw[field]) <> "String" and type(raw[field]) <> "roString" then return invalid
    end for
    if raw.username.trim() = "" or userProfileUtf8ByteCount(raw.username) > 256 then return invalid
    if CreateObject("roRegex", "[\x00-\x1F\x7F]", "").isMatch(raw.username) then return invalid
    if userProfileUtf8ByteCount(raw.displayName) > 40 then return invalid
    for each field in ["isDefault", "isStaff", "isSuperuser"]
        if not userProfileBoolean(raw[field]) then return invalid
    end for
    for each field in ["userLevel", "order", "createdAt", "updatedAt"]
        if not userProfileInteger(raw[field]) then return invalid
    end for
    if raw.userLevel < 0 or raw.order < -1 or raw.createdAt < 0 or raw.updatedAt < 0 then return invalid
    if (raw.isStaff or raw.isSuperuser) and raw.userLevel < 10 then return invalid
    if userProfileResolveRole(raw.userLevel, raw.role) <> raw.role then return invalid
    if raw.pinType = "none"
        if raw.pinHash <> "" or raw.pinSalt <> "" then return invalid
    else if not userProfilePinRecordValid(raw)
        return invalid
    end if
    raw["avatar"] = userProfileNormalizeAvatar(raw.avatar)
    result = copyJson(raw)
    result.id = id
    result["userId"] = userId
    origin = "plain"
    if raw.doesExist("addOrigin")
        if type(raw.addOrigin) <> "String" and type(raw.addOrigin) <> "roString" then return invalid
        origin = raw.addOrigin
        if origin <> "plain" and origin <> "roster" and origin <> "paused" then return invalid
    end if
    result["addOrigin"] = origin
    held = false
    if raw.doesExist("addressHeld")
        if not userProfileBoolean(raw.addressHeld) then return invalid
        held = raw.addressHeld
    end if
    if held and raw.isDefault then return invalid
    result["addressHeld"] = held
    if raw.doesExist("defaultIdentityTag")
        if raw.isDefault then return invalid
        tag = raw["defaultIdentityTag"]
        if tag <> invalid
            tag = normalizeUserProfileAddressIdentity(tag)
            if tag = invalid then return invalid
        end if
        result["defaultIdentityTag"] = tag
    end if
    pinLength = 0
    if raw.doesExist("pinLength")
        if not userProfileInteger(raw["pinLength"]) then return invalid
        pinLength = raw["pinLength"]
        if pinLength <> 0 and (pinLength < 4 or pinLength > 6) then return invalid
        if raw.pinType = "none" and pinLength <> 0 then return invalid
    end if
    result["pinLength"] = pinLength
    for each field in ["displayNameClaimed", "avatarClaimed"]
        claimed = false
        if raw.doesExist(field)
            if not userProfileBoolean(raw[field]) then return invalid
            claimed = raw[field]
        end if
        result[field] = claimed
    end for
    return result
end function

function loadUserProfileStore(registry as object, slotId as string) as object
    key = userProfileStoreKey(slotId)
    if key = "" then return userProfileStoreRecovery(slotId)
    if not registry.exists(key) then return defaultUserProfileStore(slotId)
    text = registry.read(key)
    if text = "" then return userProfileStoreRecovery(slotId)
    return normalizeUserProfileStore(ParseJson(text), slotId)
end function

' Repeated migration does not re-ID, stamp, clear a PIN, change role or replace
' metadata. Default identity replacement is a different, gated lifecycle action.
function userProfileEnsureDefault(store as object, verified as object) as dynamic
    verified = normalizeUserProfileRecord(verified, store.playlistId)
    if verified = invalid then return invalid
    if store.readOnly = true or store.playlistId <> verified.playlistId then return invalid
    if verified.isDefault <> true then return invalid
    if store.profiles.count() = 0
        result = copyJson(store)
        result.profiles.push(copyJson(verified))
        result.active = verified.id
        cleaned = normalizeUserProfileStore(result, store.playlistId)
        if cleaned.readOnly = true then return invalid
        return cleaned
    end if
    cleaned = normalizeUserProfileStore(store, store.playlistId)
    if cleaned.readOnly = true then return invalid
    for each profile in cleaned.profiles
        if profile.isDefault
            if profile.userId <> verified.userId or lcase(profile.username) <> lcase(verified.username) then return invalid
            ' Server authority is live, not a once-only migration fact. Preserve
            ' local identity/PIN/stamps, but never retain revoked admin rights.
            for each field in ["userLevel", "isStaff", "isSuperuser"]
                profile[field] = verified[field]
            end for
            profile["role"] = userProfileResolveRole(verified.userLevel, profile.role)
        end if
    end for
    return cleaned
end function

' One atomic Flush for metadata + nondefault key updates/deletions. No active
' runtime state changes here. Default key/Remember and scope cleanup belong to
' the slot lifecycle transaction, not this deliberately narrower primitive.
function commitUserProfileStore(registry as object, previous as object, staged as object, keys as object, remember as boolean) as object
    prepared = userProfileStoreChanges(registry, previous, staged, keys, remember)
    if not prepared.ok then return {ok: false, recoveryRequired: false}
    return userProfileRegistryTransaction(registry, prepared.changes)
end function

' Validated transaction preparation, also used when scoped preference cleanup
' must be committed in the very same Flush as a profile/key removal.
function userProfileStoreChanges(registry as object, previous as object, staged as object, keys as object, remember as boolean) as object
    failure = {ok: false, recoveryRequired: false}
    if previous.readOnly = true or staged.readOnly = true then return failure
    slotId = previous.playlistId
    if staged.playlistId <> slotId then return failure
    key = userProfileStoreKey(slotId)
    if key = "" then return failure
    before = previous
    if previous.profiles.count() > 0 then before = normalizeUserProfileStore(previous, slotId)
    if before.readOnly = true then return failure
    actual = loadUserProfileStore(registry, slotId)
    if actual.readOnly = true or FormatJson(actual) <> FormatJson(before) then return failure
    cleaned = normalizeUserProfileStore(staged, slotId)
    if cleaned.readOnly = true then return failure
    for each profile in previous.profiles
        if profile.isDefault
            found = false
            for each target in cleaned.profiles
                if target.isDefault and target.id = profile.id then found = true
            end for
            if not found then return failure
        end if
    end for
    text = FormatJson(cleaned)
    ' Safety ceiling for this small four-record format, not free-registry space.
    if userProfileUtf8ByteCount(text) > 8192 then return failure
    owned = {}
    for each profile in cleaned.profiles
        if not profile.isDefault then owned[profile.id] = true
    end for
    changes = {}
    for each id in keys
        if not owned.doesExist(id) then return failure
        value = keys[id]
        if type(value) <> "String" and type(value) <> "roString" then return failure
        if len(value) > 512 then return failure
        changes[userProfileKeyName(slotId, id)] = value
    end for
    for each profile in previous.profiles
        if not profile.isDefault and (not owned.doesExist(profile.id) or not remember) then changes[userProfileKeyName(slotId, profile.id)] = ""
    end for
    if not remember
        for each id in owned
            changes[userProfileKeyName(slotId, id)] = ""
        end for
    end if
    changes[key] = text
    return {ok: true, changes: changes}
end function

' Internal atomic commit primitive. Callers build an explicit owned-key map;
' this function never enumerates storage or chooses what should be deleted.
function userProfileRegistryTransaction(registry as object, changes as object) as object
    failure = {ok: false, recoveryRequired: false}
    snapshots = {}
    present = {}
    for each name in changes
        snapshots[name] = registry.read(name)
        present[name] = registry.exists(name)
    end for
    written = true
    for each name in changes
        if changes[name] = ""
            written = registry.delete(name) and written
        else
            written = registry.write(name, changes[name]) and written
        end if
    end for
    flushed = false
    if written then flushed = registry.flush()
    if written and flushed then return {ok: true, recoveryRequired: false}
    restored = true
    for each name in snapshots
        if present[name]
            restored = registry.write(name, snapshots[name]) and restored
        else
            restored = registry.delete(name) and restored
        end if
    end for
    restored = registry.flush() and restored
    failure.recoveryRequired = not restored
    return failure
end function
