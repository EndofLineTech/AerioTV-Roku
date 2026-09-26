sub main()
    resetSeriesTest()
    result = vodHydrateEpisodes("42", "https://host.test/episodes", "")
    if not result.ok or result.items.count() <> 1 then stop
    if m.hydrations.count() <> 2 or m.hydrations[1] <> "19" then stop
    if m.maxResponseBytes <> 1048576 then stop

    resetSeriesTest()
    m.available = false
    result = vodHydrateEpisodes("42", "https://host.test/episodes", "")
    if result.ok or result.category <> "episode-loading" then stop
    if m.hydrations.count() > 3 then stop

    resetSeriesTest()
    result = vodHydrateEpisodes("42", "https://host.test/episodes", "19")
    if not result.ok or m.hydrations.count() <> 1 or m.hydrations[0] <> "19" then stop

    resetSeriesTest()
    m.top.cancelRequested = true
    result = vodHydrateEpisodes("42", "https://host.test/episodes", "")
    if result.ok or m.requests <> 0 then stop

    resetSeriesTest()
    m.pageTotal = 2
    result = vodLoadSeriesEpisodes("42", "")
    if not result.ok or not result.complete or result.items.count() <> 40 then stop
    if result.items[0].season <> "0" or result.items[0].seriesId <> "42" then stop
    resetSeriesTest()
    m.pageTotal = 6
    result = vodLoadSeriesEpisodes("42", "")
    if not result.ok or result.complete or result.items.count() <> 80 then stop
    resetSeriesTest()
    if vodLoadSeriesEpisodes("../bad", "").ok or m.requests <> 0 then stop
    resetSeriesTest()
    m.top.cancelRequested = true
    if vodLoadSeriesEpisodes("42", "").ok or m.requests <> 0 then stop
    print "ALL TESTS PASSED"
end sub

sub resetSeriesTest()
    m.top = {cancelRequested: false}
    m.base = "https://host.test"
    m.maxResponseBytes = 1048576
    m.available = true
    m.loaded = false
    m.requests = 0
    m.hydrations = []
    m.clock = CreateObject("roTimespan")
    m.clock.mark()
    m.pageTotal = 0
end sub

function requestJson(url)
    m.requests++
    if instr(1, url, "/api/vod/episodes/") > 0 and m.pageTotal > 0
        page = 1
        for i = 2 to 6
            if instr(1, url, "page=" + i.toStr()) > 0 then page = i
        end for
        if page > m.pageTotal then return invalid
        rows = []
        for i = 1 to 20
            id = (page - 1) * 20 + i
            rows.push({id: id, uuid: "episode-" + id.toStr(), name: "Episode", series: {id: 42, name: "Series"}, season_number: 0, episode_number: id})
        end for
        nextUrl = invalid
        if page < m.pageTotal then nextUrl = "https://host.test/api/vod/episodes/?page=" + (page + 1).toStr()
        return {count: m.pageTotal * 20, results: rows, next: nextUrl}
    end if
    if instr(1, url, "/providers/") > 0
        return [{id: 1, m3u_account: {id: 6}}, {id: 2, m3u_account: {id: 6}}, {id: 3, m3u_account: {id: 19}}, {id: 4, m3u_account: {id: 22}}]
    end if
    if instr(1, url, "/provider-info/") > 0
        id = "6"
        if instr(1, url, "relation_id=3") > 0 then id = "19"
        if instr(1, url, "relation_id=4") > 0 then id = "22"
        m.hydrations.push(id)
        m.loaded = m.available and id = "19"
        return {episodes_fetched: m.loaded, m3u_account: {id: id}}
    end if
    if m.loaded then return {count: 1, results: [{id: 7, uuid: "episode-7", name: "Episode 1"}], next: invalid}
    return {count: 0, results: [], next: invalid}
end function
