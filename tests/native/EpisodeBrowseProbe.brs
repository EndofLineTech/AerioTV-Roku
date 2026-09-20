' Native metadata/UI fixture: temporarily import in AerioScene and call its
' installer from init. No playback; restore browse preferences afterward.
sub installEpisodeBrowseProbe()
    m.episodeProbeStage = 0
    m.episodeProbeTicks = 0
    m.episodeProbeTimer = m.top.createChild("Timer")
    m.episodeProbeTimer.duration = 1
    m.episodeProbeTimer.repeat = true
    m.episodeProbeTimer.observeField("fire", "episodeBrowseTick")
    m.episodeProbeTimer.control = "start"
end sub

sub episodeBrowseTick()
    m.episodeProbeTicks++
    if m.episodeProbeTicks > 90
        print "[episode-browse] timeout stage="; m.episodeProbeStage
        m.episodeProbeTimer.control = "stop"
        return
    end if
    if m.episodeProbeStage = 0
        if m.capabilities.series <> "allowed" then return
        m.episodeProbeSaved = invalid
        if type(m.accountPreferences.vodBrowse) = "roAssociativeArray" then m.episodeProbeSaved = copyJson(m.accountPreferences.vodBrowse)
        openVodLibrary("series")
        config = m.vod.config
        config.bookmark = {query: "Deep Space Nine", page: 1, index: 0, ordering: "name"}
        m.vod.config = config
        m.episodeProbeStage = 1
    else if m.episodeProbeStage = 1
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[episode-browse] series="; FormatJson(status)
        m.vod.callFunc("handleLibraryKey", "OK", true)
        m.episodeProbeStage = 2
    else if m.episodeProbeStage = 2
        status = m.vod.callFunc("libraryStatus")
        if status.loading or m.top.dialog = invalid then return
        for i = 0 to m.top.dialog.buttons.count() - 1
            if m.top.dialog.buttons[i] = "Browse episodes"
                m.top.dialog.buttonSelected = i
                m.episodeProbeStage = 3
                exit for
            end if
        end for
    else if m.episodeProbeStage = 3
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[episode-browse] episodes="; FormatJson(status)
        m.vod.callFunc("handleLibraryKey", "fastforward", true)
        m.episodeProbeStage = 4
    else if m.episodeProbeStage = 4
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[episode-browse] next="; FormatJson(status)
        m.vod.callFunc("handleLibraryKey", "back", true)
        m.episodeProbeStage = 5
    else if m.episodeProbeStage = 5
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[episode-browse] returned="; FormatJson(status); " focus="; m.vod.isInFocusChain()
        closeVodLibrary()
        m.episodeProbeStage = 6
    else if m.episodeProbeStage = 6
        m.accountPreferences.vodBrowse = m.episodeProbeSaved
        persistAccountPreferences()
        m.episodeProbeTimer.control = "stop"
        print "[episode-browse] complete"
    end if
end sub
