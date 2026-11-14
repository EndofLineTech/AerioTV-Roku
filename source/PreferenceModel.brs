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

' Move only one verified holder's blob. Never choose a winner over conflicting
' destination data, normalize foreign accounts, or mutate the caller's root.
function userProfilePreferenceMovePlan(store as object, oldIdentity as string, newIdentity as string) as object
    denied = {ok: false, reason: "scope-conflict", moved: false}
    if oldIdentity = "" or newIdentity = "" then return denied
    if store.readOnly = true or store.schema <> 1 or type(store.accounts) <> "roAssociativeArray" then return denied
    if oldIdentity = newIdentity then return {ok: true, moved: false, store: store}
    oldKey = preferenceScope(oldIdentity)
    newKey = preferenceScope(newIdentity)
    if not store.accounts.doesExist(oldKey) then return {ok: true, moved: false, store: store}
    own = store.accounts[oldKey]
    if type(own) <> "roAssociativeArray" then return denied
    if store.accounts.doesExist(newKey)
        existing = strictJsonEncode(store.accounts[newKey])
        incoming = strictJsonEncode(own)
        if not existing.ok or not incoming.ok then return denied
        if existing.text <> incoming.text then return denied
    end if
    result = copyPreferenceValue(store)
    result.accounts[newKey] = result.accounts[oldKey]
    result.accounts.delete(oldKey)
    return {ok: true, moved: true, store: result}
end function

' Settings-only structural copy: formatting native floating wrappers loses
' precision before a strict writer can preserve them. Keep literal key casing
' and independent mutable containers without changing the general JSON copier.
function copyPreferenceValue(value as dynamic, depth = 0 as integer) as dynamic
    ' Values deeper than the strict writer's budget remain untouched; the writer
    ' refuses them rather than persisting a truncated extension. Bound cycles too.
    if depth > 32 then return value
    kind = type(value)
    if kind = "roAssociativeArray"
        result = ParseJson("{}")
        for each key in value
            result[key] = copyPreferenceValue(value[key], depth + 1)
        end for
        return result
    else if kind = "roArray"
        result = []
        for each item in value
            result.push(copyPreferenceValue(item, depth + 1))
        end for
        return result
    end if
    return value
end function

function defaultPreferenceStore() as object
    return {schema: 1, device: normalizeDevicePreferences(invalid), accounts: {}}
end function

' JSON-backed preferences may contain both camel-case and lower-case spellings.
' Replacing only one spelling leaves the other to win during normalization.
function setCanonicalPreference(raw as object, field as string, value as dynamic) as object
    result = copyPreferenceValue(raw)
    for each key in result.keys()
        if lcase(key) = lcase(field) then result.delete(key)
    end for
    result[field] = value
    return result
end function

