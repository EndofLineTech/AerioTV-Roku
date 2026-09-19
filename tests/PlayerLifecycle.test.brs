sub main()
    ' Exercise the actual Scene handlers with field adapters. This proves control
    ' routing and lack of retune writes, not native video-plane/audio behavior.
    m.top = {dialog: invalid, setFocus: function(value as boolean) as boolean
        m.focused = value
        return true
    end function}
    m.page = "player"
    m.playingChannel = {uuid: "a"}
    m.video = {state: "playing", control: "play", content: {programId: "a"}, visible: true, mute: false}
    m.mini = false
    m.pictureWakeKey = ""
    m.pictureCover = {visible: false}
    m.pictureHint = {visible: false}
    m.pictureHintTimer = {control: "stop"}
    m.channelTuneTimer = {control: "start"}
    m.pendingChannel = {uuid: "b"}
    m.browser = {active: true}
    m.playerOptions = {active: true}
    m.transport = {active: true, visible: true}
    m.banner = {visible: true}
    m.bannerTimer = {control: "start"}
    m.userInfoOpen = true
    m.sleepDeadline = 123
    hidePicture()
    assertEqual(m.pictureCover.visible, true, "foreground cover opens")
    assertEqual(m.video.control, "play", "cover does not stop or retune player")
    assertEqual(m.video.content.programId, "a", "content identity preserved")
    assertEqual(m.video.visible, true, "native Video stays visible behind cover")
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
    m.devicePreferences = {videoScale: "fit"}
    m.accountPreferences = {videoAspects: {}}
    m.optionReturnAction = "audioMenu"
    openPlayerOptions("audio")
    assertEqual(m.playerOptions.menu.title, "Audio track", "audio submenu opens")
    onPlayerOptionsBack()
    assertEqual(m.playerOptions.menu.title, "Player options", "Back returns to parent")
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
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
