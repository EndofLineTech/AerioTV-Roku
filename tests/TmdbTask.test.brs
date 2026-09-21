sub main()
    resetTmdbTest()
    loadTmdb()
    if not m.top.result.ok or m.top.result.metadata.id <> "603" then stop
    if m.externalSawAuth or m.top.apiKey <> "" or m.top.tmdbKey <> "" then stop
    if instr(1, FormatJson(m.cachedPayload), "server-secret") > 0 then stop
    resetTmdbTest()
    m.top.enabled = false
    loadTmdb()
    if m.top.result.ok or m.calls <> 0 then stop
    resetTmdbTest()
    m.top.item.authorization = "stale"
    loadTmdb()
    if m.top.result.ok or m.calls <> 1 then stop
    resetTmdbTest()
    m.raw.uuid = "changed"
    loadTmdb()
    if m.top.result.ok or m.calls <> 2 then stop
    resetTmdbTest()
    m.top.operation = "related"
    m.top.savedState = [{id: "1", uuid: "movie-uuid", kind: "movie", title: "The Matrix", hidden: true}]
    loadTmdb()
    if not m.top.result.ok or m.top.result.items.count() <> 1 then stop
    if m.top.result.items[0].uuid <> "other-uuid" then stop
    if m.externalSawAuth then stop
    print "ALL TESTS PASSED"
end sub

sub resetTmdbTest()
    m.calls = 0
    m.externalSawAuth = false
    m.encoder = {escape: function(value as string) as string
        return value
    end function}
    m.user = {id: 1, user_level: 10, custom_properties: {}}
    m.raw = {id: 1, uuid: "movie-uuid", name: "The Matrix", year: 1999, tmdb_id: 603}
    item = vodNormalize(m.raw, "movie")
    item.authorization = metadataCacheDigest(FormatJson({account: "1", level: 10, movies: "allowed", series: "allowed", hideAdult: invalid}))
    m.top = {baseUrl: "https://dispatch.test", apiKey: "server-secret", accountId: "1", tmdbKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", enabled: true, item: item, operation: "details", pageNumber: 1, savedState: [], cancelRequested: false}
end sub

function requestJson(url as string) as dynamic
    m.calls++
    if instr(1, url, "https://api.themoviedb.org/") = 1
        if m.key <> "" then m.externalSawAuth = true
        if instr(1, url, "/recommendations") > 0 then return {results: [{id: 603, title: "The Matrix", release_date: "1999-03-30"}, {id: 604, title: "Other", release_date: "2000-01-01"}], total_pages: 1}
        return {id: 603, title: "The Matrix", overview: "English synopsis", poster_path: "/image.jpg"}
    end if
    if m.key <> "server-secret" then stop
    if instr(1, url, "/users/me/") > 0 then return m.user
    if instr(1, url, "name=") > 0
        if instr(1, url, "Other") > 0 then return {count: 1, next: invalid, results: [{id: 2, uuid: "other-uuid", name: "Other", year: 2000, tmdb_id: 604}]}
        return {count: 1, next: invalid, results: [m.raw]}
    end if
    return m.raw
end function

function metadataCacheRead(scope, kind, key, generation, now, authorized) as object
    return {state: "miss"}
end function

' The native digest primitive is outside brs's emulation; keep equality sensitive
' to the complete input so account/permission changes are still tested here.
function metadataCacheDigest(value as string) as string
    return "test-digest:" + value
end function

function metadataCacheWrite(scope, kind, key, generation, now, payload) as boolean
    m.cachedPayload = payload
    return true
end function
