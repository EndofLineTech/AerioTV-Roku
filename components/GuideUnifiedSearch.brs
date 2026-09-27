' Bounded fanout reuses the existing EPG and permission-checking VOD Tasks.
sub loadUnifiedSearchPage()
    cancelProgramSearch()
    m.programQuery = left(m.programQuery.trim(), 120)
    m.programSearchAccount = ""
    m.programSearchConnectionScope = ""
    if m.top.config <> invalid
        m.programSearchAccount = textValue(m.top.config.accountId)
        m.programSearchConnectionScope = textValue(m.top.config.scope)
    end if
    m.searchResults = {epg: [], movie: [], series: []}
    m.searchHasNext = {epg: false, movie: false, series: false}
    m.searchErrors = []
    m.searchTruncated = false
    domains = unifiedSearchDomains(m.programSearchScope, m.top.vodEnabled = true and m.top.moviesPermission = "allowed", m.top.vodEnabled = true and m.top.seriesPermission = "allowed")
    if type(m.searchNextDomains) = "roAssociativeArray"
        remaining = []
        for each domain in domains
            if m.searchNextDomains[domain] = true then remaining.push(domain)
        end for
        domains = remaining
    end if
    m.searchNextDomains = invalid
    m.searchPageDomains = domains
    m.searchView.model = {items: [], query: m.programQuery, scope: m.programSearchScope, searchField: ucase(m.programSearchScope), page: m.programSearchPage, hasNext: false, loading: true, message: "Searching permitted EPG and catalogs... Back cancels."}
    m.searchView.active = true
    params = programSearchParameters(m.programQuery, "title", m.programSearchPage, m.programSearchNow, m.settings.historyDays, m.settings.futureDays)
    if params = invalid or domains.count() = 0 or m.providerType <> "dispatcharr" or m.programSearchAccount = ""
        m.searchView.model = {items: [], query: m.programQuery, scope: m.programSearchScope, searchField: ucase(m.programSearchScope), page: m.programSearchPage, hasNext: false, loading: false, message: "Enter at least two characters for an authorized Dispatcharr search."}
        return
    end if
    m.searchPending = domains.count()
    for each domain in domains
        if domain = "epg"
            m.searchTask = CreateObject("roSGNode", "ProgramSearchTask")
            m.searchTask.baseUrl = m.base
            m.searchTask.apiKey = m.key
            m.searchTask.query = m.programQuery
            m.searchTask.searchField = m.programSearchField
            m.searchTask.page = m.programSearchPage
            m.searchTask.now = m.programSearchNow
            m.searchTask.historyDays = m.settings.historyDays
            m.searchTask.futureDays = m.settings.futureDays
            m.searchTask.channels = m.channels
            m.searchTask.observeField("result", "onProgramSearchResult")
            m.searchTask.control = "RUN"
        else
            task = CreateObject("roSGNode", "VodTask")
            task.baseUrl = m.base
            task.apiKey = m.key
            task.accountId = m.programSearchAccount
            task.kind = domain
            task.query = m.programQuery
            task.pageNumber = m.programSearchPage
            task.cacheEpoch = m.global.cacheEpoch
            if domain = "movie"
                m.searchMovieTask = task
                task.observeField("result", "onUnifiedMovieSearchResult")
            else
                m.searchSeriesTask = task
                task.observeField("result", "onUnifiedSeriesSearchResult")
            end if
            task.control = "RUN"
        end if
    end for
end sub

function unifiedSearchCurrent() as boolean
    if not m.top.active or not m.searchView.active or m.top.config = invalid then return false
    return m.programSearchAccount = textValue(m.top.config.accountId) and m.programSearchConnectionScope = textValue(m.top.config.scope)
end function

sub finishUnifiedEpgSearch(event as object)
    if not isCurrentTaskEvent(event, m.searchTask) then return
    result = event.getData()
    m.searchTask.unobserveField("result")
    m.searchTask = invalid
    if not unifiedSearchCurrent() then return
    if type(result) = "roAssociativeArray" and result.ok = true
        m.searchResults.epg = result.items
        m.searchHasNext.epg = result.hasNext = true
        m.searchTruncated = result.truncated = true
    else
        m.searchErrors.push("EPG")
    end if
    finishUnifiedSearchPart()
end sub

sub onUnifiedMovieSearchResult(event as object)
    finishUnifiedVodSearch(event, "movie")
end sub

sub onUnifiedSeriesSearchResult(event as object)
    finishUnifiedVodSearch(event, "series")
end sub

sub finishUnifiedVodSearch(event as object, domain as string)
    task = m.searchMovieTask
    if domain = "series" then task = m.searchSeriesTask
    if not isCurrentTaskEvent(event, task) then return
    result = event.getData()
    task.unobserveField("result")
    if domain = "movie" then m.searchMovieTask = invalid else m.searchSeriesTask = invalid
    if not unifiedSearchCurrent() then return
    if type(result) = "roAssociativeArray" and result.category = "permission"
        cancelProgramSearch()
        m.searchView.model = {items: [], query: m.programQuery, scope: m.programSearchScope, searchField: ucase(m.programSearchScope), page: m.programSearchPage, hasNext: false, loading: false, message: "Account permissions changed. Return to the guide and reconnect."}
        return
    end if
    if type(result) = "roAssociativeArray" and result.ok = true
        m.searchResults[domain] = result.items
        m.searchHasNext[domain] = textValue(result.next) <> ""
    else
        if domain = "movie" then m.searchErrors.push("Movies") else m.searchErrors.push("TV Shows")
    end if
    finishUnifiedSearchPart()
end sub

sub finishUnifiedSearchPart()
    if m.searchPending < 1 then return
    m.searchPending--
    if m.searchPending > 0 then return
    items = unifiedSearchRows(m.searchResults.epg, m.searchResults.movie, m.searchResults.series)
    message = "Server-indexed results within your authorized lineup and catalogs."
    if items.count() = 0 then message = "No matching permitted results on this page. Edit your search or try another page."
    if m.searchErrors.count() > 0
        missing = ""
        for each domain in m.searchErrors
            if missing <> "" then missing += ", "
            missing += domain
        end for
        message = "Some sources unavailable: " + missing + ". Results shown from responding sources."
    end if
    if m.searchTruncated then message += " EPG fanout limited to 200 airings on this page."
    m.searchView.model = {items: items, query: m.programQuery, scope: m.programSearchScope, searchField: ucase(m.programSearchScope), page: m.programSearchPage, hasNext: m.searchHasNext.epg or m.searchHasNext.movie or m.searchHasNext.series, truncated: m.searchTruncated, loading: false, message: message}
end sub

' Guide suspension cancels network Tasks, but a completed result list survives
' the authorized VOD detail detour and resumes at the same selected row.
sub resumeUnifiedSearch()
    if m.top.config = invalid or m.searchView.model = invalid then return
    if m.programSearchAccount <> textValue(m.top.config.accountId) or m.programSearchConnectionScope <> textValue(m.top.config.scope) then return
    if m.providerType <> "dispatcharr" then return
    m.searchView.active = true
    m.searchView.setFocus(true)
end sub
