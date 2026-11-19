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
    m.pendingLaunch = {kind: "live", id: "unavailable-channel"}
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
    m.startupGuideReady = false
    m.page = "welcome"
    m.top.launchRequest = {contentId: "27", mediaType: "movie"}
    onLaunchRequest()
    signalStartupComplete()
    assertEqual(m.pendingLaunch.kind, "movie", "first-run VOD link remains pending on Welcome")
    m.global = {profilegateclosed: true}
    m.page = "guide"
    handlePendingLaunch()
    assertEqual(m.pendingLaunch.id, "27", "PIN cover defers an otherwise valid VOD link")
    m.pendingLaunch = invalid
    m.global = invalid
    m.page = "welcome"
    m.top.launchRequest = {mediaType: "MoViE", contentId: "not-numeric"}
    onLaunchRequest()
    assertEqual(m.pendingLaunch, invalid, "malformed movie does not become a pending request")
    m.accountPreferences = {startupBehavior: "mini", lastChannel: "startup-channel"}
    m.notice.visible = false
    startConfiguredMiniPlayback([])
    assertEqual(m.notice.visible, false, "malformed cold VOD does not enter unrelated startup channel selection")
    m.startupVodIntent = false
    startConfiguredMiniPlayback([])
    assertEqual(m.notice.visible, true, "ordinary mini startup still looks up the saved channel")
    runProvisionalVodLaunchChecks()
    runFirstRunVodOnboardingChecks()
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
    m.playingChannel.id = "4"
    m.capabilities.switchStreams = "allowed"
    m.channelFacts = normalizeChannelCapabilities([{id: 4, uuid: "a", effective_is_radio: true}])
    m.video.content.isSameNode = function(other as object) as boolean
        return other.programId = m.programId
    end function
    m.sourceWatch = {control: "start"}
    m.sourceWatchState = {content: m.video.content, ticks: 0, stalls: 0, previous: {audio: 1.0, video: 1.0}}
    m.video.positionInfo = {audio: 4.0, video: 1.0}
    checkSourceVideo()
    assertEqual(m.sourceWatchState.stalls, 0, "radio audio without video does not count as a picture stall")
    openPlayerOptions()
    assertEqual(playerOptionsHasAction("recoverPicture"), false, "Dispatcharr radio detail hides picture-only control")
    recoverFrozenPicture()
    assertEqual(m.video.content.programId, "a", "stale picture-recovery selection does not reopen declared radio")
    m.channelFacts = normalizeChannelCapabilities([{id: 4, uuid: "a", effective_is_radio: false}])
    m.video.positionInfo = {audio: 7.0, video: 1.0}
    checkSourceVideo()
    assertEqual(m.sourceWatchState.stalls, 1, "ordinary video still detects frozen picture during audio progress")
    m.sourceWatchState = invalid
    openPlayerOptions()
    assertEqual(playerOptionsHasAction("recoverPicture"), true, "ordinary video retains picture recovery")
    m.capabilities.switchStreams = "denied"
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
    runStartupLiveLinkChecks()
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
    m.profileSetupCredentialContext = invalid
    m.childConnectionLoading = false
    m.selectedConnectionId = "slot-sync"
    m.activeUserScope = invalid
    m.userProfileRecoveryRequired = true
    m.profileSwitchContext = {connection: {id: "slot-sync"}, outgoing: invalid}
    m.profileSwitchTask = invalid
    m.profileSyncContext = {flushNonce: "sync-request"}
    m.global = {profilegateclosed: true, profilesyncflush: "sync-request"}
    m.profileGateCover = {visible: true}
    m.top.exitRequested = false
    m.top.findNode = function(id as string) as object
        return {text: ""}
    end function
    flushTask = {apiKey: "synthetic-own"
        unobserveField: sub(field as string)
        end sub
    }
    m.profileSyncWriteTask = flushTask
    assertEqual(onKeyEvent("back", true), true, "Back during fenced outgoing flush is handled as switch cancellation")
    assertEqual(m.top.exitRequested, false, "outgoing flush Back must not fall through to protected-launch app exit")
    assertEqual(m.profileSyncWriteTask, invalid, "outgoing flush cancellation retires its actual Task")
    assertEqual(flushTask.apiKey, "", "cancelled outgoing flush clears captured own credentials")
    checkRecoveryReadyRadioClassification()
    checkOwnedHlsRetryLifecycle()
    checkOwnedHlsStartupFailureBoundaries()
    checkFocusedRecoveryResume()
    checkPictureRecoveryPauseIsolation()
    checkPictureRecoveryPauseCleanup()
    print "ALL TESTS PASSED"
end sub

