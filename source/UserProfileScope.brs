' Internal scoped-state primitives. Controllers must construct/adopt a session
' only after target-owned authentication and permission/lineup staging succeed.
function userProfileAccountSeedFields() as object
    return ["startupBehavior", "vodEnabled", "vodTmdbEnabled", "dvrPreRollMinutes", "dvrPostRollMinutes"]
end function

function userProfileGuideSeedFields() as object
    return ["groupSort", "groupOrder", "channelSort", "groupLayout", "collectionsPosition", "historyDays", "futureDays", "badges", "tmdbFallback", "guideDensity", "showLogos", "showNumbers", "showNames", "showSubtitles"]
end function

' Explicit PO-approved appearance/player axis. Network, clock, accessibility,
' remote mapping/direction and hardware/display controls remain device-local.
function userProfileSettingsFields() as object
    return ["themePreset", "appearanceMode", "customAccent", "panelStyle", "textSize", "subtextSize", "contrastMode", "audioMode", "liveTransport", "liveStartupRetries", "videoScale", "archiveSkipSeconds", "infoLogo", "infoChannel", "infoTitle", "infoTime", "infoDescription", "infoNext", "infoHints"]
end function

function userProfilePickSettings(raw as dynamic, allowed as object) as object
    result = ParseJson("{}")
    if type(raw) <> "roAssociativeArray" then return result
    for each field in allowed
        matches = 0
        value = invalid
        for each key in raw
            if lcase(key) = lcase(field)
                matches++
                value = raw[key]
            end if
        end for
        ' Ambiguous aliases cannot silently choose another user's value.
        if matches = 1 then result[field] = copyJson(value)
    end for
    return result
end function

function normalizeUserProfileSettings(raw as dynamic) as object
    selected = userProfilePickSettings(raw, userProfileSettingsFields())
    selected = userProfileTypedSettings(selected, ["textSize", "subtextSize", "liveStartupRetries", "archiveSkipSeconds"], ["infoLogo", "infoChannel", "infoTitle", "infoTime", "infoDescription", "infoNext", "infoHints"], [], [])
    normalized = normalizeDevicePreferences(selected)
    return userProfileNormalizedFields(normalized, userProfileSettingsFields())
end function

function userProfileTypedSettings(selected as object, integers as object, booleans as object, arrays as object, objects as object) as object
    for each field in selected.keys()
        expected = "string"
        for each key in integers
            if lcase(field) = lcase(key) then expected = "integer"
        end for
        for each key in booleans
            if lcase(field) = lcase(key) then expected = "boolean"
        end for
        for each key in arrays
            if lcase(field) = lcase(key) then expected = "array"
        end for
        for each key in objects
            if lcase(field) = lcase(key) then expected = "object"
        end for
        kind = type(selected[field])
        valid = false
        if expected = "string" then valid = kind = "String" or kind = "roString"
        if expected = "integer" then valid = userProfileInteger(selected[field])
        if expected = "boolean" then valid = kind = "Boolean" or kind = "roBoolean"
        if expected = "array" then valid = kind = "roArray"
        if expected = "object" then valid = kind = "roAssociativeArray"
        if not valid then selected.delete(field)
    end for
    return selected
end function

' The legacy normalizer writes validated values through lower-case aliases on
' native parsed maps. Select those validated outputs, never an older raw alias.
' This helper is only for normalizer output; untrusted input uses PickSettings.
function userProfileNormalizedFields(normalized as object, fields as object) as object
    result = ParseJson("{}")
    for each field in fields
        key = field
        if normalized.doesExist(lcase(field)) then key = lcase(field)
        if normalized.doesExist(key) then result[field] = copyJson(normalized[key])
    end for
    return result
end function

function userProfileSeedAccountPreferences(raw as dynamic) as object
    ' Build from the Copy allowlist, never clone an entire user blob then clear.
    selected = userProfilePickSettings(raw, userProfileAccountSeedFields())
    selected = userProfileTypedSettings(selected, ["dvrPreRollMinutes", "dvrPostRollMinutes"], ["vodEnabled", "vodTmdbEnabled"], [], [])
    guide = invalid
    settings = invalid
    if type(raw) = "roAssociativeArray"
        guide = raw.guide
        settings = raw.profileSettings
    end if
    selected["guide"] = userProfileTypedSettings(userProfilePickSettings(guide, userProfileGuideSeedFields()), ["historyDays", "futureDays"], ["tmdbFallback", "showLogos", "showNumbers", "showNames", "showSubtitles"], ["groupOrder"], ["badges"])
    selected["profileSettings"] = normalizeUserProfileSettings(settings)
    result = normalizeAccountPreferences(selected)
    normalized = userProfileNormalizedFields(result, userProfileAccountSeedFields())
    for each field in normalized
        result = setCanonicalPreference(result, field, normalized[field])
    end for
    return result