function normalizeDevicePreferences(raw as dynamic) as object
    result = {}
    if type(raw) = "roAssociativeArray" then result = copyPreferenceValue(raw)
    ' Earlier Settings writes lowercased camel-case keys on ParseJson's
    ' case-sensitive map. Migrate the displayed choice to the canonical field.
    for each field in ["archiveSkipSeconds", "audioMode", "liveTransport", "liveStartupRetries", "videoScale", "themePreset", "appearanceMode", "panelStyle", "textSize", "subtextSize", "contrastMode", "infoLogo", "infoChannel", "infoTitle", "infoTime", "infoDescription", "infoNext", "infoHints", "networkTimeoutSeconds", "refreshSeconds", "clockFormat", "audioGuide"]
        alias = lcase(field)
        exactAlias = CreateObject("roRegex", "^" + alias + "$", "")
        for each key in result.keys()
            if exactAlias.isMatch(key)
                value = result[key]
                result.delete(key)
                result[field] = value
            end if
        end for
    end for
    preset = "aerio"
    for each choice in ["aerio", "midnight", "sunset", "forest", "lavender", "monochrome", "light"]
        if result.themePreset = choice then preset = choice
    end for
    result.themePreset = preset
    if result.appearanceMode <> "light" then result.appearanceMode = "dark"
    result.customAccent = ucase(textValue(result.customAccent))
    if not CreateObject("roRegex", "^[0-9A-F]{6}$", "").isMatch(result.customAccent) then result.customAccent = ""
    if result.panelStyle <> "solid" then result.panelStyle = "translucent"
    for each field in ["textSize", "subtextSize"]
        size = 100
        for each allowed in [90, 100, 110, 120]
            if result[field] = allowed then size = allowed
        end for
        result[field] = size
    end for
    if result.contrastMode <> "high" then result.contrastMode = "standard"
    result.channelDirection = textValue(result.channelDirection)
    result.videoScale = textValue(result.videoScale)
    result.audioMode = textValue(result.audioMode)
    result.liveTransport = textValue(result.liveTransport)
    result.clockFormat = textValue(result.clockFormat)
    legacyGuideReplay = textValue(result.guideReplayAction)
    legacyPlayerReplay = textValue(result.playerReplayAction)
    if result.channelDirection <> "apple" and result.channelDirection <> "guide" then result.channelDirection = "apple"
    if result.videoScale <> "fit" and result.videoScale <> "fill" and result.videoScale <> "stretch" then result.videoScale = "fit"
    if result.audioMode <> "auto" and result.audioMode <> "direct" and result.audioMode <> "aac" then result.audioMode = "auto"
    if result.liveTransport <> "ts" and result.liveTransport <> "hls" then result.liveTransport = "auto"
    if result.liveStartupRetries <> 0 and result.liveStartupRetries <> 1 and result.liveStartupRetries <> 2 and result.liveStartupRetries <> 3 then result.liveStartupRetries = 1
    if result.clockFormat <> "12" and result.clockFormat <> "24" then result.clockFormat = "system"
    hasRemoteMap = type(result.remoteMap) = "roAssociativeArray"
    result.remoteMap = normalizeRemoteMap(result.remoteMap)
    ' Migrate the two 0.3.30 Replay preferences once into the sparse map.
    if not hasRemoteMap
        if result.channelDirection = "guide"
            result.remoteMap = setRemoteAction(result.remoteMap, "player", "upShort", "channelDown")
            result.remoteMap = setRemoteAction(result.remoteMap, "player", "downShort", "channelUp")
        end if
        if legacyGuideReplay = "options" then result.remoteMap = setRemoteAction(result.remoteMap, "guide", "replay", "openOptions")
        if legacyPlayerReplay = "rewind" then result.remoteMap = setRemoteAction(result.remoteMap, "player", "replay", "rewindHistory")
    end if
    result.delete("guideReplayAction")
    result.delete("playerReplayAction")
    if result.networkTimeoutSeconds <> 10 and result.networkTimeoutSeconds <> 20 and result.networkTimeoutSeconds <> 30 then result.networkTimeoutSeconds = 20
    if result.refreshSeconds <> 120 and result.refreshSeconds <> 300 and result.refreshSeconds <> 600 then result.refreshSeconds = 300
    if result.infoLogo <> false then result.infoLogo = true
    if result.infoChannel <> false then result.infoChannel = true
    if result.infoTitle <> false then result.infoTitle = true
    if result.infoTime <> false then result.infoTime = true
    if result.infoDescription <> false then result.infoDescription = true
    if result.infoNext <> false then result.infoNext = true
    if result.infoHints <> false then result.infoHints = true
    if type(result.audioGuide) <> "Boolean" and type(result.audioGuide) <> "roBoolean" then result.audioGuide = false
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

function normalizeDvrPositions(raw as dynamic) as object
    result = {}
    if type(raw) <> "roAssociativeArray" then return result
    numericId = CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "")
    for each id in raw
        if numericId.isMatch(id) and result.count() < 50
            position = raw[id]
            if GetInterface(position, "ifInt") <> invalid
                if position > 0 and position < 86400 then result[id] = position
            end if
        end if
    end for
    return result
end function

function normalizeAccountPreferences(raw as dynamic) as object
    result = {}
    if type(raw) = "roAssociativeArray" then result = copyPreferenceValue(raw)
    for each field in ["startupBehavior", "vodEnabled", "vodTmdbEnabled", "dvrPreRollMinutes", "dvrPostRollMinutes"]
        alias = lcase(field)
        exactAlias = CreateObject("roRegex", "^" + alias + "$", "")
        for each key in result.keys()
            if exactAlias.isMatch(key)
                value = result[key]
                result.delete(key)
                result[field] = value
            end if
        end for
    end for
    result.favoriteIds = compactIds(result.favoriteIds, 2000)
    result.recent = compactIds(result.recent, 25)
    result.aacChannels = compactIds(result.aacChannels, 100)
    result.dvrPositions = normalizeDvrPositions(result.dvrPositions)
    result.guide = normalizeGuideSettings(result.guide)
    result.collections = normalizeCollections(result.collections)
    result.reminders = normalizeReminders(result.reminders)
    result.lastWatched = textValue(result.lastWatched)
    result.previous = textValue(result.previous)
    result.lastChannel = textValue(result.lastChannel)
    result.group = textValue(result.group)
    if result.group = "" then result.group = "all"
    result.startupBehavior = textValue(result.startupBehavior)
    if result.startupBehavior <> "mini" then result.startupBehavior = "guide"
    for each field in ["dvrPreRollMinutes", "dvrPostRollMinutes"]
        selected = 0
        for each allowed in [0, 5, 10, 15, 30]
            if result[field] = allowed then selected = allowed
        end for
        result[field] = selected
    end for
    result.whatsNewVersion = left(textValue(result.whatsNewVersion), 32)
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
    result = copyPreferenceValue(raw)
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

' Lossless reconciliation is deliberately not last-writer-wins: the old values
' have no reliable timestamps. Conflicting leaves require recovery, not deletion.
function reconcileLegacyPreferenceObjects(first as object, second as object, depth = 0 as integer) as object
    if depth > 24 then return {ok: false}
    result = copyPreferenceValue(first)
    for each key in second
        if not result.doesExist(key)
            result[key] = copyPreferenceValue(second[key])
        else if type(result[key]) = "roAssociativeArray" and type(second[key]) = "roAssociativeArray"
            nested = reconcileLegacyPreferenceObjects(result[key], second[key], depth + 1)
            if not nested.ok then return {ok: false}
            result[key] = nested.value
        else
            prior = strictJsonEncode(result[key])
            incoming = strictJsonEncode(second[key])
            if not prior.ok or not incoming.ok then return {ok: false}
            if prior.text <> incoming.text then return {ok: false}
        end if
    end for
    return {ok: true, value: result}