sub checkRecoveryReadyRadioClassification()
    m.global = {activeusersession: "recovery-session"}
    m.hlsSession = invalid
    m.playingChannel = {id: "4", uuid: "a", isRadio: false}
    for each declaredRadio in [true, false]
        bridge = {id: "bridge", aeriosession: "recovery-session", ready: true, release: false, detached: [], isSameNode: function(other as object) as boolean
            return m.id = other.id
        end function, unobserveField: sub(field as string)
            m.detached.push(field)
        end sub}
        ready = {node: bridge, getRoSGNode: function() as object
            return m.node
        end function, getData: function() as boolean
            return true
        end function}
        m.channelFacts = {}
        m.video = {content: lifecycleRetryContent(10), control: "pause"}
        m.streamReady = true
        m.decoderSnapshot = {renderCount: 12}
        m.recoveryContent = m.video.content
        m.recoveryPaused = true
        m.recoveryPausePending = false
        m.recoveryIssued = false
        m.recoveryTask = bridge
        ' Metadata arrives after recovery has acquired its own temporary bridge.
        m.channelFacts = normalizeChannelCapabilities([{id: 4, uuid: "a", effective_is_radio: declaredRadio}])
        onRecoveryReady(ready)
        if declaredRadio
            assertEqual(m.video.content.serial, 10, "late radio classification keeps original content")
            assertEqual(m.video.control, "pause", "late radio classification does not write playback controls")
            assertEqual(m.streamReady, true, "late radio classification preserves stream readiness")
            assertEqual(m.decoderSnapshot.renderCount, 12, "late radio classification preserves decoder state")
            assertEqual(m.recoveryIssued, false, "late radio classification does not issue restart")
            assertEqual(m.recoveryPausePending, false, "late radio classification does not queue a pause")
            assertEqual(bridge.release, true, "owned bridge is released for task-side cleanup")
            assertEqual(bridge.detached.join(","), "ready,result", "release detaches both bridge callbacks")
            assertEqual(m.recoveryTask, invalid, "released bridge is no longer current")
            assertEqual(m.recoveryContent, invalid, "released recovery drops content reference")
        else
            assertEqual(m.video.content.serial, 11, "ordinary video still clones and restarts content")
            assertEqual(m.video.control, "play", "ordinary video restarts the local decoder")
            assertEqual(m.streamReady, false, "ordinary video waits for new readiness")
            assertEqual(m.recoveryIssued, true, "ordinary video issues restart")
            assertEqual(m.recoveryPausePending, true, "ordinary video preserves requested pause")
            assertEqual(bridge.release, false, "ordinary video holds bridge until replacement is playing")
            assertEqual(bridge.detached.count(), 0, "ordinary video keeps its bridge callbacks")
        end if
    end for

    ' Resume while the temporary bridge is still starting. A later callback
    ' must honor that command even before Video publishes its new state.
    m.recoveryIssued = false
    clearPictureRecoveryPause()
    m.recoveryContent = m.video.content
    m.video.state = "paused"
    togglePause()
    assertEqual(m.video.control, "resume", "viewer resumes before bridge readiness")
    onRecoveryReady(ready)
    assertEqual(m.recoveryPausePending, false, "decoder replacement does not reapply stale pause")

    m.recoveryIssued = false
    clearPictureRecoveryPause()
    m.recoveryContent = m.video.content
    m.video.state = "playing"
    togglePause()
    assertEqual(m.video.control, "pause", "viewer pauses before bridge readiness")
    onRecoveryReady(ready)
    assertEqual(m.recoveryPausePending, true, "decoder replacement preserves the new pause request")

    for each hidden in [false, true]
        m.top = {dialog: invalid}
        m.page = "player"
        m.pictureCover = {visible: hidden}
        m.pictureWakeKey = ""
        m.playerOptions = {active: false}
        m.browser = {active: false}
        m.transport = {active: false}
        m.heldZap = ""
        m.profileSwitchContext = invalid
        m.recoveryIssued = false
        clearPictureRecoveryPause()
        m.video.state = "playing"
        m.recoveryPaused = false
        m.recoveryContent = m.video.content
        togglePause()
        assertEqual(m.video.control, "pause", "manual Pause queues while Video still reports playing")
        assertEqual(onKeyEvent("playonly", true), true, "playonly handled in the player")
        assertEqual(m.video.control, "resume", "playonly supersedes pending Pause before Video ack")
        onRecoveryReady(ready)
        assertEqual(m.recoveryPausePending, false, "decoder replacement honors playonly before ack")

        m.recoveryIssued = false
        clearPictureRecoveryPause()
        m.recoveryPaused = true
        m.video.state = "paused"
        m.recoveryContent = m.video.content
        assertEqual(onKeyEvent("playonly", true), true, "playonly handles acknowledged pause")
        assertEqual(m.video.control, "resume", "playonly resumes paused Video")
        onRecoveryReady(ready)
        assertEqual(m.recoveryPausePending, false, "decoder replacement does not reapply pause after playonly")

        m.recoveryPausePending = true
        m.recoveryPaused = true
        assertEqual(onKeyEvent("playonly", true), true, "playonly updates the already issued replacement")
        assertEqual(m.recoveryPausePending, false, "playonly cancels deferred pause on replacement")
        assertEqual(m.video.control, "play", "playonly does not overwrite replacement startup control")
    end for
end sub

