' Native integration fixture. Temporarily copy into components, import in
' AerioScene.xml and call installVodAppProbe from init. Remove all hooks after
' use. This intentionally plays/seeks a movie and restores its test state.
sub installVodAppProbe()
    m.vodProbeStage = 0
    m.vodProbeElapsed = 0
    m.vodProbePeak = 0
    m.vodProbeMonitor = CreateObject("roAppMemoryMonitor")
    m.vodProbeTimer = m.top.createChild("Timer")
    m.vodProbeTimer.duration = 1
    m.vodProbeTimer.repeat = true
    m.vodProbeTimer.observeField("fire", "onVodProbeTick")
    m.vodProbeTimer.control = "start"
end sub

sub onVodProbeTick()
    if m.vodProbeStage = 9
        m.vodProbeTimer.control = "stop"
        m.accountPreferences.vod = m.vodProbeSaved
        persistAccountPreferences()
        print "[vod-app-probe] complete peak="; m.vodProbePeak
        return
    end if
    m.vodProbeElapsed++
    percent = m.vodProbeMonitor.getMemoryLimitPercent()
    if percent > m.vodProbePeak then m.vodProbePeak = percent
    if m.vodProbeElapsed > 120
        print "[vod-app-probe] timeout stage="; m.vodProbeStage
        finishVodAppProbe()
        return
    end if
    if m.vodProbeStage = 0
        if m.serverAccountId = "" or m.capabilities.movies <> "allowed" then return
        m.vodProbeSaved = m.accountPreferences.vod
        openVodLibrary("movie")
        m.vodProbeTask = CreateObject("roSGNode", "VodTask")
        m.vodProbeTask.baseUrl = m.baseUrl
        m.vodProbeTask.apiKey = m.apiKey
        m.vodProbeTask.accountId = m.serverAccountId
        m.vodProbeTask.kind = "movie"
        m.vodProbeTask.query = "The Matrix"
        m.vodProbeTask.titleOnly = true
        m.vodProbeTask.year = "1999"
        m.vodProbeTask.cacheEpoch = m.global.cacheEpoch
        m.vodProbeTask.observeField("result", "onVodProbePage")
        m.vodProbeTask.control = "RUN"
        m.vodProbeStage = 1
    else if m.vodProbeStage = 3
        video = m.mediaPlayer.findNode("mediaVideo")
        if video.errorCode <> 0
            print "[vod-app-probe] media-failed code="; video.errorCode; " format="; m.vodProbeItem.streamFormat
            finishVodAppProbe()
            return
        end if
        if video.state <> "playing" then return
        print "[vod-app-probe] first-play duration="; video.duration; " format="; m.vodProbeItem.streamFormat; " library-nodes="; m.vod.getChildCount()
        video.seek = 60
        m.vodProbeSeekAt = m.vodProbeElapsed
        m.vodProbeStage = 4
    else if m.vodProbeStage = 4
        video = m.mediaPlayer.findNode("mediaVideo")
        if m.vodProbeElapsed - m.vodProbeSeekAt < 20 or video.state <> "playing" then return
        print "[vod-app-probe] seek-result="; video.position
        m.mediaPlayer.callFunc("closeMedia")
        m.vodProbeStage = 5
    else if m.vodProbeStage = 5 and m.page = "library"
        entry = vodStateEntry(m.accountPreferences.vod, m.vodProbeItem)
        m.vodProbeItem.resume = vodResumePosition(entry, entry.duration)
        print "[vod-app-probe] saved-resume="; m.vodProbeItem.resume
        onVodPlay(vodProbeEvent(m.vod, m.vodProbeItem))
        m.vodProbeResumeAt = m.vodProbeElapsed
        m.vodProbeStage = 6
    else if m.vodProbeStage = 6
        video = m.mediaPlayer.findNode("mediaVideo")
        if video.errorCode <> 0 and video.state <> "playing"
            print "[vod-app-probe] resume-failed code="; video.errorCode
            finishVodAppProbe()
            return
        end if
        if video.state <> "playing" or m.vodProbeElapsed - m.vodProbeResumeAt < 8 then return
        print "[vod-app-probe] resumed-position="; video.position; " requested="; m.vodProbeItem.resume
        finishVodAppProbe()
    end if
end sub

sub onVodProbePage(event as object)
    if not isCurrentTaskEvent(event, m.vodProbeTask) then return
    result = event.getData()
    m.vodProbeTask.unobserveField("result")
    if not result.ok or result.items.count() = 0
        print "[vod-app-probe] page-failed"
        finishVodAppProbe()
        return
    end if
    print "[vod-app-probe] page rows="; result.items.count(); " total="; result.total
    m.vodProbeTask = CreateObject("roSGNode", "VodTask")
    m.vodProbeTask.baseUrl = m.baseUrl
    m.vodProbeTask.apiKey = m.apiKey
    m.vodProbeTask.accountId = m.serverAccountId
    m.vodProbeTask.kind = "movie"
    m.vodProbeTask.itemId = result.items[0].id
    m.vodProbeTask.observeField("result", "onVodProbeDetail")
    m.vodProbeTask.control = "RUN"
    m.vodProbeStage = 2
end sub

sub onVodProbeDetail(event as object)
    if not isCurrentTaskEvent(event, m.vodProbeTask) then return
    result = event.getData()
    m.vodProbeTask.unobserveField("result")
    if not result.ok
        print "[vod-app-probe] detail-failed"
        finishVodAppProbe()
        return
    end if
    m.vodProbeItem = result.item
    print "[vod-app-probe] selected-format="; m.vodProbeItem.streamFormat; " provider="; m.vodProbeItem.providerId <> ""
    m.vodProbeItem.resume = 0
    onVodPlay(vodProbeEvent(m.vod, m.vodProbeItem))
    m.vodProbeStage = 3
end sub

function vodProbeEvent(node as object, data as object) as object
    return {node: node, data: data, getRoSGNode: function()
        return m.node
    end function, getData: function()
        return m.data
    end function}
end function

sub finishVodAppProbe()
    m.mediaPlayer.callFunc("closeMedia")
    m.mediaIdentity = ""
    m.vodProbeStage = 9
end sub
