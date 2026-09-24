' Disposable device-only probe. The builder replaces these expressions in the
' ignored ZIP; no actual credential exists in this repository source.
sub startNativeXtreamVodProbe()
    m.probeBase = __PROBE_BASE__
    m.probeUser = __PROBE_USER__
    m.probePassword = __PROBE_PASSWORD__
    m.probeKind = __PROBE_KIND__
    if m.probeKind = "auth-denied" then m.probePassword += "-invalid"
    m.probeScope = "native-xc-probe"
    m.probeStage = "auth"
    m.probeElapsed = 0
    m.probeMediaStarted = -1
    m.probeOpenedSeries = false
    m.probeTimer = m.top.createChild("Timer")
    m.probeTimer.duration = 1
    m.probeTimer.repeat = true
    m.probeTimer.observeField("fire", "nativeXtreamVodTick")
    ' Test only the ephemeral scene and the existing shared VOD screen.
    ' Never invoke the connection roster, preference writes, or guide loader.
    m.baseUrl = m.probeBase
    m.apiKey = ""
    m.accountIdentity = m.probeScope
    m.accountPreferences = normalizeAccountPreferences(invalid)
    m.probeTask = CreateObject("roSGNode", "XtreamTask")
    m.probeTask.baseUrl = m.probeBase
    m.probeTask.username = m.probeUser
    m.probeTask.password = m.probePassword
    m.probeTask.connectionId = "native-xc-probe"
    if m.probeKind = "cancel" then m.probeTask.cancelRequested = true
    m.probeTask.observeField("result", "onNativeXtreamProbeAuth")
    m.probeTask.control = "RUN"
    m.probeTimer.control = "start"
end sub

sub onNativeXtreamProbeAuth(event as object)
    if not isCurrentTaskEvent(event, m.probeTask) then return
    result = event.getData()
    m.probeTask.unobserveField("result")
    m.probeTask = invalid
    if m.probeKind = "auth-denied"
        print "[xc-vod-probe] rejected-login relogin="; result.relogin = true; " accepted="; result.ok = true
        nativeXtreamVodDone()
        return
    end if
    if not result.ok or result.movies <> true or result.series <> true
        print "[xc-vod-probe] authorized connection failed"
        nativeXtreamVodDone()
        return
    end if
    print "[xc-vod-probe] live channels="; result.channels.count(); " movie/series access="; result.movies; "/"; result.series
    m.probeStage = "categories"
    m.capabilities.movies = "allowed"
    m.capabilities.series = "allowed"
    m.vod.unobserveField("playRequested")
    m.vod.unobserveField("stateChange")
    m.vod.unobserveField("bookmark")
    m.vod.observeField("playRequested", "nativeXtreamVodPlay")
    m.vod.savedState = []
    m.vod.permissions = {movies: "allowed", series: "allowed", level: -1}
    m.page = "library"
    m.screen.visible = false
    m.guide.visible = false
    m.guide.active = false
    m.vod.config = {kind: m.probeKind, providerType: "xtream", baseUrl: m.probeBase, username: m.probeUser, password: m.probePassword, accountScope: m.probeScope, apiKey: "", accountId: "", tmdbEnabled: false}
    m.vod.active = true
    print "[xc-vod-probe] library opened"
end sub