sub resetOwnedHlsFixture()
    m.hlsSessionTaskFactory = function() as object
        m.hlsTestSerial++
        return {id: m.hlsTestSerial, cancelRequested: false, observeField: sub(field as string, callback as string)
            m.callback = callback
        end sub, unobserveField: sub(field as string)
            m.callback = ""
        end sub, isSameNode: function(other as object) as boolean
            return m.id = other.id
        end function}
    end function
    m.hlsTestSerial = 0
    m.hlsMintTask = invalid
    m.hlsSession = invalid
    m.top = {dialog: invalid}
    m.playbackFailureDialogFactory = function() as object
        return {observeField: sub(field as string, callback as string)
        end sub, unobserveField: sub(field as string)
        end sub}
    end function
    m.global = {activeusersession: "hls-test-owner"}
    m.baseUrl = "https://example.test"
    m.apiKey = "fixture-key"
    m.page = "player"
    m.playingChannel = {uuid: "a", name: "Local fixture"}
    m.video = {control: "stop", state: "none", pauseBufferOverflow: false, content: lifecycleRetryContent(10), setFocus: function(focused as boolean) as boolean
        return true
    end function}
    for each field in ["heldZapTimer", "pictureHintTimer", "sourceWatch", "playerClock", "channelTuneTimer", "bannerTimer", "audioCheck"]
        m[field] = {control: "stop"}
    end for
    for each field in ["browser", "guide", "transport", "miniFrame", "playerOptions", "pictureCover"]
        m[field] = {visible: false, active: false}
    end for
    m.banner = {playbackState: "", visible: false}
    m.noticeText = {text: ""}
    m.notice = {visible: false}
    m.noticeTimer = {control: "stop"}
    m.recoveryTask = invalid
    m.sourceTask = invalid
    m.sourceWatchState = invalid
    m.hlsPendingMints = []
    m.hlsStopTasks = []
    m.startupRetryLimit = 1
    m.startupRetryCount = 0
    m.liveRetryCount = 0
    m.streamReady = false
    m.pendingChannel = invalid
    m.heldZap = ""
    m.accountIdentity = "fixture-account"
    m.devicePreferences = normalizeDevicePreferences(invalid)
    m.accountPreferences = normalizeAccountPreferences(invalid)
    m.channelFacts = {}
    m.liveSession = invalid
    m.recordedChannel = m.playingChannel.uuid
    m.serverAccountId = ""
    m.sleepDeadline = 0
    m.video.globalCaptionMode = "Off"
end sub

