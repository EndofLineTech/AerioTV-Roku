' Native-only archive transport probe; placeholders are replaced inside an
' ignored disposable ZIP. No live media names or credentials are printed.
sub startNativeXtreamArchiveProbe()
    m.probeBase = __BASE__
    m.xcUsername = __USER__
    m.xcPassword = __PASSWORD__
    m.xcTimezone = "UTC"
    m.baseUrl = m.probeBase
    m.apiKey = ""
    m.accountIdentity = "native-archive-probe"
    m.accountPreferences = normalizeAccountPreferences(invalid)
    m.capabilities.catchup = "allowed"
    id = "__CHANNEL_ID__"
    days = __DAYS__
    channel = {id: "xc-" + id, uuid: "xc-" + id, streamId: id, archiveDays: days, name: "Archive probe", number: "1", groupId: "", epgKey: "", tvgId: "", epgId: "", logoId: ""}
    m.probeChannel = channel
    m.probeProgram = {id: "archived-fixture", title: "Archived programme", startsAt: __START__, endsAt: __END__}
    m.channelFacts = xtreamArchiveFacts([channel], "UTC")
    m.connectionStore = connectionStoreAdd(defaultConnectionStore(), "native-xc-probe", "Native XC probe", "xtream")
    m.connectionStore = connectionStoreUpdate(m.connectionStore, "native-xc-probe", {url: m.probeBase})
    m.selectedConnectionId = "native-xc-probe"
    m.guide.active = false
    m.guide.config = {channels: [channel], groups: [], warning: "", baseUrl: m.probeBase, apiKey: "", providerType: "xtream", guideUrl: "", preferences: m.accountPreferences, scope: "native-archive-probe", generation: "probe"}
    m.guide.channelFacts = m.channelFacts
    m.guide.catchupPermission = "allowed"
    m.page = "guide"
    m.screen.visible = false
    m.probeStage = "opening"
    m.probeElapsed = 0
    m.probePlayingAt = -1
    m.probeTimer = m.top.createChild("Timer")
    m.probeTimer.duration = 1
    m.probeTimer.repeat = true
    m.probeTimer.observeField("fire", "nativeXtreamArchiveTick")
    print "[xc-archive-probe] fixture eligible="; catchupEligible(m.probeProgram, days, uiNow())
    m.guide.archiveRequest = {channel: channel, program: m.probeProgram, scope: "native-archive-probe", restart: false}
    if m.page <> "onDemand" then print "[xc-archive-probe] could not open archive" : nativeXtreamArchiveDone() : return
    m.probeTimer.control = "start"
end sub

sub nativeXtreamArchiveTick()
    m.probeElapsed++
    if m.probeElapsed >= 85
        print "[xc-archive-probe] timed out stage="; m.probeStage
        nativeXtreamArchiveDone()
        return
    end if
    if m.probeStage = "go-live"
        if m.page = "player" and m.video.state = "playing"
            print "[xc-archive-probe] go-live state=playing"
            stopPlayback()
            nativeXtreamArchiveDone()
        end if
        return
    end if
    video = m.mediaPlayer.findNode("mediaVideo")
    state = video.state
    if state = "error" or state = "finished"
        print "[xc-archive-probe] state="; state; " stage="; m.probeStage; " code="; video.errorCode
        nativeXtreamArchiveDone()
        return
    end if
    if m.probeStage = "pausing" and state = "paused"
        print "[xc-archive-probe] paused before seek"
        m.probeStage = "seek-paused"
        m.mediaPlayer.archiveSeek = 120
        return
    end if
    if m.probeStage = "seek-paused" and state = "paused"
        if m.archiveOffset <> 120 then return
        print "[xc-archive-probe] paused after seek offset="; m.archiveOffset
        m.probeStage = "seeking"
        m.probePlayingAt = -1
        m.mediaPlayer.callFunc("handleArchiveKey", "play", true)
        return
    end if
    if state <> "playing" then return
    if m.probePlayingAt < 0 then m.probePlayingAt = m.probeElapsed
    if m.probeElapsed - m.probePlayingAt < 10 then return
    if m.probeStage = "opening"
        print "[xc-archive-probe] playing position-positive="; video.position > 0
        m.probeStage = "pausing"
        m.mediaPlayer.callFunc("handleArchiveKey", "play", true)
    else if m.probeStage = "seeking"
        print "[xc-archive-probe] seek offset="; m.archiveOffset; " position-positive="; video.position > 0
        m.probeStage = "go-live"
        m.probePlayingAt = -1
        m.mediaPlayer.goLiveRequested = true
    end if
end sub

sub nativeXtreamArchiveDone()
    m.probeTimer.control = "stop"
    m.page = "setup"
    if m.mediaPlayer.request <> invalid then m.mediaPlayer.callFunc("closeMedia")
    releaseArchive()
    m.guide.active = false
    m.guide.config = invalid
    m.xcUsername = ""
    m.xcPassword = ""
    m.probeBase = ""
    print "[xc-archive-probe] done"
end sub
