' Discardable metadata only. Playback URLs, credentials and user preferences
' are deliberately outside this cache; callers pass freshly authorized scope.
function metadataCachePolicy(kind as string) as dynamic
    if kind = "channels" or kind = "mapping" then return {ttl: 300, stale: 0, maxBytes: 1048576}
    if kind = "guide" then return {ttl: 300, stale: 600, maxBytes: 3145728}
    if kind = "vod" then return {ttl: 300, stale: 600, maxBytes: 1048576}
    return invalid
end function

function metadataCacheEnvelope(scope as string, kind as string, key as string, generation as string, now as integer, payload as dynamic) as dynamic
    policy = metadataCachePolicy(kind)
    if policy = invalid or scope = "" or key = "" or generation = "" or now <= 0 then return invalid
    return {schema: 1, scope: scope, kind: kind, key: key, generation: generation, fetched: now, fresh: now + policy.ttl, stale: now + policy.ttl + policy.stale, complete: true, payload: payload}
end function

function metadataCacheState(entry as dynamic, scope as string, kind as string, key as string, generation as string, now as integer, authorized as boolean, bytes as integer) as string
    if not authorized or type(entry) <> "roAssociativeArray" then return "miss"
    policy = metadataCachePolicy(kind)
    if policy = invalid or bytes < 1 or bytes > policy.maxBytes then return "miss"
    if type(entry.schema) <> "Integer" and type(entry.schema) <> "roInt" then return "miss"
    if type(entry.complete) <> "Boolean" and type(entry.complete) <> "roBoolean" then return "miss"
    for each field in ["scope", "kind", "key", "generation"]
        if GetInterface(entry[field], "ifString") = invalid then return "miss"
    end for
    if entry.schema <> 1 or entry.complete <> true then return "miss"
    if entry.scope <> scope or entry.kind <> kind or entry.key <> key or entry.generation <> generation then return "miss"
    if type(entry.fetched) <> "Integer" and type(entry.fetched) <> "roInt" then return "miss"
    if entry.fetched > now or entry.fetched <= 0 then return "miss"
    if kind = "channels"
        if type(entry.payload) <> "roArray" then return "miss"
    else
        if type(entry.payload) <> "roAssociativeArray" then return "miss"
    end if
    ' Derive age from the policy rather than trusting persisted TTL fields.
    age = now - entry.fetched
    if age < policy.ttl then return "fresh"
    if age < policy.ttl + policy.stale then return "stale"
    return "miss"
end function

function metadataCacheDigest(value as string) as string
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(value)
    digest = CreateObject("roEVPDigest")
    digest.setup("sha256")
    return lcase(digest.process(bytes))
end function

' Artwork can contain signed/provider URLs. Persist text/timing facts only;
' program details can hydrate artwork again when requested.
function metadataCacheGuidePayload(index as object) as object
    result = {}
    result.setModeCaseSensitive()
    fields = ["id", "title", "description", "subtitle", "startsAt", "endsAt", "key", "is_new", "is_live", "is_premiere", "is_finale", "is_previously_shown", "season", "episode", "categories", "rating", "year", "language", "country", "quality", "credits"]
    for each key in index
        result[key] = []
        for each program in index[key]
            clean = {poster: ""}
            for each field in fields
                clean[field] = program[field]
            end for
            result[key].push(clean)
        end for
    end for
    return result
end function
