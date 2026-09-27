sub main()
    m.top = {active: true, config: {scope: "selected-account", accountId: "42"}, vodEnabled: true, moviesPermission: "allowed", seriesPermission: "allowed", searchVodSelection: invalid, setFocus: sub(value as boolean)
    end sub}
    m.providerType = "dispatcharr"
    m.programSearchAccount = "42"
    m.programSearchConnectionScope = "selected-account"
    m.programSearchScope = "all"
    m.programSearchField = "title"
    m.programQuery = "blue"
    m.programSearchPage = 1
    m.searchView = {active: true, model: invalid, setFocus: sub(value as boolean)
    end sub}
    m.searchResults = {epg: [], movie: [], series: []}
    m.searchHasNext = {epg: false, movie: false, series: false}
    m.searchErrors = []
    m.searchTruncated = false
    m.searchPending = 3
    m.searchTask = searchStub("epg")
    m.searchMovieTask = searchStub("movie")
    m.searchSeriesTask = searchStub("series")
    epgRow = {channel: {uuid: "channel-1", number: "1", name: "Allowed"}, program: {id: "7", title: "Blue Bloods", startsAt: 1, endsAt: 2}}
    finishUnifiedEpgSearch(searchEvent("epg", {ok: true, items: [epgRow], hasNext: false, truncated: false}))
    if m.searchView.model <> invalid then stop ' wait for all authorized domains
    finishUnifiedVodSearch(searchEvent("movie", {ok: true, items: [{id: "11", kind: "movie", title: "Blue movie"}], next: "next"}), "movie")
    if m.searchView.model <> invalid then stop
    finishUnifiedVodSearch(searchEvent("series", {ok: true, items: [{id: "12", kind: "series", title: "Blue series"}], next: ""}), "series")
    if m.searchView.model.items.count() <> 3 or not m.searchView.model.hasNext then stop
    if m.searchView.model.items[0].program.id <> "7" then stop
    if m.searchView.model.items[1].vod.id <> "11" then stop
    if m.searchView.model.items[2].vod.id <> "12" then stop

    onProgramSearchSelection(searchEvent("player", m.searchView.model.items[1]))
    if m.top.searchVodSelection.id <> "11" or m.top.searchVodSelection.scope <> "selected-account" then stop
    m.top.moviesPermission = "denied"
    m.top.searchVodSelection = invalid
    onProgramSearchSelection(searchEvent("player", m.searchView.model.items[1]))
    if m.top.searchVodSelection <> invalid then stop ' permission changed since results were fetched
    m.top.moviesPermission = "allowed"

    m.searchPending = 2
    m.searchMovieTask = searchStub("movie")
    m.searchSeriesTask = searchStub("series")
    finishUnifiedVodSearch(searchEvent("movie", {ok: false, category: "permission", message: "private"}), "movie")
    if m.searchView.model.items.count() <> 0 then stop ' no partial results after authorization refusal
    if m.searchSeriesTask <> invalid or m.searchPending <> 0 then stop ' cancel in-flight other-domain Task
    if instr(1, m.searchView.model.message, "private") > 0 then stop

    m.searchTask = searchStub("epg")
    m.searchView.model = invalid
    m.top.config.accountId = "another-account"
    finishUnifiedEpgSearch(searchEvent("epg", {ok: true, items: [epgRow], hasNext: false}))
    if m.searchView.model <> invalid then stop ' stale account response ignored
    m.top.searchVodSelection = invalid
    onProgramSearchSelection(searchEvent("player", {vod: {kind: "movie", id: "11"}}))
    if m.top.searchVodSelection <> invalid then stop ' stale result cannot open a different account's detail
    m.top.config.accountId = "42"
    m.searchPending = 2
    m.searchMovieTask = searchStub("movie")
    m.searchTask = searchStub("epg")
    m.searchResults = {epg: [], movie: [], series: []}
    m.searchHasNext = {epg: false, movie: false, series: false}
    m.searchErrors = []
    finishUnifiedEpgSearch(searchEvent("epg", {ok: false, message: "private-url"}))
    finishUnifiedVodSearch(searchEvent("movie", {ok: true, items: [{id: "11", kind: "movie", title: "Blue movie"}], next: ""}), "movie")
    if m.searchView.model.items.count() <> 1 or instr(1, m.searchView.model.message, "EPG") = 0 then stop
    if instr(1, m.searchView.model.message, "private-url") > 0 then stop
    m.programQuery = "x"
    m.programSearchNow = 1000
    m.settings = {historyDays: 3, futureDays: 7}
    m.searchView.model = invalid
    loadUnifiedSearchPage()
    if m.searchTask <> invalid or m.searchMovieTask <> invalid or m.searchSeriesTask <> invalid then stop
    if instr(1, m.searchView.model.message, "two characters") = 0 then stop
    print "ALL TESTS PASSED"
end sub

function searchStub(id as string) as object
    return {id: id, unobserveField: sub(field as string)
    end sub, isSameNode: function(node as object) as boolean
        return node.id = m.id
    end function}
end function

function searchEvent(id as string, data as object) as object
    return {id: id, data: data, getRoSGNode: function() as object
        return {id: m.id}
    end function, getData: function() as object
        return m.data
    end function}
end function
