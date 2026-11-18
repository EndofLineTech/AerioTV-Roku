sub main()
    tests = ["replacement", "ambiguous", "forbidden", "prefetch", "cancelled", "wrong-detail", "wrong-station", "replacement-forbidden", "replacement-missing"]
    for each scenario in tests
        m.scenario = scenario
        m.paths = []
        m.top = {baseUrl: "https://provider.example", apiKey: "fixture", programId: "5", tmdbKey: "", cancelRequested: false}
        if scenario <> "prefetch" then m.top.selectedAiring = {id: "5", key: "Station", title: "Live Event", startsAt: 1000, endsAt: 2000}
        loadDetails()
        if scenario = "replacement"
            verify(m.paths.count() = 3, "one detail, one grid, one replacement detail")
            verify(m.paths[2] = "https://provider.example/api/epg/programs/7/", "only strictly matched ID requested")
            verify(m.top.result.ok and m.top.result.id = "5" and m.top.result.program.id = "5", "result enriches the original airing")
            verify(m.top.result.program.poster = "/media/detail.png", "detail icon beats replacement feed icon")
        else if scenario = "ambiguous" or scenario = "wrong-station"
            verify(m.paths.count() = 2 and not m.top.result.ok, "unsafe grid match rejected without detail request")
        else if scenario = "wrong-detail" or scenario = "replacement-forbidden"
            verify(m.paths.count() = 3 and not m.top.result.ok, "replacement detail must still match the airing")
        else if scenario = "replacement-missing"
            verify(m.paths.count() = 3 and m.top.result.ok and m.top.result.program.poster = "/media/feed.png", "404 retains strictly matched grid artwork")
        else
            verify(m.paths.count() = 1, "no extra request on permission failure, cancellation, or background prefetch")
            if scenario = "prefetch" then verify(not m.top.result.explicit, "prefetch failure belongs to a separate cooldown")
        end if
        verify(m.key = "" and m.top.apiKey = "", "task clears provider key")
    end for
    print "ALL TESTS PASSED"
end sub

function requestJson(url as string) as dynamic
    m.paths.push(url)
    m.httpFailure = invalid
    if m.paths.count() = 1
        status = 404
        if m.scenario = "forbidden" then status = 403
        if m.scenario = "cancelled" then m.top.cancelRequested = true
        m.httpFailure = {status: status}
        m.failure = "Fixture failure"
        return invalid
    end if
    row = {id: 7, tvg_id: "Station", title: "Live Event", start_time: 1000, end_time: 2000, icon: "/media/feed.png"}
    if m.paths.count() = 2
        verify(instr(1, url, "https://provider.example/api/epg/grid/?start=") = 1, "replacement lookup stays on the configured origin")
        other = {id: 6, tvg_id: "station", title: "Live Event", start_time: 1000, end_time: 2000}
        if m.scenario = "ambiguous" then other.tvg_id = "Station"
        if m.scenario = "wrong-station" then row.tvg_id = "Other"
        return [other, row]
    end if
    if m.scenario = "replacement-forbidden" or m.scenario = "replacement-missing"
        status = 403
        if m.scenario = "replacement-missing" then status = 404
        m.httpFailure = {status: status}
        return invalid
    end if
    if m.scenario = "wrong-detail" then row.start_time = 1001
    row.icon = "/media/detail.png"
    return row
end function

function httpGuideWindowUrl(base as string, starts as string, ends as string) as string
    return base + "/api/epg/grid/?start=" + starts + "&end=" + ends
end function

sub verify(passed as boolean, label as string)
    if not passed
        print "FAIL: "; m.scenario; " "; label
        stop
    end if
end sub
