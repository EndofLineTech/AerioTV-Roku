' Optional enrichment and bounded discovery; runs in VodView component scope.
sub cancelTmdb()
    if m.tmdbTask <> invalid
        m.tmdbTask.unobserveField("result")
        cancelNetworkTask(m.tmdbTask)
        m.tmdbTask = invalid
    end if
    m.tmdbDialog = invalid
end sub

function createTmdbTask(operation as string, item as object) as object
    task = CreateObject("roSGNode", "TmdbTask")
    task.baseUrl = m.top.config.baseUrl
    task.apiKey = m.top.config.apiKey
    task.accountId = m.top.config.accountId
    task.tmdbKey = textValue(m.top.config.tmdbKey)
    task.enabled = m.top.config.tmdbEnabled = true
    task.item = item
    task.operation = operation
    task.pageNumber = m.pageNumber
    task.personId = textValue(m.discoveryPerson)
    task.savedState = m.top.savedState
    task.cacheEpoch = m.global.cacheEpoch
    task.observeField("result", "onTmdbLoaded")
    return task
end function

sub beginTmdb()
    cancelTmdb()
    if m.top.config.tmdbEnabled <> true then return
    if textValue(m.top.config.tmdbKey) = ""
        m.tmdbNotice = "TMDB key not configured. Save it in Guide settings > Optional TMDB artwork fallback."
        renderDetailDescription()
        return
    end if
    m.tmdbNotice = "Loading optional TMDB metadata... Playback remains available."
    renderDetailDescription()
    m.tmdbDialog = m.dialog
    m.tmdbTask = createTmdbTask("details", m.detail)
    m.tmdbTask.control = "RUN"
end sub

sub onTmdbLoaded(event as object)
    if not isCurrentTaskEvent(event, m.tmdbTask) then return
    result = event.getData()
    operation = m.tmdbTask.operation
    dialog = m.tmdbDialog
    cancelTmdb()
    if not m.top.active then return
    if operation = "details"
        if dialog = invalid or m.dialog = invalid or m.detail = invalid then return
        if not dialog.isSameNode(m.dialog) or result.key <> m.detail.key then return
        m.tmdbNotice = "TMDB metadata unavailable; provider information remains usable."
        if result.ok
            m.detail = vodMergeTmdb(m.detail, result.metadata)
            m.tmdbNotice = "Includes TMDB metadata (English requested)."
            if descriptionLanguage(m.detail.description) = "en" then m.descriptionNotice = ""
        end if
        renderDetailDescription()
        return
    end if
    if not result.ok
        m.failure = textValue(result.message) + "  * > Refresh to retry."
        drawVod()
        return
    end if
    m.items = result.items
    m.total = result.total
    m.hasNext = result.next <> ""
    m.discoveryMessage = textValue(result.message)
    if m.index >= m.items.count() then m.index = 0
    drawVod()
end sub

sub enterDiscovery(kind as string, anchor as object, personId = "" as string)
    if m.discoveryStack.count() >= 4
        m.failure = "Discovery is limited to four nested pages. Back returns to the parent."
        drawVod()
        return
    end if
    m.discoveryStack.push({kind: m.kind, shelf: m.shelf, page: m.pageNumber, index: m.index, query: m.query, category: m.category, providerId: m.providerId, seriesId: m.seriesId, parentPage: m.parentPage, anchor: m.discoveryAnchor, person: m.discoveryPerson})
    m.discoveryAnchor = anchor
    m.discoveryPerson = personId
    m.shelf = kind
    m.pageNumber = 1
    m.index = 0
    loadDiscovery()
end sub

sub restoreDiscovery()
    old = m.discoveryStack.pop()
    m.kind = old.kind
    m.shelf = old.shelf
    m.pageNumber = old.page
    m.index = old.index
    m.query = old.query
    m.category = old.category
    m.providerId = old.providerId
    m.seriesId = old.seriesId
    m.parentPage = old.parentPage
    m.discoveryAnchor = old.anchor
    m.discoveryPerson = old.person
    m.discoveryMessage = ""
    loadVodPage()
end sub

sub loadDiscovery()
    cancelVod()
    m.items = []
    m.failure = ""
    m.discoveryMessage = ""
    m.status.text = "Matching optional TMDB discovery to your permitted catalog... Back cancels."
    m.tmdbTask = createTmdbTask(m.shelf, m.discoveryAnchor)
    m.tmdbTask.control = "RUN"
end sub

sub openFullSynopsis()
    text = textValue(m.detail.description)
    if text = "" then text = "No synopsis is currently available."
    pages = int((len(text) + 899) / 900)
    if m.synopsisPage >= pages then m.synopsisPage = pages - 1
    if m.synopsisPage < 0 then m.synopsisPage = 0
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = m.detail.title + " — synopsis " + (m.synopsisPage + 1).toStr() + "/" + pages.toStr()
    dialog.message = mid(text, m.synopsisPage * 900 + 1, 900)
    buttons = []
    m.synopsisActions = []
    if m.synopsisPage + 1 < pages then buttons.push("Next") : m.synopsisActions.push("next")
    if m.synopsisPage > 0 then buttons.push("Previous") : m.synopsisActions.push("previous")
    buttons.push("Close") : m.synopsisActions.push("close")
    dialog.buttons = buttons
    dialog.observeField("buttonSelected", "onSynopsisAction")
    dialog.observeField("wasClosed", "onVodDialogClosed")
    m.dialog = dialog
    m.top.getScene().dialog = dialog
end sub

sub onSynopsisAction(event as object)
    if not isCurrentTaskEvent(event, m.dialog) then return
    index = event.getData()
    if index < 0 or index >= m.synopsisActions.count() then return
    action = m.synopsisActions[index]
    dismissVodDialog()
    if action = "close" then return
    if action = "next" then m.synopsisPage++ else m.synopsisPage--
    openFullSynopsis()
end sub
