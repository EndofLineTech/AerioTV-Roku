' Import-only batch core. The receiver must still own its UI/Task nonce, commit
' the verified slot first, and keep protected content covered through this second
' transaction. This module does not enable the receiver or create PIN material.
function phoneSetupProfileSyncOffer(incoming as dynamic, choice as object) as boolean
    if type(incoming) <> "roAssociativeArray" then return false
    return incoming.provider = "dispatcharr" and incoming.enabled = true and choice.enabled <> true and choice.declined <> true
end function

function phoneSetupProfileProof(connection as object, username as string, proofs as object) as dynamic
    proof = proofs[lcase(username)]
    if type(proof) <> "roAssociativeArray" then return invalid
    if proof.ok <> true or proof.verifiedBaseUrl <> connection.url then return invalid
    if type(proof.apiKey) <> "String" and type(proof.apiKey) <> "roString" then return invalid
    if proof.apiKey = "" or len(proof.apiKey) > 512 then return invalid
    facts = userProfileFromVerified(connection.id, "00000000-0000-4000-8000-000000000001", proof.verifiedUser, 1)
    if facts = invalid then return invalid
    if lcase(facts.username) <> lcase(username) then return invalid
    return proof
end function

function phoneSetupProfileMetadata(profile as object, row as object, now as integer) as object
    nextProfile = copyJson(profile)
    name = userProfileDisplayName(userProfileTrim(textValue(row.displayName)))
    if name <> ""
        nextProfile = setCanonicalPreference(nextProfile, "displayName", name)
        nextProfile = setCanonicalPreference(nextProfile, "displayNameClaimed", true)
    end if
    if row.role = "admin" or row.role = "user" or row.role = "child"
        nextProfile = setCanonicalPreference(nextProfile, "role", userProfileResolveRole(nextProfile.userLevel, row.role))
    end if
    if userProfileInteger(row.order)
        if row.order >= 0 then nextProfile = setCanonicalPreference(nextProfile, "order", row.order)
    end if
    if type(row.avatar) = "roAssociativeArray"
        nextProfile = setCanonicalPreference(nextProfile, "avatar", userProfileNormalizeAvatar(row.avatar))
        nextProfile = setCanonicalPreference(nextProfile, "avatarClaimed", true)
    end if
    if userProfilePinRecordValid(row)
        for each field in ["pinType", "pinHash", "pinSalt"]
            nextProfile = setCanonicalPreference(nextProfile, field, row[field])
        end for
        nextProfile = setCanonicalPreference(nextProfile, "pinLength", 0)
    end if
    return setCanonicalPreference(nextProfile, "updatedAt", now)
end function

function phoneSetupProfileKeepPins(profiles as object, deviceAdmin as dynamic) as boolean
    child = false
    protectedAdults = 0
    adults = 0
    for each profile in profiles
        if profile.role = "child" then child = true
        if userProfileFullAccess(profile.role)
            adults++
            if userProfilePinRecordValid(profile) then protectedAdults++
        end if
    end for
    if not child then return true
    if adults <> protectedAdults then return false
    return protectedAdults > 0 or userProfilePinRecordValid(deviceAdmin)
end function