sub nativeXtreamVodTick()
    m.probeElapsed++
    if m.probeKind = "cancel" and m.probeTask <> invalid
        if m.probeTask.state = "done" or m.probeTask.state = "stop"
            print "[xc-vod-probe] cancelled result-absent="; m.probeTask.result = invalid; " password-cleared="; m.probeTask.password = ""
            nativeXtreamVodDone()
            return
        end if
    end if
    if m.probeElapsed >= 95
        print "[xc-vod-probe] timed out stage="; m.probeStage
        nativeXtreamVodDone()
        return
    end if
    if m.probeStage = "categories" or m.probeStage = "titles"
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        if status.failure <> "" or status.loaded = 0
            print "[xc-vod-probe] catalog failed stage="; m.probeStage
            nativeXtreamVodDone()
            return
        end if
        if m.probeStage = "categories"
            print "[xc-vod-probe] categories="; status.total; " page="; status.loaded
            m.probeStage = "titles"
        else
            print "[xc-vod-probe] titles="; status.total; " page="; status.loaded
            m.probeStage = "details"
        end if
        m.vod.callFunc("handleLibraryKey", "OK", true)
        return
    end if
    if m.probeStage = "details"
        status = m.vod.callFunc("libraryStatus")
        if status.loading then return
        dialog = m.vod.findNode("vodDetails")
        if dialog = invalid then return
        if m.probeKind = "series" and not m.probeOpenedSeries
            print "[xc-vod-probe] series details opened"
            m.probeOpenedSeries = true
            m.probeStage = "episodes"
            dialog.buttonSelected = 0
            return
        end if
        print "[xc-vod-probe] details opened"
        m.probeStage = "playing"
        dialog.buttonSelected = 0
        return
    end if
    if m.probeStage = "episodes"
        status = m.vod.callFunc("libraryStatus")
        if status.kind <> "episode" or status.loading then return
        if status.failure <> "" or status.loaded = 0
            print "[xc-vod-probe] episodes failed"
            nativeXtreamVodDone()
            return
        end if
        print "[xc-vod-probe] episodes="; status.total; " page="; status.loaded
        m.probeStage = "details"
        m.vod.callFunc("handleLibraryKey", "OK", true)
        return
    end if
    if m.probeStage = "playing"
        state = m.mediaPlayer.findNode("mediaVideo").state
        if state = "error" or state = "finished"
            print "[xc-vod-probe] media state="; state
            m.mediaPlayer.callFunc("closeMedia")
            nativeXtreamVodDone()
        else if state = "playing"
            if m.probeMediaStarted < 0 then m.probeMediaStarted = m.probeElapsed
            if m.probeElapsed - m.probeMediaStarted >= 12
                position = m.mediaPlayer.findNode("mediaVideo").position
                print "[xc-vod-probe] media state=playing position-positive="; position > 0
                m.mediaPlayer.callFunc("closeMedia")
                nativeXtreamVodDone()
            end if
        end if
    end if
end sub

sub nativeXtreamVodPlay(event as object)
    if m.probeStage <> "playing" then return
    item = event.getData()
    if textValue(item.accountScope) <> m.probeScope
        print "[xc-vod-probe] scope rejected"
        nativeXtreamVodDone()
        return
    end if
    url = xtreamVodStreamUrl(m.probeBase, m.probeUser, m.probePassword, item)
    if url = ""
        print "[xc-vod-probe] unsupported title format"
        nativeXtreamVodDone()
        return
    end if
    print "[xc-vod-probe] media format="; item.streamFormat
    m.mediaReturn = "library"
    m.mediaItem = invalid
    m.vod.active = false
    m.page = "onDemand"
    m.mediaPlayer.request = {account: m.probeScope, identity: "native-xc-probe", key: item.key, mode: "vod", providerType: "xtream", url: url, title: "Xtream VOD probe", apiKey: "", streamFormat: item.streamFormat, resume: 0}
end sub

sub nativeXtreamVodDone()
    m.probeTimer.control = "stop"
    if m.probeTask <> invalid
        m.probeTask.unobserveField("result")
        cancelNetworkTask(m.probeTask)
        m.probeTask = invalid
    end if
    m.page = "setup"
    if m.mediaPlayer.request <> invalid then m.mediaPlayer.callFunc("closeMedia")
    m.vod.callFunc("cancelVod")
    m.vod.active = false
    m.vod.config = invalid
    m.probeBase = ""
    m.probeUser = ""
    m.probePassword = ""
    print "[xc-vod-probe] done"
end sub
