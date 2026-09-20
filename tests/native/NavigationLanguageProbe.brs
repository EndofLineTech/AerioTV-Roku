' Native UI fixture: temporarily import in AerioScene and call its installer.
' No playback; restore browse preferences and remove hooks after validation.
sub installNavigationLanguageProbe()
    m.navProbeStage = 0
    m.navProbeTicks = 0
    m.navProbeTimer = m.top.createChild("Timer")
    m.navProbeTimer.duration = 1
    m.navProbeTimer.repeat = true
    m.navProbeTimer.observeField("fire", "navigationLanguageTick")
    m.navProbeTimer.control = "start"
end sub

sub navigationLanguageTick()
    m.navProbeTicks++
    if m.navProbeTicks > 90
        print "[nav-language] timeout stage="; m.navProbeStage
        m.navProbeTimer.control = "stop"
        return
    end if
    if m.navProbeStage = 0
        if m.capabilities.series <> "allowed" or m.capabilities.movies <> "allowed" then return
        m.navSavedBrowse = invalid
        if type(m.accountPreferences.vodBrowse) = "roAssociativeArray" then m.navSavedBrowse = copyJson(m.accountPreferences.vodBrowse)
        m.guide.callFunc("focusPrimaryNavigation")
        nav = m.guide.findNode("primaryNavigation")
        print "[nav-language] guide-header-focus="; nav.isInFocusChain()
        nav.callFunc("handleNavigationKey", "right", true)
        nav.callFunc("handleNavigationKey", "OK", true)
        m.navProbeStage = 1
    else if m.navProbeStage = 1
        if m.page <> "library" then return
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[nav-language] vod-entered="; status.kind; " loaded="; status.loaded
        tabs = m.vod.findNode("libraryNavigation")
        tabs.active = true
        tabs.callFunc("handleNavigationKey", "right", true)
        tabs.callFunc("handleNavigationKey", "OK", true)
        m.navProbeStage = 2
    else if m.navProbeStage = 2
        status = m.vod.callFunc("libraryStatus")
        if status.kind <> "series" or status.loading then return
        print "[nav-language] tv-tab="; status.kind
        config = m.vod.config
        config.bookmark = {query: "Deep Space Nine", page: 1, index: 0, ordering: "name"}
        m.vod.config = config
        m.navProbeStage = 3
    else if m.navProbeStage = 3
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        m.vod.callFunc("handleLibraryKey", "OK", true)
        m.navProbeStage = 4
    else if m.navProbeStage = 4
        status = m.vod.callFunc("libraryStatus")
        if status.loading or m.top.dialog = invalid then return
        m.navProbeDialog = m.top.dialog
        m.navProbeButtons = m.top.dialog.buttons.count()
        m.navProbeStage = 5
    else if m.navProbeStage = 5
        status = m.vod.callFunc("libraryStatus")
        if status.descriptionPending then return
        print "[nav-language] language="; status.descriptionLanguage; " same-dialog="; m.top.dialog.isSameNode(m.navProbeDialog); " same-buttons="; m.top.dialog.buttons.count() = m.navProbeButtons
        m.top.dialog.buttonSelected = m.top.dialog.buttons.count() - 1
        m.navProbeStage = 6
    else if m.navProbeStage = 6
        print "[nav-language] detail-return-focus="; m.vod.isInFocusChain()
        primary = m.vod.findNode("primaryNavigation")
        primary.active = true
        primary.callFunc("handleNavigationKey", "left", true)
        primary.callFunc("handleNavigationKey", "OK", true)
        m.navProbeStage = 7
    else if m.navProbeStage = 7
        if m.page <> "guide" then return
        print "[nav-language] live-return-focus="; m.guide.isInFocusChain()
        m.accountPreferences.vodBrowse = m.navSavedBrowse
        persistAccountPreferences()
        openVodLibrary("movie")
        m.navProbeStage = 8
    else if m.navProbeStage = 8
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        m.navProbeTimer.control = "stop"
        print "[nav-language] complete"
    end if
end sub