function phoneSetupProfileBatchPlan(connection as object, previous as object, rows as object, proofs as object, ids as object, now as integer, deviceAdmin = invalid as dynamic) as object
    denied = {ok: false, reason: "Could not safely import profiles."}
    if connection.provider <> "dispatcharr" or previous.readOnly = true or now <= 0 then return denied
    if connection.id <> previous.playlistId or type(rows) <> "roArray" then return denied
    store = defaultUserProfileStore(connection.id)
    if previous.profiles.count() > 0
        store = normalizeUserProfileStore(previous, connection.id)
        if store.readOnly = true then return denied
    else if FormatJson(previous) <> FormatJson(store)
        return denied
    end if
    defaultRow = invalid
    queue = []
    for each row in rows
        if type(row) <> "roAssociativeArray" then return denied
        if row.isDefault = true
            if defaultRow <> invalid then return denied
            defaultRow = row
        else
            group = 1
            if row.role = "child" then group = 2
            rank = 2147483647
            if userProfileInteger(row.order)
                if row.order >= 0 then rank = row.order
            end if
            item = {row: row, group: group, rank: rank}
            position = queue.count()
            for i = 0 to queue.count() - 1
                if group < queue[i].group or (group = queue[i].group and rank < queue[i].rank) then position = i : exit for
            end for
            queue.push(item)
            for i = queue.count() - 1 to position + 1 step -1
                queue[i] = queue[i - 1]
            end for
            queue[position] = item
        end if
    end for
    name = textValue(connection.accountUsername)
    if name = "" then return denied
    if defaultRow <> invalid
        if lcase(textValue(defaultRow.username)) <> lcase(name) then return denied
    end if
    base = phoneSetupProfileProof(connection, name, proofs)
    if base = invalid then return denied
    facts = userProfileFromVerified(connection.id, lcase(textValue(ids.defaultId)), base.verifiedUser, now)
    if facts = invalid or facts.userId.toStr() <> connection.accountId then return denied
    defaultIndex = -1
    authorityChanged = false
    for i = 0 to store.profiles.count() - 1
        profile = store.profiles[i]
        if profile.addressHeld then return {ok: false, reason: "Resolve the saved server address before importing profiles."}
        if profile.isDefault then defaultIndex = i
    end for
    if defaultIndex < 0
        store.profiles.push(facts)
        store.active = facts.id
        defaultIndex = 0
    else
        current = store.profiles[defaultIndex]
        if current.userId <> facts.userId or lcase(current.username) <> lcase(facts.username) or now < current.updatedAt then return denied
        for each field in ["userLevel", "isStaff", "isSuperuser"]
            current = setCanonicalPreference(current, field, facts[field])
        end for
        nextRole = userProfileResolveRole(facts.userLevel, current.role)
        authorityChanged = nextRole <> current.role
        current = setCanonicalPreference(current, "role", nextRole)
        if authorityChanged then current = setCanonicalPreference(current, "updatedAt", now)
        store.profiles[defaultIndex] = current
    end if
    if defaultRow <> invalid then store.profiles[defaultIndex] = phoneSetupProfileMetadata(store.profiles[defaultIndex], defaultRow, now)
    skipped = []
    keys = {}
    for each item in queue
        row = item.row
        username = textValue(row.username)
        duplicate = false
        used = {}
        for each profile in store.profiles
            used[profile.id] = true
            if lcase(profile.username) = lcase(username) then duplicate = true
        end for
        if duplicate or store.profiles.count() >= 4
            skipped.push(username)
        else
            id = userProfileLocalId(lcase(textValue(row.id)))
            if id = "" or used.doesExist(id) then id = userProfileLocalId(lcase(textValue(ids.byUsername[lcase(username)])))
            proof = phoneSetupProfileProof(connection, username, proofs)
            target = invalid
            if id <> "" and not used.doesExist(id) and proof <> invalid then target = userProfileFromVerified(connection.id, id, proof.verifiedUser, now)
            if target <> invalid
                for each profile in store.profiles
                    if profile.userId = target.userId then target = invalid : exit for
                end for
            end if
            if target <> invalid
                for each removed in store.removed
                    if lcase(removed[0]) = lcase(username) and removed[1] >= now then target = invalid : exit for
                end for
            end if
            if target <> invalid
                target = setCanonicalPreference(target, "isDefault", false)
                target = setCanonicalPreference(target, "addOrigin", "roster")
                target = phoneSetupProfileMetadata(target, row, now)
                candidates = []
                for each profile in store.profiles
                    candidates.push(profile)
                end for
                candidates.push(target)
                if not phoneSetupProfileKeepPins(candidates, deviceAdmin) then target = invalid
            end if
            if target = invalid
                skipped.push(username)
            else
                store.profiles.push(target)
                keys[target.id] = proof.apiKey
            end if
        end if
    end for
    if not phoneSetupProfileKeepPins(store.profiles, deviceAdmin) then return {ok: false, reason: "Imported profiles need existing adult PIN protection."}
    if defaultRow <> invalid or keys.count() > 0 or authorityChanged then store = setCanonicalPreference(store, "pendingRoster", true)
    recorded = userProfileRecordDefaultIdentity(store, store.doesExist("addressChangeSnapshot"))
    if not recorded.ok then return denied
    store = normalizeUserProfileStore(recorded.store, connection.id)
    if store.readOnly = true then return denied
    return {ok: true, store: store, keys: keys, skipped: skipped}
end function

function commitPhoneSetupProfileBatch(registry as object, context as object, now as integer, activeNonce as string) as object
    denied = {ok: false, recoveryRequired: false}
    if userProfileLocalId(context.nonce) = "" or context.nonce <> activeNonce then return denied
    if context.connectionRoot <> registry.read("connectionsV1") then return denied
    connections = loadConnectionStore(registry)
    if connections.readOnly = true or connections.selected <> context.connection.id then return denied
    entry = connectionStoreEntry(connections, context.connection.id)
    if entry = invalid then return denied
    if FormatJson(entry) <> FormatJson(normalizeConnectionEntry(context.connection)) then return denied
    actual = loadUserProfileStore(registry, entry.id)
    if actual.readOnly = true or FormatJson(actual) <> FormatJson(context.store) then return denied
    admin = userProfileLoadDeviceAdminPin(registry, entry.id)
    if not admin.ok then return denied
    if FormatJson(admin.record) <> FormatJson(context.deviceAdmin) then return denied
    plan = phoneSetupProfileBatchPlan(entry, actual, context.rows, context.proofs, context.ids, now, context.deviceAdmin)
    if not plan.ok then return plan
    saved = commitUserProfileStore(registry, actual, plan.store, plan.keys, entry.remember)
    if not saved.ok then return saved
    return plan
end function