sub checkOwnedHlsRetryLifecycle()
    resetOwnedHlsFixture()
    entry = "https://example.test/proxy/ts/stream/fixture?output_format=hls&output_profile=7"
    legacy = "https://example.test/proxy/ts/stream/fixture?output_format=mpegts"
    m.video.content.url = legacy
    m.playbackBridgeTaskFactory = m.hlsSessionTaskFactory
    m.capabilities = {switchStreams: "allowed"}
    recoverFrozenPicture()
    assertEqual(m.recoveryTask.url, legacy, "legacy TS bridge passes through the current reader URL")
    cancelPictureRecovery()
    openPlayerOptions()
    assertEqual(playerOptionsHasAction("recoverPicture"), true, "legacy picture recovery action exists before mint")
    m.video.content.url = entry
    beginOwnedHlsPlayback(m.video.content)
    onPlayerOption({getData: function() as object
        return {action: "recoverPicture"}
    end function})
    assertEqual(m.recoveryTask = invalid, true, "a stale Options action cannot open the raw mint entry")
    openPlayerOptions()
    assertEqual(playerOptionsHasAction("recoverPicture"), false, "new Options menu hides recovery during mint")
    recoverFrozenPicture()
    assertEqual(m.recoveryTask = invalid, true, "direct recovery handler also cannot open a pending entry")
    m.playerOptions.active = false
    oldToken = "opaque_first_12345678"
    onHlsSessionOpened(hlsFixtureEvent(m.hlsMintTask, hlsFixtureResult(oldToken)))
    m.video.content.url = entry
    recoverFrozenPicture()
    assertEqual(m.recoveryTask = invalid, true, "an owned session never authorizes a changed entry URL")
    m.video.content.url = hlsFixtureResult(oldToken).url
    m.global.activeUserSession = "unrelated-session"
    recoverFrozenPicture()
    assertEqual(m.recoveryTask = invalid, true, "another profile cannot open the owned playlist")
    m.global.activeUserSession = "hls-test-owner"
    recoverFrozenPicture()
    assertEqual(m.recoveryTask.url, m.video.content.url, "owned recovery opens only the minted playlist")
    assertEqual(m.recoveryTask.apiKey, "fixture-key", "owned bridge uses the captured owner's key")
    cancelPictureRecovery()
    m.video.state = "buffering"
    assertEqual(retryStartupPlayback(), true, "owned HLS startup retry admitted once")
    assertEqual(m.hlsStopTasks.count(), 1, "startup retry queues one owner close")
    oldClose = m.hlsStopTasks[0]
    assertEqual(oldClose.token, oldToken, "startup retry closes the old token")
    assertEqual(oldClose.apiKey, "fixture-key", "close uses original owner")
    assertEqual(m.video.control, "stop", "reader waits for replacement mint")
    mint = m.hlsMintTask
    assertEqual(mint.entryUrl, entry, "startup retry mints from original entry and profile")
    m.video.state = "finished"
    onVideoState()
    assertEqual(m.hlsMintTask.isSameNode(mint), true, "outgoing Video finish cannot cancel a pending mint")
    assertEqual(m.startupRetryCount, 1, "mint does not reset the startup budget")
    secondToken = "opaque_second_12345678"
    onHlsSessionOpened(hlsFixtureEvent(mint, hlsFixtureResult(secondToken)))
    onHlsSessionOpened(hlsFixtureEvent(mint, hlsFixtureResult(secondToken)))
    onHlsSessionClosed(hlsFixtureEvent(oldClose, {status: 204}))
    assertEqual(m.hlsStopTasks.count(), 0, "duplicate mint and completed close do not enqueue another close")
    assertEqual(m.hlsSession.token, secondToken, "old close cannot clear replacement ownership")
    assertEqual(m.video.control, "play", "only replacement result starts Video")
    assertEqual(m.startupWatch.recovering, true, "startup retry watch survives asynchronous mint")
    assertEqual(m.startupWatch.waitForSources, true, "owned startup retry retains its source wait")
    onVideoState()
    assertEqual(m.hlsSession <> invalid, true, "late outgoing finish cannot close minted replacement before progress")
    assertEqual(m.hlsSession.token, secondToken, "late finish preserves the replacement token")
    assertEqual(m.hlsStopTasks.count(), 0, "late finish issues no close")
    m.video.state = "paused"
    m.streamReady = true
    assertEqual(retryInterruptedLive("buffering", -2, ""), false, "paused owner keeps the same session")
    assertEqual(m.hlsStopTasks.count(), 0, "pause sends no close")
    m.video.state = "finished"
    assertEqual(retryInterruptedLive("finished", 0, ""), true, "owned midstream reconnect admitted")
    assertEqual(m.hlsStopTasks.count(), 1, "midstream reconnect closes just its previous owner")
    assertEqual(m.hlsStopTasks[0].token, secondToken, "midstream close cannot target older token")
    mint = m.hlsMintTask
    assertEqual(mint.entryUrl, entry, "midstream reconnect remints the original entry")
    thirdToken = "opaque_third_12345678"
    onHlsSessionOpened(hlsFixtureEvent(mint, hlsFixtureResult(thirdToken)))
    assertEqual(m.startupWatch.waitForSources, false, "midstream replacement retains the shorter watchdog")
    assertEqual(m.startupRetryCount, m.startupRetryLimit, "midstream replacement cannot reset startup budget")
    m.streamReady = true
    assertEqual(retryInterruptedLive("finished", 0, ""), false, "successful mint does not replenish reconnect budget")
    onTransportAction({getData: function() as string
        return "stop"
    end function})
    stopPlayback()
    assertEqual(m.hlsStopTasks.count(), 2, "app Stop closes current owner exactly once")
    assertEqual(m.hlsStopTasks[1].token, thirdToken, "Stop targets only the current owner token")
    assertEqual(m.video.content, invalid, "Stop clears the reader")

    m.playingChannel = {uuid: "new"}
    m.video.content = lifecycleRetryContent(20)
    beginOwnedHlsPlayback(m.video.content)
    staleMint = m.hlsMintTask
    cancelHlsMint()
    m.global.activeUserSession = "new-owner"
    m.apiKey = "new-fixture-key"
    m.video.content = lifecycleRetryContent(21)
    beginOwnedHlsPlayback(m.video.content)
    currentMint = m.hlsMintTask
    onHlsSessionOpened(hlsFixtureEvent(staleMint, hlsFixtureResult(oldToken)))
    onHlsSessionOpened(hlsFixtureEvent(staleMint, hlsFixtureResult(oldToken)))
    assertEqual(m.hlsStopTasks.count(), 3, "late successful mint closes once despite duplicate callback")
    assertEqual(m.hlsStopTasks[2].apiKey, "fixture-key", "old mint cleans up under captured owner")
    assertEqual(m.hlsMintTask.isSameNode(currentMint), true, "late mint cannot replace current task")
    assertEqual(m.video.control, "stop", "late mint cannot start Video")

    fourthToken = "opaque_fourth_12345678"
    onHlsSessionOpened(hlsFixtureEvent(currentMint, hlsFixtureResult(fourthToken)))
    m.connectionStore = {entries: [{id: "fixture-m3u", provider: "m3u", authMode: "authorization", userAgent: "Fixture Player/1.0"}]}
    m.selectedConnectionId = "fixture-m3u"
    m.accountIdentity = "fixture-account"
    m.devicePreferences = normalizeDevicePreferences(invalid)
    m.accountPreferences = normalizeAccountPreferences(invalid)
    m.videoViewport = {}
    m.screen = {}
    m.guide.callFunc = function(name as string, channel as dynamic, now = 0 as integer) as dynamic
        return invalid
    end function
    m.video.setFocus = function(focused as boolean) as boolean
        return true
    end function
    startPlayback({uuid: "direct-m3u", name: "Direct fixture", number: "2", streamUrl: "https://other.test/live.ts?label=guide.m3u8"})
    assertEqual(m.hlsStopTasks.count(), 4, "retune to a direct feed retires only the old owned session")
    assertEqual(m.hlsStopTasks[3].token, fourthToken, "retune closes the outgoing token")
    assertEqual(m.hlsStopTasks[3].apiKey, "new-fixture-key", "retune uses the outgoing token's owner")
    assertEqual(m.hlsMintTask, invalid, "direct feed does not mint a Dispatcharr session")
    assertEqual(m.video.content.streamFormat, "ts", "direct TS playback uses the actual path")
    assertEqual(m.video.content.httpHeaders[0], "User-Agent: Fixture Player/1.0", "direct reader gets custom User-Agent")
    assertEqual(m.video.content.httpHeaders.count(), 1, "Dispatcharr credential is not sent to direct feed")

    m.connectionStore = {entries: [{id: "fixture-dispatcharr", provider: "dispatcharr", authMode: "x-api-key", userAgent: ""}]}
    m.selectedConnectionId = "fixture-dispatcharr"
    m.devicePreferences.liveTransport = "hls"
    startPlayback({uuid: "first-retune", name: "First retune", number: "3"})
    superseded = m.hlsMintTask
    startPlayback({uuid: "second-retune", name: "Second retune", number: "4"})
    assertEqual(superseded.cancelRequested, true, "second retune cancels first pending mint")
    retiredToken = "opaque_retired_12345678"
    onHlsSessionOpened(hlsFixtureEvent(superseded, hlsFixtureResult(retiredToken)))
    assertEqual(m.hlsStopTasks[4].token, retiredToken, "superseded retune closes only its own late token")
    latestToken = "opaque_latest_12345678"
    onHlsSessionOpened(hlsFixtureEvent(m.hlsMintTask, hlsFixtureResult(latestToken)))
    m.video.state = "finished"
    onVideoState()
    assertEqual(m.hlsSession.token, latestToken, "rapid retunes preserve outgoing-reader protection")
    assertEqual(m.hlsStopTasks.count(), 5, "outgoing finish does not close the latest token")
    stopPlayback()
    assertEqual(m.hlsStopTasks[5].token, latestToken, "explicit Stop still closes the latest token")
