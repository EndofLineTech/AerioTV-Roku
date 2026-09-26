sub main()
    resetSeriesTask()
    loadVod()
    if not m.top.result.ok or m.top.result.target.status <> "play" then stop
    if m.top.result.target.item.uuid <> "episode-1" or m.top.apiKey <> "" or m.top.savedState <> invalid then stop
    if m.requests <> 2 then stop

    resetSeriesTask()
    m.user.id = 2
    loadVod()
    if m.top.result.ok or m.requests <> 1 then stop

    resetSeriesTask()
    m.top.seriesId = "../42"
    loadVod()
    if m.top.result.ok or m.requests <> 1 then stop
    print "ALL TESTS PASSED"
end sub

sub resetSeriesTask()
    m.requests = 0
    m.failure = ""
    m.user = {id: 1, user_level: 10, custom_properties: {}}
    m.top = {baseUrl: "https://host.test", apiKey: "test-only", accountId: "1", operation: "seriesTarget", kind: "series", seriesId: "42", providerId: "", savedState: [], pageNumber: 1, cancelRequested: false}
end sub

function metadataCacheDigest(value as string) as string
    return "current"
end function

function requestJson(url as string) as dynamic
    m.requests++
    if instr(1, url, "/users/me/") > 0 then return m.user
    return {count: 1, results: [{id: 1, uuid: "episode-1", name: "Episode", series: {id: 42, name: "Series"}, season_number: 0, episode_number: 1}], next: invalid}
end function
