' Manual Add reads the new user's existing protection before creating a row.
' No source preferences, credential or authenticated scope are copied.
function userProfileAddSyncAvailable(settings as object, scheduledTask as dynamic, outgoingTask as dynamic) as boolean
    if settings.ok <> true then return false
    ' Sync On is not an Add prohibition. The new own form already suspends
    ' scheduling/callback admission; do not open it over an existing transaction.
    return scheduledTask = invalid and outgoingTask = invalid
end function

function userProfileAddPlan(connection as object, previous as object, id as string, username as string, verified as object, read as dynamic, now as integer, sourceRows = invalid as dynamic, profilesEnabled = true as boolean) as object
    denied = {ok: false, reason: "Could not verify this profile."}
    if connection.provider <> "dispatcharr" or now <= 0 or userProfileLocalId(id) = "" then return denied
    store = normalizeUserProfileStore(previous, connection.id)
    if store.readOnly = true then return denied
    if store.profiles.count() >= 4 then return {ok: false, reason: "This playlist already has four profiles."}
    actor = invalid
    for each profile in store.profiles
        if profile.id = store.active then actor = profile
        if profile.id = lcase(id) then return denied
    end for
    if actor = invalid then return denied
    if actor.addressHeld or not userProfileFullAccess(actor.role) then return denied
    if verified.ok <> true or verified.verifiedBaseUrl <> connection.url or textValue(verified.apiKey) = "" then return denied
    if len(textValue(verified.apiKey)) > 512 then return denied
    candidate = userProfileFromVerified(connection.id, id, verified.verifiedUser, now)
    if candidate = invalid then return denied
    if lcase(candidate.username) <> lcase(username.trim()) then return denied
    paused = userProfileRosterAddressPaused(store)
    own = verified.verifiedUser
    if not paused
        if type(read) <> "roAssociativeArray" then return denied
        if read.ok <> true or read.verifiedBaseUrl <> connection.url then return denied
        if textValue(read.accountId) <> candidate.userId.toStr() or lcase(textValue(read.accountUsername)) <> lcase(candidate.username) then return denied
        live = userProfileFromVerified(connection.id, id, read.verifiedUser, now)
        if live = invalid then return denied
        if live.userId <> candidate.userId or lcase(live.username) <> lcase(candidate.username) then return denied
        candidate = live
        own = read.verifiedUser
    end if
    candidate = setCanonicalPreference(candidate, "isDefault", false)
    for each profile in store.profiles
        if profile.userId = candidate.userId or lcase(profile.username) = lcase(candidate.username) then return {ok: false, reason: "This account already has a profile."}
    end for
    removedAt = -1
    for each removed in store.removed
        if lcase(removed[0]) = lcase(candidate.username) and removed[1] >= now - 7776000 then removedAt = removed[1]
    end for
    roster = false
    rosterRow = invalid
    if not paused and profilesEnabled and type(sourceRows) = "roArray"
        for each raw in sourceRows
            row = dispatcharrSyncRosterRow(raw)
            if row = invalid then return denied
            if lcase(row.username) = lcase(candidate.username)
                if row.userId <> candidate.userId then return denied
                if rosterRow = invalid
                    rosterRow = row
                else if row.updatedAt > rosterRow.updatedAt
                    rosterRow = row
                end if
            end if
        end for
    end if
    if paused
        ' No App Data from any user, including the newly authenticated holder.
        ' The saved credential cannot activate this holder until an applying pull.
        candidate = setCanonicalPreference(candidate, "addOrigin", "paused")
    else if read.state = "ready"
        if read.profilesState <> "ready" and read.profilesState <> "absent" then return denied
        if read.profilesState = "ready"
            wire = invalid
            if type(read.data) = "roAssociativeArray"
                categories = read.data["categories"]
                if type(categories) = "roAssociativeArray"
                    category = categories["profiles"]
                    if type(category) = "roAssociativeArray" then wire = category["data"]
                end if
            end if
            decoded = dispatcharrSyncRosterDecode(wire)
            if not decoded.ok then return denied
            for each removed in decoded.removed
                if removed.username = lcase(candidate.username) and removed.removedAt >= now - 7776000 and removed.removedAt > removedAt then removedAt = removed.removedAt
            end for
            for each row in decoded.rows
                if lcase(row.username) = lcase(candidate.username)
                    if row.userId <> candidate.userId then return denied
                    if not profilesEnabled
                        ' A safety read may refuse a protected account while
                        ' Profiles is Off, but cannot import any of its metadata.
                        if row.pinAction <> "clear" or row.role = "child" then return {ok: false, reason: "Turn on Profiles sync to add this protected profile."}
                    else
                        if rosterRow = invalid
                            rosterRow = row
                        else if row.updatedAt > rosterRow.updatedAt
                            rosterRow = row
                        end if
                    end if
                end if
            end for
        end if
    else if read.state <> "missing"
        return {ok: false, reason: "Update this account's profile data on your other device first."}
    end if
    if removedAt >= 0
        if rosterRow = invalid then return {ok: false, reason: "Restore this recently removed profile from your other device first."}
        if rosterRow.updatedAt <= removedAt then return {ok: false, reason: "Restore this recently removed profile from your other device first."}
    end if
    if rosterRow <> invalid
        if rosterRow.pinAction = "keep" then return denied
        ' A new holder has no competing local metadata. Apply the complete row,
        ' including a zero-stamp PIN, rather than turning it into a plain Add.
        candidate = setCanonicalPreference(candidate, "updatedAt", -1)
        candidate = dispatcharrSyncMergeProfile(candidate, rosterRow, now)
        if candidate.updatedAt = 0 then candidate = setCanonicalPreference(candidate, "updatedAt", now)
        roster = true
    end if
    for each profile in store.profiles
        if profile.role = "child" and userProfileFullAccess(candidate.role) and candidate.pinType = "none" then return {ok: false, reason: "While a Child profile exists, Admin and Standard profiles keep a PIN."}
        if candidate.role = "child" and userProfileFullAccess(profile.role) and profile.pinType = "none" then return {ok: false, reason: "Set a PIN on every Admin and Standard profile before adding a Child."}
    end for
    if roster
        candidate = setCanonicalPreference(candidate, "addOrigin", "roster")
    else
        candidate = setCanonicalPreference(candidate, "updatedAt", now)
        ' A paused origin is itself durable deferred intent. Setting the
        ' shared dirty bit here would leave a push queued after a local Undo.
        if not paused then store = setCanonicalPreference(store, "pendingRoster", true)
    end if
    store.profiles.push(candidate)
    tagged = userProfileAddressOwnTagPlan(store, candidate.id, own, userProfileLiveDefaultAt(connection, store), true)
    if not tagged.ok then return denied
    store = normalizeUserProfileStore(tagged.store, connection.id)
    if store.readOnly = true then return denied
    for each profile in store.profiles
        if profile.id = candidate.id then candidate = profile
    end for
    return {ok: true, store: store, target: candidate}
