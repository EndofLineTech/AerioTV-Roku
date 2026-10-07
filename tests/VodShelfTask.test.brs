sub main()
    resetShelfTest()
    loadShelf()
    if not m.top.result.ok or m.top.result.items.count() <> 1 then stop
    if m.top.result.items[0].title <> "Fresh title" then stop
    if m.top.result.patches[0].availability <> "available" then stop
    if m.top.apiKey <> "" or m.top.savedState <> invalid then stop

    resetShelfTest()
    m.status = 404
    m.top.shelf = "continue"
    loadShelf()
    if m.top.result.items.count() <> 0 then stop
    if m.top.result.patches[0].availability <> "missing" then stop

    resetShelfTest()
    m.status = 404
    loadShelf()
    if m.top.result.items.count() <> 1 or not m.top.result.items[0].unavailable then stop

    resetShelfTest()
    m.status = 403
    loadShelf()
    if m.top.result.items.count() <> 0 or m.top.result.patches[0].availability <> "denied" then stop

    resetShelfTest()
    m.top.savedState[0].authorization = "previous-permissions"
    m.status = 404
    loadShelf()
    if m.top.result.items.count() <> 0 then stop
    resetShelfTest()
    m.top.shelf = "recent"
    m.top.savedState = []
    m.top.history = [{id: 1, uuid: "movie-uuid", kind: "movie", title: "Played"}]
    m.raw.uuid = "different-identity"
    loadShelf()
    if m.top.result.items.count() <> 0 then stop
    resetShelfTest()
    m.top.shelf = "recent"
    m.top.savedState = []
    m.top.history = [{id: 1, uuid: "movie-uuid", kind: "movie", title: "Played"}]
    m.status = 500
    loadShelf()
    if m.top.result.items.count() <> 0 or not m.top.result.partial then stop

    resetShelfTest()
    m.status = 500
    loadShelf()
    if m.top.result.items.count() <> 1 or not m.top.result.items[0].metadataPending then stop
    if m.top.result.items[0].unavailable then stop

    resetShelfTest()
    m.status = 500
    m.top.savedState[0].availability = "denied"
    loadShelf()
    if m.top.result.items.count() <> 0 then stop

    resetShelfTest()
    m.raw.uuid = "reused-id-new-identity"
    loadShelf()
    if not m.top.result.items[0].unavailable then stop

    resetShelfTest()
    m.user.id = 2
    loadShelf()
    if m.top.result.ok or m.calls <> 1 then stop

    resetShelfTest()
    m.status = 401
    loadShelf()
    if m.top.result.ok then stop

    resetShelfTest()
    m.top.cancelRequested = true
    loadShelf()
    if m.top.result <> invalid then stop

    resetShelfTest()
    m.top.shelf = "continue"
    m.top.savedState = [{id: 1, uuid: "episode-1", kind: "episode", title: "Completed", seriesId: "42", watched: true, touch: 3, authorization: "current"}]
    m.seriesPage = true
    loadShelf()
    if not m.top.result.ok or m.top.result.items.count() <> 1 then stop
    if m.top.result.items[0].uuid <> "episode-2" or m.top.result.items[0].nextUp <> true then stop
    if m.calls > 6 then stop

    resetShelfTest()
    m.top.shelf = "continue"
    m.top.savedState = [{id: 1, uuid: "episode-1", kind: "episode", title: "Completed", seriesId: "42", watched: true, touch: 3, authorization: "current"}]
    m.seriesPage = true
    m.denyEpisode = true
    loadShelf()
    if m.top.result.items.count() <> 0 then stop

    resetShelfTest()
    m.top.shelf = "continue"
    m.top.savedState = [{id: 1, uuid: "episode-1", kind: "episode", title: "Completed", seriesId: "42", watched: true, touch: 3, authorization: "current"}, {id: 2, uuid: "episode-2", kind: "episode", title: "Old resume", seriesId: "42", position: 100, duration: 1000, touch: 2, authorization: "current"}]
    m.seriesPage = true
    loadShelf()
    if m.top.result.items.count() <> 1 or m.top.result.items[0].uuid <> "episode-2" then stop
    if m.top.result.items[0].nextUp <> true or m.top.result.items[0].savedPosition <> 100 then stop
    resetShelfTest()
    m.top.shelf = "favorite"
    m.top.savedState[0].favorite = true
    m.top.savedState[0].watchlist = false
    loadShelf()
    if not m.top.result.ok or m.top.result.items.count() <> 1 then stop

    resetShelfTest()
    m.top.shelf = "recent"
    m.top.savedState = []
    m.top.history = [{id: 1, uuid: "movie-uuid", kind: "movie", title: "Played"}]
    loadShelf()
    if not m.top.result.ok or m.top.result.items.count() <> 1 then stop
    if m.top.result.items[0].title <> "Fresh title" then stop

    resetShelfTest()
    m.top.shelf = "recent"
    m.top.savedState = []
    m.top.history = [{id: 1, uuid: "movie-uuid", kind: "movie", title: "Played"}]
    m.status = 404
    loadShelf()
    if m.top.result.items.count() <> 0 then stop
    print "ALL TESTS PASSED"
end sub

sub resetShelfTest()
    m.calls = 0
    m.status = 200
    m.user = {id: 1, user_level: 10, custom_properties: {}}
    m.raw = {id: 1, uuid: "movie-uuid", name: "Fresh title", year: 1999}
    m.seriesPage = false
    m.denyEpisode = false
    m.top = {baseUrl: "https://dispatch.test", apiKey: "server-secret", accountId: "1", shelf: "watchlist", cancelRequested: false}
    m.top.savedState = [{id: "1", uuid: "movie-uuid", kind: "movie", title: "Old title", watchlist: true, position: 100, duration: 1000, authorization: "current"}]
end sub

function requestJson(url as string) as dynamic
    m.calls++
    if m.key <> "server-secret" then stop
    if instr(1, url, "/users/me/") > 0 then return m.user
    if m.seriesPage and instr(1, url, "/api/vod/episodes/") > 0
        if instr(1, url, "?page_size=20") > 0
            return {count: 2, results: [{id: 1, uuid: "episode-1", name: "First", series: {id: 42, name: "Series"}, season_number: 0, episode_number: 1}, {id: 2, uuid: "episode-2", name: "Second", series: {id: 42, name: "Series"}, season_number: 0, episode_number: 2}], next: invalid}
        end if
        if m.denyEpisode then m.httpFailure = {status: 403} : return invalid
        if instr(1, url, "/2/") > 0 then return {id: 2, uuid: "episode-2", name: "Second", series: {id: 42, name: "Series"}, season_number: 0, episode_number: 2}
        return {id: 1, uuid: "episode-1", name: "First", series: {id: 42, name: "Series"}, season_number: 0, episode_number: 1}
    end if
    m.httpFailure = {status: m.status}
    if m.status <> 200 then return invalid
    return m.raw
end function

' Native hashing is covered on-device; tests vary the stored fingerprint.
function metadataCacheDigest(value as string) as string
    return "current"
end function