end sub

sub checkOwnedHlsStartupFailureBoundaries()
    for each scenario in ["timeout", "stopped", "second-finish", "progress", "error", "late-finish", "initial-finish"]
        resetOwnedHlsFixture()
        m.startupRetryCount = m.startupRetryLimit
        mintOwnedHlsPlayback(m.video.content, m.baseUrl, m.apiKey, true, false, scenario <> "initial-finish")
        token = "opaque_failure_12345678"
        onHlsSessionOpened(hlsFixtureEvent(m.hlsMintTask, hlsFixtureResult(token)))
        m.startupWatch.clock = {ms: 0, totalMilliseconds: function() as integer
            return m.ms
        end function}
        if scenario = "progress"
            m.video.state = "buffering"
            onVideoState()
        else if scenario = "late-finish"
            m.startupWatch.clock.ms = 2001
        end if
        m.video.state = "finished"
        if scenario = "error"
            m.video.state = "error"
            m.video.errorCode = -1
            m.video.errorStr = "reader failed"
        else if scenario = "stopped"
            m.video.state = "stopped"
        else if scenario = "second-finish"
            m.activeAudioProfile = "7"
            m.aacDecodeRetried = true
        end if
        if scenario = "stopped"
            m.startupWatch.clock.ms = 25000
            checkStartupPlayback()
        end if
        onVideoState()
        if scenario = "timeout" or scenario = "second-finish"
            assertEqual(m.hlsSession <> invalid, true, "one ambiguous immediate finish keeps ownership: " + scenario)
            assertEqual(m.hlsStopTasks.count(), 0, "one ambiguous finish must not close: " + scenario)
            if scenario = "timeout"
                m.startupWatch.clock.ms = 24999
                checkStartupPlayback()
                assertEqual(m.hlsSession <> invalid, true, "existing deadline is not shortened")
                m.startupWatch.clock.ms = 25000
                checkStartupPlayback()
            else
                onVideoState()
            end if
        end if
        assertEqual(m.hlsSession, invalid, "genuine startup failure clears ownership: " + scenario)
        assertEqual(m.hlsStopTasks.count(), 1, "genuine startup failure queues one close: " + scenario)
        assertEqual(m.hlsStopTasks[0].token, token, "failure closes only its own token: " + scenario)
        assertEqual(m.hlsMintTask, invalid, "exhausted startup budget cannot remint: " + scenario)
        assertEqual(m.playbackRetry.channel.uuid, "a", "manual retry remains available: " + scenario)
        onVideoState()
        assertEqual(m.hlsStopTasks.count(), 1, "later Video callback cannot double-close: " + scenario)
    end for
end sub

function startPictureRecoveryFixture() as object
    resetOwnedHlsFixture()
    m.playbackBridgeTaskFactory = m.hlsSessionTaskFactory
    m.mini = false
    m.video.state = "playing"
    m.streamReady = true
    recoverFrozenPicture()
    bridge = m.recoveryTask
    bridge.ready = true
    return bridge
end function

sub checkFocusedRecoveryResume()
    bridge = startPictureRecoveryFixture()
    togglePause() ' Issued but not yet acknowledged by Video.
    assertEqual(m.video.control, "pause", "Pause before focused Resume is outstanding")
    onTransportAction({getData: function() as string
        return "playonly"
    end function})
    assertEqual(m.video.control, "resume", "focused action reaches the latest manual intent setter")
    onRecoveryReady(hlsFixtureEvent(bridge, true))
    assertEqual(m.recoveryPausePending, false, "focused Resume supersedes pre-ack Pause in the bridge")
end sub

