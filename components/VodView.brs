sub init()
    m.top.focusable = true
    m.task = invalid
    m.descriptionTask = invalid
    m.tmdbTask = invalid
    m.discoveryStack = []
    m.items = []
    m.dialog = invalid
    m.tiles = []
    m.index = 0
    m.pageNumber = 1
    m.kind = "movie"
    m.query = ""
    m.category = ""
    m.providerId = ""
    m.seriesId = ""
    m.ordering = "name"
    m.shelf = "catalog"
    m.failure = ""
    m.bypassCache = false
    background = uiRect(m.top, 0, 0, 1920, 1080, "0x0A1628FF")
    m.top.removeChild(background)
    m.top.insertChild(background, 0)
    m.primaryNavigation = m.top.findNode("primaryNavigation")
    m.libraryNavigation = m.top.findNode("libraryNavigation")
    m.primaryNavigation.observeField("selection", "onLibraryPrimarySelection")
    m.primaryNavigation.observeField("exitRequested", "onLibraryPrimaryExit")
    m.libraryNavigation.observeField("selection", "onLibraryTabSelection")
    m.libraryNavigation.observeField("exitRequested", "onLibraryTabExit")
    updateLibraryTabs()
    m.heading = uiLabel(m.top, "Movies", 96, 91, 440, 55, 38)
    m.status = uiLabel(m.top, "", 96, 154, 1728, 40, 24, "0x9EB5C9FF")
    for i = 0 to 19
        root = m.top.createChild("Group")
        border = uiSurface(root, 68, 0, 200, 296, 12, "0x263549FF")
        poster = root.createChild("Poster")
        poster.translation = [72, 4]
        poster.width = 192
        poster.height = 288
        poster.loadWidth = 192
        poster.loadHeight = 288
        poster.loadDisplayMode = "scaleToFit"
        corners = []
        names = ["tl", "tr", "bl", "br"]
        positions = [[72, 4], [256, 4], [72, 284], [256, 284]]
        for j = 0 to 3
            mask = root.createChild("Poster")
            mask.uri = "pkg:/images/ui-cutout-" + names[j] + ".png"
            mask.translation = positions[j]
            mask.width = 8
            mask.height = 8
            mask.loadDisplayMode = "scaleToFill"
            corners.push(mask)
        end for
        title = uiLabel(root, "", 4, 304, 328, 52, uiTypeSize("body"))
        title.wrap = true
        title.maxLines = 2
        title.horizAlign = "center"
        fact = uiLabel(root, "", 4, 354, 328, 26, uiTypeSize("caption"), "0x9EB5C9FF")
        fact.horizAlign = "center"
        m.tiles.push({root: root, border: border, poster: poster, title: title, fact: fact, corners: corners})
    end for
    hints = uiRemoteHints(m.top, 96, 990, 1728, 40, 23)
    hints.text = "Up from first row  Navigation    OK  Details    *  Library options    FF / Rew  Pages    Back  Return"
end sub

sub configureVod()
    cancelVod()
    dismissVodDialog()
    m.discoveryStack = []
    m.discoveryAnchor = invalid
    m.discoveryPerson = ""
    m.items = []
    m.detail = invalid
    for each tile in m.tiles
        tile.poster.uri = ""
        tile.title.text = ""
    end for
    if m.top.config = invalid then return
    m.kind = m.top.config.kind
    updateLibraryTabs()
    m.pageNumber = 1
    m.index = 0
    m.query = ""
    m.category = ""
    m.providerId = ""
    m.seriesId = ""
    m.items = []
    m.ordering = "name"
    m.parentPage = invalid
    m.versionItem = invalid
    m.versionReturn = invalid
    m.relationId = ""
    m.versionFor = ""
    m.shelf = "catalog"
    m.failure = ""
    saved = m.top.config.bookmark
    if type(saved) = "roAssociativeArray"
        m.query = left(textValue(saved.query), 120)
        m.category = left(textValue(saved.category), 240)
        m.providerId = left(textValue(saved.providerId), 20)
        m.ordering = textValue(saved.ordering)
        m.pageNumber = textValue(saved.page).toInt()
        if m.pageNumber < 1 then m.pageNumber = 1
        m.index = textValue(saved.index).toInt()
        if m.index < 0 or m.index > 19 then m.index = 0
    end if
    loadVodPage()
end sub

