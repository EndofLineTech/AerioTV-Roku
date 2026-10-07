sub main()
    ' Exercise the actual Scene handlers with field adapters. This proves control
    ' routing and lack of retune writes, not native video-plane/audio behavior.
    m.top = {dialog: invalid, setFocus: function(value as boolean) as boolean
        m.focused = value
        return true
    end function}
    m.top.beacons = []
    m.top.signalBeacon = sub(name as string)
        m.beacons.push(name)
    end sub
    m.startupDialogOpen = false
    m.startupBeaconSent = false
    beginStartupBeacons(false)
    beginStartupDialog()
    beginStartupDialog()
    assertEqual(m.top.beacons.count(), 1, "pre-home setup starts a dialog interval")
    assertEqual(m.top.beacons[0], "AppDialogInitiate", "saved-connection setup starts dialog once")
    assertEqual(m.startupBeaconSent, false, "setup does not complete launch before sign-in")
    signalStartupComplete()
    signalStartupComplete()
    assertEqual(m.top.beacons.count(), 3, "startup beacons fire once")
    assertEqual(m.top.beacons[1], "AppDialogComplete", "sign-in interval ends before ready guide")
    assertEqual(m.top.beacons[2], "AppLaunchComplete", "rendered guide completes app launch")
    m.top.beacons = []
    m.startupDialogOpen = false
    m.startupBeaconSent = false
    beginStartupBeacons(true)
    assertEqual(m.top.beacons.count(), 0, "first-run Welcome is the initial interactive screen")
    m.page = "welcome"
    m.pendingLaunch = {id: "unavailable-channel"}
    signalStartupComplete()
    assertEqual(m.top.beacons.count(), 1, "Welcome completes launch without waiting for credentials")
    assertEqual(m.top.beacons[0], "AppLaunchComplete", "fully rendered Welcome satisfies unattended launch test")
    assertEqual(m.pendingLaunch.id, "unavailable-channel", "pre-sign-in link remains pending on Welcome")
    beginStartupDialog()
    assertEqual(m.top.beacons.count(), 1, "no pre-home dialog interval after launch is complete")
    m.guide = {callFunc: function(name as string, id as string) as dynamic
        return invalid
    end function}
    m.noticeText = {text: ""}
    m.notice = {visible: false}
    m.noticeTimer = {control: "stop"}
    m.page = "guide"
    signalStartupComplete()
    assertEqual(m.top.beacons.count(), 1, "later sign-in does not emit a second launch beacon")
    assertEqual(m.pendingLaunch, invalid, "authorized guide consumes the pending link after sign-in")
    assertEqual(m.notice.visible, true, "unavailable link falls back safely to the guide")
    m.page = "guide"
    m.heldZap = ""
    m.heldZapTimer = {control: "stop"}
    m.pictureWakeKey = ""
    m.top.dialog = {}
    assertEqual(onKeyEvent("OK", true), false, "uninitialized dialog close field cannot crash input")
    m.top.dialog = invalid
    m.playerInput = m.top
    m.playerOkTimer = {control: "stop"}
    m.page = "player"
    m.heldZap = ""
    m.heldZapTimer = {control: "stop"}
    m.playingChannel = {uuid: "a"}
    m.video = {state: "playing", control: "play", content: {programId: "a"}, visible: true, mute: false, suppressCaptions: false}
    m.video.setFocus = m.top.setFocus
    m.mini = false
    m.pictureWakeKey = ""
    m.pictureCover = {visible: false}
    m.pictureHint = {visible: false}
    m.pictureHintTimer = {control: "stop"}
    m.channelTuneTimer = {control: "start"}
    m.pendingChannel = {uuid: "b"}
    m.browser = {active: true}
    m.playerOptions = {active: true}
    m.transport = {active: true, visible: true, focused: false, setFocus: function(value as boolean) as boolean
        m.focused = value
        return true
    end function, callFunc: function(name as string, key as string, press as boolean) as boolean
        m.forwarded = key
        return true
    end function}
    m.banner = {visible: true}
    m.bufferingIndicator = {visible: false, translation: [1536, 146], scale: [1.0, 1.0]}
    m.bufferingSpinner = {control: "stop"}
    m.bannerTimer = {control: "start"}
    m.userInfoOpen = true
    m.sleepDeadline = 123
    m.guide = {sleepActive: false}
    onPlayerOption({getData: function() as object
        return {action: "hidePicture"}
    end function})
    onKeyEvent("OK", true)
    assertEqual(m.pictureCover.visible, true, "selecting OK cannot immediately wake hidden picture")
    onKeyEvent("OK", false)
    assertEqual(m.pictureCover.visible, true, "selection release leaves picture hidden")
    restorePicture()
    hidePicture()
    assertEqual(m.pictureCover.visible, true, "foreground cover opens")
    assertEqual(m.video.control, "play", "cover does not stop or retune player")
    assertEqual(m.video.content.programId, "a", "content identity preserved")
    assertEqual(m.video.visible, false, "native video plane hidden without stopping")
    assertEqual(m.video.suppressCaptions, true, "captions suppressed while hidden")
    assertEqual(m.video.mute, false, "audio remains enabled")
    assertEqual(m.pendingChannel, invalid, "cancel pending tune preview")
    assertEqual(m.sleepDeadline, 123, "sleep timer preserved")
    hidePictureHint()
    assertEqual(m.pictureHint.visible, false, "intro fades to black")
    assertEqual(onKeyEvent("play", true), true, "pause handled in hidden-picture mode")
    assertEqual(m.video.control, "pause", "pause routed to same Video")
    assertEqual(m.pictureCover.visible, true, "pause does not uncover picture")
    assertEqual(onKeyEvent("right", true), true, "navigation wakes picture")
    assertEqual(m.pictureCover.visible, false, "picture restored")
    assertEqual(m.video.visible, true, "native plane restored")
    assertEqual(m.video.suppressCaptions, false, "caption suppression restored")
    assertEqual(onKeyEvent("right", true), true, "held wake key consumed")
    assertEqual(m.video.content.programId, "a", "held wake key does not zap")
    assertEqual(onKeyEvent("right", false), true, "wake key release consumed")
    assertEqual(m.pictureWakeKey, "", "normal navigation restored after release")
    m.mini = true
    hidePicture()
    assertEqual(m.pictureCover.visible, false, "mini-player cannot cover guide")
    m.mini = false
    m.video.globalCaptionMode = "Off"
    m.video.availableAudioTracks = []
    m.video.audioTrack = ""
    m.capabilities = {switchStreams: "allowed"}
    m.devicePreferences = normalizeDevicePreferences(invalid)
    m.accountPreferences = {videoAspects: {}}
    m.optionReturnAction = "audioMenu"
    openPlayerOptions("audio")
    assertEqual(m.playerOptions.menu.title, "Audio track", "audio submenu opens")
    onPlayerOptionsBack()
    assertEqual(m.playerOptions.menu.title, "AerioTV player options", "Back returns to parent")
    assertEqual(m.playerOptions.menu.items[m.playerOptions.menu.focusIndex].action, "audioMenu", "parent focus restored")
    assertEqual(m.video.content.programId, "a", "submenu Back does not retune")
    infoTask = {control: "RUN", unobserved: false, unobserveField: sub(field as string)
        m.unobserved = true
    end sub}
    m.streamInfoTask = infoTask
    m.serverStreamInfo = {resolution: "old source"}
    clearServerStreamInfo()
    assertEqual(infoTask.cancelRequested, true, "source transition cooperatively cancels old metadata request")
    assertEqual(infoTask.unobserved, true, "old metadata callback detached")
    assertEqual(m.streamInfoTask, invalid, "stale Task no longer current")
    assertEqual(m.serverStreamInfo, invalid, "old source facts cleared")
    m.playerOptions.active = false
    m.browser.active = false
    m.transport.active = false
    m.userInfoOpen = true
    m.banner.visible = true
    for each key in ["up", "left", "right"]
        assertEqual(onKeyEvent(key, true), true, "explicit info owns direction: " + key)
        if key = "up" then onTransportInfoFocus()
        onBannerTimeout()
        assertEqual(m.userInfoOpen, true, "queued auto timeout cannot dismiss explicit info")
        m.transport.focused = false
        assertEqual(onKeyEvent("down", true), true, "controls remain reachable after " + key)
        assertEqual(m.transport.focused, true, "Down explicitly restores focus")
        assertEqual(m.transport.visible, true, "active controls visible")
        onTransportInfoFocus()
        assertEqual(m.transport.active, false, "Up handoff clears active control state")
        assertEqual(m.bannerTimer.control, "stop", "explicit info never auto-expires")
    end for
    m.transport.active = true
    m.transport.focused = false
    m.transport.visible = false
    assertEqual(onKeyEvent("left", true), true, "stranded active controls recover")
    assertEqual(m.transport.forwarded, "left", "key dispatched to active controls")
    assertEqual(m.transport.focused, true, "displaced focus restored")
    assertEqual(onKeyEvent("options", true), false, "fullscreen star is left to Roku")
    assertEqual(m.playerOptions.active, false, "star does not open app options")
    openPlayerOptions()
    assertEqual(m.playerOptions.menu.title, "AerioTV player options", "clearly branded app menu")
    m.capabilities.dvr = "manage"
    openPlayerOptions()
    assertEqual(m.playerOptions.menu.items[0].action, "recordCurrent", "authorized player offers current-program recording")
    m.capabilities.dvr = "view"
    openPlayerOptions()
    assertEqual(m.playerOptions.menu.items[0].action = "recordCurrent", false, "view-only player does not offer recording")
    assertEqual(m.video.content.programId, "a", "focus repair preserves content")
    m.userInfoOpen = false
    m.transport.active = false
    m.playerOptions.active = false
    m.banner.visible = true
    onBannerTimeout()
    assertEqual(m.banner.visible, false, "automatic tune banner still expires")
    m.apiKey = ""
    m.guide.callFunc = function(name as string, channel as object, now as integer) as object
        return {programs: [], status: "ready"}
    end function
    m.video.state = "buffering"
    m.bannerTimer.control = "untouched"
    onVideoState()
    assertEqual(m.banner.visible, false, "midstream buffering does not reopen dismissed info")
    assertEqual(m.bannerTimer.control, "untouched", "hidden info does not acquire a new timer")
    assertEqual(m.bufferingIndicator.visible, true, "hidden info uses compact buffering status")
    assertEqual(m.bufferingSpinner.control, "start", "compact status spins during buffering")
    m.video.state = "paused"
    onVideoState()
    assertEqual(m.banner.visible, false, "pause does not reopen dismissed info")
    assertEqual(m.bufferingIndicator.visible, false, "buffering status hides when paused")
    m.userInfoOpen = true
    m.banner.visible = true
    m.bannerTimer.control = "start"
    m.video.state = "buffering"
    onVideoState()
    assertEqual(m.banner.visible, true, "explicitly opened info remains visible during buffering")
    assertEqual(m.bannerTimer.control, "stop", "explicit info never expires while buffering")
    assertEqual(instr(1, m.banner.hint, "Buffering") > 0, true, "visible info describes buffering")
    assertEqual(m.bufferingIndicator.visible, false, "visible info avoids duplicate buffering chrome")
    m.userInfoOpen = false
    m.banner.visible = false
    m.mini = true
    m.page = "guide"
    onVideoState()
    assertEqual(m.bufferingIndicator.visible, true, "mini-player still has compact buffering status")
    assertEqual(m.bufferingIndicator.scale[0], 0.72, "mini indicator stays within the video tile")
    m.pictureCover.visible = true
    onVideoState()
    assertEqual(m.bufferingIndicator.visible, false, "hidden-picture mode has no overlay")
    m.pictureCover.visible = false
    m.video.state = "playing"
    m.mini = false
    m.page = "player"
    m.audioCheck = {control: "stop"}
    m.recordedChannel = "a"
    onVideoState()
    assertEqual(m.bufferingIndicator.visible, false, "playing stops compact status")
    assertEqual(m.bufferingSpinner.control, "stop", "spinner stops when playback resumes")
    m.playerOptions.active = false
    m.pendingChannel = invalid
    m.video.control = "play"
    m.guide = {callFunc: function(name as string, current as dynamic, value as dynamic) as dynamic
        if name = "adjacentPlayingChannel"
            return adjacentLiveChannel([{uuid: "a", number: "1"}, {uuid: "b", number: "2"}, {uuid: "c", number: "3"}], current, value)
        end if
        return {programs: [], status: "ready"}
    end function}
    assertEqual(onKeyEvent("up", true), true, "held key begins preview")
    assertEqual(m.pendingChannel.uuid, "b", "initial candidate")
    repeatHeldZap()
    assertEqual(m.pendingChannel.uuid, "c", "timer advances held candidate")
    assertEqual(m.video.content.programId, "a", "hold does not open intermediate streams")
    assertEqual(onKeyEvent("up", true), true, "native repeated key coalesced")
    assertEqual(m.pendingChannel.uuid, "c", "no double advancement from native repeats")
    assertEqual(onKeyEvent("up", false), true, "release captured")
    assertEqual(m.heldZap, "", "release clears held state")
    assertEqual(m.channelTuneTimer.control, "start", "one deferred tune after release")
    m.pendingChannel = invalid
    m.devicePreferences.remoteMap = setRemoteAction(defaultRemoteMap(), "player", "leftShort", "channelUp")
    assertEqual(onKeyEvent("left", true), true, "custom Left channel mapping routes through actual Scene")
    assertEqual(m.pendingChannel.uuid, "b", "custom Left queues adjacent channel")
    repeatHeldZap()
    assertEqual(m.pendingChannel.uuid, "c", "custom Left supports held channel repeat")
    onKeyEvent("left", false)
    assertEqual(m.heldZap, "", "custom Left release ends hold")
    m.pendingChannel = invalid
    m.devicePreferences.remoteMap = setRemoteAction(defaultRemoteMap(), "player", "upShort", "toggleInfo")
    onKeyEvent("up", true)
    assertEqual(m.userInfoOpen, true, "custom Up non-channel action routes through actual Scene")
    assertEqual(m.pendingChannel, invalid, "custom Up info does not tune")
    assertEqual(onKeyEvent("home", true), false, "Home remains system-owned even with info visible")
    onKeyEvent("back", true)
    assertEqual(m.userInfoOpen, false, "Back still dismisses custom-opened info")
    m.devicePreferences.remoteMap = defaultRemoteMap()
    m.playerOptions.active = false
    m.transport.active = false
    m.userInfoOpen = false
    m.pendingChannel = invalid
    assertEqual(onKeyEvent("OK", true), true, "tap OK still opens info immediately")
    assertEqual(m.userInfoOpen, true, "information is visible during hold preparation")
    m.playerOkClock = {totalMilliseconds: function() as integer
        return 1100
    end function}
    onPlayerOkHold()
    assertEqual(m.playerOptions.active, true, "actual Scene hold opens Options")
    assertEqual(m.playerOptions.consumeSelectRelease, true, "menu protects initiating release")
    assertEqual(m.video.content.programId, "a", "hold preserves same playback content")
    m.pendingChannel = invalid
    m.apiKey = "test-only"
    m.video.content = lifecycleRetryContent(1)
    m.video.state = "error"
    m.video.errorCode = -5
    m.video.errorStr = "buffering is stalled"
    m.audioCheck = {control: "stop"}
    m.noticeText = {text: ""}
    m.notice = {visible: false}
    m.noticeTimer = {control: "stop"}
    m.startupRetryCount = 0
    m.startupRetryLimit = 1
    beginStartupWatch(m.video.content)
    onVideoState()
    assertEqual(m.startupRetryCount, 1, "actual Video error handler routes startup stall to bounded retry")
    assertEqual(m.video.content.serial, 2, "actual error path replaces local content")
    assertEqual(m.video.content.url, "https://example.test/live?output_profile=7", "error path retains audio profile")
    assertEqual(m.top.dialog, invalid, "retry does not open terminal failure dialog")
    m.playingChannel = invalid
    m.video.state = "stopped"
    m.sourceWatch = {control: "stop"}
    m.baseUrl = "https://example.test"
    m.accountIdentity = "account-one"
    m.devicePreferences.audioMode = "aac"
    m.aacProfile = invalid
    m.aacDiscoveryState = "pending"
    m.capabilityTask = {}
    m.aacWaitTimer = {control: "stop"}
    startPlayback({uuid: "waiting-id", name: "Waiting channel"})
    assertEqual(m.pendingAacTune.channel.uuid, "waiting-id", "actual tune path defers mandatory AAC")
    assertEqual(m.video.content.serial, 2, "no replacement/direct media content created while profile pending")
    assertEqual(m.startupWatch, invalid, "startup-recovery clock does not run during profile discovery")
    assertEqual(onKeyEvent("back", true), true, "Back cancels deferred AAC tune")
    assertEqual(m.pendingAacTune, invalid, "cancelled profile wait cannot tune later")
    pendingRecording = {control: "RUN"}
    m.recordTask = pendingRecording
    m.recordDialog = {title: "existing picker"}
    m.refreshTask = {isSameNode: function(node as object) as boolean
        return true
    end function, unobserveField: sub(field as string)
    end sub}
    onLineupRefresh({getRoSGNode: function() as object
        return {}
    end function, getData: function() as object
        return {ok: false, message: "try again"}
    end function})
    assertEqual(m.recordTask.control, "RUN", "failed lineup refresh keeps recording Task owned")
    assertEqual(m.recordDialog.title, "existing picker", "failed lineup refresh does not orphan dialog")
    m.preferenceStore = defaultPreferenceStore()
    m.accountPreferences = normalizeAccountPreferences(invalid)
    m.vod = {savedState: []}
    m.registry = {data: "", failWrite: false, failFlush: false
        read: function(key as string) as string
            return m.data
        end function
        write: function(key as string, value as string) as boolean
            if m.failWrite then return false
            m.data = value
            return true
        end function
        flush: function() as boolean
            return not m.failFlush
        end function
    }
    savedItem = vodNormalize({id: 301, uuid: "saved-item", name: "Saved"}, "movie")
    saveVodChange(savedItem, {watchlist: true})
    assertEqual(m.vod.savedState[0].watchlist, true, "scene saves explicit choice")
    saveVodChange(savedItem, {favorite: true})
    assertEqual(m.vod.savedState[0].favorite, true, "favorite persists independently of to watch")
    m.mediaHistoryRecorded = false
    saveVodChange(savedItem, {position: 80, duration: 900}, true)
    assertEqual(m.vod.history.count(), 1, "playing progress records recent title")
    assertEqual(m.mediaHistoryRecorded, true, "successful history write records session")
    replacement = vodNormalize({id: 302, uuid: "next-item", name: "Next"}, "movie")
    m.registry.failWrite = true
    m.mediaHistoryRecorded = false
    saveVodChange(replacement, {hidden: true}, true)
    assertEqual(m.vod.savedState.count(), 1, "failed save restores shelf")
    assertEqual(m.vod.history.count(), 1, "failed save restores playback history")
    assertEqual(m.mediaHistoryRecorded, false, "failed save can retry recording")
    assertEqual(m.accountPreferences.vod.count(), 1, "failed save restores account state")
    assertEqual(m.preferenceStore.accounts[preferenceScope(m.accountIdentity)].vod.count(), 1, "failed save restores preference store")
    assertEqual(vodStateEntry(loadPreferenceStore(m.registry).accounts[preferenceScope(m.accountIdentity)].vod, savedItem).watchlist, true, "failed save preserves registry")
    m.registry.failWrite = false
    m.registry.failFlush = true
    saveVodChange(replacement, {hidden: true})
    assertEqual(m.vod.savedState.count(), 1, "failed flush restores shelf")
    assertEqual(m.preferenceStore.accounts[preferenceScope(m.accountIdentity)].vod.count(), 1, "failed flush restores preference store")
    m.registry.failFlush = false
    for i = 2 to 40
        item = vodNormalize({id: 400 + i, uuid: "pin-" + i.toStr(), name: "Pinned"}, "movie")
        saveVodChange(item, {hidden: true})
    end for
    assertEqual(m.vod.savedState.count(), 40, "scene retains all explicit choices")
    saveVodChange(replacement, {watchlist: true})
    assertEqual(m.vod.savedState.count(), 40, "full shelf cannot evict older choice")
    assertEqual(m.noticeText.text.instr(0, "Saved titles are full") >= 0, true, "visible capacity notice")
    m.mediaHistoryRecorded = false
    saveVodChange(replacement, {watched: true, position: 0, duration: 20}, true)
    assertEqual(m.vod.savedState.count(), 40, "completion cannot evict curated choices")
    assertEqual(m.vod.history[0].key, replacement.key, "completed play records history even when watched marker is full")
    m.accountPreferences.vodRecent = []
    m.vod.history = []
    m.mediaPlayer = {isSameNode: function(node as object) as boolean
        return true
    end function}
    m.mediaItem = savedItem
    m.mediaIdentity = "vod-session"
    m.mediaHistoryRecorded = false
    m.lastVodWrite = 0
    m.lastVodState = ""
    onMediaProgress(vodProgressEvent({account: m.accountIdentity, identity: "vod-session", key: savedItem.key, mode: "vod", state: "buffering", position: 0, duration: 900, finished: false, closing: false}))
    assertEqual(m.vod.history.count(), 0, "buffering cannot record recently watched")
    onMediaProgress(vodProgressEvent({account: "other-account", identity: "vod-session", key: savedItem.key, mode: "vod", state: "playing", position: 10, duration: 900, finished: false, closing: false}))
    assertEqual(m.vod.history.count(), 0, "another account cannot record recent title")
    onMediaProgress(vodProgressEvent({account: m.accountIdentity, identity: "vod-session", key: savedItem.key, mode: "vod", state: "playing", position: 10, duration: 900, finished: false, closing: false}))
    assertEqual(m.vod.history.count(), 1, "confirmed playing progress records recently watched")
    assertEqual(m.mediaHistoryRecorded, true, "one recording per playback session")
    m.vod.config = {accountScope: "account-one"}
    m.vod.isSameNode = function(node as object) as boolean
        return true
    end function
    m.baseUrl = "https://example.test"
    m.serverAccountId = "1"
    m.registry.failWrite = true
    onVodStateChange(vodProgressEvent({scope: "account-one", clearHistory: true}))
    assertEqual(m.vod.history.count(), 1, "failed clear restores history")
    m.registry.failWrite = false
    onVodStateChange(vodProgressEvent({scope: "account-one", removeHistoryKey: savedItem.key}))
    assertEqual(m.vod.history.count(), 0, "history removal is separate from favorite and watchlist")
    assertEqual(vodStateEntry(m.accountPreferences.vod, savedItem).favorite, true, "history removal retains curated choice")
    m.guide = {active: false, visible: false, miniActive: false, epgRequests: 0, callFunc: function(name as string) as boolean
        if name <> "beginEpgLaunch" then return false
        m.epgRequests++
        m.requestedBeforeActive = not m.active and m.visible
        return true
    end function}
    m.playingChannel = {uuid: "a", name: "Live channel"}
    m.video.state = "playing"
    m.video.content = {programId: "a"}
    m.videoViewport = {}
    m.miniFrame = {visible: false}
    m.miniCaption = {text: ""}
    m.screen = {visible: false}
    m.page = "player"
    m.mini = false
    m.userInfoOpen = false
    m.playerOptions.active = false
    m.browser.active = false
    m.transport.active = false
    m.banner.visible = false
    minimizePlayback(true)
    assertEqual(m.guide.epgRequests, 1, "remote return asks GuideView to start EPG measurement")
    assertEqual(m.guide.requestedBeforeActive, true, "EPG initiate precedes guide activation")
    assertEqual(m.guide.active, true, "guide activates after remote request")
    assertEqual(m.video.content.programId, "a", "EPG return keeps the same live stream")
    m.page = "player"
    m.mini = false
    m.guide.active = false
    minimizePlayback()
    assertEqual(m.guide.epgRequests, 1, "programmatic return does not invent an EPG keypress")
    oldTask = {id: "old", cancelRequested: false, unobserveField: sub(field as string)
        m.unobserved = true
    end sub, isSameNode: function(other as object) as boolean
        return m.id = other.id
    end function}
    m.hlsPendingMints = [{task: oldTask, content: m.video.content, baseUrl: "https://example.test", apiKey: "old-key"}]
    m.hlsMintTask = oldTask
    cancelHlsMint()
    assertEqual(oldTask.cancelRequested, true, "retune marks pending mint for owner cleanup")
    assertEqual(m.hlsMintTask, invalid, "cancelled mint cannot become current playback")
    onHlsSessionOpened({node: oldTask, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return {ok: false, status: 200}
    end function})
    assertEqual(m.hlsPendingMints.count(), 0, "cancelled mint releases task reference after cleanup")
    currentTask = {id: "current", cancelRequested: false, unobserveField: sub(field as string)
    end sub, isSameNode: function(other as object) as boolean
        return m.id = other.id
    end function}
    m.video.content = lifecycleRetryContent(10)
    m.playingChannel = {uuid: "a"}
    m.hlsMintTask = currentTask
    m.hlsPendingMints = [{task: currentTask, content: m.video.content, baseUrl: "https://example.test", apiKey: "current-key"}]
    onHlsSessionOpened({node: currentTask, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return {ok: true, status: 200, token: "opaque_1234567890abcdefghijklmnop", url: "https://example.test/proxy/hls/opaque_1234567890abcdefghijklmnop/index.m3u8"}
    end function})
    assertEqual(m.hlsMintTask, invalid, "successful mint is no longer pending")
    assertEqual(m.hlsSession.baseUrl, "https://example.test", "owner account context retained for disconnect")
    assertEqual(m.hlsSession.apiKey, "current-key", "owner key retained across later connection changes")
    assertEqual(m.video.control, "play", "native player starts only after owned session is captured")
    assertEqual(m.video.content.url, "https://example.test/proxy/hls/opaque_1234567890abcdefghijklmnop/index.m3u8", "native Video reuses minted capability instead of opening another client")
    print "ALL TESTS PASSED"
end sub

function vodProgressEvent(value as object) as object
    return {data: value, getRoSGNode: function() as object
        return {}
    end function, getData: function() as object
        return m.data
    end function}
end function

function lifecycleRetryContent(serial as integer) as object
    return {serial: serial, url: "https://example.test/live?output_profile=7", isSameNode: function(other as object) as boolean
        return m.serial = other.serial
    end function, clone: function(deep as boolean) as object
        return lifecycleRetryContent(m.serial + 1)
    end function}
end function

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