sub checkPictureRecoveryPauseIsolation()
    bridge = startPictureRecoveryFixture()
    onRecoveryReady(hlsFixtureEvent(bridge, true))
    onRecoveryFinished(hlsFixtureEvent(bridge, {ok: true, source: "same", beforeCount: 1, afterCount: 1}))
    m.video.state = "playing"
    onVideoState()
    assertEqual(m.video.control, "play", "the exact replacement starts resumed")

    m.video.state = "finished"
    onVideoState()
    assertEqual(m.liveRetryCount, 1, "later unexpected finish starts an ordinary reconnect")
    m.video.state = "buffering"
    onTransportAction({getData: function() as string
        return "play"
    end function})
    assertEqual(m.recoveryPausePending, false, "completed picture recovery cannot defer Pause into ordinary reconnect")
    m.video.state = "playing"
    onVideoState()
    assertEqual(m.video.control, "play", "unrelated reconnect is not paused by the completed bridge")
end sub

sub checkPictureRecoveryPauseCleanup()
    for each outcome in ["ready", "ready-after-bridge", "paused", "failure", "video-error", "abandoned", "stop"]
        bridge = startPictureRecoveryFixture()
        togglePause()
        onRecoveryReady(hlsFixtureEvent(bridge, true))
        replacement = m.video.content
        onRecoveryReady(hlsFixtureEvent(bridge, true))
        assertEqual(m.video.content.isSameNode(replacement), true, "ready callback still restarts only once")
        assertEqual(m.recoveryPausePending, true, "pause initially belongs to the replacement")

        if outcome = "failure"
            onRecoveryFinished(hlsFixtureEvent(bridge, {ok: false, source: "unknown", beforeCount: 1, afterCount: 0}))
        else if outcome = "stop"
            stopPlayback()
        else
            if outcome = "ready-after-bridge"
                onRecoveryFinished(hlsFixtureEvent(bridge, {ok: true, source: "same", beforeCount: 1, afterCount: 1}))
                assertEqual(m.recoveryPausePending, true, "successful bridge exit does not clear its still-starting replacement")
            end if
            m.video.state = "playing"
            if outcome = "paused" then m.video.state = "paused"
            if outcome = "abandoned" then m.video.content = lifecycleRetryContent(99)
            if outcome = "video-error"
                m.video.state = "error"
                m.video.errorCode = -1
                m.video.errorStr = "reader failed"
            end if
            onVideoState()
        end if
        assertEqual(m.recoveryPauseContent, invalid, "reader-specific intent cleared on " + outcome)
        assertEqual(m.recoveryPausePending, false, "pause flag cleared on " + outcome)
        if outcome = "ready" or outcome = "ready-after-bridge"
            assertEqual(m.video.control, "pause", "exact replacement honors Pause once")
            if outcome = "ready" then assertEqual(bridge.release, true, "ordinary readiness still releases the bridge")
            onVideoState()
            assertEqual(m.recoveryPauseContent, invalid, "duplicate readiness does not rearm pause")
        else if outcome <> "stop" and outcome <> "video-error"
            assertEqual(m.video.control, "play", "no stale pause write on " + outcome)
        end if
    end for
end sub

function hlsFixtureEvent(node as object, data as dynamic) as object
    return {node: node, data: data, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as dynamic
        return m.data
    end function}
end function

function hlsFixtureResult(token as string) as object
    return {ok: true, status: 200, token: token, url: "https://example.test/proxy/hls/" + token + "/index.m3u8"}
end function

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

function playerOptionsHasAction(action as string) as boolean
    for each item in m.playerOptions.menu.items
        if item.action = action then return true
    end for
    return false
end function

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub

