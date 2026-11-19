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
    for each shelf in ["continue", "related"]
        m.shelf = shelf
        drawVod()
        if m.heading.translation[1] < 141 or m.heading.height + m.heading.translation[1] > 210 then stop
        if m.heading.width < 600 or m.heading.translation[0] + m.heading.width > m.status.translation[0] then stop
        if shelf = "continue" and m.heading.font.size <> 43 then stop
        if shelf = "related" and m.heading.font.size <> 58 then stop
        if m.status.translation[1] < 141 or m.status.height + m.status.translation[1] > 210 then stop
        if m.status.font.size <> 52 or m.status.font.size * 1.12 > m.status.height then stop
        m.global.appearance.subtextSize = 110
        drawVod()
        if m.status.font.size <> 48 then stop
        m.global.appearance.subtextSize = 120
    end for
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
    drawVod()
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

function vodTestLabel() as object
    return {font: {size: 24}, translation: [0, 0], text: ""}
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
