' Archived with the retired star diagnostic; not part of active acceptance.
sub main()
    m.playingChannel = {uuid: "test"}
    m.mini = false
    m.page = "player"
    m.video = {state: "playing", content: {id: "same-session"}, control: "play", width: 1920, height: 1080, scale: [1, 1], translation: [0, 0], visible: true, allowOptionsKeyOverride: true, enableUI: false, showUI: false, enableTrickPlay: true, setFocus: sub(value as boolean)
        m.focused = value
    end sub, hasFocus: function() as boolean
        return m.focused = true
    end function}
    m.playerInput = {setFocus: sub(value as boolean)
        m.focused = value
    end sub}
    m.playerOptions = {active: true}
    m.transport = {active: true}
    m.bannerTimer = {control: "start"}
    m.videoViewport = {}
    m.optionsProbeHud = {visible: false}
    m.optionsProbeText = {text: ""}
    m.optionsProbeRearm = {control: "stop"}
    m.optionsHoldTimer = {control: "stop"}
    beginOptionsProbe()
    if m.optionsProbeActive <> true or m.optionsProbeMode <> 0 then stop
    if m.video.control <> "play" or m.video.content.id <> "same-session" then stop
    if not handleOptionsProbeKey("fastforward", true) then stop
    if m.optionsProbeMode <> 1 or not m.playerInput.focused then stop
    if not handleOptionsProbeKey("fastforward", true) then stop
    if m.optionsProbeMode <> 1 then stop ' held press cannot skip cases
    ' Focus transfer may lose key-up: a later deliberate tap must still advance.
    m.optionsProbeInputClock = {totalMilliseconds: function() as integer
        return 700
    end function}
    handleOptionsProbeKey("fastforward", true)
    if m.optionsProbeMode <> 2 or m.video.allowOptionsKeyOverride then stop
    if m.optionsProbeRearm.control <> "start" then stop
    finishOptionsProbeRearm()
    if not m.video.allowOptionsKeyOverride then stop
    applyOptionsProbe(4)
    if m.video.width <> 960 or m.video.height <> 540 then stop
    applyOptionsProbe(5)
    if m.video.scale[0] <> 2 or m.video.scale[1] <> 2 then stop
    recordOptionsProbeKey("video", false)
    if m.optionsProbePresses <> 0 or m.optionsProbeReleases <> 1 then stop
    recordOptionsProbeKey("video", true)
    if m.optionsProbePresses <> 1 then stop
    if m.video.control <> "play" or m.video.content.id <> "same-session" then stop
    applyOptionsProbe(6)
    if m.optionsProbeMode <> 6 or not m.video.enableUI or m.video.showUI then stop
    if m.video.width <> 1920 or m.video.height <> 1080 or m.video.scale[0] <> 1 then stop
    if m.video.enableTrickPlay then stop
    m.video.focused = false
    applyOptionsProbe(7)
    if not m.video.focused or m.optionsProbeMode <> 7 then stop
    if m.video.width <> 1920 or m.video.height <> 1080 or m.video.translation[0] <> 0 then stop
    applyOptionsProbe(8)
    if m.optionsProbeMode <> 8 or m.video.enableUI then stop
    if m.video.width <> 1920 or m.video.height <> 1080 then stop
    m.menuOpens = 0
    handleOptionsHoldProbe(false)
    onOptionsHoldThreshold()
    if m.menuOpens <> 0 then stop ' release without down cannot manufacture a hold
    handleOptionsHoldProbe(true)
    m.optionsHoldClock = {totalMilliseconds: function() as integer
        return 1100
    end function}
    handleOptionsHoldProbe(true)
    if m.optionsHoldRepeats <> 1 then stop
    onOptionsHoldThreshold()
    onOptionsHoldThreshold()
    if m.menuOpens <> 1 or not m.optionsHoldFired then stop
    handleOptionsHoldProbe(false)
    if m.optionsHoldDown or m.optionsHoldTimer.control <> "stop" then stop
    applyOptionsProbe(9)
    handleOptionsHoldProbe(true)
    handleOptionsHoldProbe(false)
    onOptionsHoldThreshold()
    if m.menuOpens <> 1 then stop ' released short press cannot fire later
    handleOptionsProbeKey("back", true)
    if m.optionsProbeActive or m.optionsProbeHud.visible then stop
    if not m.layoutRestored or not m.focusRestored then stop
    if m.optionsProbeRearm.control <> "stop" then stop
    finishOptionsProbeRearm()
    if m.optionsProbeActive then stop
    if m.video.width <> 1920 or m.video.scale[0] <> 1 then stop
    if m.video.enableUI or m.video.showUI or not m.video.enableTrickPlay then stop
    beginOptionsProbe(4)
    if m.optionsProbeMode <> 4 then stop
    endOptionsProbe()
    m.video.state = "buffering"
    beginOptionsProbe()
    if m.optionsProbeActive then stop
    print "ALL TESTS PASSED"
end sub

sub openPlayerOptions()
    m.menuOpens++
end sub

sub applyVideoLayout()
    m.layoutRestored = true
    m.video.width = 1920
    m.video.height = 1080
    m.video.scale = [1, 1]
end sub

sub focusPlaybackInput()
    m.focusRestored = true
end sub

sub hideBanner()
end sub

sub showNotice(text as string)
    m.notice = text
end sub
