function loadRememberPolicy(registry as object) as boolean
    choice = registry.read("rememberApiKey")
    ' Missing policy is the pre-0.2.8 default; malformed values fail closed.
    return choice = "" or choice = "true"
end function

function saveRememberPolicy(registry as object, remember as boolean) as boolean
    choice = "false"
    if remember then choice = "true"
    written = registry.write("rememberApiKey", choice)
    removed = true
    if not remember and registry.read("apiKey") <> "" then removed = registry.delete("apiKey")
    flushed = registry.flush()
    ' Never restore a credential when the viewer has chosen session-only use.
    return written and removed and flushed
end function

function copyJson(value as dynamic) as dynamic
    return ParseJson(FormatJson(value))
end function

function defaultPreferenceStore() as object
    return {schema: 1, device: normalizeDevicePreferences(invalid), accounts: {}}
end function

function normalizeDevicePreferences(raw as dynamic) as object
    result = {}
    if type(raw) = "roAssociativeArray" then result = copyJson(raw)
    result.channelDirection = textValue(result.channelDirection)
    result.videoScale = textValue(result.videoScale)
    result.audioMode = textValue(result.audioMode)
    result.clockFormat = textValue(result.clockFormat)
    if result.channelDirection <> "apple" and result.channelDirection <> "guide" then result.channelDirection = "apple"
    if result.videoScale <> "fit" and result.videoScale <> "fill" and result.videoScale <> "stretch" then result.videoScale = "fit"
    if result.audioMode <> "auto" and result.audioMode <> "direct" and result.audioMode <> "aac" then result.audioMode = "auto"
    if result.clockFormat <> "12" and result.clockFormat <> "24" then result.clockFormat = "system"
    skip = result.archiveSkipSeconds
    ' Keep one canonical key even if a JSON dictionary contains case variants.
    for each key in result.keys()
        if lcase(key) = "archiveskipseconds" then result.delete(key)
    end for
    if skip <> 60 and skip <> 120 and skip <> 300 then skip = 60
    result.archiveSkipSeconds = skip
    return result
end function

function compactIds(raw as dynamic, limit as integer) as object
    result = []
    seen = {}
    seen.setModeCaseSensitive()
    if type(raw) <> "roArray" then return result
    for each value in raw
        id = textValue(value)
        if id <> "" and len(id) <= 128 and not seen.doesExist(id)
            result.push(id)
            seen[id] = true
            if result.count() >= limit then exit for
        end if
    end for
    return result
end function

function normalizeAccountPreferences(raw as dynamic) as object
    result = {}
    if type(raw) = "roAssociativeArray" then result = copyJson(raw)
    result.favoriteIds = compactIds(result.favoriteIds, 2000)
    result.recent = compactIds(result.recent, 25)
    result.aacChannels = compactIds(result.aacChannels, 100)
    result.guide = normalizeGuideSettings(result.guide)
    result.collections = normalizeCollections(result.collections)
    result.reminders = normalizeReminders(result.reminders)
    result.lastWatched = textValue(result.lastWatched)
    result.previous = textValue(result.previous)
    result.lastChannel = textValue(result.lastChannel)
    result.group = textValue(result.group)
    if result.group = "" then result.group = "all"
    aspects = {}
    if type(result.videoAspects) = "roAssociativeArray"
        for each id in result.videoAspects
            aspect = textValue(result.videoAspects[id])
            if len(id) <= 128 and (aspect = "4:3" or aspect = "16:9" or aspect = "21:9") and aspects.count() < 100 then aspects[id] = aspect
        end for
    end if
    result.videoAspects = aspects
    return result
end function

function normalizePreferenceStore(raw as dynamic) as object
    if type(raw) <> "roAssociativeArray" then return defaultPreferenceStore()
    ' Unknown schemas are read-only; never overwrite a newer install's data.
    if type(raw.schema) <> "Integer" and type(raw.schema) <> "roInt" then return defaultPreferenceStore()
    if raw.schema > 1 then return {schema: raw.schema, device: normalizeDevicePreferences(invalid), accounts: {}}
    if raw.schema <> 1 then return defaultPreferenceStore()
    result = copyJson(raw)
    result.device = normalizeDevicePreferences(result.device)
    if type(result.accounts) <> "roAssociativeArray" then result.accounts = {}
    for each key in result.accounts
        result.accounts[key] = normalizeAccountPreferences(result.accounts[key])
    end for
    return result
end function

function preferenceScope(identity as string) as string
    ' Numeric character encoding remains distinct in case-insensitive AA keys.
    key = "account_"
    for i = 1 to len(identity)
        key += asc(mid(identity, i, 1)).toStr() + "_"
    end for
    return key
end function

function preferenceByteBudget(value as string) as integer
    count = 0
    for i = 1 to len(value)
        code = asc(mid(value, i, 1))
        if code < 128
            count++
        else if code < 2048
            count += 2
        else if code < 65536
            count += 3
        else
            count += 4
        end if
    end for
    return count
end function

function accountPreferences(store as object, identity as string, legacyIdentity = "" as string, legacy = invalid as dynamic) as object
    key = preferenceScope(identity)
    if store.accounts.doesExist(key) then return normalizeAccountPreferences(store.accounts[key])
    if identity = legacyIdentity then return normalizeAccountPreferences(legacy)
    return normalizeAccountPreferences(invalid)
end function

function mergeAccountPreferences(current as object, patch as object) as object
    result = copyJson(current)
    for each key in patch
        result[key] = patch[key]
    end for
    return normalizeAccountPreferences(result)
end function

function loadPreferenceStore(registry as object) as object
    raw = registry.read("settingsV1")
    if raw = "" then return defaultPreferenceStore()
    return normalizePreferenceStore(ParseJson(raw))
end function

function savePreferenceStore(registry as object, store as object, maxBytes = 24000 as integer) as boolean
    if store.schema <> 1 then return false
    json = FormatJson(store)
    if preferenceByteBudget(json) > maxBytes then return false
    previous = registry.read("settingsV1")
    if not registry.write("settingsV1", json) then return false
    if registry.flush() then return true
    ' Best-effort rollback of the in-memory registry on failed flush.
    if previous = "" then registry.delete("settingsV1") else registry.write("settingsV1", previous)
    registry.flush()
    return false
end function

function recordWatched(preferences as object, uuid as string) as object
    result = normalizeAccountPreferences(preferences)
    uuid = uuid.trim()
    if uuid = "" then return result
    if result.lastWatched <> uuid
        result.previous = result.lastWatched
        result.lastWatched = uuid
    end if
    result.recent.unshift(uuid)
    result.recent = compactIds(result.recent, 25)
    return result
end function

function reconcileWatchHistory(preferences as object, channels as object) as object
    result = normalizeAccountPreferences(preferences)
    allowed = {}
    for each channel in channels
        allowed[channel.uuid] = true
    end for
    recent = []
    for each id in result.recent
        if allowed.doesExist(id) then recent.push(id)
    end for
    result.recent = recent
    reminders = []
    for each entry in result.reminders
        if allowed.doesExist(entry.channelUuid) then reminders.push(entry)
    end for
    result.reminders = reminders
    aac = []
    for each id in result.aacChannels
        if allowed.doesExist(id) then aac.push(id)
    end for
    result.aacChannels = aac
    if not allowed.doesExist(result.lastWatched) then result.lastWatched = ""
    if not allowed.doesExist(result.previous) then result.previous = ""
    return result
end function

function previousWatched(preferences as object, requestedUuid as string) as string
    if preferences.lastWatched <> requestedUuid and preferences.lastWatched <> "" then return preferences.lastWatched
    return preferences.previous
end function
