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
    testVodLinks()
    print "ALL TESTS PASSED"
end sub

sub testVodLinks()
    resetLinkTask("movie", "12")
    m.top.savedState = [{kind: "movie", id: "12", uuid: "movie-12", position: 85, duration: 600}]
    loadVod()
    check(m.top.result.ok and m.top.result.item.key = "movie:movie-12" and m.top.result.item.resume = 85, "fresh movie resumes under own bookmark")
    check(m.urls.count() = 2 and m.urls[0] = "https://host.test/api/accounts/users/me/" and m.urls[1] = "https://host.test/api/vod/movies/12/", "fresh me then exact movie GET")
    check(m.top.result.item.accountScope = "https://host.test|1" and m.top.apiKey = "" and m.top.savedState = invalid, "scoped playback item without retained task credentials")

    resetLinkTask("episode", "19")
    loadVod()
    check(m.top.result.ok and m.top.result.item.key = "episode:episode-19" and m.top.result.item.resume = 0, "exact episode starts with no bookmark")
    check(m.urls.count() = 2 and m.urls[1] = "https://host.test/api/vod/episodes/19/", "no series fallback for exact episode")

    resetLinkTask("series", "42")
    m.top.savedState = [{kind: "episode", id: "18", uuid: "episode-18", seriesId: "42", watched: true, touch: 1}]
    loadVod()
    check(m.top.result.ok and m.top.result.item.id = "19" and m.top.result.item.resume = 0, "series directly selects the next authorized episode")
    check(m.urls.count() = 4 and m.urls[1] = "https://host.test/api/vod/series/42/" and m.urls[3] = "https://host.test/api/vod/episodes/19/", "series verifies both exact fresh details")

    resetLinkTask("series", "42")
    m.top.savedState = [{kind: "episode", id: "18", uuid: "episode-18", seriesId: "42", position: 85, duration: 600}]
    loadVod()
    check(m.top.result.ok and m.top.result.item.id = "18" and m.top.result.item.resume = 85, "series resumes its in-progress episode without a dialog")

    for each scenario in ["different-id", "different-user", "denied", "missing", "wrong-id", "unknown-container", "hidden-series", "different-episode", "different-series", "ambiguous-episode"]
        kind = "movie"
        id = "12"
        if scenario = "hidden-series" or scenario = "different-episode" or scenario = "different-series" or scenario = "ambiguous-episode"
            kind = "series"
            id = "42"
        end if
        resetLinkTask(kind, id)
        m.scenario = scenario
        if scenario = "different-id" then m.user.id = 2
        if scenario = "different-user" then m.user.username = "other"
        if scenario = "denied" then m.user.custom_properties = {vod_movies_enabled: false}
        if scenario = "hidden-series" then m.top.savedState = [{kind: "series", id: "42", uuid: "series-42", hidden: true}]
        loadVod()
        check(not m.top.result.ok, "refuses " + scenario)
        if scenario = "different-id" or scenario = "different-user" or scenario = "denied" then check(m.urls.count() = 1, "no catalog before own authorization")
    end for

    resetLinkTask("movie", "12")
    m.top.cancelRequested = true
    loadVod()
    check(m.top.result = invalid and m.urls.count() = 0, "cancelled link neither fetches nor publishes")

    resetLinkTask("movie", "12/../../")
    loadVod()
    check(not m.top.result.ok and m.urls.count() = 0, "invalid identifier is rejected even at the Task boundary")

    resetLinkTask("movie", "12")
    m.scenario = "enriched-container"
    loadVod()
    check(m.top.result.ok and m.top.result.item.streamFormat = "mkv" and m.urls.count() = 3, "uses verified matching provider metadata only if container was unknown")

    resetLinkTask("series", "42")
    m.scenario = "incomplete"
    loadVod()
    check(not m.top.result.ok and m.urls.count() = 6, "bounded series scan does not guess an unanchored target")
end sub

sub resetLinkTask(kind as string, id as string)
    resetSeriesTask()
    m.top.operation = "deepLink"
    m.top.kind = kind
    m.top.itemId = id
    m.top.accountUsername = "viewer"
    m.user.username = "Viewer"
end sub

sub check(value as boolean, message as string)
    if not value
        print "FAIL: "; message
        stop
    end if
end sub

sub resetSeriesTask()
    m.requests = 0
    m.urls = []
    m.scenario = ""
    m.failure = ""
    m.user = {id: 1, user_level: 10, custom_properties: {}}
    m.top = {baseUrl: "https://host.test", apiKey: "test-only", accountId: "1", operation: "seriesTarget", kind: "series", seriesId: "42", providerId: "", savedState: [], pageNumber: 1, cancelRequested: false}
end sub

function metadataCacheDigest(value as string) as string
    return "current"
end function

function requestJson(url as string) as dynamic
    m.requests++
    m.urls.push(url)
    if instr(1, url, "/users/me/") > 0 then return m.user
    if m.top.operation = "deepLink"
        if instr(1, url, "/provider-info/") > 0
            if m.scenario = "enriched-container" then return {id: 12, uuid: "movie-12", name: "Movie", container_extension: "mkv"}
            return invalid
        end if
        if instr(1, url, "/movies/12/") > 0
            if m.scenario = "missing" then return invalid
            movie = {id: 12, uuid: "movie-12", name: "Movie", container_extension: "mp4", duration_secs: 600}
            if m.scenario = "wrong-id" then movie.id = 13
            if m.scenario = "unknown-container" or m.scenario = "enriched-container" then movie.container_extension = ""
            return movie
        end if
        first = {id: 18, uuid: "episode-18", name: "One", series: {id: 42}, season_number: 1, episode_number: 1, container_extension: "mkv", duration_secs: 600}
        second = {id: 19, uuid: "episode-19", name: "Two", series: {id: 42}, season_number: 1, episode_number: 2, container_extension: "mp4", duration_secs: 600}
        if instr(1, url, "/episodes/?") > 0
            if m.scenario = "incomplete" then return {count: 81, results: [first, second], next: "/api/vod/episodes/?page=2"}
            if m.scenario = "ambiguous-episode" then second.episode_number = 1
            return {count: 2, results: [first, second], next: invalid}
        end if
        if instr(1, url, "/series/42/") > 0 then return {id: 42, uuid: "series-42", name: "Series"}
        if instr(1, url, "/episodes/18/") > 0
            if m.scenario = "different-episode" then first.uuid = "replacement"
            if m.scenario = "different-series" then first.series.id = 43
            return first
        end if
        if instr(1, url, "/episodes/19/") > 0 then return second
        return invalid
    end if
    return {count: 1, results: [{id: 1, uuid: "episode-1", name: "Episode", series: {id: 42, name: "Series"}, season_number: 0, episode_number: 1}], next: invalid}
end function