sub activateVod()
    m.top.visible = m.top.active
    if m.top.active
        if m.shelf <> "catalog" and m.shelf <> "categories" and m.shelf <> "providers" then loadVodPage()
        drawVod()
        m.top.setFocus(true)
    else
        m.primaryNavigation.active = false
        m.libraryNavigation.active = false
        cancelVod()
    end if
end sub

sub cancelVod()
    cancelDescription()
    cancelTmdb()
    if m.task <> invalid
        m.task.unobserveField("result")
        cancelNetworkTask(m.task)
        m.task = invalid
    end if
end sub

sub loadVodPage(itemId = "" as string)
    cancelVod()
    if itemId = "" and (m.shelf = "people" or m.shelf = "related" or m.shelf = "person")
        loadDiscovery()
        return
    end if
    if itemId <> m.versionFor
        m.relationId = ""
        if itemId <> "" and type(m.top.permissions) = "roAssociativeArray"
            if m.top.permissions.level >= 10
                for each item in m.items
                    if item.id = itemId and item.kind = m.kind
                        saved = vodStateEntry(m.top.savedState, item)
                        m.relationId = textValue(saved.relationId)
                        exit for
                    end if
                end for
            end if
        end if
    end if
    m.failure = ""
    if itemId = ""
        m.items = []
    end if
    m.status.text = "Loading... Back cancels."
    if itemId = "" and (m.shelf = "continue" or m.shelf = "watchlist" or m.shelf = "hidden")
        m.task = CreateObject("roSGNode", "VodShelfTask")
        m.task.baseUrl = m.top.config.baseUrl
        m.task.apiKey = m.top.config.apiKey
        m.task.accountId = m.top.config.accountId
        m.task.savedState = m.top.savedState
        m.task.shelf = m.shelf
        m.task.observeField("result", "onVodLoaded")
        m.task.control = "RUN"
        return
    end if
    m.task = CreateObject("roSGNode", "VodTask")
    m.task.baseUrl = m.top.config.baseUrl
    m.task.apiKey = m.top.config.apiKey
    m.task.accountId = m.top.config.accountId
    m.task.kind = m.kind
    m.task.pageNumber = m.pageNumber
    m.task.query = m.query
    m.task.category = m.category
    m.task.providerId = m.providerId
    m.task.seriesId = m.seriesId
    m.task.itemId = itemId
    m.task.relationId = m.relationId
    m.task.ordering = m.ordering
    m.task.cacheEpoch = m.global.cacheEpoch
    m.task.bypassCache = m.bypassCache
    m.bypassCache = false
    if m.shelf <> "catalog" and m.shelf <> "categories" and m.shelf <> "providers" and m.shelf <> "versions" and itemId = "" then m.task.operation = "authorize"
    if m.shelf = "categories" then m.task.operation = "categories"
    if m.shelf = "providers" then m.task.operation = "providers"
    if m.shelf = "versions"
        m.task.operation = "versions"
        m.task.itemId = m.versionItem.id
        m.task.relationId = ""
    end if
    m.task.observeField("result", "onVodLoaded")
    m.task.control = "RUN"
end sub

