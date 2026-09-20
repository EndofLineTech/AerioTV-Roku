sub init()
    m.top.focusable = true
    m.task = invalid
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
    uiRect(m.top, 0, 0, 1920, 1080, "0x0A1628FF")
    m.heading = uiLabel(m.top, "Movies", 96, 55, 1728, 64, 42)
    m.status = uiLabel(m.top, "", 96, 127, 1728, 40, 24, "0x9EB5C9FF")
    for i = 0 to 19
        x = 96 + (i mod 5) * 348
        y = 195 + (i \ 5) * 181
        border = uiRect(m.top, x, y, 336, 170, "0x17344AFF")
        poster = m.top.createChild("Poster")
        poster.translation = [x + 8, y + 8]
        poster.width = 104
        poster.height = 154
        poster.loadWidth = 104
        poster.loadHeight = 154
        poster.loadDisplayMode = "scaleToFit"
        title = uiLabel(m.top, "", x + 122, y + 16, 203, 103, 24)
        title.wrap = true
        title.maxLines = 3
        fact = uiLabel(m.top, "", x + 122, y + 122, 203, 30, 19, "0x9EB5C9FF")
        m.tiles.push({border: border, poster: poster, title: title, fact: fact})
    end for
    uiLabel(m.top, "Arrows  Browse    OK  Details    *  Search / library / sort    FF / Rew  Pages    Back  Return", 96, 990, 1728, 40, 24, "0x9EB5C9FF")
end sub

sub configureVod()
    cancelVod()
    if m.dialog <> invalid
        m.dialog.close = true
        m.dialog = invalid
    end if
    m.items = []
    m.detail = invalid
    for each tile in m.tiles
        tile.poster.uri = ""
        tile.title.text = ""
    end for
    if m.top.config = invalid then return
    m.kind = m.top.config.kind
    m.pageNumber = 1
    m.index = 0
    m.query = ""
    m.category = ""
    m.providerId = ""
    m.seriesId = ""
    m.items = []
    m.ordering = "name"
    m.parentPage = invalid
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
        cancelVod()
    end if
end sub

sub cancelVod()
    if m.task <> invalid
        m.task.unobserveField("result")
        cancelNetworkTask(m.task)
        m.task = invalid
    end if
end sub

sub loadVodPage(itemId = "" as string)
    cancelVod()
    m.failure = ""
    if itemId = ""
        m.items = []
    end if
    m.status.text = "Loading... Back cancels."
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
    m.task.ordering = m.ordering
    m.task.cacheEpoch = m.global.cacheEpoch
    m.task.bypassCache = m.bypassCache
    m.bypassCache = false
    if m.shelf <> "catalog" and m.shelf <> "categories" and m.shelf <> "providers" and itemId = "" then m.task.operation = "authorize"
    if m.shelf = "categories" then m.task.operation = "categories"
    if m.shelf = "providers" then m.task.operation = "providers"
    m.task.observeField("result", "onVodLoaded")
    m.task.control = "RUN"
end sub

sub onVodLoaded(event as object)
    if not isCurrentTaskEvent(event, m.task) then return
    result = event.getData()
    detail = m.task.itemId <> ""
    m.task.unobserveField("result")
    m.task = invalid
    if not result.ok
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
    if result.authorizedShelf = true
        for each entry in vodShelfEntries(m.top.savedState, m.shelf, result)
            m.items.push(vodNormalize({id: entry.id, uuid: entry.uuid, name: entry.title}, entry.kind))
        end for
        m.total = m.items.count()
        m.hasNext = false
        if m.index >= m.items.count() then m.index = 0
        drawVod()
        return
    end if
    if detail
        m.detail = result.item
        dialog = CreateObject("roSGNode", "Dialog")
        dialog.title = m.detail.title
        dialog.message = m.detail.year + "  " + m.detail.genre + "  Rating: " + m.detail.rating + chr(10) + left(m.detail.description, 700)
        if m.detail.duration > 0 then dialog.message += chr(10) + (m.detail.duration \ 60).toStr() + " min"
        if m.detail.airDate <> "" then dialog.message += "  " + m.detail.airDate
        if m.detail.actors <> "" then dialog.message += chr(10) + "Cast: " + left(m.detail.actors, 180)
        if m.detail.director <> "" then dialog.message += chr(10) + "Director: " + m.detail.director
        entry = vodStateEntry(m.top.savedState, m.detail)
        menu = vodDetailMenu(m.detail, entry)
        m.detailActions = menu.actions
        dialog.buttons = menu.buttons
        dialog.observeField("buttonSelected", "onVodDetailAction")
        dialog.observeField("wasClosed", "onVodDialogClosed")
        m.dialog = dialog
        m.top.getScene().dialog = dialog
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
    m.heading.text = "Movies"
    if m.kind = "series" then m.heading.text = "TV Shows"
    if m.kind = "episode" then m.heading.text = "Episodes"
    if m.shelf <> "catalog" then m.heading.text = "Library — " + m.shelf
    if m.query <> "" then m.heading.text += " — " + m.query
    if m.category <> "" and m.shelf = "catalog" then m.heading.text += " — " + m.category
    if m.providerId <> "" and m.shelf = "catalog" then m.heading.text += " — Provider " + m.providerId
    if m.task = invalid
        m.status.text = "Page " + m.pageNumber.toStr() + "  |  " + m.items.count().toStr() + " titles loaded"
        if m.total <> invalid then m.status.text += " of " + m.total.toStr()
        if m.items.count() = 0 then m.status.text = "No available titles match this account and search."
        if m.items.count() = 0 and m.hasNext = true then m.status.text = "Nothing visible on this page. FF loads the next page."
    end if
    if m.failure <> "" then m.status.text = m.failure
    for i = 0 to 19
        tile = m.tiles[i]
        tile.border.visible = i < m.items.count()
        tile.poster.visible = i < m.items.count()
        tile.title.visible = i < m.items.count()
        tile.fact.visible = i < m.items.count()
        if i < m.items.count()
            item = m.items[i]
            tile.border.color = "0x17344AFF"
            if i = m.index then tile.border.color = "0x146779FF"
            tile.title.text = item.title
            tile.fact.text = item.year + "  " + item.rating
            if m.kind = "episode" then tile.fact.text = "S" + item.season + " E" + item.episode
            uri = ""
            if item.logoId <> "" then uri = m.top.config.baseUrl + "/api/vod/vodlogos/" + item.logoId + "/cache/"
            if tile.poster.uri <> uri then tile.poster.uri = uri
        else
            tile.poster.uri = ""
        end if
    end for
