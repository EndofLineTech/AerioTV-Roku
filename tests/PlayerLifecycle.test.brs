sub main()
    ' Exercise the actual Scene handlers with field adapters. This proves control
    ' routing and lack of retune writes, not native video-plane/audio behavior.
    m.top = {dialog: invalid, setFocus: function(value as boolean) as boolean
        m.focused = value
        return true
    end function}
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
    assertEqual(infoTask.control, "STOP", "source transition cancels old metadata request")
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
    assertEqual(m.video.content.programId, "a", "focus repair preserves content")
    m.userInfoOpen = false
    m.transport.active = false
    m.banner.visible = true
    onBannerTimeout()
    assertEqual(m.banner.visible, false, "automatic tune banner still expires")
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
    print "ALL TESTS PASSED"
end sub

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
