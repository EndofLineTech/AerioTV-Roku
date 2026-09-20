' Native UI smoke fixture: temporarily copy to components, import in
' AerioScene.xml and call installLibrarySmoke from init. Remove all hooks
' before normal installation. No playback or credential export is performed.
sub installLibrarySmoke()
    m.librarySmokeStep = 0
    m.librarySmokeTicks = 0
    m.librarySmokeTimer = m.top.createChild("Timer")
    m.librarySmokeTimer.duration = 1
    m.librarySmokeTimer.repeat = true
    m.librarySmokeTimer.observeField("fire", "librarySmokeTick")
    m.librarySmokeTimer.control = "start"
end sub

sub librarySmokeTick()
    m.librarySmokeTicks++
    if m.librarySmokeTicks > 90
        print "[library-smoke] timeout stage="; m.librarySmokeStep
        m.librarySmokeTimer.control = "stop"
        return
    end if
    if m.librarySmokeStep = 0
        if m.capabilities.movies <> "allowed" then return
        m.librarySmokeSavedBrowse = invalid
        if type(m.accountPreferences.vodBrowse) = "roAssociativeArray" then m.librarySmokeSavedBrowse = copyJson(m.accountPreferences.vodBrowse)
        openVodLibrary("movie")
        m.librarySmokeStep = 1
    else if m.librarySmokeStep = 1
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[library-smoke] first="; FormatJson(status)
        m.vod.callFunc("handleLibraryKey", "right", true)
        m.vod.callFunc("handleLibraryKey", "down", true)
        print "[library-smoke] focus="; m.vod.callFunc("libraryStatus").index
        m.vod.callFunc("handleLibraryKey", "OK", true)
        m.librarySmokeStep = 7
    else if m.librarySmokeStep = 7
        status = m.vod.callFunc("libraryStatus")
        if status.loading or m.top.dialog = invalid then return
        print "[library-smoke] detail-buttons="; m.top.dialog.buttons.count()
        m.top.dialog.buttonSelected = m.top.dialog.buttons.count() - 1
        m.librarySmokeStep = 8
    else if m.librarySmokeStep = 8
        print "[library-smoke] detail-return-focus="; m.vod.isInFocusChain()
        m.vod.callFunc("handleLibraryKey", "fastforward", true)
        m.librarySmokeStep = 2
    else if m.librarySmokeStep = 2
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[library-smoke] next="; FormatJson(status)
        m.vod.callFunc("handleLibraryKey", "options", true)
        print "[library-smoke] menu-buttons="; m.top.dialog.buttons.count()
        m.top.dialog.buttonSelected = 8
        m.librarySmokeStep = 3
    else if m.librarySmokeStep = 3
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[library-smoke] categories="; FormatJson(status)
        m.vod.callFunc("handleLibraryKey", "OK", true)
        m.librarySmokeStep = 4
    else if m.librarySmokeStep = 4
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[library-smoke] filtered="; FormatJson(status)
        m.vod.callFunc("handleLibraryKey", "options", true)
        m.top.dialog.buttonSelected = m.top.dialog.buttons.count() - 1
        m.librarySmokeStep = 9
    else if m.librarySmokeStep = 9
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[library-smoke] providers="; FormatJson(status)
        m.vod.callFunc("handleLibraryKey", "OK", true)
        m.librarySmokeStep = 10
    else if m.librarySmokeStep = 10
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        print "[library-smoke] provider-filter="; FormatJson(status)
        closeVodLibrary()
        recordDiagnostic("vod", 0, "Library smoke complete")
        showDiagnostics()
        print "[library-smoke] diagnostic-buttons="; m.top.dialog.buttons.count()
        m.top.dialog.buttonSelected = 3
        m.librarySmokeStep = 5
    else if m.librarySmokeStep = 5
        m.top.dialog.buttonSelected = 2
        m.librarySmokeStep = 6
    else if m.librarySmokeStep = 6
        print "[library-smoke] cleared-events="; m.diagnosticLog.count()
        m.accountPreferences.vodBrowse = m.librarySmokeSavedBrowse
        persistAccountPreferences()
        m.top.dialog.close = true
        m.librarySmokeTimer.control = "stop"
        print "[library-smoke] complete"
    end if
end sub
