' Non-secret roster only. Keys live in separate registry values and provider
' passwords live on Dispatcharr, never in connectionsV1 or settingsV1.
function defaultConnectionStore() as object
    return {schema: 1, selected: "", entries: []}
end function

function connectionRegistryKey(id as string) as string
    if not CreateObject("roRegex", "^[A-Za-z0-9-]{1,40}$", "").isMatch(id) then return ""
    return "connKey_" + id
end function

function connectionNameValid(name as string) as boolean
    if name = "" or len(name) > 48 then return false
    return not CreateObject("roRegex", "[\x00-\x1F<>]", "").isMatch(name)
end function

function normalizeConnectionEntry(raw as dynamic) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    id = textValue(raw.id)
    if connectionRegistryKey(id) = "" then return invalid
    name = textValue(raw.name)
    if not connectionNameValid(name) then return invalid
    if raw.provider <> "dispatcharr" then return invalid
    url = textValue(raw.url)
    if len(url) > 256 then return invalid
    if url <> "" and normalizeBaseUrl(url) = "" then return invalid
    localUrl = textValue(raw.localUrl)
    if len(localUrl) > 256 then return invalid
    if localUrl <> "" and normalizeBaseUrl(localUrl) = "" then return invalid
    agent = textValue(raw.userAgent)
    if len(agent) > 80 or CreateObject("roRegex", "[\x00-\x1F]", "").isMatch(agent) then return invalid
    mode = textValue(raw.authMode)
    if mode <> "bearer" then mode = "api-key"
    accountId = textValue(raw.accountId)
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(accountId) then accountId = ""
    profileId = textValue(raw.profileId)
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(profileId) then profileId = ""
    return {
        id: id, name: name, provider: "dispatcharr", url: normalizeBaseUrl(url)
        localUrl: normalizeBaseUrl(localUrl), userAgent: agent, authMode: mode
        accountId: accountId, profileId: profileId, remember: raw.remember = true
    }
end function

function normalizeConnectionStore(raw as dynamic) as object
    if type(raw) <> "roAssociativeArray" then return defaultConnectionStore()
    if raw.schema <> 1 then return {schema: textValue(raw.schema).toInt(), selected: "", entries: [], readOnly: true}
    if type(raw.entries) <> "roArray" then return {schema: 1, selected: "", entries: [], readOnly: true}
    if raw.entries.count() > 4 then return {schema: 1, selected: "", entries: [], readOnly: true}
    result = defaultConnectionStore()
    ids = {}
    for each candidate in raw.entries
        entry = normalizeConnectionEntry(candidate)
        if entry = invalid then return {schema: 1, selected: "", entries: [], readOnly: true}
        if ids.doesExist(entry.id) then return {schema: 1, selected: "", entries: [], readOnly: true}
        result.entries.push(entry)
        ids[entry.id] = true
    end for
    result.selected = textValue(raw.selected)
    if result.entries.count() > 0 and not ids.doesExist(result.selected) then result.selected = result.entries[0].id
    return result
end function

function loadConnectionStore(registry as object) as object
    saved = registry.read("connectionsV1")
    if saved <> "" then return normalizeConnectionStore(ParseJson(saved))
    legacyUrl = normalizeBaseUrl(registry.read("serverUrl"))
    if legacyUrl = "" then return defaultConnectionStore()
    entry = normalizeConnectionEntry({id: "legacy", name: "Main", provider: "dispatcharr", url: legacyUrl, remember: loadRememberPolicy(registry)})
    return {schema: 1, selected: "legacy", entries: [entry]}
end function

function saveConnectionStore(registry as object, store as object) as boolean
    if store.readOnly = true or store.schema <> 1 then return false
    cleaned = normalizeConnectionStore(store)
    if cleaned.readOnly = true or cleaned.entries.count() <> store.entries.count() then return false
    serialized = FormatJson(cleaned)
    if preferenceByteBudget(serialized) > 5000 then return false
    previous = registry.read("connectionsV1")
    if not registry.write("connectionsV1", serialized) then return false
    if registry.flush() then return true
    if previous = "" then registry.delete("connectionsV1") else registry.write("connectionsV1", previous)
    registry.flush()
    return false
end function

function connectionStoreEntry(store as object, id as string) as dynamic
    for each entry in store.entries
        if entry.id = id then return entry
    end for
    return invalid
end function

function connectionStoreSelect(store as object, id as string) as dynamic
    if connectionStoreEntry(store, id) = invalid then return invalid
    result = copyJson(store)
    result.selected = id
    return result
end function

function connectionStoreAdd(store as object, id as string, name as string) as dynamic
    if store.readOnly = true or store.entries.count() >= 4 or connectionStoreEntry(store, id) <> invalid then return invalid
    entry = normalizeConnectionEntry({id: id, name: name, provider: "dispatcharr", url: "", remember: false})
    if entry = invalid then return invalid
    result = copyJson(store)
    result.entries.push(entry)
    result.selected = id
    return result
end function

function connectionStoreRename(store as object, id as string, name as string) as dynamic
    name = name.trim()
    if not connectionNameValid(name) or connectionStoreEntry(store, id) = invalid then return invalid
    result = copyJson(store)
    for each entry in result.entries
        if entry.id = id then entry.name = name
    end for
    return result
end function

function connectionStoreUpdate(store as object, id as string, patch as object) as dynamic
    previous = connectionStoreEntry(store, id)
    if previous = invalid or store.readOnly = true then return invalid
    result = copyJson(store)
    for each entry in result.entries
        if entry.id = id
            for each key in ["url", "localUrl", "userAgent", "authMode", "accountId", "profileId", "remember"]
                if patch.doesExist(key) then entry[key] = patch[key]
            end for
            if entry.url <> previous.url
                entry.remember = false
                entry.accountId = ""
                entry.profileId = ""
                entry.localUrl = ""
            end if
            normalized = normalizeConnectionEntry(entry)
            if normalized = invalid then return invalid
            entry.append(normalized)
            return result
        end if
    end for
    return invalid
end function

function connectionStoreMove(store as object, id as string, direction as integer) as dynamic
    if direction <> -1 and direction <> 1 then return invalid
    result = copyJson(store)
    for i = 0 to result.entries.count() - 1
        if result.entries[i].id = id
            target = i + direction
            if target < 0 or target >= result.entries.count() then return result
            other = result.entries[target]
            result.entries[target] = result.entries[i]
            result.entries[i] = other
            return result
        end if
    end for
    return invalid
end function

function connectionStoreRemove(store as object, id as string) as dynamic
    if connectionStoreEntry(store, id) = invalid then return invalid
    result = copyJson(store)
    kept = []
    for each entry in result.entries
        if entry.id <> id then kept.push(entry)
    end for
    result.entries = kept
    if result.selected = id
        result.selected = ""
        if kept.count() > 0 then result.selected = kept[0].id
    end if
    return result
end function

function connectionPreferenceIdentity(entry as object, accountId as string) as string
    if normalizeBaseUrl(entry.url) = "" or accountId = "" then return ""
    return entry.url + "|" + accountId + "|" + entry.id
end function
