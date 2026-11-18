' Import-only batch core. The receiver must still own its UI/Task nonce, commit
' the verified slot first, and keep protected content covered through this second
' transaction. This module does not enable the receiver or create PIN material.
function phoneSetupPlaylistIdentityPlan(connections as object, incoming as dynamic, generated as string) as object
    denied = {ok: false}
    if connections.readOnly = true then return denied
    id = ""
    if type(incoming) = "String" or type(incoming) = "roString" then id = lcase(incoming)
    if connectionRegistryKey(id) = "" then id = ""
    matched = ""
    if id <> ""
        for each entry in connections.entries
            if lcase(entry.id) = id
                if matched <> "" then return denied
                matched = entry.id
            end if
        end for
    end if
    if matched <> "" then return {ok: true, id: matched, matchedId: matched}
    if id = "" then id = lcase(generated)
    if connectionRegistryKey(id) = "" then return denied
    for each entry in connections.entries
        if lcase(entry.id) = id then return denied
    end for
    return {ok: true, id: id, matchedId: ""}
end function

' Called before verifying a matched payload at another origin. Reuse the
' established hold/snapshot policy and retire all persisted target keys in the
' same transaction as the URL edit. No incoming identity updates that snapshot.
function phoneSetupHoldMatchedAddress(registry as object, connections as object, slotId as string, nextUrl as string) as object
    denied = {ok: false, recoveryRequired: false}
    if registry.exists("preferences") or connections.readOnly = true then return denied
    actual = loadConnectionStore(registry)
    if actual.readOnly = true or FormatJson(actual) <> FormatJson(normalizeConnectionStore(connections)) then return denied
    entry = connectionStoreEntry(actual, slotId)
    if entry = invalid then return denied
    previous = loadUserProfileStore(registry, slotId)
    if previous.readOnly = true or previous.profiles.count() = 0 then return denied
    planned = userProfileAddressChangePlan(entry, previous, nextUrl)
    if not planned.ok then return denied
    updated = connectionStoreUpdate(actual, slotId, {url: nextUrl, remember: false})
    if updated = invalid or preferenceByteBudget(FormatJson(updated)) > 5000 then return denied
    prepared = userProfileStoreChanges(registry, previous, planned.store, {}, false)
    if not prepared.ok then return denied
    prepared.changes["connectionsV1"] = FormatJson(updated)
    prepared.changes[connectionRegistryKey(slotId)] = ""
    if slotId = "legacy" then prepared.changes["apiKey"] = ""
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if not saved.ok then return saved
    return {ok: true, connections: updated, store: planned.store, previous: previous, changed: planned.changed}
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
    end if
    if row.role = "admin" or row.role = "user" or row.role = "child"
        nextProfile = setCanonicalPreference(nextProfile, "role", userProfileResolveRole(nextProfile.userLevel, row.role))
    end if
    if userProfileInteger(row.order)
        if row.order >= 0 then nextProfile = setCanonicalPreference(nextProfile, "order", row.order)
    end if
    if type(row.avatar) = "roAssociativeArray"
        nextProfile = setCanonicalPreference(nextProfile, "avatar", userProfileNormalizeAvatar(row.avatar))
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
    if connection.id <> previous.playlistId then return denied
    store = defaultUserProfileStore(connection.id)
    if previous.profiles.count() > 0
        store = normalizeUserProfileStore(previous, connection.id)
        if store.readOnly = true then return denied
    else if FormatJson(previous) <> FormatJson(store)
        return denied
    end if
    ordered = phoneSetupProfileQueue(rows)
    if not ordered.ok then return denied
    defaultRow = ordered.defaultRow
    queue = ordered.queue
    name = textValue(connection.accountUsername)
    if name = "" then return denied
    if defaultRow <> invalid
        if lcase(textValue(defaultRow.username)) <> lcase(name) then return denied
    end if
    base = phoneSetupProfileProof(connection, name, proofs)
    if base = invalid then return denied
    defaultId = lcase(textValue(ids.defaultId))
    if store.profiles.count() = 0 and defaultRow <> invalid
        suppliedId = userProfileLocalId(defaultRow.id)
        if suppliedId <> "" then defaultId = suppliedId
    end if
    facts = userProfileFromVerified(connection.id, defaultId, base.verifiedUser, now)
    if facts = invalid or facts.userId.toStr() <> connection.accountId then return denied
    previousRole = facts.role
    for each profile in store.profiles
        if profile.isDefault then previousRole = profile.role
    end for
    if store.profiles.count() > 0
        ' Preserve the old comparison snapshot, PIN and default UUID while
        ' rebuilding changed account metadata through the shared policy.
        rebuilt = userProfileEnsureDefault(store, facts, true)
        if rebuilt = invalid then return denied
        checked = userProfileDefaultAddressCheck(connection, rebuilt, base)
        if not checked.ok then return denied
        store = checked.store
    end if
    defaultIndex = -1
    authorityChanged = false
    for i = 0 to store.profiles.count() - 1
        profile = store.profiles[i]
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
        authorityChanged = nextRole <> previousRole
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