sub onVodLoaded(event as object)
    if not isCurrentTaskEvent(event, m.task) then return
    result = event.getData()
    shelfResult = m.task.subtype() = "VodShelfTask"
    detail = false
    if not shelfResult then detail = m.task.itemId <> "" and m.task.operation <> "versions"
    m.task.unobserveField("result")
    m.task = invalid
    if not result.ok
        if detail
            m.relationId = ""
            m.versionFor = ""
        end if
        if not detail and m.pageNumber > 1 and result.status = 404
            m.pageNumber = 1
            m.index = 0
            loadVodPage()
            return
        end if
        m.failure = result.message + "  * > Refresh to retry."
        m.status.text = m.failure
        return
    end if
    if shelfResult
        m.top.stateChange = {scope: m.top.config.accountScope, availability: result.patches}
        m.items = result.items
        m.total = m.items.count()
        m.hasNext = false
        if m.index >= m.items.count() then m.index = 0
        drawVod()
        return
    end if
    if detail
        m.detail = result.item
        dismissVodDialog()
        dialog = CreateObject("roSGNode", "VodDetails")
        dialog.id = "vodDetails"
        m.top.appendChild(dialog)
        dialog.baseUrl = m.top.config.baseUrl
        dialog.apiKey = m.top.config.apiKey
        dialog.title = m.detail.title
        m.descriptionNotice = ""
        m.tmdbNotice = ""
        entry = vodStateEntry(m.top.savedState, m.detail)
        menu = vodDetailMenu(m.detail, entry)
        menu.actions.pop()
        menu.buttons.pop()
        if type(m.top.permissions) = "roAssociativeArray"
            if m.top.permissions.level >= 10 and m.detail.kind <> "series"
                menu.actions.push("versions")
                menu.buttons.push("Choose source version")
                if textValue(entry.relationId) <> ""
                    menu.actions.push("autoSource")
                    menu.buttons.push("Use Auto source")
                end if
            end if
        end if
        if m.top.config.tmdbEnabled = true and m.top.config.tmdbKey <> ""
            menu.actions.push("related") : menu.buttons.push("Related titles in my library")
            menu.actions.push("people") : menu.buttons.push("Cast and crew discovery")
            if vodExternalLinks(m.detail).count() = 0 then menu.actions.push("links") : menu.buttons.push("External information / trailer links")
        end if
        menu.actions.push("synopsis") : menu.buttons.push("Full synopsis")
        menu.actions.push("back") : menu.buttons.push("Back")
        m.detailActions = menu.actions
        dialog.buttons = menu.buttons
        dialog.observeField("buttonSelected", "onVodDetailAction")
        dialog.observeField("wasClosed", "onVodDialogClosed")
        m.dialog = dialog
        renderDetailDescription()
        dialog.callFunc("focusActions")
        beginDescription()
        beginTmdb()
        drawVod()
        return
    end if
    m.items = []
    for each item in result.items
        entry = vodStateEntry(m.top.savedState, item)
        if not vodItemHidden(m.top.savedState, item) then m.items.push(item)
    end for
    m.total = result.total
    m.hasNext = result.next <> ""
    if m.index >= m.items.count() then m.index = 0
    drawVod()
end sub

