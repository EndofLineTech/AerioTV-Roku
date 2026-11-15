' Durable LOCAL deletion intent, not a new sync tombstone, authentication scope
' or credential store. This bounded record survives only the select/cleanup gap.
function userProfileNormalizeRetirementJournal(raw as dynamic, slotId as string) as dynamic
    journal = userProfileCanonicalFields(raw, ["schema", "playlistId", "baseUrl", "defaultId", "defaultUserId", "defaultUsername", "intentId", "removed"])
    if journal = invalid then return invalid
    if not userProfileInteger(journal.schema) then return invalid
    if journal.schema <> 1 then return invalid
    if GetInterface(journal.playlistId, "ifString") = invalid then return invalid
    if journal.playlistId <> slotId then return invalid
    if GetInterface(journal.baseUrl, "ifString") = invalid then return invalid
    if normalizeBaseUrl(journal.baseUrl) = "" or normalizeBaseUrl(journal.baseUrl) <> journal.baseUrl then return invalid
    if userProfileLocalId(journal.defaultId) = "" or userProfileLocalId(journal.intentId) = "" then return invalid
    if not userProfileInteger(journal.defaultUserId) then return invalid
    if userProfileUserId(journal.defaultUserId) = invalid then return invalid
    if GetInterface(journal.defaultUsername, "ifString") = invalid then return invalid
    if journal.defaultUsername.trim() = "" then return invalid
    if type(journal.removed) <> "roArray" then return invalid
    if journal.removed.count() = 0 or journal.removed.count() > 4 then return invalid
    entries = []
    seen = {}
    for each value in journal.removed
        row = userProfileCanonicalFields(value, ["id", "userId", "username", "removedAt", "preferenceIdentity"])
        if row = invalid then return invalid
        id = userProfileLocalId(row.id)
        if id = "" or id = userProfileLocalId(journal.defaultId) or seen.doesExist(id) then return invalid
        seen[id] = true
        if not userProfileInteger(row.userId) or not userProfileInteger(row.removedAt) then return invalid
        if userProfileUserId(row.userId) = invalid or row.removedAt <= 0 or row.removedAt > 9007199254740991& then return invalid
        if GetInterface(row.username, "ifString") = invalid or GetInterface(row.preferenceIdentity, "ifString") = invalid then return invalid
        if row.username.trim() = "" then return invalid
        identity = row.preferenceIdentity
        suffix = "|" + row.userId.toStr() + "|" + slotId
        if len(identity) > 2048 or len(identity) <= len(suffix) then return invalid
        if right(identity, len(suffix)) <> suffix then return invalid
        origin = left(identity, len(identity) - len(suffix))
        if normalizeBaseUrl(origin) = "" or normalizeBaseUrl(origin) <> origin then return invalid
        row = setCanonicalPreference(row, "id", id)
        row = setCanonicalPreference(row, "username", lcase(row.username))
        entries.push(row)
    end for
    journal = setCanonicalPreference(journal, "defaultId", userProfileLocalId(journal.defaultId))
    journal = setCanonicalPreference(journal, "intentId", userProfileLocalId(journal.intentId))
    journal = setCanonicalPreference(journal, "defaultUsername", lcase(journal.defaultUsername))
    journal = setCanonicalPreference(journal, "removed", entries)
    encoded = strictJsonEncode(journal)
    if not encoded.ok then return invalid
    if userProfileUtf8ByteCount(encoded.text) > 4096 then return invalid
    return journal
end function