' Slot/key and a credential-free fence share the first Flush. All normal
' profile loaders fail closed until the second transaction installs protection.
function phoneSetupCommitFencedConnection(registry as object, previous as object, staged as object, apiKey as string, nonce as string) as object
    denied = {ok: false, recoveryRequired: false}
    if userProfileLocalId(nonce) = "" or previous.readOnly = true or staged.readOnly = true then return denied
    before = normalizeConnectionStore(previous)
    after = normalizeConnectionStore(staged)
    if before.readOnly = true or after.readOnly = true then return denied
    entry = connectionStoreEntry(after, after.selected)
    if entry = invalid then return denied
    if entry.provider <> "dispatcharr" or apiKey = "" or len(apiKey) > 512 then return denied
    if preferenceByteBudget(FormatJson(after)) > 5000 then return denied
    if registry.read("connectionsV1") <> ""
        actual = loadConnectionStore(registry)
        if actual.readOnly = true or FormatJson(actual) <> FormatJson(before) then return denied
    else if before.entries.count() <> 0
        return denied
    end if
    ' The pre-verification address controller must already have committed any
    ' URL change. Default identity replacement stays behind this fence until
    ' the shared rebuild policy runs in the metadata transaction.
    old = connectionStoreEntry(before, entry.id)
    if old <> invalid
        if old.url <> entry.url then return denied
    end if
    fenceKey = userProfileImportKey(entry.id)
    if registry.exists(fenceKey) then return denied
    store = loadUserProfileStore(registry, entry.id)
    if store.readOnly = true then return denied
    root = FormatJson({schema: 1, nonce: nonce, hadPrevious: old <> invalid, previous: old, previousSelected: before.selected, profileRootHash: phoneSetupProfileRootHash(registry.read(userProfileStoreKey(entry.id)))})
    changes = {}
    changes["connectionsV1"] = FormatJson(after)
    changes[fenceKey] = root
    key = ""
    if entry.remember then key = apiKey
    changes[connectionRegistryKey(entry.id)] = key
    if entry.id = "legacy" then changes["apiKey"] = ""
    saved = userProfileRegistryTransaction(registry, changes)
    if not saved.ok then return saved
    return {ok: true, store: after, importRoot: root}
end function

function phoneSetupProfileRootHash(text as string) as string
    if m.phoneProfileRootHasher <> invalid then return m.phoneProfileRootHasher(text)
    ' roEVPDigest returns "" for a never-updated/empty input on Roku. Use the
    ' standard SHA-256 empty-message value for an absent new-slot profile root.
    if text = "" then return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(text)
    digest = CreateObject("roEVPDigest")
    digest.setup("sha256")
    return lcase(digest.process(bytes))
end function