sub drawVod()
    if m.kind = "movie" then m.libraryNavigation.selected = "movie" else m.libraryNavigation.selected = "series"
    if m.shelf = "continue" or m.shelf = "watchlist" or m.shelf = "hidden" or m.shelf = "categories" then m.libraryNavigation.selected = m.shelf
    m.heading.text = "Movies"
    if m.kind = "series" then m.heading.text = "TV Shows"
    if m.kind = "episode" then m.heading.text = "Episodes"
    if m.shelf <> "catalog" then m.heading.text = "Library — " + m.shelf
    if m.shelf = "continue" then m.heading.text = "Continue Watching"
    if m.shelf = "watchlist" then m.heading.text = "Watchlist"
    if m.shelf = "hidden" then m.heading.text = "Hidden titles"
    if m.shelf = "categories" then m.heading.text = "Categories"
    if m.task = invalid and m.tmdbTask = invalid
        m.status.text = "Page " + m.pageNumber.toStr() + "  |  " + m.items.count().toStr() + " titles loaded"
        if m.total <> invalid then m.status.text += " of " + m.total.toStr()
        if m.items.count() = 0 then m.status.text = "No available titles match this account and search."
        if m.items.count() = 0 and m.hasNext = true then m.status.text = "Nothing visible on this page. FF loads the next page."
        if m.query <> "" then m.status.text += "  |  Search: " + m.query
        if m.category <> "" and m.shelf = "catalog" then m.status.text += "  |  " + m.category
        if m.providerId <> "" and m.shelf = "catalog" then m.status.text += "  |  Provider " + m.providerId
    end if
    if m.failure <> "" then m.status.text = m.failure
    if (m.shelf = "related" or m.shelf = "person") and m.failure = "" and textValue(m.discoveryMessage) <> "" then m.status.text = m.discoveryMessage
    for i = 0 to 19
        tile = m.tiles[i]
        compact = m.shelf = "categories" or m.shelf = "providers" or m.shelf = "versions"
        placement = vodVisualTile(i, m.index, m.items.count(), compact)
        tile.root.translation = [placement.x, placement.y]
        tile.root.visible = placement.visible
        tile.border.visible = i < m.items.count()
        tile.poster.visible = i < m.items.count() and not compact
        tile.title.visible = i < m.items.count()
        tile.fact.visible = i < m.items.count()
        if i < m.items.count()
            item = m.items[i]
            borderColor = "0x263549FF"
            if i = m.index then borderColor = "0x1AC4D8FF"
            uiSetColor(tile.border, borderColor)
            uiSetColor(tile.title, "0xE8F3FAFF")
            if compact
                style = uiControlStyle("action", false, i = m.index, true, false)
                tile.border.translation = [0, 0]
                tile.border.width = 336
                tile.border.height = 116
                tile.border.radius = 24
                borderColor = style.fill
                uiSetColor(tile.border, borderColor)
                tile.title.translation = [16, 18]
                tile.title.width = 304
                uiSetColor(tile.title, style.ink)
                uiSetColor(tile.fact, style.ink)
                tile.fact.translation = [16, 78]
                tile.fact.width = 304
            else
                tile.border.translation = [68, 0]
                tile.border.width = 200
                tile.border.height = 296
                tile.border.radius = 12
                tile.title.translation = [4, 304]
                tile.title.width = 328
                tile.fact.translation = [4, 354]
                tile.fact.width = 328
                uiSetColor(tile.fact, "0x9EB5C9FF")
                if uiAppearance().textSize = 110 or uiAppearance().textSize = 120
                    tile.border.translation = [76, 0]
                    tile.border.width = 184
                    tile.border.height = 272
                    tile.poster.translation = [80, 4]
                    tile.poster.width = 176
                    tile.poster.height = 264
                    tile.title.translation = [4, 282]
                    tile.title.height = 68
                else
                    tile.poster.translation = [72, 4]
                    tile.poster.width = 192
                    tile.poster.height = 288
                    tile.title.height = 52
                end if
            end if
            for j = 0 to tile.corners.count() - 1
                corner = tile.corners[j]
                corner.visible = not compact
                uiSetColor(corner, borderColor, "blendColor")
                px = tile.poster.translation[0]
                py = tile.poster.translation[1]
                if j mod 2 = 1 then px += tile.poster.width - 8
                if j >= 2 then py += tile.poster.height - 8
                corner.translation = [px, py]
            end for
            tile.title.text = item.title
            tile.fact.text = item.year + "  " + item.rating
            if item.kind = "episode" then tile.fact.text = "S" + item.season + " E" + item.episode
            if m.shelf = "continue" and item.kind = "episode" and textValue(item.seriesTitle) <> "" then tile.title.text = item.seriesTitle + " — " + item.title
            uri = vodArtworkUrl(m.top.config.baseUrl, item)
            if not placement.visible or compact then uri = ""
            if item.metadataPending = true then tile.fact.text = "Refresh to verify"
            if item.unavailable = true
                tile.fact.text = "Unavailable — * to remove"
                uri = ""
            end if
            if placement.visible and not compact and uri = "" and tmdbImagePath(item.tmdbPosterPath) <> "" then uri = "https://image.tmdb.org/t/p/w185" + item.tmdbPosterPath
            if tile.poster.uri <> uri
                agent = CreateObject("roHttpAgent")
                agent.setCertificatesFile("common:/certs/ca-bundle.crt")
                if trustedPageUrl(m.top.config.baseUrl, uri) <> "" then agent.setHeaders({"X-API-Key": m.top.config.apiKey})
                tile.poster.setHttpAgent(agent)
                tile.poster.uri = uri
            end if
        else
            tile.poster.uri = ""
        end if
    end for
end sub

sub refreshAppearance()
    if m.heading <> invalid then drawVod()
end sub