end sub

sub onVodDetailAction(event as object)
    if not isCurrentTaskEvent(event, m.dialog) then return
    event.getRoSGNode().close = true
    choice = event.getData()
    if choice < 0 or choice >= m.detailActions.count() then return
    action = m.detailActions[choice]
    if action = "back" then return
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
        m.parentPage = {page: m.pageNumber, index: m.index, query: m.query}
        m.seriesId = m.detail.id
        m.kind = "episode"
        m.pageNumber = 1
        m.index = 0
        m.query = ""
        m.shelf = "catalog"
        m.items = []
        loadVodPage()
    else
        saveLibraryBookmark()
        m.detail.resume = 0
        if action = "resume" then m.detail.resume = vodResumePosition(entry, m.detail.duration)
        if action = "mp4" then m.detail.streamFormat = "mp4"
        if action = "mkv" then m.detail.streamFormat = "mkv"
        if action <> "resume" then m.top.stateChange = {scope: m.detail.accountScope, item: m.detail, patch: {position: 0, watched: false}}
        m.top.playRequested = m.detail
    end if
end sub

sub onVodDialogClosed(event as object)
    if not isCurrentTaskEvent(event, m.dialog) then return
    ' Native Dialog.wasClosed is a signal; its event payload can be invalid.
    if m.top.active then m.top.setFocus(true)
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

sub onVodOption(event as object)
    if not isCurrentTaskEvent(event, m.dialog) then return
    event.getRoSGNode().close = true
    choice = event.getData()
    if choice < 0 or choice >= m.optionCodes.count() then return
    choice = m.optionCodes[choice]
    if choice = 4 then m.bypassCache = true
    if choice = 0
        dialog = CreateObject("roSGNode", "KeyboardDialog")
        dialog.title = "Search permitted library"
        dialog.text = m.query
        dialog.buttons = ["Search", "Cancel"]
        dialog.observeField("buttonSelected", "onVodSearch")
        dialog.observeField("wasClosed", "onVodDialogClosed")
        m.dialog = dialog
        m.top.getScene().dialog = dialog
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
    if event.getData() = 0
        m.shelf = "catalog"
        m.query = left(event.getRoSGNode().text.trim(), 120)
        m.pageNumber = 1
        m.index = 0
        m.items = []
        loadVodPage()
    end if
    event.getRoSGNode().close = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not m.top.active or not press then return false
    if key = "back"
        saveLibraryBookmark()
        cancelVod()
        if m.kind = "episode" and m.parentPage <> invalid
            m.kind = "series"
            m.seriesId = ""
            m.pageNumber = m.parentPage.page
            m.index = m.parentPage.index
            m.query = m.parentPage.query
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
    if m.task <> invalid then return true
    if key = "fastforward" and m.hasNext
        m.pageNumber++
        m.index = 0
        loadVodPage()
    else if key = "rewind" and m.pageNumber > 1
        m.pageNumber--
        m.index = 0
        loadVodPage()
    else if key = "OK" and m.items.count() > 0
        if m.shelf = "categories" or m.shelf = "providers"
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
    return {kind: m.kind, shelf: m.shelf, page: m.pageNumber, index: m.index, loaded: m.items.count(), total: m.total, loading: m.task <> invalid, failure: m.failure}
end function

function handleLibraryKey(key as string, press as boolean) as boolean
    return onKeyEvent(key, press)
end function

sub saveLibraryBookmark()
    if m.top.config = invalid or m.shelf <> "catalog" or m.kind = "episode" then return
    m.top.bookmark = {scope: m.top.config.accountScope, kind: m.kind, query: m.query, category: m.category, providerId: m.providerId, ordering: m.ordering, page: m.pageNumber, index: m.index}
end sub

sub closeVodLink(event as object)
    if not isCurrentTaskEvent(event, m.dialog) then return
    m.dialog.close = true
end sub