end function

' Only the original legacy connection and its verified holder can consume the
' unscoped value. Slot/account replacement must be refused before calling this.
' No registry writes occur here; retirement shares the caller's roster Flush.
function legacyOwnerPreferencePlan(registry as object, connection as object, accountId as string) as object
    unchanged = {ok: true, moved: false, retireLegacy: false}
    if connection.id <> "legacy" or connection.provider <> "dispatcharr" then return unchanged
    oldIdentity = connection.url + "|" + accountId
    if normalizeBaseUrl(registry.read("serverUrl")) <> connection.url or registry.read("accountIdentity") <> oldIdentity then return unchanged
    store = loadStrictPreferenceStore(registry)
    if store.readOnly = true then return {ok: false}
    priorKey = preferenceScope(oldIdentity)
    ' This helper is Dispatcharr/legacy-only; keep the shared preference model
    ' independent of the connection controller in Guide/Browser component scope.
    newKey = preferenceScope(oldIdentity + "|" + connection.id)
    hasLegacy = registry.exists("preferences")
    if not hasLegacy and not store.accounts.doesExist(priorKey) then return unchanged
    combined = ParseJson("{}")
    for each source in [newKey, priorKey]
        if store.accounts.doesExist(source)
            merged = reconcileLegacyPreferenceObjects(combined, store.accounts[source])
            if not merged.ok then return {ok: false}
            combined = merged.value
        end if
    end for
    if hasLegacy
        raw = registry.read("preferences")
        if raw = "" then return {ok: false}
        if m.profilePreferenceDecoder <> invalid
            decoded = m.profilePreferenceDecoder(raw)
        else
            decoded = ParseJson(raw, "d")
        end if
        if type(decoded) <> "roAssociativeArray" then return {ok: false}
        merged = reconcileLegacyPreferenceObjects(combined, decoded)
        if not merged.ok then return {ok: false}
        combined = merged.value
    end if
    nextStore = copyPreferenceValue(store)
    nextStore.accounts[newKey] = combined
    nextStore.accounts.delete(priorKey)
    encoded = strictJsonEncode(nextStore)
    if not encoded.ok then return {ok: false}
    if preferenceByteBudget(encoded.text) > 24000 then return {ok: false}
    return {ok: true, moved: true, retireLegacy: hasLegacy, store: nextStore}
end function

function mergeAccountPreferences(current as object, patch as object) as object
    result = copyPreferenceValue(current)
    for each key in patch
        result[key] = patch[key]
    end for
    return normalizeAccountPreferences(result)
end function

function loadPreferenceStore(registry as object, preservePrecision = false as boolean) as object
    if preservePrecision
        decoded = loadStrictPreferenceStore(registry)
        if decoded.readOnly = true then return decoded
        return normalizePreferenceStore(decoded)
    end if
    raw = registry.read("settingsV1")
    if raw = "" then return defaultPreferenceStore()
    return normalizePreferenceStore(ParseJson(raw))
end function

' Cleanup owns deletions, not normalization of other users' known/future fields.
function loadStrictPreferenceStore(registry as object) as object
    refused = {schema: 0, readOnly: true, device: normalizeDevicePreferences(invalid), accounts: {}}
    raw = registry.read("settingsV1")
    if raw = ""
        if registry.exists("settingsV1") then return refused
        return defaultPreferenceStore()
    end if
    if m.profilePreferenceDecoder <> invalid
        decoded = m.profilePreferenceDecoder(raw)
    else
        decoded = ParseJson(raw, "d")
    end if
    if type(decoded) <> "roAssociativeArray" then return refused
    kind = type(decoded.schema)
    if kind <> "Integer" and kind <> "roInt" and kind <> "roInteger" then return refused
    if decoded.schema <> 1 or type(decoded.device) <> "roAssociativeArray" or type(decoded.accounts) <> "roAssociativeArray" then return refused
    for each key in decoded.accounts
        if type(decoded.accounts[key]) <> "roAssociativeArray" then return refused
    end for
    return decoded
end function

function savePreferenceStore(registry as object, store as object, maxBytes = 24000 as integer) as boolean
    if store.schema <> 1 then return false
    encoded = strictJsonEncode(store)
    if not encoded.ok then return false
    json = encoded.text
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

function changeRecentHistory(preferences as object, action as string, uuid as string) as object
    result = normalizeAccountPreferences(preferences)
    if action <> "remove" and action <> "clear" then return result
    recent = []
    for each id in result.recent
        if action = "remove" and id <> uuid then recent.push(id)
    end for
    result.recent = recent
    if action = "clear" or result.lastWatched = uuid then result.lastWatched = ""
    if action = "clear" or result.previous = uuid then result.previous = ""
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
