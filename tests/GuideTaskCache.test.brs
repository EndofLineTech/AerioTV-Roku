sub main()
    resetTask()
    m.cached = {state: "fresh", payload: {Station: []}, fetched: 1700000000}
    loadWindow()
    check(m.requests = 0 and m.top.result.source = "cache", "fresh coverage avoids network")
    check(m.top.apiKey = "" and m.top.result.fetched = 1700000000, "restore preserves original freshness and clears key")

    resetTask()
    m.cached = {state: "stale", payload: {Station: []}, fetched: 1700000000}
    m.response = invalid
    loadWindow()
    check(m.top.cached.fetched = 1700000000 and not m.top.result.ok, "stale snapshot is published but failed refresh is not success")
    check(m.requests = 1 and m.writes = 0, "failed refresh cannot extend persisted freshness")

    resetTask()
    m.cached = {state: "fresh", payload: {Wrong: []}, fetched: 1700000000}
    m.top.bypassCache = true
    loadWindow()
    check(m.requests = 1 and m.top.result.source = "network", "manual bypass fetches server data")
    check(m.top.result.index.count() = 1 and m.top.result.index.Station.count() = 1, "only authorized EPG keys survive")
    check(m.written.Station[0].poster = "" and m.top.result.index.Station[0].poster <> "", "provider artwork URLs excluded from persistence without mutating live data")

    resetTask()
    m.cancelDuringRequest = true
    loadWindow()
    check(m.top.result = invalid and m.top.apiKey = "", "cancelled request suppresses publication and clears credential")

    resetTask()
    m.top.cancelRequested = true
    loadWindow()
    check(m.requests = 0 and m.top.result = invalid and m.top.apiKey = "", "pre-cancel prevents network and publication")
    resetTask()
    m.top.providerType = "dispatcharr"
    m.top.guideUrl = "https://guide.example.test/feed.xml"
    loadWindow()
    check(m.downloadUrl = "https://guide.example.test/feed.xml" and m.requests = 0, "opt-in Dispatcharr XMLTV uses external file Task, never server JSON guide")

    resetTask()
    m.top.providerType = "xtream"
    m.top.guideUrl = "https://guide.example.test/Feed/"
    m.cached = {state: "fresh", payload: {}, fetched: 1700000000}
    m.top.bypassCache = true
    loadWindow()
    check(m.downloadUrl = "https://guide.example.test/Feed/" and m.downloads = 1 and m.requests = 0, "Xtream guide refresh requests only the exact explicit override")
    check(not m.sendSourceReferer and not m.top.result.ok and m.top.apiKey = "" and m.top.guideUrl = "", "failed override neither falls back nor publishes credential inputs")

    resetTask()
    m.top.providerType = "xtream"
    m.top.baseUrl = "http://fixture.invalid/panel"
    m.top.guideUrl = "http://fixture.invalid/panel/xmltv.php?username=viewer&password=fixture%21"
    loadWindow()
    check(m.downloadUrl = "http://fixture.invalid/panel/xmltv.php?username=viewer&password=fixture%21", "account guide credentials go only to the configured panel endpoint")
    check(not m.sendSourceReferer, "account URL cannot be used as a redirect referrer")

    for each cancelled in [false, true]
        resetTask()
        m.top.providerType = "xtream"
        m.top.guideUrl = "http://fixture.invalid/xmltv.php?username=viewer&password=fixture"
        m.cached = {state: "fresh", payload: {}, fetched: 1700000000}
        m.top.cancelRequested = cancelled
        loadWindow()
        check(m.top.guideUrl = "" and m.downloadUrl = "", "cache hit or pre-cancel clears volatile account URL without requesting it")
    end for

    for each badUrl in ["http://foreign.invalid/xmltv.php?username=viewer&password=fixture", "http://fixture.invalid.evil/xmltv.php?username=viewer&password=fixture", "http://fixture.invalid/xmltv.php?username=viewer&password=fixture&other=1", "http://fixture.invalid/xmltv.php?username=viewer&password=fixture#fragment"]
        resetTask()
        m.top.providerType = "xtream"
        m.top.guideUrl = badUrl
        loadWindow()
        check(m.downloadUrl = "" and m.requests = 0 and not m.top.result.ok, "untrusted credential-bearing guide URL is never requested")
        check(instr(1, FormatJson(m.top.result), "fixture") = 0, "guide rejection is secret-free")
    end for
    print "ALL TESTS PASSED"
end sub

sub resetTask()
    m.top = {baseUrl: "http://fixture.invalid", apiKey: "test-only", windowStart: "1700000000".toInt(), allowedKeys: {Station: true}, scope: "account", generation: "lineup", bypassCache: false, cancelRequested: false}
    m.cached = {state: "miss"}
    m.requests = 0
    m.downloadUrl = ""
    m.downloads = 0
    m.sendSourceReferer = true
    m.writes = 0
    m.cancelDuringRequest = false
    m.failure = "Unavailable"
    m.response = [
        {id: 1, title: "Authorized", tvg_id: "Station", start_time: "2023-11-14T22:13:20Z", end_time: "2023-11-14T23:13:20Z", poster_url: "https://provider.invalid/signed?token=example"},
        {id: 2, title: "Unauthorized", tvg_id: "Other", start_time: "2023-11-14T22:13:20Z", end_time: "2023-11-14T23:13:20Z"}
    ]
end sub

function xmltvDownloadToFile(url, path, sendSourceReferer = true as boolean)
    m.downloads++
    m.downloadUrl = url
    m.sendSourceReferer = sendSourceReferer
    return {ok: false, message: "Fixture download failure."}
end function

function metadataCacheRead(scope, kind, key, generation, now, authorized)
    return m.cached
end function

function metadataCacheWrite(scope, kind, key, generation, now, payload)
    if m.top.cancelRequested then return false
    m.writes++
    m.written = payload
    return true
end function

function requestJson(url)
    m.requests++
    if m.cancelDuringRequest then m.top.cancelRequested = true
    return m.response
end function

' brs has no native roUrlTransfer.escape; URL encoding is a transport boundary.
function httpGuideWindowUrl(base, start, finish)
    return base + "/api/epg/grid/"
end function

sub check(value, label)
    if not value then print "FAIL: " + label : stop
end sub
