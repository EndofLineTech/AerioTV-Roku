sub main()
    m.playingChannel = {uuid: "test"}
    m.mini = false
    m.page = "player"
    m.video = {state: "playing", content: {id: "same-session"}, control: "play", width: 1920, height: 1080, scale: [1, 1], translation: [0, 0], visible: true, allowOptionsKeyOverride: true, enableUI: false, setFocus: sub(value as boolean)
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
    handleOptionsProbeKey("back", true)
    if m.optionsProbeActive or m.optionsProbeHud.visible then stop
    if not m.layoutRestored or not m.focusRestored then stop
    if m.optionsProbeRearm.control <> "stop" then stop
    finishOptionsProbeRearm()
    if m.optionsProbeActive then stop
    if m.video.width <> 1920 or m.video.scale[0] <> 1 then stop
    beginOptionsProbe(4)
    if m.optionsProbeMode <> 4 then stop
    endOptionsProbe()
    m.video.state = "buffering"
    beginOptionsProbe()
    if m.optionsProbeActive then stop
    print "ALL TESTS PASSED"
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
