' Explicitly entered, session-only physical-key experiment. Never retunes Video.
sub beginOptionsProbe(index = 0 as integer)
    if m.playingChannel = invalid or m.mini then return
    if m.video.state <> "playing" and m.video.state <> "paused"
        showNotice("Start a working channel before testing the Options key.")
        return
    end if
    if m.optionsProbeActive <> true then m.optionsProbeOriginalOverride = m.video.allowOptionsKeyOverride
    m.optionsProbeActive = true
    m.optionsProbeHeldKey = ""
    m.playerOptions.active = false
    m.transport.active = false
    hideBanner()
    m.bannerTimer.control = "stop"
    m.optionsProbeHud.visible = true
    applyOptionsProbe(index)
end sub

function optionsProbeNames() as object
    return ["Full size / Video focus", "Full size / sibling focus", "Full size / re-arm override", "Inset 1888 x 1062 / sibling focus", "Half size 960 x 540 / sibling focus", "Half size scaled 2x / sibling focus"]
end function

sub applyOptionsProbe(index as integer)
    m.optionsProbeRearm.control = "stop"
    if index < 0 then index = 0
    if index > 5 then index = 5
    m.optionsProbeMode = index
    m.optionsProbePresses = 0
    m.optionsProbeReleases = 0
    names = optionsProbeNames()
    m.optionsProbeName = names[index]
    m.videoViewport.translation = [0, 0]
    m.videoViewport.clippingRect = [0, 0, 1920, 1080]
    m.video.width = 1920
    m.video.height = 1080
    m.video.translation = [0, 0]
    m.video.scale = [1, 1]
    if index = 3
        m.video.width = 1888
        m.video.height = 1062
        m.video.translation = [16, 9]
    else if index = 4 or index = 5
        m.video.width = 960
        m.video.height = 540
        m.video.translation = [480, 270]
        if index = 5
            m.video.translation = [0, 0]
            m.video.scale = [2, 2]
        end if
    end if
    m.video.allowOptionsKeyOverride = true
    if index = 2
        ' Separate the writes across render frames, rather than relying on two
        ' same-frame assignments reaching the native media player independently.
        m.video.allowOptionsKeyOverride = false
        m.optionsProbeRearm.control = "start"
    end if
    if index = 0 then m.video.setFocus(true) else m.playerInput.setFocus(true)
    updateOptionsProbeHud()
    snapshot = {
        caseNumber: index + 1, name: m.optionsProbeName, state: m.video.state
        videoFocus: m.video.hasFocus(), visible: m.video.visible
        width: m.video.width, height: m.video.height, scale: m.video.scale
        optionsOverride: m.video.allowOptionsKeyOverride, enableUI: m.video.enableUI
        videoPlanes: m.video.alwaysShowVideoPlanes
    }
    print "[options-probe] "; FormatJson(snapshot)
end sub

sub finishOptionsProbeRearm()
    if m.optionsProbeActive <> true or m.optionsProbeMode <> 2 then return
    m.video.allowOptionsKeyOverride = true
    m.playerInput.setFocus(true)
    print "[options-probe] case=3 post-start override re-armed="; m.video.allowOptionsKeyOverride
end sub

sub updateOptionsProbeHud()
    m.optionsProbeText.text = "OPTIONS KEY TEST " + (m.optionsProbeMode + 1).toStr() + "/6: " + m.optionsProbeName + chr(10) + "Delivered * presses: " + m.optionsProbePresses.toStr() + "   releases: " + m.optionsProbeReleases.toStr() + chr(10) + "Press * once. Back closes its menu. Fast Forward: next test. Rewind: previous. Back: exit test."
end sub

sub recordOptionsProbeKey(owner as string, press as boolean)
    if m.optionsProbeActive <> true then return
    if press then m.optionsProbePresses++ else m.optionsProbeReleases++
    updateOptionsProbeHud()
    print "[options-probe] case="; m.optionsProbeMode + 1; " owner="; owner; " press="; press; " state="; m.video.state
end sub

function handleOptionsProbeKey(key as string, press as boolean) as boolean
    if m.optionsProbeActive <> true then return false
    if key <> "fastforward" and key <> "rewind" and key <> "back" then return false
    if not press
        if m.optionsProbeHeldKey = key then m.optionsProbeHeldKey = ""
        return true
    end if
    if key = m.optionsProbeHeldKey and m.optionsProbeInputClock <> invalid
        if m.optionsProbeInputClock.totalMilliseconds() < 500 then return true
    end if
    m.optionsProbeHeldKey = key
    ' A focus-changing case can lose key-up. Bound debounce instead of latching
    ' until release forever; these diagnostic controls are tap-only.
    m.optionsProbeInputClock = CreateObject("roTimespan")
    m.optionsProbeInputClock.mark()
    if key = "back"
        endOptionsProbe()
    else if key = "fastforward"
        applyOptionsProbe(m.optionsProbeMode + 1)
    else
        applyOptionsProbe(m.optionsProbeMode - 1)
    end if
    return true
end function

sub endOptionsProbe()
    if m.optionsProbeActive <> true then return
    m.optionsProbeActive = false
    m.optionsProbeHeldKey = ""
    m.optionsProbeHud.visible = false
    m.optionsProbeRearm.control = "stop"
    m.video.allowOptionsKeyOverride = m.optionsProbeOriginalOverride
    applyVideoLayout()
    if m.page = "player" and m.playingChannel <> invalid then focusPlaybackInput()
    print "[options-probe] ended; normal layout restored"
end sub