end function

function userProfileSessionFields() as object
    return ["playlistId", "profileId", "accountId", "preferenceIdentity", "authorizationGeneration", "sessionId"]
end function

function userProfileSessionScope(connection as object, profileId as string, verifiedUserId as dynamic, generation as string, sessionId as string) as dynamic
    if connection.provider <> "dispatcharr" then return invalid
    if userProfileKeyPrefix(connection.id) = "" then return invalid
    profileId = userProfileLocalId(profileId)
    sessionId = userProfileLocalId(sessionId)
    accountId = userProfileUserId(verifiedUserId)
    if profileId = "" or sessionId = "" or accountId = invalid or generation = "" or len(generation) > 512 then return invalid
    identity = connectionPreferenceIdentity(connection, accountId.toStr())
    if identity = "" then return invalid
    result = ParseJson("{}")
    result["playlistId"] = connection.id
    result["profileId"] = profileId
    result["accountId"] = accountId.toStr()
    result["preferenceIdentity"] = identity
    result["authorizationGeneration"] = generation
    result["sessionId"] = sessionId
    return result
end function

function userProfileSameSession(first as dynamic, second as dynamic) as boolean
    if type(first) <> "roAssociativeArray" or type(second) <> "roAssociativeArray" then return false
    for each field in userProfileSessionFields()
        value = first[field]
        if type(value) <> "String" and type(value) <> "roString" then return false
        other = second[field]
        if type(other) <> "String" and type(other) <> "roString" then return false
        if value = "" or value <> other then return false
    end for
    return true
end function

function userProfileMergeSettings(raw as dynamic, normalized as object) as object
    result = ParseJson("{}")
    if type(raw) = "roAssociativeArray" then result = copyJson(raw)
    for each field in userProfileSettingsFields()
        result = setCanonicalPreference(result, field, normalized[field])
    end for
    return result
end function

' legacyDevice is the already-normalized on-device baseline, not the outgoing
' profile's effective UI object. Presence of an empty settings map is migration;
' a malformed present map is recovery, never permission to copy another user.
function userProfilePrepareSettings(preferences as object, legacyDevice as object) as object
    count = 0
    raw = invalid
    for each key in preferences
        if lcase(key) = "profilesettings"
            count++
            raw = preferences[key]
        end if
    end for
    if count > 1 then return {ok: false}
    if count = 1 and type(raw) <> "roAssociativeArray" then return {ok: false}
    migrated = count = 0
    if migrated then raw = userProfileNormalizedFields(legacyDevice, userProfileSettingsFields())
    normalized = normalizeUserProfileSettings(raw)
    stored = userProfileMergeSettings(raw, normalized)
    nextPreferences = setCanonicalPreference(preferences, "profileSettings", stored)
    effective = copyJson(legacyDevice)
    for each field in userProfileSettingsFields()
        effective = setCanonicalPreference(effective, field, normalized[field])
    end for
    return {ok: true, migrated: migrated, preferences: nextPreferences, device: effective}
end function

' One staged settingsV1 value owns both account settings and physical-device
' settings. Callers adopt it only after the registry transaction succeeds.
function userProfileSettingsCommitPlan(store as object, identity as string, preferences as object, effectiveDevice as object) as object
    if identity = "" or len(identity) > 2048 then return {ok: false}
    if type(store.device) <> "roAssociativeArray" or type(store.accounts) <> "roAssociativeArray" then return {ok: false}
    prepared = userProfilePrepareSettings(preferences, store.device)
    if not prepared.ok then return {ok: false}
    settings = normalizeUserProfileSettings(userProfileNormalizedFields(effectiveDevice, userProfileSettingsFields()))
    current = prepared.preferences.profileSettings
    nextPreferences = setCanonicalPreference(prepared.preferences, "profileSettings", userProfileMergeSettings(current, settings))
    baseline = normalizeUserProfileSettings(userProfileNormalizedFields(store.device, userProfileSettingsFields()))
    persistedDevice = copyJson(effectiveDevice)
    for each field in userProfileSettingsFields()
        persistedDevice = setCanonicalPreference(persistedDevice, field, baseline[field])
    end for
    ' Copy only the containers this plan replaces. Never serialize untouched
    ' accounts/root extensions through FormatJson: it shortens native Doubles.
    ' Foreign blobs remain read-only; neither this plan nor the commit edits them.
    nextStore = ParseJson("{}")
    for each key in store
        nextStore[key] = store[key]
    end for
    nextAccounts = ParseJson("{}")
    for each key in store.accounts
        nextAccounts[key] = store.accounts[key]
    end for
    nextStore.accounts = nextAccounts
    nextStore.device = persistedDevice
    nextStore.accounts[preferenceScope(identity)] = nextPreferences
    return {ok: true, store: nextStore, preferences: nextPreferences}
end function
