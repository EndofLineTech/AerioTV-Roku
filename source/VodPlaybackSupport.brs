' Device-local marks for catalog titles this Roku refused to decode. Dispatcharr
' exposes no resolution/codec, so a native format refusal is the only evidence.
' The decoder limit belongs to the device, not a profile. Never synced.
' Keys are "<server digest>:<catalog uuid>" and never retain the server URL.

function vodUnsupportedLimit() as integer
    return 200
end function

function vodUnsupportedKey(base as string, uuid as string) as string
    base = normalizeBaseUrl(base)
    if base = "" or not CreateObject("roRegex", "^[A-Za-z0-9_-]{1,80}$", "").isMatch(uuid) then return ""
    return left(metadataCacheDigest(base), 16) + ":" + uuid
end function

function loadVodUnsupported(registry as object) as object
    store = {schema: 1, keys: []}
    raw = registry.read("vodUnsupportedV1")
    if raw = "" then return store
    value = ParseJson(raw)
    if type(value) <> "roAssociativeArray" or value.schema <> 1 or type(value.keys) <> "roArray" then return store
    valid = CreateObject("roRegex", "^[0-9a-f]{16}:[A-Za-z0-9_-]{1,80}$", "")
    for each key in value.keys
        if GetInterface(key, "ifString") <> invalid
            if valid.isMatch(key) and store.keys.count() < vodUnsupportedLimit() then store.keys.push(key)
        end if
    end for
    return store
end function

function vodUnsupportedMarked(store as object, base as string, uuid as string) as boolean
    ' Common case: nothing marked, so playback progress never needs a digest.
    if store.keys.count() = 0 then return false
    key = vodUnsupportedKey(base, uuid)
    if key = "" then return false
    for each existing in store.keys
        if existing = key then return true
    end for
    return false
end function

' Most recent last; the oldest mark is evicted first.
function markVodUnsupported(store as object, base as string, uuid as string) as object
    key = vodUnsupportedKey(base, uuid)
    result = clearVodUnsupported(store, base, uuid)
    if key = "" then return result
    result.keys.push(key)
    while result.keys.count() > vodUnsupportedLimit()
        result.keys.shift()
    end while
    return result
end function

function clearVodUnsupported(store as object, base as string, uuid as string) as object
    key = vodUnsupportedKey(base, uuid)
    result = {schema: 1, keys: []}
    for each existing in store.keys
        if existing <> key then result.keys.push(existing)
    end for
    return result
end function

function saveVodUnsupported(registry as object, store as object) as boolean
    previous = registry.read("vodUnsupportedV1")
    if not registry.write("vodUnsupportedV1", FormatJson({schema: 1, keys: store.keys})) then return false
    if registry.flush() then return true
    if previous = "" then registry.delete("vodUnsupportedV1") else registry.write("vodUnsupportedV1", previous)
    registry.flush()
    return false
end function

' Catalog uuid -> true for one server, for views that do not hold the store.
function vodUnsupportedLookup(store as object, base as string) as object
    lookup = {}
    if store.keys.count() = 0 then return lookup
    prefix = vodUnsupportedKey(base, "x")
    if prefix = "" then return lookup
    prefix = left(prefix, 17)
    for each key in store.keys
        if left(key, 17) = prefix then lookup[mid(key, 18)] = true
    end for
    return lookup
end function