sub onVodDetailAction(event as object)
    if not isCurrentTaskEvent(event, m.dialog) then return
    choice = event.getData()
    if choice < 0 or choice >= m.detailActions.count() then return
    action = m.detailActions[choice]
    dismissVodDialog()
    if action = "back" then return
    if action = "people" or action = "related"
        enterDiscovery(action, m.detail)
        return
    end if
    if action = "synopsis"
        m.synopsisPage = 0
        openFullSynopsis()
        return
    end if
    if action = "autoSource"
        m.relationId = ""
        m.versionFor = m.detail.id
        m.top.stateChange = {scope: m.detail.accountScope, item: m.detail, patch: {relationId: ""}}
        m.top.savedState = vodStateUpdate(m.top.savedState, m.detail, {relationId: ""})
        loadVodPage(m.detail.id)
        return
    end if
    if action = "versions"
        m.versionItem = m.detail
        m.versionReturn = {items: m.items, index: m.index, page: m.pageNumber, shelf: m.shelf, total: m.total, hasNext: m.hasNext}
        m.shelf = "versions"
        m.pageNumber = 1
        m.index = 0
        loadVodPage()
        return
    end if
    if action = "links"
        dialog = CreateObject("roSGNode", "Dialog")
        dialog.title = "Open on another device"
        message = "External links; these do not play inside AerioTV."
        for each link in vodExternalLinks(m.detail)
            message += chr(10) + link
        end for
        dialog.message = message
        dialog.buttons = ["Close"]
        dialog.observeField("buttonSelected", "closeVodLink")
        dialog.observeField("wasClosed", "onVodDialogClosed")
        m.dialog = dialog
        m.top.getScene().dialog = dialog
        return
    end if
    entry = vodStateEntry(m.top.savedState, m.detail)
    if action = "watchlist" or action = "hidden" or action = "watched"
        patch = {}
        patch[action] = not entry[action]
        if action = "watched" then patch.position = 0
        m.top.stateChange = {scope: m.detail.accountScope, item: m.detail, patch: patch}
        m.top.savedState = vodStateUpdate(m.top.savedState, m.detail, patch)
        if action = "hidden" or m.shelf <> "catalog" then loadVodPage()
        return
    end if
    if action = "episodes"
        saveLibraryBookmark()
        m.parentPage = {page: m.pageNumber, index: m.index, query: m.query, category: m.category, providerId: m.providerId}
        m.seriesId = m.detail.id
        m.kind = "episode"
        m.pageNumber = 1
        m.index = 0
        m.query = ""
        m.category = ""
        m.shelf = "catalog"
        m.items = []
        loadVodPage()
    else
        saveLibraryBookmark()
        m.detail.resume = 0
        if action = "resume" then m.detail.resume = vodResumePosition(entry, entry.duration)
        if action = "mp4" then m.detail.streamFormat = "mp4"
        if action = "mkv" then m.detail.streamFormat = "mkv"
        if action <> "resume" then m.top.stateChange = {scope: m.detail.accountScope, item: m.detail, patch: {position: 0, watched: false}}
        m.top.playRequested = m.detail
    end if
end sub

sub onVodDialogClosed(event as object)
    if not isCurrentTaskEvent(event, m.dialog) then return
    dismissVodDialog()
end sub

sub dismissVodDialog()
    cancelDescription()
    cancelTmdb()
    node = m.dialog
    m.dialog = invalid
    if node <> invalid
        node.unobserveField("buttonSelected")
        node.unobserveField("wasClosed")
        node.close = true
        if node.subtype() = "VodDetails" then m.top.removeChild(node)
    end if
    if m.top.active then m.top.setFocus(true)
    if m.top.active and m.status <> invalid then drawVod()
end sub

sub renderDetailDescription()
    if m.dialog = invalid or m.detail = invalid then return
    message = m.detail.year + "  " + left(m.detail.genre, 100)
    actors = left(m.detail.actors, 180)
    director = left(m.detail.director, 160)
    if m.detail.tmdb <> invalid
        message += chr(10) + "TMDB rating: " + m.detail.tmdb.rating
        if m.detail.tmdb.runtimeMinutes > 0 then message += "  |  Runtime (TMDB): " + m.detail.tmdb.runtimeMinutes.toStr() + " min"
        tmdbActors = ""
        tmdbDirectors = ""
        for each person in m.detail.tmdb.people
            if person.director = true
                if tmdbDirectors <> "" then tmdbDirectors += ", "
                tmdbDirectors += person.name
            end if
            if person.cast = true and len(tmdbActors) < 160
                if tmdbActors <> "" then tmdbActors += ", "
                tmdbActors += person.name
            end if
        end for
        if tmdbActors <> "" then actors = left(tmdbActors, 200)
        if tmdbDirectors <> "" then director = left(tmdbDirectors, 160)
    else
        message += chr(10) + "Provider rating: " + m.detail.rating
        if m.detail.duration > 0 then message += "  |  Provider runtime: " + (m.detail.duration \ 60).toStr() + " min"
    end if
    if m.detail.airDate <> "" then message += "  " + m.detail.airDate
    message += chr(10) + chr(10) + left(m.detail.description, 900)
    if actors <> "" then message += chr(10) + chr(10) + "Cast: " + actors
    if director <> "" then message += chr(10) + "Director / creator: " + director
    if m.descriptionNotice <> "" then message += chr(10) + m.descriptionNotice
    if m.detail.tmdb = invalid and textValue(m.tmdbNotice) <> "" then message += chr(10) + m.tmdbNotice
    m.dialog.message = message
    if type(m.dialog) <> "roAssociativeArray"
        if m.dialog.subtype() = "VodDetails"
            uri = vodArtworkUrl(m.top.config.baseUrl, m.detail)
            m.dialog.posterUri = uri
            fallback = ""
            if textValue(m.detail.seriesLogoId) <> "" then fallback = m.top.config.baseUrl + "/api/vod/vodlogos/" + m.detail.seriesLogoId + "/cache/"
            if tmdbImagePath(m.detail.tmdbPosterPath) <> "" then fallback = "https://image.tmdb.org/t/p/w342" + m.detail.tmdbPosterPath
            m.dialog.fallbackUri = fallback
            m.dialog.tmdbUsed = m.detail.tmdb <> invalid
        end if
    end if