end function

function commitUserProfileAdd(registry as object, context as object, verified as object, read as object, now as integer, activeNonce as string, activeScope as dynamic, managementNonce as string) as object
    denied = {ok: false, recoveryRequired: false, reason: "Profile access changed. Please try again."}
    if userProfileLocalId(context.nonce) = "" or context.nonce <> activeNonce then return denied
    if not userProfileSameSession(context.scope, activeScope) then return denied
    if activeScope.playlistId <> context.connection.id or activeScope.profileId <> context.store.active then return denied
    connections = loadConnectionStore(registry)
    entry = connectionStoreEntry(connections, context.connection.id)
    if connections.readOnly = true or connections.selected <> context.connection.id or entry = invalid then return denied
    if FormatJson(entry) <> FormatJson(normalizeConnectionEntry(context.connection)) then return denied
    actor = invalid
    for each profile in context.store.profiles
        if profile.id = activeScope.profileId then actor = profile
    end for
    if actor = invalid then return denied
    if actor.userId.toStr() <> activeScope.accountId or activeScope.preferenceIdentity <> connectionPreferenceIdentity(entry, activeScope.accountId) then return denied
    admin = userProfileLoadDeviceAdminPin(registry, entry.id)
    if not admin.ok then return denied
    if not userProfileManagementGrantMatches(context.store, admin.record, context.addGrant, managementNonce, true) then return denied
    settings = loadDispatcharrSyncSettings(registry)
    if not settings.ok then return denied
    sourceRows = invalid
    if type(context.addRosterRows) = "roArray"
        if context.addRosterRows.count() > 0
            if not userProfileSameSession(context.addRosterScope, activeScope) then return denied
            if settings.profiles then sourceRows = context.addRosterRows
        end if
    end if
    planned = userProfileAddPlan(entry, context.store, context.target.id, context.username, verified, read, now, sourceRows, settings.profiles)
    if not planned.ok then return planned
    keys = {}
    keys[planned.target.id] = verified.apiKey
    prepared = userProfileStoreChanges(registry, context.store, planned.store, keys, entry.remember)
    if not prepared.ok then return denied
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if saved.ok
        saved.store = planned.store
        saved.target = planned.target
    end if
    return saved
end function