sub runStartupLiveLinkChecks()
    linked = {uuid: "linked-channel", name: "Explicit linked channel"}
    saved = {uuid: "saved-channel", name: "Saved mini channel"}
    m.guide.callFunc = function(name as string, id as dynamic, now = 0 as integer) as dynamic
        if name = "channelByUuid" and id = "linked-channel" then return {uuid: id, name: "Explicit linked channel"}
        return invalid
    end function
    m.accountPreferences = {startupBehavior: "mini", lastChannel: saved.uuid}
    m.page = "setup"
    m.startupGuideReady = false
    m.startupVodIntent = false
    m.top.launchRequest = {contentID: linked.uuid, mediatype: "live"}
    onLaunchRequest()
    assertEqual(m.pendingAacTune, invalid, "pre-guide launch cannot open playback")
    m.page = "guide"
    onLaunchRequest()
    assertEqual(m.pendingAacTune, invalid, "provisional guide page alone cannot dispatch a live input")
    assertEqual(m.pendingLaunch.id, linked.uuid, "latest live input stays pending until guide readiness")
    m.global = {profilegateclosed: true}
    handlePendingLaunch()
    assertEqual(m.pendingAacTune, invalid, "protected startup cannot dispatch a live input")
    assertEqual(m.pendingLaunch.id, linked.uuid, "PIN/Child gate retains rather than executes the intent")
    m.global = invalid
    m.startMiniAfterPlayback = true
    linkedTune = signalStartupComplete()
    startConfiguredMiniPlayback([linked, saved], linkedTune)
    assertEqual(m.pendingAacTune.channel.uuid, linked.uuid, "saved mini cannot replace a linked tune waiting for AAC")
    assertEqual(m.startMiniAfterPlayback, false, "linked tune remains fullscreen even with a saved mini preference")
    assertEqual(m.pendingLaunch, invalid, "authorized startup live intent is consumed once")
    cancelAacWait()

    m.page = "setup"
    m.startupGuideReady = false
    m.top.launchRequest = {contentID: "unknown-channel", mediaType: "livefeed"}
    onLaunchRequest()
    m.page = "guide"
    linkedTune = signalStartupComplete()
    startConfiguredMiniPlayback([linked, saved], linkedTune)
    assertEqual(m.pendingAacTune.channel.uuid, saved.uuid, "unavailable link does not claim the normal startup tune")
    assertEqual(m.startMiniAfterPlayback, true, "unavailable live link preserves normal mini startup")
    cancelAacWait()
    m.startMiniAfterPlayback = false

    startPlayback(saved)
    task = {control: "RUN", unobserveField: sub(field as string)
        m.detached = true
    end sub}
    m.vodDeepLinkTask = task
    m.pendingAacTune.vodHold = {page: "guide", session: "", waiting: true}
    startPlayback(linked)
    assertEqual(task.cancelRequested and task.detached, true, "a later explicit live tune retires the warm VOD resolver")
    assertEqual(m.vodDeepLinkTask, invalid, "late warm VOD result cannot replace the viewer's live tune")
    assertEqual(m.pendingAacTune.channel.uuid, linked.uuid, "only the viewer's new AAC wait survives")
    assertEqual(m.pendingAacTune.vodHold, invalid, "the new tune does not inherit the old hold")
    cancelAacWait()

    m.page = "player"
    startPlayback(saved)
    task = {control: "RUN", unobserveField: sub(field as string)
        m.detached = true
    end sub}
    m.vodDeepLinkTask = task
    m.pendingAacTune.vodHold = {page: "player", session: "", waiting: true}
    assertEqual(onKeyEvent("back", true), true, "Back cancels both pending intents without navigating away")
    assertEqual(task.cancelRequested and task.detached, true, "Back retires the warm VOD task")
    assertEqual(m.pendingAacTune, invalid, "Back discards held AAC instead of restoring it")
    assertEqual(m.page, "player", "Back with a held tune preserves existing player surface")
end sub

sub runProvisionalVodLaunchChecks()
    m.startupGuideReady = false
    m.page = "setup"
    entry = normalizeConnectionEntry({id: "first-slot", name: "Saved", provider: "dispatcharr", url: "https://example.test", accountId: "7"})
    m.profileStartupLaunchConnection = entry
    m.startupVodFallbackHolder = {playlist: entry.id, base: entry.url, profile: "original-profile", account: "8"}
    m.global = {activeusersession: "provisional-default-session"}
    m.top.launchRequest = {mediaType: "live", contentId: "live-channel"}
    onLaunchRequest()
    m.page = "guide" ' page published, but guide-ready continuation hasn't run
    m.top.launchRequest = {mediaType: "movie", contentId: "12"}
    onLaunchRequest()
    assertEqual(m.pendingLaunch.profile, "original-profile", "replacement stays bound to saved holder after provisional default scope publishes")
    assertEqual(m.pendingLaunch.session, invalid, "replacement does not adopt provisional default session")
    assertEqual(m.vodDeepLinkTask, invalid, "page name alone cannot dispatch a startup replacement")
    m.top.launchRequest = {mediaType: "episode", contentId: "invalid-id"}
    onLaunchRequest()
    assertEqual(m.pendingLaunch, invalid, "malformed replacement retires previous valid link")
    assertEqual(m.startupVodIntent, true, "malformed recognized replacement keeps live startup suppressed")
    m.notice.visible = false
    startConfiguredMiniPlayback([])
    assertEqual(m.notice.visible, false, "provisional session does not let unrelated startup autoplay")
    m.page = "library"
    m.startupGuideReady = true
    m.top.launchRequest = {mediaType: "episode", contentId: "25"}
    onLaunchRequest()
    assertEqual(m.pendingLaunch.session, "provisional-default-session", "after guide readiness a new warm request binds the actual active session")
    assertEqual(m.pendingLaunch.profile, invalid, "warm intent does not inherit the retired startup holder")
    m.pendingLaunch = invalid
    m.global = invalid
    m.profileStartupLaunchConnection = invalid
    m.startupVodFallbackHolder = invalid
end sub