end sub

sub beginDescription()
    cancelDescription()
    if descriptionLanguage(m.detail.description) = "en" then return
    if m.detail.kind <> "movie" and m.detail.kind <> "series" then return
    m.descriptionNotice = "Checking for an English summary... Playback is available."
    renderDetailDescription()
    m.descriptionDialog = m.dialog
    m.descriptionTask = CreateObject("roSGNode", "DescriptionTask")
    m.descriptionTask.baseUrl = m.top.config.baseUrl
    m.descriptionTask.apiKey = m.top.config.apiKey
    m.descriptionTask.accountId = m.top.config.accountId
    m.descriptionTask.item = m.detail
    m.descriptionTask.cacheEpoch = m.global.cacheEpoch
    m.descriptionTask.observeField("result", "onDescriptionLoaded")
    m.descriptionTask.control = "RUN"
end sub

sub cancelDescription()
    if m.descriptionTask <> invalid
        m.descriptionTask.unobserveField("result")
        cancelNetworkTask(m.descriptionTask)
        m.descriptionTask = invalid
    end if
    m.descriptionDialog = invalid
end sub

sub onDescriptionLoaded(event as object)
    if not isCurrentTaskEvent(event, m.descriptionTask) then return
    result = event.getData()
    dialog = m.descriptionDialog
    cancelDescription()
    if not m.top.active or m.dialog = invalid or dialog = invalid then return
    if not m.dialog.isSameNode(dialog) or m.detail.key <> result.key then return
    m.descriptionNotice = "No alternate English summary found; showing provider text."
    if m.detail.description = "" then m.descriptionNotice = "No description supplied by the provider."
    if result.ok
        if descriptionLanguage(m.detail.description) <> "en"
            m.detail.description = result.description
            m.descriptionNotice = "English provider summary."
        else
            m.descriptionNotice = ""
        end if
    else if descriptionLanguage(m.detail.description) = "en"
        m.descriptionNotice = ""
    end if
    ' Keep the existing Dialog/buttons/focus; update only its text.
    renderDetailDescription()
end sub

sub openVodOptions()
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Library options"
    labels = ["Search"]
    m.optionCodes = [0]
    permissions = m.top.permissions
    if type(permissions) = "roAssociativeArray"
        if permissions.movies = "allowed" then labels.push("Movies") : m.optionCodes.push(1)
        if permissions.series = "allowed" then labels.push("TV Shows") : m.optionCodes.push(2)
    end if
    labels.append(["Sort: title / newest / year", "Refresh", "Continue Watching", "Watchlist", "Hidden titles", "Categories", "Reset hidden list", "Close"])
    m.optionCodes.append([3, 4, 5, 6, 7, 8, 9, 10])
    if type(permissions) = "roAssociativeArray"
        if permissions.level >= 10
            labels.push("Filter by provider") : m.optionCodes.push(12)
            if m.items.count() > 0 and (m.kind = "movie" or m.kind = "episode") and m.shelf <> "versions" and m.shelf <> "categories" and m.shelf <> "providers"
                labels.push("Choose source for selected title") : m.optionCodes.push(13)
            end if
        end if
    end if
    if m.shelf = "continue" or m.shelf = "watchlist" or m.shelf = "hidden"
        labels.push("Remove selected saved entry") : m.optionCodes.push(11)
    end if
    dialog.buttons = labels
    dialog.observeField("buttonSelected", "onVodOption")
    dialog.observeField("wasClosed", "onVodDialogClosed")
    m.dialog = dialog
    m.top.getScene().dialog = dialog
end sub

sub openVodSearch()
    dismissVodDialog()
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.title = "Search permitted library"
    dialog.text = m.query
    dialog.buttons = ["Search", "Cancel"]
    dialog.observeField("buttonSelected", "onVodSearch")
    dialog.observeField("wasClosed", "onVodDialogClosed")
    m.dialog = dialog
    m.top.getScene().dialog = dialog