' Explicit local cancellation after restart. Restore only non-secret slot
' metadata; the overwritten default key is deleted, never guessed or borrowed.
' The original profile root must still match the pre-import digest.
function phoneSetupDiscardIncompleteImport(registry as object, connections as object, slotId as string, capturedRoot as string) as object
    denied = {ok: false, recoveryRequired: false, reason: "journal"}
    if capturedRoot = "" or registry.read(userProfileImportKey(slotId)) <> capturedRoot then return denied
    journal = ParseJson(capturedRoot)
    if type(journal) <> "roAssociativeArray" then return denied
    if journal.schema <> 1 or userProfileLocalId(textValue(journal.nonce)) = "" then return denied
    if not userProfileBoolean(journal.hadPrevious) then return denied
    if type(journal.previousSelected) <> "String" and type(journal.previousSelected) <> "roString" then return denied
    if not CreateObject("roRegex", "^[0-9a-f]{64}$", "").isMatch(textValue(journal.profileRootHash)) then return denied
    denied.reason = "profile-root"
    if journal.profileRootHash <> phoneSetupProfileRootHash(registry.read(userProfileStoreKey(slotId))) then return denied
    if registry.exists(userProfileRetirementKey(slotId)) then return denied
    denied.reason = "connections"
    actual = loadConnectionStore(registry)
    if actual.readOnly = true or FormatJson(actual) <> FormatJson(normalizeConnectionStore(connections)) then return denied
    entry = connectionStoreEntry(actual, slotId)
    if entry = invalid or entry.provider <> "dispatcharr" then return denied
    denied.reason = "previous-slot"
    if not journal.hadPrevious
        if journal.previous <> invalid then return denied
        updated = connectionStoreRemove(actual, slotId)
    else
        previous = normalizeConnectionEntry(journal.previous)
        if previous = invalid then return denied
        if previous.id <> slotId or previous.provider <> "dispatcharr" then return denied
        updated = copyJson(actual)
        for i = 0 to updated.entries.count() - 1
            if updated.entries[i].id = slotId then updated.entries[i] = previous
        end for
    end if
    if updated = invalid then return denied
    if actual.selected = slotId and connectionStoreEntry(updated, textValue(journal.previousSelected)) <> invalid then updated.selected = journal.previousSelected
    changes = {}
    changes["connectionsV1"] = FormatJson(updated)
    changes[connectionRegistryKey(slotId)] = ""
    changes[userProfileImportKey(slotId)] = ""
    if slotId = "legacy" then changes["apiKey"] = ""
    saved = userProfileRegistryTransaction(registry, changes)
    if not saved.ok then saved.reason = "storage"
    if saved.ok then saved.connections = updated
    return saved
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
    importRoot = context.importRoot
    if importRoot <> invalid
        if type(importRoot) <> "String" and type(importRoot) <> "roString" then return denied
        journal = ParseJson(importRoot)
        if type(journal) <> "roAssociativeArray" then return denied
        if journal.schema <> 1 or journal.nonce <> activeNonce then return denied
        if journal.profileRootHash <> phoneSetupProfileRootHash(registry.read(userProfileStoreKey(entry.id))) then return denied
        if registry.read(userProfileImportKey(entry.id)) <> importRoot then return denied
        if registry.exists(userProfileRetirementKey(entry.id)) then return denied
        actual = defaultUserProfileStore(entry.id)
        if registry.exists(userProfileStoreKey(entry.id)) then actual = normalizeUserProfileStore(ParseJson(registry.read(userProfileStoreKey(entry.id))), entry.id)
        if actual.retirementPending = true then return denied
    end if
    if actual.readOnly = true or FormatJson(actual) <> FormatJson(context.store) then return denied
    admin = userProfileLoadDeviceAdminPin(registry, entry.id)
    if not admin.ok then return denied
    if FormatJson(admin.record) <> FormatJson(context.deviceAdmin) then return denied
    plan = phoneSetupProfileBatchPlan(entry, actual, context.rows, context.proofs, context.ids, now, context.deviceAdmin)
    if not plan.ok then return plan
    prepared = userProfileStoreChanges(registry, actual, plan.store, plan.keys, entry.remember, invalid, importRoot)
    if not prepared.ok then return prepared
    if importRoot <> invalid then prepared.changes[userProfileImportKey(entry.id)] = ""
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if not saved.ok then return saved
    return plan
end function
