sub main()
    resetDescriptionTest()
    onDescriptionLoaded(descriptionEvent(m.descriptionTask, {ok: true, key: m.detail.key, description: "The crew and their captain must find the visitor who arrived from another world."}))
    if instr(1, m.detail.description, "The crew") <> 1 then stop
    if m.dialog.serial <> 5 or m.dialog.buttons.count() <> 2 or m.dialog.focused <> 1 then stop
    if m.descriptionTask <> invalid then stop

    resetDescriptionTest()
    onDescriptionLoaded(descriptionEvent(descriptionNode(99), {ok: true, key: m.detail.key, description: "Stale"}))
    if m.detail.description <> "Texte original" then stop
    onDescriptionLoaded(descriptionEvent(m.descriptionTask, {ok: true, key: "movie:old", description: "Wrong title"}))
    if m.detail.description <> "Texte original" then stop

    resetDescriptionTest()
    onDescriptionLoaded(descriptionEvent(m.descriptionTask, {ok: false, key: m.detail.key}))
    if m.detail.description <> "Texte original" then stop
    if instr(1, m.dialog.message, "No alternate English summary found") = 0 then stop
    m.top = {config: {accountScope: "fixture"}, bookmark: invalid}
    m.fromUnifiedSearch = true
    m.shelf = "catalog"
    m.kind = "movie"
    m.query = "blue"
    m.category = ""
    m.providerId = ""
    m.ordering = "name"
    m.pageNumber = 1
    m.index = 0
    saveLibraryBookmark()
    if m.top.bookmark <> invalid then stop ' search detour cannot overwrite the library bookmark
    m.fromUnifiedSearch = false
    saveLibraryBookmark()
    if m.top.bookmark.query <> "blue" then stop ' normal library browsing still persists
    m.primaryNavigation = {items: []}
    m.libraryNavigation = {items: []}
    m.top = {config: {providerType: "xtream"}, permissions: {movies: "allowed", series: "allowed"}}
    updateLibraryTabs()
    if m.libraryNavigation.items.count() <> 6 then stop
    if m.libraryNavigation.items[2].id <> "recent" or m.libraryNavigation.items[3].id <> "watchlist" or m.libraryNavigation.items[4].id <> "favorite" then stop
    m.top.config.providerType = "dispatcharr"
    updateLibraryTabs()
    if m.libraryNavigation.items.count() <> 8 or m.libraryNavigation.items[2].id <> "continue" then stop
    testVodDisplayFrames()
    testVodUnsupportedBadge()
    testVodTwoStepBack()
    print "ALL TESTS PASSED"
end sub