end sub

sub onVodOption(event as object)
    if not isCurrentTaskEvent(event, m.dialog) then return
    choice = event.getData()
    if choice < 0 or choice >= m.optionCodes.count() then return
    choice = m.optionCodes[choice]
    dismissVodDialog()
    if choice = 4 then m.bypassCache = true
    if choice = 0
        openVodSearch()
        return
    else if choice = 1 or choice = 2
        m.shelf = "catalog"
        m.category = ""
        m.providerId = ""
        m.kind = "movie"
        if choice = 2 then m.kind = "series"
        m.seriesId = ""
        m.query = ""
        m.parentPage = invalid
    else if choice = 3
        if m.ordering = "name" then m.ordering = "-created_at" else if m.ordering = "-created_at" then m.ordering = "-year" else m.ordering = "name"
    else if choice = 5 or choice = 6 or choice = 7
        if choice = 5 then m.shelf = "continue"
        if choice = 6 then m.shelf = "watchlist"
        if choice = 7 then m.shelf = "hidden"
    else if choice = 8
        m.shelf = "categories"
        m.query = ""
    else if choice = 9
        m.top.stateChange = {scope: m.top.config.accountScope, clearHidden: true}
        m.shelf = "catalog"
    else if choice = 11
        if m.items.count() > 0 then m.top.stateChange = {scope: m.top.config.accountScope, removeKey: m.items[m.index].key}
    else if choice = 12
        m.shelf = "providers"
        m.query = ""
    else if choice = 13
        m.versionItem = m.items[m.index]
        m.versionReturn = {items: m.items, index: m.index, page: m.pageNumber, shelf: m.shelf, total: m.total, hasNext: m.hasNext}
        m.shelf = "versions"
    else if choice <> 4
        return
    end if
    m.pageNumber = 1
    m.index = 0
    m.items = []
    loadVodPage()
end sub

sub onVodSearch(event as object)
    if not isCurrentTaskEvent(event, m.dialog) then return
    text = event.getRoSGNode().text
    submitted = event.getData() = 0
    dismissVodDialog()
    if submitted
        m.shelf = "catalog"
        m.query = left(text.trim(), 120)
        m.pageNumber = 1
        m.index = 0
        m.items = []
        loadVodPage()
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not m.top.active or not press then return false
    if key = "up" and m.index < 5
        m.libraryNavigation.active = true
        return true
    end if
    if key = "back"
        saveLibraryBookmark()
        cancelVod()
        if (m.shelf = "people" or m.shelf = "related" or m.shelf = "person") and m.discoveryStack.count() > 0
            restoreDiscovery()
            return true
        end if
        if m.shelf = "versions" and m.versionReturn <> invalid
            restoreVersionPage()
            return true
        end if
        if m.kind = "episode" and m.parentPage <> invalid
            m.kind = "series"
            m.seriesId = ""
            m.pageNumber = m.parentPage.page
            m.index = m.parentPage.index
            m.query = m.parentPage.query
            m.category = m.parentPage.category
            m.providerId = m.parentPage.providerId
            m.parentPage = invalid
            m.items = []
            loadVodPage()
        else if m.shelf <> "catalog"
            m.shelf = "catalog"
            m.category = ""
            m.pageNumber = 1
            m.index = 0
            loadVodPage()
        else
            m.top.exitRequested = true
        end if
        return true
    else if key = "options"
        openVodOptions()
        return true
    end if
    if m.task <> invalid or m.tmdbTask <> invalid then return true
    if key = "fastforward" and m.hasNext
        m.pageNumber++
        m.index = 0
        loadVodPage()
    else if key = "rewind" and m.pageNumber > 1
        m.pageNumber--
        m.index = 0
        loadVodPage()
    else if key = "OK" and m.items.count() > 0
        if m.shelf = "people"
            enterDiscovery("person", m.discoveryAnchor, m.items[m.index].id)
        else if m.shelf = "versions"
            m.relationId = m.items[m.index].id
            itemId = m.versionItem.id
            m.versionFor = itemId
            restoreVersionPage()
            loadVodPage(itemId)
        else if m.shelf = "categories" or m.shelf = "providers"
            categoryType = "movie"
            if m.kind <> "movie" then categoryType = "series"
            if m.kind = "episode"
                m.kind = "series"
                m.seriesId = ""
                m.parentPage = invalid
            end if
            if m.shelf = "categories" then m.category = m.items[m.index].value + "|" + categoryType else m.providerId = m.items[m.index].id
            m.shelf = "catalog"
            m.pageNumber = 1
            m.index = 0
            loadVodPage()
        else
            if m.shelf <> "catalog" then m.kind = m.items[m.index].kind
            loadVodPage(m.items[m.index].id)
        end if
    else
        change = 0
        if key = "left" then change = -1
        if key = "right" then change = 1
        if key = "up" then change = -5
        if key = "down" then change = 5
        target = m.index + change
        if target >= 0 and target < m.items.count() then m.index = target
        drawVod()
    end if
    return true
