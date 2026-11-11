' Probe-only configuration. Actual loading callbacks, rendering, navigation,
' menus, detail actions and pagination below this boundary remain production.
sub seedUiAuditVod(scenario as string)
    m.top.permissions = {movies: "allowed", series: "allowed", dvr: "manage", level: 10}
    if scenario = "library-denied" then m.top.permissions = {movies: "denied", series: "denied", dvr: "none", level: 0}
    config = {baseUrl: "https://example.invalid", apiKey: "", accountId: "fixture", accountScope: "ui-audit", providerType: "dispatcharr", kind: "movie", tmdbEnabled: false, tmdbKey: ""}
    if scenario = "library-series" then config.kind = "series"
    if scenario = "library-episodes" then config.kind = "episode"
    if scenario = "library-xtream" then config.providerType = "xtream"
    m.top.config = config
    cancelVod()
    m.shelf = "catalog"
    for each shelf in ["favorite", "watchlist", "continue", "recent", "hidden", "categories", "providers", "versions"]
        if scenario = "library-" + shelf then m.shelf = shelf
    end for
    if scenario = "library-xtream" then m.shelf = "categories"
    if m.shelf = "versions" then m.versionItem = {id: "1"}
    saved = []
    for i = 1 to 20
        id = i.toStr()
        row = {id: id, uuid: "fixture-movie-" + id, kind: "movie", title: "Synthetic Movie " + id, authorization: "ui-audit", availability: "available"}
        if m.shelf = "favorite" then row.favorite = true
        if m.shelf = "watchlist" then row.watchlist = true
        if m.shelf = "hidden" then row.hidden = true
        if m.shelf = "continue"
            row.position = 600
            row.duration = 5400
        end if
        saved.push(row)
    end for
    m.top.savedState = saved
    if config.kind = "episode"
        m.seriesId = "1"
        m.parentPage = {page: 1, index: 0, query: "", category: "", providerId: ""}
    end if
    m.top.active = true
    loadVodPage()
    m.top.setFocus(true)
end sub

function uiAuditLibraryState() as object
    state = libraryStatus()
    state.primary = m.primaryNavigation.active
    state.tabs = m.libraryNavigation.active
    state.exitRequested = m.top.exitRequested
    state.dialog = ""
    state.buttons = []
    state.focused = -1
    if m.dialog <> invalid
        state.dialog = m.dialog.subtype()
        state.buttons = m.dialog.buttons
        if m.dialog.subtype() = "AerioDialog" then state.focused = m.dialog.buttonFocused
        if m.dialog.subtype() = "VodDetails" then state.focused = m.dialog.findNode("actions").itemFocused
    end if
    state.playRequested = m.top.playRequested <> invalid
    return state
end function
