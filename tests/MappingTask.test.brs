sub main()
    resetTask()
    loadMappings()
    check(m.top.result.ok and m.top.result.links.count() = 1, "persist only authorized lineup assignments")
    check(m.top.result.links["10"] = "Station" and m.written.count() = 1, "mapping identifiers retained exactly")
    check(m.lastUrl = "http://fixture.invalid/api/epg/epgdata/?page=1&page_size=500", "mapping request stays paged")
    check(m.top.apiKey = "" and m.top.channels.count() = 0, "release credentials and full lineup")
    resetTask()
    m.cached = {state: "fresh", payload: {"10": "Station"}}
    loadMappings()
    check(m.requests = 0 and m.top.result.source = "cache", "warm mapping avoids unpaged endpoint")
    resetTask()
    m.response = invalid
    m.httpFailure = {category: "response-too-large", sizeBucket: "at-least-8-mib"}
    loadMappings()
    check(not m.top.result.ok and m.writes = 0, "failure never caches empty successful mapping")
    check(m.top.result.category = "response-too-large" and m.top.result.sizeBucket = "at-least-8-mib", "mapping preserves safe transfer diagnostics")
    resetTask()
    m.top.cancelRequested = true
    loadMappings()
    check(m.top.result = invalid and m.top.apiKey = "", "cancel suppresses stale result")
    check(m.requests = 0, "pre-cancel prevents transfer")
    resetTask()
    m.top.channels = [{epgId: ""}]
    loadMappings()
    check(m.requests = 0 and m.top.result.ok, "lineup without explicit assignments needs no mapping transfer")
    print "ALL TESTS PASSED"
end sub

sub resetTask()
    m.top = {baseUrl: "http://fixture.invalid", apiKey: "test-only", channels: [{epgId: "10"}], scope: "account", generation: "lineup", bypassCache: false, cancelRequested: false}
    m.cached = {state: "miss"}
    m.requests = 0
    m.writes = 0
    m.failure = "Unavailable"
    m.httpFailure = invalid
    m.response = [{id: 10, tvg_id: "Station"}, {id: 11, tvg_id: "Not-authorized"}]
end sub

function metadataCacheRead(scope, kind, key, generation, now, authorized)
    return m.cached
end function

function metadataCacheWrite(scope, kind, key, generation, now, payload)
    if m.top.cancelRequested then return false
    m.writes++
    m.written = payload
    return true
end function

function requestPages(path)
    m.requests++
    m.lastUrl = m.base + path
    return m.response
end function

sub check(value, label)
    if not value then print "FAIL: " + label : stop
end sub
