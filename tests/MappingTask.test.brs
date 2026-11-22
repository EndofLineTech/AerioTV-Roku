sub main()
    resetTask()
    loadMappings()
    check(m.top.result.ok and m.top.result.links.count() = 1, "persist only authorized lineup assignments")
    check(m.top.result.links["10"] = "Station" and m.written.count() = 1, "mapping identifiers retained exactly")
    check(m.detailRequests = 1 and m.requests = 0 and m.top.result.source = "details", "small lineup skips unpaginated list")
    check(m.top.apiKey = "" and m.top.channels.count() = 0, "release credentials and full lineup")
    resetTask()
    m.cached = {state: "fresh", payload: {"10": "Station"}}
    loadMappings()
    check(m.requests = 0 and m.top.result.source = "cache", "warm mapping avoids unpaged endpoint")
    resetTask()
    m.response = invalid
    m.httpFailure = {category: "memory-pressure", sizeBucket: "at-least-8-mib"}
    m.top.channels = []
    for i = 1 to 101
        m.top.channels.push({epgId: i.toStr()})
    end for
    loadMappings()
    check(not m.top.result.ok and m.writes = 0, "failure never caches empty successful mapping")
    check(m.top.result.category = "memory-pressure" and m.top.result.sizeBucket = "at-least-8-mib", "mapping preserves safe transfer diagnostics")
    check(m.requests = 1 and m.detailRequests = 0, "larger lineup tries list first")
    resetTask()
    m.response = invalid
    m.httpFailure = {category: "response-too-large", sizeBucket: "at-least-16-mb"}
    m.detailResponse = {"10": "Station"}
    m.top.channels = []
    for i = 1 to 101
        m.top.channels.push({epgId: i.toStr()})
    end for
    loadMappings()
    check(m.top.result.ok and m.top.result.source = "details", "oversized list uses bounded detail lookup")
    check(m.detailRequests = 1 and m.detailAllowed.count() = 101 and m.detailAllowed.doesExist("10"), "lookup uses only authorized assignments")
    check(m.writes = 1 and m.written["10"] = "Station", "detail mappings are cached for warm load")
    resetTask()
    m.top.channels = []
    m.detailResponse = {}
    for i = 1 to 91
        id = i.toStr()
        m.top.channels.push({epgId: id})
        m.detailResponse[id] = "station-" + id
    end for
    m.response = invalid
    m.httpFailure = {category: "response-too-large", sizeBucket: "at-least-16-mb"}
    loadMappings()
    check(m.top.result.ok and m.top.result.links.count() = 91 and m.detailAllowed.count() = 91 and m.requests = 0, "91-channel lineup skips full list")
    resetTask()
    m.response = invalid
    m.httpFailure = {category: "response-too-large", sizeBucket: "at-least-16-mb"}
    m.detailResponse = invalid
    loadMappings()
    check(not m.top.result.ok and m.writes = 0 and m.top.result.message = "Detail lookup timed out.", "failed detail lookup cannot cache partial links")
    check(m.requests = 0, "small-lineup detail timeout does not trigger full-list storm")
    resetTask()
    m.response = invalid
    m.httpFailure = {category: "timeout", sizeBucket: ""}
    m.top.channels = []
    for i = 1 to 101
        m.top.channels.push({epgId: i.toStr()})
    end for
    loadMappings()
    check(not m.top.result.ok and m.detailRequests = 0, "unrelated errors do not trigger detail storm")
    resetTask()
    m.top.channels = []
    for i = 1 to 101
        m.top.channels.push({epgId: i.toStr()})
    end for
    m.response = [{id: 10, tvg_id: "Station"}, {id: 999, tvg_id: "Not-authorized"}]
    loadMappings()
    check(m.requests = 1 and m.detailRequests = 0 and m.top.result.source = "network", "large lineup retains full-list path")
    check(m.lastUrl = "http://fixture.invalid/api/epg/epgdata/?page=1&page_size=500", "large-lineup request stays compatible with pagination")
    check(m.top.result.links.count() = 1 and m.top.result.links["10"] = "Station", "full list retains only authorized assignment IDs")
    resetTask()
    m.top.channels = []
    for i = 1 to 100
        m.top.channels.push({epgId: i.toStr()})
    end for
    m.top.channels.push({epgId: "10"})
    loadMappings()
    check(m.detailRequests = 1 and m.detailAllowed.count() = 100 and m.requests = 0, "100 distinct assignments use details despite duplicate channels")
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
    m.detailResponse = {"10": "Station"}
    m.detailRequests = 0
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

function requestMappedDetails(allowed)
    m.detailRequests++
    m.detailAllowed = allowed
    if m.detailResponse = invalid
        m.httpFailure = {category: "timeout", sizeBucket: ""}
        m.failure = "Detail lookup timed out."
    end if
    return m.detailResponse
end function

sub check(value, label)
    if not value then print "FAIL: " + label : stop
end sub