end function

function libraryStatus() as object
    language = "unknown"
    if m.detail <> invalid then language = descriptionLanguage(m.detail.description)
    return {kind: m.kind, shelf: m.shelf, page: m.pageNumber, index: m.index, loaded: m.items.count(), total: m.total, loading: m.task <> invalid or m.tmdbTask <> invalid, failure: m.failure, descriptionLanguage: language, descriptionPending: m.descriptionTask <> invalid, tmdbPending: m.tmdbTask <> invalid}
end function

function handleLibraryKey(key as string, press as boolean) as boolean
    return onKeyEvent(key, press)
end function

sub saveLibraryBookmark()
    if m.top.config = invalid or m.shelf <> "catalog" or m.kind = "episode" then return
    m.top.bookmark = {scope: m.top.config.accountScope, kind: m.kind, query: m.query, category: m.category, providerId: m.providerId, ordering: m.ordering, page: m.pageNumber, index: m.index}
end sub

sub updateLibraryTabs()
    if m.primaryNavigation = invalid or m.libraryNavigation = invalid then return
    permissions = m.top.permissions
    movies = false
    series = false
    if type(permissions) = "roAssociativeArray"
        movies = permissions.movies = "allowed"
        series = permissions.series = "allowed"
    end if
    primary = [{id: "live", label: "Live TV", enabled: true}, {id: "vod", label: "VOD", enabled: movies or series}]
    libraries = [{id: "movie", label: "Movies", enabled: movies}, {id: "series", label: "TV Shows", enabled: series}]
    for each destination in [{id: "continue", label: "Continue"}, {id: "watchlist", label: "Watchlist"}, {id: "hidden", label: "Hidden"}, {id: "categories", label: "Categories"}]
        destination.enabled = movies or series
        libraries.push(destination)
    end for
    if FormatJson(m.primaryNavigation.items) <> FormatJson(primary) then m.primaryNavigation.items = primary
    if FormatJson(m.libraryNavigation.items) <> FormatJson(libraries) then m.libraryNavigation.items = libraries
end sub

sub onLibraryPrimarySelection(event as object)
    if event.getData() = "live" then m.top.exitRequested = true else m.libraryNavigation.active = true
end sub

sub onLibraryPrimaryExit(event as object)
    if event.getData() = "down" then m.libraryNavigation.active = true else m.top.setFocus(true)
end sub

sub onLibraryTabSelection(event as object)
    selected = event.getData()
    if selected = "continue" or selected = "watchlist" or selected = "hidden" or selected = "categories"
        saveLibraryBookmark()
        dismissVodDialog()
        m.shelf = selected
        m.pageNumber = 1
        m.index = 0
        if selected = "categories" and m.kind = "episode"
            m.kind = "series"
            m.seriesId = ""
        end if
        loadVodPage()
        m.top.setFocus(true)
        return
    end if
    if selected = m.kind and m.shelf = "catalog" and m.seriesId = ""
        m.top.setFocus(true)
    else
        saveLibraryBookmark()
        m.top.destination = selected
    end if
end sub

sub onLibraryTabExit(event as object)
    if event.getData() = "up" then m.primaryNavigation.active = true else m.top.setFocus(true)
end sub

sub restoreVersionPage()
    m.items = m.versionReturn.items
    m.index = m.versionReturn.index
    m.pageNumber = m.versionReturn.page
    m.shelf = m.versionReturn.shelf
    m.total = m.versionReturn.total
    m.hasNext = m.versionReturn.hasNext
    m.versionReturn = invalid
    drawVod()
end sub

sub closeVodLink(event as object)
    if not isCurrentTaskEvent(event, m.dialog) then return
    m.dialog.close = true
end sub
