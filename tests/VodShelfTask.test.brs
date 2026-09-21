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
    print "ALL TESTS PASSED"
end sub

sub resetShelfTest()
    m.calls = 0
    m.status = 200
    m.user = {id: 1, user_level: 10, custom_properties: {}}
    m.raw = {id: 1, uuid: "movie-uuid", name: "Fresh title", year: 1999}
    m.top = {baseUrl: "https://dispatch.test", apiKey: "server-secret", accountId: "1", shelf: "watchlist", cancelRequested: false}
    m.top.savedState = [{id: "1", uuid: "movie-uuid", kind: "movie", title: "Old title", watchlist: true, position: 100, duration: 1000, authorization: "current"}]
end sub

function requestJson(url as string) as dynamic
    m.calls++
    if m.key <> "server-secret" then stop
    if instr(1, url, "/users/me/") > 0 then return m.user
    m.httpFailure = {status: m.status}
    if m.status <> 200 then return invalid
    return m.raw
end function

' Native hashing is covered on-device; tests vary the stored fingerprint.
function metadataCacheDigest(value as string) as string
    return "current"
end function