sub testVodDisplayFrames()
    m.global = {appearance: {vodDisplayScale: 150, textSize: 120, subtextSize: 120}}
    m.top = {active: true, config: {baseUrl: "https://fixtures.invalid"}}
    m.primaryNavigation.active = false
    m.libraryNavigation.active = false
    m.heading = vodTestLabel()
    m.status = vodTestLabel()
    m.tiles = []
    for i = 0 to 19
        m.tiles.push({root: {}, border: {}, poster: {uri: ""}, title: vodTestLabel(), fact: vodTestLabel(), corners: []})
    end for
    m.items = []
    m.index = 0
    m.pageNumber = 1
    m.kind = "movie"
    m.failure = ""
    m.query = ""
    m.category = ""
    m.providerId = ""
    for each shelf in ["continue", "related"]
        m.shelf = shelf
        drawVod()
        if m.heading.translation[1] < 141 or m.heading.height + m.heading.translation[1] > 210 then stop
        if m.heading.width < 600 or m.heading.translation[1] + m.heading.height > m.status.translation[1] then stop
        if shelf = "continue" and m.heading.font.size <> 43 then stop
        if shelf = "related" and m.heading.font.size <> 58 then stop
        if m.status.translation[0] <> 96 or m.status.width <> 1728 then stop
        if m.status.translation[1] + m.status.height > m.tiles[0].root.translation[1] then stop
        if m.status.font.size <> 52 or m.status.font.size * 1.12 > m.status.height then stop
        m.global.appearance.subtextSize = 110
        drawVod()
        if m.status.font.size <> 48 then stop
        m.global.appearance.subtextSize = 120
    end for
    m.shelf = "watchlist"
    drawVod()
    if m.status.text <> "Nothing in To Watch yet. Add a movie or TV show from its details." then stop
    if m.status.width <> 1728 or m.status.font.size <> 52 then stop
    if len(m.status.text) * m.status.font.size * 0.51 > m.status.width then stop
    testVodFailureStatus()
    m.shelf = "versions"
    name = "A VERY LONG SOURCE NAME WITH UPPERCASE EXAMPLES AND A SHARED PREFIX FOR BOTH VERSIONS"
    m.items = vodVersionPage([{id: "1234567890123456788", m3u_account: {id: 5, name: name}}, {id: "1234567890123456789", m3u_account: {id: 5, name: name}}], 1).items
    for each scale in [85, 100, 115, 125, 135, 150]
        m.global.appearance.vodDisplayScale = scale
        m.index = 1
        drawVod()
        for i = 0 to 1
            tile = m.tiles[i]
            if not tile.root.visible or not tile.fact.visible or tile.fact.text <> "Version " + m.items[i].id then stop
            if tile.title.text <> name or tile.title.horizAlign <> "center" or tile.fact.horizAlign <> "center" then stop
            if tile.title.translation[1] <= tile.title.uiControlBounds.y or tile.fact.translation[1] <= tile.fact.uiControlBounds.y then stop
            if tile.title.translation[1] < 0 or tile.title.translation[1] + tile.title.height > tile.fact.translation[1] then stop
            if tile.fact.translation[1] + tile.fact.height > tile.border.height then stop
            if tile.title.maxLines * tile.title.font.size * 1.12 > tile.title.height then stop
            if tile.fact.maxLines <> 1 or tile.fact.wrap or tile.fact.font.size * 1.12 > tile.fact.height then stop
            if len(tile.fact.text) * tile.fact.font.size * 0.7 > tile.fact.width then stop
        end for
        if m.tiles[0].border.color = m.tiles[1].border.color then stop
    end for
    m.global.appearance.vodDisplayScale = 100
    m.global.appearance.textSize = 100
    m.global.appearance.subtextSize = 100
    drawVod()
    if m.tiles[0].fact.font.size <> 13 or m.tiles[0].fact.font.size * 1.12 > m.tiles[0].fact.height then stop
    if m.heading.translation[0] <> 96 or m.heading.translation[1] <> 91 or m.heading.width <> 280 or m.heading.height <> 55 then stop
    if m.status.translation[0] <> 96 or m.status.translation[1] <> 154 or m.status.width <> 1728 or m.status.height <> 40 then stop
    m.shelf = "categories"
    m.global.appearance.vodDisplayScale = 150
    m.items = [{id: "3", kind: "category", title: name, year: "", rating: ""}]
    m.index = 0
    drawVod()
    tile = m.tiles[0]
    if not tile.root.visible or tile.fact.visible or tile.title.translation[1] <= tile.title.uiControlBounds.y then stop
    if tile.title.translation[1] + tile.title.height > tile.border.height or tile.title.maxLines * tile.title.font.size * 1.12 > tile.title.height then stop
end sub

sub testVodFailureStatus()
    m.kind = "episode"
    m.shelf = "catalog"
    m.items = []
    for i = 0 to 1
        m.items.push({id: "fixture-" + i.toStr(), kind: "episode", title: "Fixture", season: "1", episode: i.toStr(), year: "", rating: ""})
        m.tiles[i].poster.uri = "pkg:/images/channel-icon-hd.png"
    end for
    m.index = 1
    m.task = descriptionNode(20)
    m.task.itemId = ""
    m.task.operation = "page"
    m.task.subtype = function() as string
        return "VodTask"
    end function
    reason = "Episode catalog could not be loaded from the available sources. Refresh to retry."
    onVodLoaded(descriptionEvent(m.task, {ok: false, message: reason, category: "episode-loading"}))
    if m.task <> invalid or m.index <> 1 or not m.tiles[1].root.visible then stop
    if m.tiles[0].border.color = m.tiles[1].border.color then stop
    if m.libraryNavigation.active or m.primaryNavigation.active then stop
    if m.status.text <> "* > Refresh to retry.  Episode catalog could not be loaded from the available sources." then stop
    if not m.status.wrap or m.status.maxLines <> 2 or m.status.font.size <> 52 then stop
    if m.status.height < 2 * m.status.font.size * 1.12 then stop
    if m.status.translation[1] + m.status.height > m.tiles[0].root.translation[1] then stop
    x = m.tiles[1].root.translation[0]
    m.failure = ""
    drawVod()
    if m.status.wrap or m.status.maxLines <> 1 or m.tiles[1].root.translation[1] <> 278 or m.tiles[1].root.translation[0] <> x or m.index <> 1 then stop
    for i = 0 to 1
        m.tiles[i].poster.uri = ""
    end for