' Cold/local recovery executes only already-committed deletion intent, never a
' fresh remote roster merge. No old key, old request nonce, PIN grant or fabricated
' authenticated scope is needed or returned. Ordinary readers stay fenced until
' the journal is deleted in the same transaction as all eligible local cleanup.
function resumeUserProfileRetirement(registry as object, connection as object, activeScope as dynamic, activeKey as string) as object
    denied = {ok: false, applied: false, recoveryRequired: true}
    if activeScope <> invalid or activeKey <> "" then return denied
    if connection.provider <> "dispatcharr" then return denied
    journalKey = userProfileRetirementKey(connection.id)
    if journalKey = "" then return denied
    if not registry.exists(journalKey)
        orphaned = loadUserProfileStoreForRetirement(registry, connection.id)
        if orphaned.retirementPending = true then return denied
        return {ok: true, applied: false, recovered: false, recoveryRequired: false}
    end if
    root = registry.read(journalKey)
    if root = "" or userProfileUtf8ByteCount(root) > 4096 then return denied
    journal = userProfileNormalizeRetirementJournal(ParseJson(root), connection.id)
    if journal = invalid then return denied
    connections = loadConnectionStore(registry)
    if connections.readOnly = true or connections.selected <> connection.id then return denied
    actualConnection = connectionStoreEntry(connections, connection.id)
    if actualConnection = invalid then return denied
    if FormatJson(actualConnection) <> FormatJson(normalizeConnectionEntry(connection)) then return denied
    if journal.baseUrl <> connection.url then return denied
    current = loadUserProfileStoreForRetirement(registry, connection.id)
    if current.readOnly = true or current.active <> journal.defaultId or current.retirementPending <> true then return denied
    defaultProfile = invalid
    for each profile in current.profiles
        if profile.isDefault then defaultProfile = profile
    end for
    if defaultProfile = invalid or defaultProfile.id <> journal.defaultId then return denied
    if defaultProfile.userId <> journal.defaultUserId or lcase(defaultProfile.username) <> journal.defaultUsername then return denied
    retained = []
    cleanup = []
    found = {}
    for each profile in current.profiles
        remove = false
        for each entry in journal.removed
            if entry.id = profile.id
                found[entry.id] = true
                if profile.isDefault then return denied
                ' A later intentional local/remote edit wins. Do not drop its
                ' key, learned backoff, blob or pending roster mark.
                if profile.updatedAt <= entry.removedAt
                    if profile.userId <> entry.userId or lcase(profile.username) <> entry.username then return denied
                    if userProfilePreferenceIdentity(connection, profile) <> entry.preferenceIdentity then return denied
                    remove = true
                    cleanup.push(entry)
                end if
            end if
        end for
        if not remove then retained.push(profile)
    end for
    ' A prior partial cleanup may have removed the row but left an owned orphan
    ' key/backoff/blob. The bounded journal still names that exact old local ID.
    for each entry in journal.removed
        if not found.doesExist(entry.id) then cleanup.push(entry)
    end for
    staged = setCanonicalPreference(current, "profiles", retained)
    for each field in staged.keys()
        if lcase(field) = "retirementpending" then staged.delete(field)
    end for
    prepared = userProfileStoreChanges(registry, current, staged, {}, true, root)
    if not prepared.ok then return denied
    for each entry in cleanup
        keyName = userProfileKeyName(connection.id, entry.id)
        backoff = userProfilePinBackoffKey(connection.id, entry.id)
        if keyName = "" or backoff = "" then return denied
        if registry.exists(keyName) then prepared.changes[keyName] = ""
        if registry.exists(backoff) then prepared.changes[backoff] = ""
    end for
    preferences = invalid
    if registry.exists("settingsV1")
        preferences = loadStrictPreferenceStore(registry)
        if preferences.readOnly = true then return denied
        if type(preferences) <> "roAssociativeArray" or not userProfileInteger(preferences.schema) then return denied
        if preferences.schema <> 1 or type(preferences.accounts) <> "roAssociativeArray" or type(preferences.device) <> "roAssociativeArray" then return denied
        for each entry in cleanup
            owned = false
            for each profile in retained
                if userProfilePreferenceIdentity(connection, profile) = entry.preferenceIdentity then owned = true
            end for
            if not owned then preferences.accounts.delete(preferenceScope(entry.preferenceIdentity))
        end for
        encoded = strictJsonEncode(preferences)
        if not encoded.ok then return denied
        if preferenceByteBudget(encoded.text) > 24000 then return denied
        if cleanup.count() > 0 then prepared.changes["settingsV1"] = encoded.text
    end if
    prepared.changes[journalKey] = ""
    saved = userProfileRegistryTransaction(registry, prepared.changes)
    if not saved.ok then return saved
    result = {ok: true, applied: true, recovered: true, recoveryRequired: false, store: normalizeUserProfileStore(staged, connection.id), removed: cleanup}
    if type(preferences) = "roAssociativeArray" then result.preferenceStore = preferences
    return result
end function

function userProfilePrepareRetirementJournal(connection as object, previous as object, decoded as object, plan as object, intentId as string) as object
    denied = {ok: false}
    if plan.needsDefaultSwitch <> true then return denied
    defaultProfile = invalid
    for each profile in previous.profiles
        if profile.isDefault then defaultProfile = profile
    end for
    if defaultProfile = invalid then return denied
    entries = []
    for each profile in plan.removed
        stamp = 0&
        for each row in decoded.removed
            if row.username = lcase(profile.username) and row.removedAt > stamp then stamp = row.removedAt
        end for
        for each row in previous.removed
            if lcase(row[0]) = lcase(profile.username) and row[1] > stamp then stamp = row[1]
        end for
        if stamp <= 0 or stamp < profile.updatedAt then return denied
        entries.push({id: profile.id, userId: profile.userId, username: lcase(profile.username), removedAt: stamp, preferenceIdentity: userProfilePreferenceIdentity(connection, profile)})
    end for
    journal = userProfileNormalizeRetirementJournal({schema: 1, playlistId: connection.id, baseUrl: connection.url, defaultId: defaultProfile.id, defaultUserId: defaultProfile.userId, defaultUsername: lcase(defaultProfile.username), intentId: intentId, removed: entries}, connection.id)
    if journal = invalid then return denied
    encoded = strictJsonEncode(journal)
    if not encoded.ok then return denied
    return {ok: true, journal: journal, root: encoded.text}
end function