sub runFirstRunVodOnboardingChecks()
    for each finishAction in ["continue", "back", "child-skip", "child-skip-before-guide", "child-vod-disabled"]
        m.startupGuideReady = false
        m.page = "welcome"
        m.top.launchRequest = {mediaType: "episode", contentId: "27"}
        onLaunchRequest()
        m.page = "guide"
        slot = "first-slot"
        entry = normalizeConnectionEntry({id: slot, name: "First setup", provider: "dispatcharr", url: "https://example.test", accountId: "7", remember: true})
        profile = userProfileFromVerified(slot, "00000000-0000-4000-8000-000000000001", {id: 7, username: "alice", user_level: 1}, 1)
        child = finishAction = "child-skip" or finishAction = "child-skip-before-guide" or finishAction = "child-vod-disabled"
        if child then profile = setCanonicalPreference(profile, "role", "child")
        store = defaultUserProfileStore(slot)
        store.profiles = [profile]
        store.active = profile.id
        values = {}
        values["connectionsV1"] = FormatJson({schema: 1, selected: slot, entries: [entry]})
        values[userProfileStoreKey(slot)] = FormatJson(store)
        values[connectionRegistryKey(slot)] = "own-key"
        scope = userProfileSessionScope(entry, profile.id, "7", "generation", "00000000-0000-4000-8000-000000000003")
        m.global = {activeusersession: scope.sessionId, profilegateclosed: false}
        m.activeUserScope = scope
        m.selectedConnectionId = scope.playlistId
        m.busy = false
        m.registry = {values: values, read: function(key as string) as string
            if m.values.doesExist(key) then return m.values[key]
            return ""
        end function, exists: function(key as string) as boolean
            return m.values.doesExist(key)
        end function}
        m.connectionStore = loadConnectionStore(m.registry)
        m.scopedPreferencesRequired = true
        m.userProfileStore = loadUserProfileStore(m.registry, slot)
        m.apiKey = "own-key"
        m.baseUrl = entry.url
        m.serverAccountId = scope.accountId
        m.accountIdentity = scope.preferenceIdentity
        m.accountPreferences = {vodEnabled: finishAction <> "child-vod-disabled", vod: []}
        m.guide.config = userViewEvent({providerType: "dispatcharr", accountId: scope.accountId, baseUrl: m.baseUrl, apiKey: m.apiKey}, scope.sessionId)
        m.phoneProfileOnboarding = {phase: "offer", slot: slot, addedIds: []}
        m.vodDeepLinkTaskFactory = function() as object
            return {observeField: sub(field as string, callback as string)
            end sub, unobserveField: sub(field as string)
            end sub}
        end function
        m.phoneProfileOnboardingDialogFactory = function() as object
            return {tag: "onboarding", isSameNode: function(other as object) as boolean
                return other.tag = m.tag
            end function, observeField: sub(field as string, callback as string)
            end sub, unobserveField: sub(field as string)
            end sub, setFocus: sub(focus as boolean)
            end sub}
        end function
        m.notice.visible = false
        if finishAction = "child-skip-before-guide"
            ' Startup picker adoption can run onboarding just before the guide
            ' continuation. Skipping must not dispatch into an unready guide.
            continuePhoneProfileOnboarding()
            assertEqual(m.pendingLaunch.id, "27", "early Child skip leaves the link for guide readiness")
            assertEqual(m.vodDeepLinkTask, invalid, "early Child skip cannot start resolution")
            signalStartupComplete()
        else
            signalStartupComplete()
            assertEqual(m.pendingLaunch.id, "27", "authenticated guide must keep the deep link through onboarding")
            assertEqual(m.pendingLaunch.session, scope.sessionId, "first-run pending link is now owned by the authenticated session")
            assertEqual(m.vodDeepLinkTask, invalid, "no premature resolver before onboarding")
            continuePhoneProfileOnboarding()
        end if
        if child
            assertEqual(m.phoneProfileOnboarding, invalid, "Child finishes without adult profile setup")
            assertEqual(m.phoneProfileOnboardingDialog, invalid, "Child never sees adult onboarding dialog")
            assertEqual(m.pendingLaunch, invalid, "terminal Child skip settles the deferred link")
            if finishAction <> "child-vod-disabled"
                assertEqual(m.vodDeepLinkTask.apiKey, "own-key", "authorized Child continuation uses only its own key")
                cancelVodDeepLink()
            else
                assertEqual(m.vodDeepLinkTask, invalid, "disabled VOD for Child does not start resolver")
                assertEqual(m.notice.visible, true, "disabled VOD for Child explicitly declines the link")
            end if
        else
            dialog = m.phoneProfileOnboardingDialog
            assertEqual(m.phoneProfileOnboarding.phase, "who", "normal onboarding shows profile setup")
            event = {node: dialog, choice: m.phoneProfileOnboardingChoices.count() - 1, getRoSGNode: function() as object
                return m.node
            end function, getData: function() as integer
                return m.choice
            end function}
            if finishAction = "continue" then onPhoneProfileOnboardingChoice(event) else onPhoneProfileOnboardingClosed(event)
            assertEqual(m.phoneProfileOnboarding, invalid, "onboarding settles for " + finishAction)
            assertEqual(m.top.dialog, invalid, "retry happens after close for " + finishAction)
            assertEqual(m.pendingLaunch, invalid, "guide consumes pending request after " + finishAction)
            assertEqual(m.vodDeepLinkTask.itemId, "27", "resolver dispatches the original item after " + finishAction)
            assertEqual(m.vodDeepLinkTask.apiKey, "own-key", "continuation still uses only own credential")
            cancelVodDeepLink()
        end if
    end for
    m.global = invalid
    m.activeUserScope = invalid
    m.registry = invalid
    m.selectedConnectionId = ""
    m.connectionStore = invalid
    m.apiKey = ""
    m.accountIdentity = ""
    m.scopedPreferencesRequired = false
    m.userProfileStore = invalid
    m.profileLaunchResolvedConnection = invalid
end sub