end sub

function vodTestLabel() as object
    return {font: {size: 24}, translation: [0, 0], text: "", localBoundingRect: function() as object
        return {width: len(m.text) * m.font.size * 0.51}
    end function}
end function

sub resetDescriptionTest()
    m.top = {active: true}
    m.detail = vodNormalize({id: 1, uuid: "test", name: "Title", description: "Texte original"}, "movie")
    m.dialog = descriptionNode(5)
    m.dialog.buttons = ["Play", "Back"]
    m.dialog.focused = 1
    m.descriptionDialog = m.dialog
    m.descriptionTask = descriptionNode(6)
end sub

function descriptionNode(serial)
    return {serial: serial, isSameNode: function(other)
        return m.serial = other.serial
    end function, unobserveField: sub(field)
    end sub}
end function

function descriptionEvent(node, data)
    return {node: node, data: data, getRoSGNode: function()
        return m.node
    end function, getData: function()
        return m.data
    end function}
end function

sub testVodUnsupportedBadge()
    m.global = {appearance: {vodDisplayScale: 100, textSize: 100, subtextSize: 100}}
    m.top = {active: true, config: {baseUrl: "https://fixtures.invalid"}, unsupportedTitles: {"wide-uuid": true}}
    m.shelf = "catalog"
    m.items = [vodNormalize({id: 7, uuid: "wide-uuid", name: "Wide", year: 2010, rating: "7"}, "movie"), vodNormalize({id: 8, uuid: "fine-uuid", name: "Fine", year: 2011, rating: "6"}, "movie")]
    m.index = 0
    for i = 0 to 1
        ' Preset artwork so the host test does not create a native roHttpAgent.
        m.tiles[i].poster.uri = vodArtworkUrl(m.top.config.baseUrl, m.items[i])
    end for
    drawVod()
    if m.tiles[0].fact.text <> "Won't play on Roku" then stop
    if m.tiles[1].fact.text = "Won't play on Roku" or instr(1, m.tiles[1].fact.text, "2011") = 0 then stop
    if m.tiles[0].fact.color = m.tiles[1].fact.color then stop ' the badge is visually distinct
    m.top.unsupportedTitles = {}
    drawVod()
    if instr(1, m.tiles[0].fact.text, "2010") = 0 or m.tiles[0].fact.color <> m.tiles[1].fact.color then stop
    resetDescriptionTest()
    m.top.unsupportedTitles = {test: true}
    renderDetailDescription()
    if instr(1, m.dialog.message, "Won't play on Roku") <> 1 then stop
    m.top.unsupportedTitles = {}
    renderDetailDescription()
    if instr(1, m.dialog.message, "Won't play on Roku") > 0 then stop
end sub

' Upstream parity (9jr0): the first Back at a library root focuses the VOD
' tab; Back from that tab returns to Live TV.
sub testVodTwoStepBack()
    for each provider in ["dispatcharr", "xtream"]
        m.top = {active: true, config: {providerType: provider, accountScope: "fixture"}}
        m.fromUnifiedSearch = true
        m.descriptionTask = invalid
        m.task = invalid
        m.kind = "movie"
        m.parentPage = invalid
        m.discoveryStack = []
        m.shelf = "catalog"
        if provider = "xtream" then m.shelf = "categories"
        m.index = 7
        m.primaryNavigation = {active: false}
        m.libraryNavigation = {active: false}
        if not onKeyEvent("back", true) then stop
        if m.top.exitRequested = true then stop ' first Back must not leave the library
        if m.primaryNavigation.active <> true then stop
        onLibraryPrimaryExit(descriptionEvent(m.primaryNavigation, "back"))
        if m.top.exitRequested <> true then stop
        m.top.exitRequested = invalid
        onLibraryPrimaryExit(descriptionEvent(m.primaryNavigation, "down"))
        if m.top.exitRequested = true or m.libraryNavigation.active <> true then stop
    end for
end sub
