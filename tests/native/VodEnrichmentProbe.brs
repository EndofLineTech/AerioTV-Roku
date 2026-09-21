' Native-only Scene fixture. Uses registry key; never logs credentials.
sub installVodEnrichmentProbe()
    m.enrichmentStage = 0
    m.enrichmentTicks = 0
    m.enrichmentTimer = m.top.createChild("Timer")
    m.enrichmentTimer.duration = 1
    m.enrichmentTimer.repeat = true
    m.enrichmentTimer.observeField("fire", "vodEnrichmentTick")
    m.enrichmentTimer.control = "start"
end sub

sub vodEnrichmentTick()
    m.enrichmentTicks++
    if m.enrichmentTicks > 180
        print "[vod-enrichment] timeout stage="; m.enrichmentStage
        m.enrichmentTimer.control = "stop"
        return
    end if
    if m.enrichmentStage = 0
        if m.page <> "guide" or m.capabilities.movies <> "allowed" then return
        print "[vod-enrichment] configured-key="; len(m.registry.read("tmdbApiKey")) = 32
        m.accountPreferences.vodTmdbEnabled = true ' PO explicitly authorized it.
        persistAccountPreferences()
        m.enrichmentBrowse = m.accountPreferences.vodBrowse
        m.enrichmentSavedVod = vodState(m.accountPreferences.vod)
        kind = CreateObject("roAppInfo").getValue("vod_enrichment_kind")
        if kind = "" then kind = "movie"
        query = CreateObject("roAppInfo").getValue("vod_enrichment_query")
        if query = "" then query = "The Matrix"
        openVodLibrary(kind)
        config = m.vod.config
        config.bookmark = {query: query, category: "", providerId: "", ordering: "name", page: 1, index: 0}
        m.vod.config = config
        m.enrichmentStage = 1
    else if m.enrichmentStage = 1
        state = m.vod.callFunc("libraryStatus")
        if state.loading then return
        if m.vod.callFunc("probeOpenMatch") then m.enrichmentStage = 2
    else if m.enrichmentStage = 2
        state = m.vod.callFunc("probeDetailSnapshot")
        if not state.open or state.tmdbPending or state.descriptionPending then return
        print "[vod-enrichment] detail="; FormatJson(state)
        if CreateObject("roAppInfo").getValue("vod_enrichment_kind") = "series"
            m.vod.callFunc("probeDetailAction", "episodes")
            m.enrichmentStage = 20
            return
        end if
        m.vod.callFunc("probeDetailAction", "people")
        m.enrichmentStage = 3
    else if m.enrichmentStage = 3
        state = m.vod.callFunc("libraryStatus")
        if state.loading then return
        print "[vod-enrichment] people="; state.loaded; " failure="; state.failure
        if state.loaded = 0
            m.enrichmentTimer.control = "stop"
            return
        end if
        m.vod.callFunc("handleLibraryKey", "OK", true)
        m.enrichmentStage = 4
    else if m.enrichmentStage = 4
        state = m.vod.callFunc("libraryStatus")
        if state.loading then return
        print "[vod-enrichment] person-matches="; state.loaded; " failure="; state.failure
        m.vod.callFunc("handleLibraryKey", "back", true)
        m.enrichmentStage = 5
    else if m.enrichmentStage = 5
        state = m.vod.callFunc("libraryStatus")
        if state.loading then return
        print "[vod-enrichment] back-people="; state.shelf = "people"
        m.vod.callFunc("handleLibraryKey", "back", true)
        m.enrichmentStage = 6
    else if m.enrichmentStage = 6
        state = m.vod.callFunc("libraryStatus")
        if state.loading then return
        if m.vod.callFunc("probeOpenMatch") then m.enrichmentStage = 7
    else if m.enrichmentStage = 7
        state = m.vod.callFunc("probeDetailSnapshot")
        if not state.open or state.tmdbPending then return
        m.vod.callFunc("probeDetailAction", "related")
        m.enrichmentStage = 8
    else if m.enrichmentStage = 8
        state = m.vod.callFunc("libraryStatus")
        if state.loading then return
        print "[vod-enrichment] related-matches="; state.loaded; " failure="; state.failure
        m.vod.callFunc("handleLibraryKey", "back", true)
        m.enrichmentStage = 9
    else if m.enrichmentStage = 9
        state = m.vod.callFunc("libraryStatus")
        if state.loading then return
        if m.vod.callFunc("probeOpenMatch") then m.enrichmentStage = 10
    else if m.enrichmentStage = 10
        state = m.vod.callFunc("probeDetailSnapshot")
        if not state.open or state.tmdbPending or state.descriptionPending then return
        m.vod.callFunc("probeDetailAction", "versions")
        m.enrichmentStage = 28
    else if m.enrichmentStage = 28
        if m.vod.callFunc("probeChooseProvider19") then m.enrichmentStage = 29
    else if m.enrichmentStage = 29
        state = m.vod.callFunc("probeDetailSnapshot")
        if not state.open or state.tmdbPending or state.descriptionPending then return
        m.vod.callFunc("probeSeedResume")
        m.enrichmentStage = 30
    else if m.enrichmentStage = 30
        state = m.vod.callFunc("probeDetailSnapshot")
        if not state.open or state.tmdbPending or state.descriptionPending then return
        print "[vod-enrichment] resume-action="; m.vod.callFunc("probeDetailAction", "resume")
        m.enrichmentStage = 31
    else if m.enrichmentStage = 31
        video = m.mediaPlayer.findNode("mediaVideo")
        if m.enrichmentTicks mod 5 = 0 then print "[vod-enrichment] waiting page="; m.page; " state="; video.state; " position="; video.position; " duration="; video.duration; " code="; video.errorCode
        if video.errorCode <> 0
            print "[vod-enrichment] playback-failure="; FormatJson(m.mediaPlayer.diagnostic)
            m.mediaPlayer.callFunc("closeMedia")
            m.enrichmentStage = 34
            return
        end if
        if video.state <> "playing" or video.position < 100 then return
        print "[vod-enrichment] resumed position="; video.position; " duration="; video.duration; " playbackSpeed="; video.hasField("playbackSpeed"); " playbackRate="; video.hasField("playbackRate")
        m.rateStart = video.position
        m.rateClock = CreateObject("roTimespan")
        m.rateClock.mark()
        m.enrichmentStage = 32
    else if m.enrichmentStage = 32
        if m.rateClock.totalMilliseconds() < 12000 then return
        video = m.mediaPlayer.findNode("mediaVideo")
        print "[vod-enrichment] normal seconds="; m.rateClock.totalMilliseconds() / 1000.0; " delta="; video.position - m.rateStart; " av="; FormatJson(video.positionInfo)
        if video.hasField("playbackSpeed")
            video.control = "pause"
            video.playbackSpeed = 1.5
            video.control = "resume"
            m.rateStart = video.position
            m.rateClock.mark()
            m.enrichmentStage = 33
        else
            m.mediaPlayer.callFunc("closeMedia")
            m.enrichmentStage = 34
        end if
    else if m.enrichmentStage = 33
        if m.rateClock.totalMilliseconds() < 12000 then return
        video = m.mediaPlayer.findNode("mediaVideo")
        print "[vod-enrichment] requested1.5 speed="; video.playbackSpeed; " seconds="; m.rateClock.totalMilliseconds() / 1000.0; " delta="; video.position - m.rateStart; " av="; FormatJson(video.positionInfo)
        m.rateStart = video.position
        m.rateClock.mark()
        m.enrichmentStage = 36
    else if m.enrichmentStage = 36
        if m.rateClock.totalMilliseconds() < 12000 then return
        video = m.mediaPlayer.findNode("mediaVideo")
        print "[vod-enrichment] stable1.5 speed="; video.playbackSpeed; " seconds="; m.rateClock.totalMilliseconds() / 1000.0; " delta="; video.position - m.rateStart; " av="; FormatJson(video.positionInfo)
        video.control = "pause"
        video.playbackSpeed = 1.0
        video.control = "resume"
        m.mediaPlayer.callFunc("closeMedia")
        m.enrichmentStage = 34
    else if m.enrichmentStage = 34
        closeVodLibrary()
        m.guide.playerRequest = "searchMovies"
        m.enrichmentStage = 35
    else if m.enrichmentStage = 35
        if m.page <> "library" then return
        print "[vod-enrichment] global-search="; m.top.dialog.subtype(); " tabs="; m.vod.findNode("libraryNavigation").items.count()
        m.top.dialog.buttonSelected = 1
        m.accountPreferences.vod = m.enrichmentSavedVod
        m.accountPreferences.vodBrowse = m.enrichmentBrowse
        persistAccountPreferences()
        m.vod.savedState = m.enrichmentSavedVod
        m.enrichmentTimer.control = "stop"
        print "[vod-enrichment] complete"
    else if m.enrichmentStage = 20
        state = m.vod.callFunc("libraryStatus")
        if state.loading then return
        print "[vod-enrichment] episodes="; state.loaded
        m.vod.callFunc("handleLibraryKey", "OK", true)
        m.enrichmentStage = 21
    else if m.enrichmentStage = 21
        state = m.vod.callFunc("probeDetailSnapshot")
        if not state.open or state.tmdbPending or state.descriptionPending then return
        print "[vod-enrichment] episode-detail="; FormatJson(state)
        m.vod.callFunc("probeShelf", "watchlist")
        m.enrichmentStage = 22
    else if m.enrichmentStage = 22
        state = m.vod.callFunc("probeShelfSnapshot")
        if state.loading then return
        print "[vod-enrichment] watchlist="; FormatJson(state)
        m.vod.callFunc("probeShelf", "continue")
        m.enrichmentStage = 23
    else if m.enrichmentStage = 23
        state = m.vod.callFunc("probeShelfSnapshot")
        if state.loading then return
        print "[vod-enrichment] continue="; FormatJson(state)
        m.accountPreferences.vodBrowse = m.enrichmentBrowse
        persistAccountPreferences()
        m.enrichmentTimer.control = "stop"
        print "[vod-enrichment] complete"
    end if
end sub
