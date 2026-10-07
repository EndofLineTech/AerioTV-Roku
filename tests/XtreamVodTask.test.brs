sub main()
    m.top = taskInput()
    loadXtreamVod()
    assertEqual(m.top.result.ok, false, "no category cannot request whole catalog")
    assertEqual(m.requested, invalid, "no request issued")
    assertEqual(m.top.password, "", "password cleared on failure")
    m.top = taskInput()
    m.top.category = "7"
    m.fixture = [{stream_id: 19, name: "Film", category_id: "7", container_extension: "mp4", stream_icon: "https://other.test/private"}]
    loadXtreamVod()
    assertEqual(m.top.result.ok, true, "category page loaded")
    if instr(1, m.requested, "category_id=7") = 0 then stop
    if instr(1, FormatJson(m.top.result), "test-only") > 0 then stop
    m.top = taskInput()
    m.top.category = "7"
    m.fixture = invalid
    m.fakeStatus = 401
    loadXtreamVod()
    assertEqual(m.top.result.relogin, true, "revoked library credentials return explicit sign-in")
    assertEqual(m.top.password, "", "revoked library Task clears credentials")
    if instr(1, FormatJson(m.top.result), "other.test") > 0 then stop
    assertEqual(m.top.password, "", "password cleared on success")
    m.top = taskInput()
    m.top.operation = "categories"
    m.fixture = []
    loadXtreamVod()
    assertEqual(m.top.result.ok, true, "empty category list distinguished from error")
    m.top = taskInput()
    m.top.operation = "categories"
    m.fixture = invalid
    loadXtreamVod()
    assertEqual(m.top.result.ok, false, "network failure")
    if instr(1, FormatJson(m.top.result), "test-only") > 0 then stop
    m.top = taskInput()
    m.top.operation = "shelf"
    m.top.shelf = "watchlist"
    m.top.savedState = [{id: "19", uuid: "xc-movie-19", kind: "movie", title: "Saved", watchlist: true, authorization: metadataCacheDigest("xc-vod|xc-slot")}]
    m.fixture = {info: {name: "Verified"}, movie_data: {stream_id: 19, container_extension: "mp4"}}
    m.fakeStatus = invalid
    loadXtreamVod()
    assertEqual(m.top.result.items.count(), 1, "verified watchlist")
    assertEqual(m.top.result.items[0].title, "Verified", "fresh title")
    assertEqual(m.top.result.items[0].authorization, metadataCacheDigest("xc-vod|xc-slot"), "saved item exposes compact account authorization")
    assertEqual(m.top.password, "", "shelf task clears secret")
    m.top = taskInput()
    m.top.operation = "shelf"
    m.top.shelf = "watchlist"
    m.top.accountScope = "https://example.test|xc-012345678901234567890123|connection-012345678901234567890123456789"
    m.top.savedState = [{id: "19", uuid: "xc-movie-19", kind: "movie", title: "Saved", watchlist: true, authorization: metadataCacheDigest("xc-vod|" + m.top.accountScope)}]
    m.fixture = {info: {name: "Verified"}, movie_data: {stream_id: 19, container_extension: "mp4"}}
    loadXtreamVod()
    assertEqual(m.top.result.items.count(), 1, "real-length Xtream account scope retains a saved title")

    m.top = taskInput()
    m.top.operation = "shelf"
    m.top.shelf = "recent"
    m.top.history = [{id: "90", uuid: "xc-episode-90", kind: "episode", title: "Episode", seriesId: "12"}]
    m.fixture = {info: {series_id: 12, name: "Show"}, episodes: {"1": [{id: 90, title: "Verified episode", episode_num: 1, info: {}, container_extension: "mp4"}]}}
    loadXtreamVod()
    assertEqual(m.top.result.items.count(), 1, "verified recent episode")
    assertEqual(m.top.result.items[0].seriesId, "12", "episode parent retained")
    if instr(1, m.requested, "series_id=12") = 0 then stop

    m.top = taskInput()
    m.top.operation = "shelf"
    m.top.shelf = "favorite"
    m.top.savedState = [{id: "19", uuid: "xc-movie-19", kind: "movie", title: "Saved", favorite: true, authorization: metadataCacheDigest("xc-vod|another-slot")}]
    m.requested = invalid
    loadXtreamVod()
    assertEqual(m.top.result.items.count(), 0, "foreign favorite rejected")
    assertEqual(m.requested, invalid, "foreign title not requested")
    m.top = taskInput()
    m.top.operation = "shelf"
    m.top.shelf = "watchlist"
    m.top.savedState = [{id: "19", uuid: "xc-movie-19", kind: "movie", title: "Saved", watchlist: true, authorization: metadataCacheDigest("xc-vod|xc-slot")}]
    m.fixture = {info: {name: "Replacement"}, movie_data: {stream_id: 20, container_extension: "mp4"}}
    loadXtreamVod()
    assertEqual(m.top.result.items.count(), 0, "reused id or wrong result cannot be opened")
    m.top = taskInput()
    m.top.operation = "shelf"
    m.top.shelf = "recent"
    m.top.history = [{id: "19", uuid: "xc-movie-19", kind: "movie", title: "Saved"}]
    m.fixture = invalid
    m.fakeStatus = 500
    loadXtreamVod()
    assertEqual(m.top.result.partial, true, "temporary shelf failure is retryable")
    assertEqual(m.top.result.items.count(), 0, "failed request has no actionable tile")
    print "ALL TESTS PASSED"
end sub

function taskInput() as object
    return {baseUrl: "https://example.test", username: "viewer", password: "test-only", accountScope: "xc-slot", kind: "movie", operation: "page", pageNumber: 1, category: "", query: "", seriesId: "", itemId: "", cancelRequested: false}
end function

function metadataCacheDigest(value as string) as string
    if value = "xc-vod|xc-slot" then return "scoped-xc-slot"
    if value = "xc-vod|another-slot" then return "scoped-another-slot"
    return "scoped-connection-with-long-base-url"
end function

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string, method = "GET" as string) as dynamic
    m.requested = url
    m.failure = "Request failed."
    m.httpFailure = invalid
    if m.fakeStatus <> invalid then m.httpFailure = {status: m.fakeStatus}
    return m.fixture
end function

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
