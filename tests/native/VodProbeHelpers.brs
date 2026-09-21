' Native-only VodView helper; temporarily import/export for fixture validation.
sub probeSeedResume()
    print "[vod-enrichment] rendition item="; m.detail.id; " format="; m.detail.streamFormat; " provider="; m.detail.providerId; " relation="; m.detail.relationId
    m.top.savedState = vodStateUpdate(m.top.savedState, m.detail, {position: 120, duration: 8293, watched: false, hidden: false})
    loadVodPage(m.detail.id)
end sub

function probeChooseProvider19() as boolean
    if m.task <> invalid then return false
    selected = -1
    for i = 0 to m.items.count() - 1
        if m.items[i].providerId = "19" then selected = i
    end for
    if selected >= 0
        m.index = selected
        return handleLibraryKey("OK", true)
    end if
    return false
end function

sub probeShelf(shelf as string)
    if m.shelfFixture = invalid
        m.shelfFixture = vodStateUpdate([], m.detail, {watchlist: true, position: 100, duration: 1000})
        missing = vodNormalize({id: "999999999", uuid: "native-missing-fixture", name: "Deleted fixture"}, "movie")
        missing.authorization = m.detail.authorization
        m.shelfFixture = vodStateUpdate(m.shelfFixture, missing, {watchlist: true, position: 100, duration: 1000})
    end if
    dismissVodDialog()
    m.top.savedState = m.shelfFixture
    m.shelf = shelf
    m.pageNumber = 1
    m.index = 0
    loadVodPage()
end sub

function probeShelfSnapshot() as object
    missing = 0
    for each item in m.items
        if item.unavailable = true then missing++
    end for
    return {count: m.items.count(), missing: missing, loading: m.task <> invalid, failure: m.failure}
end function

function probeOpenMatch() as boolean
    if m.task <> invalid then return false
    wanted = CreateObject("roAppInfo").getValue("vod_enrichment_tmdb")
    if wanted = "" then wanted = "603"
    for i = 0 to m.items.count() - 1
        if m.items[i].tmdbId = wanted
            m.index = i
            loadVodPage(m.items[i].id)
            return true
        end if
    end for
    if m.hasNext and m.pageNumber < 10
        m.pageNumber++
        loadVodPage()
    end if
    return false
end function

function probeDetailSnapshot() as object
    result = {open: false}
    if m.dialog = invalid or m.detail = invalid then return result
    if m.dialog.subtype() <> "VodDetails" then return result
    result = {open: true, tmdbPending: m.tmdbTask <> invalid, descriptionPending: m.descriptionTask <> invalid, language: descriptionLanguage(m.detail.description), characters: len(m.detail.description), tmdb: m.detail.tmdb <> invalid, poster: m.dialog.findNode("poster").loadStatus, attribution: m.dialog.findNode("tmdbLogo").visible, focus: m.dialog.findNode("actions").itemFocused}
    if m.detail.tmdb <> invalid then result.people = m.detail.tmdb.people.count()
    return result
end function

function probeDetailAction(action as string) as boolean
    if m.dialog = invalid then return false
    for i = 0 to m.detailActions.count() - 1
        if m.detailActions[i] = action
            m.dialog.buttonSelected = i
            return true
        end if
    end for
    return false
end function
