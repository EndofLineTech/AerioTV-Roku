' Native-only direct M3U + XMLTV probe; no account/source registry writes.
sub startNativeM3uGuideProbe()
    m.probePlaylist = __PLAYLIST__
    m.probeGuide = __XMLTV__
    m.probeMode = __MODE__
    m.probeApiKey = __KEY__
    m.global.httpReferer = __REFERER__
    m.accountIdentity = "native-m3u-probe"
    m.accountPreferences = normalizeAccountPreferences(invalid)
    m.guide.unobserveField("preferences")
    m.probeStage = "playlist"
    m.probeElapsed = 0
    m.probeTimer = m.top.createChild("Timer")
    m.probeTimer.duration = 1
    m.probeTimer.repeat = true
    m.probeTimer.observeField("fire", "nativeM3uGuideTick")
    if m.probeMode = "api-key-override" or m.probeMode = "api-key-default"
        m.global.httpReferer = ""
        m.global.authHeaderMode = "x-api-key"
        m.probeTask = CreateObject("roSGNode", "DispatcharrTask")
        m.probeTask.baseUrl = urlOrigin(m.probePlaylist)
        m.probeTask.apiKey = m.probeApiKey
        m.probeTask.authMode = "x-api-key"
        m.probeTask.profileId = ""
        m.probeTask.cacheEpoch = m.global.cacheEpoch
    else
        m.probeTask = CreateObject("roSGNode", "M3uTask")
        m.probeTask.url = m.probePlaylist
        m.probeTask.connectionId = "native-m3u-probe"
    end if
    m.probeTask.observeField("result", "onNativeM3uLineup")
    m.probeTask.control = "RUN"
    m.probeTimer.control = "start"
end sub

sub onNativeM3uLineup(event as object)
    if not isCurrentTaskEvent(event, m.probeTask) then return
    result = event.getData()
    m.probeTask.unobserveField("result")
    m.probeTask = invalid
    if not result.ok
        print "[m3u-guide-probe] playlist failed"
        nativeM3uGuideDone()
        return
    end if
    print "[m3u-guide-probe] channels="; result.channels.count(); " groups="; result.groups.count()
    m.probeChannel = result.channels[0]
    m.probeStage = "guide"
    providerType = "m3u"
    if m.probeMode <> "m3u" then providerType = "dispatcharr"
    scope = "native-m3u-probe"
    if m.probeMode = "api-key-override" or m.probeMode = "api-key-default" then scope = result.scope
    guideUrl = m.probeGuide
    if m.probeMode = "api-key-default" then guideUrl = ""
    m.guide.config = {channels: result.channels, groups: result.groups, warning: "", baseUrl: urlOrigin(m.probePlaylist), apiKey: m.probeApiKey, providerType: providerType, guideUrl: guideUrl, preferences: m.accountPreferences, scope: scope, generation: result.generation}
    m.page = "guide"
    m.screen.visible = false
    m.guide.visible = true
    m.guide.active = true
end sub

sub nativeM3uGuideTick()
    m.probeElapsed++
    if m.probeElapsed >= 105
        print "[m3u-guide-probe] timed out stage="; m.probeStage
        nativeM3uGuideDone()
        return
    end if
    if m.probeStage <> "guide" then return
    snapshot = m.guide.callFunc("cachedPlaybackInfo", m.probeChannel, uiNow())
    if type(snapshot) <> "roAssociativeArray" then return
    if type(snapshot.programs) = "roArray"
        if snapshot.programs.count() > 0
            print "[m3u-guide-probe] mode="; m.probeMode; " guide matched channel, programmes="; snapshot.programs.count()
            nativeM3uGuideDone()
        end if
    end if
end sub

sub nativeM3uGuideDone()
    m.probeTimer.control = "stop"
    if m.probeTask <> invalid
        m.probeTask.unobserveField("result")
        cancelNetworkTask(m.probeTask)
        m.probeTask = invalid
    end if
    m.page = "setup"
    m.guide.callFunc("cancelMetadataLoads")
    m.guide.active = false
    m.guide.config = invalid
    m.global.httpReferer = ""
    m.probePlaylist = ""
    m.probeGuide = ""
    m.probeApiKey = ""
    print "[m3u-guide-probe] done"
end sub
