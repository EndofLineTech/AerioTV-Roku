' Archived 0.3.10 diagnostic; excluded from the application package.
sub beginOptionsProbe(index = 0 as integer)
    if m.playingChannel = invalid or m.mini then return
    if m.video.state <> "playing" and m.video.state <> "paused"
        showNotice("Start a working channel before testing the Options key.")
        return
    end if
    if m.optionsProbeActive <> true
        m.optionsProbeOriginalOverride = m.video.allowOptionsKeyOverride
        m.optionsProbeOriginalUI = m.video.enableUI
        m.optionsProbeOriginalShowUI = m.video.showUI
        m.optionsProbeOriginalTrickPlay = m.video.enableTrickPlay
    end if
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
    return ["Full size / Video focus", "Full size / sibling focus", "Full size / re-arm override", "Inset 1888 x 1062 / sibling focus", "Half size 960 x 540 / sibling focus", "Half size scaled 2x / sibling focus", "Full size / native UI enabled / sibling focus", "Full size / native UI enabled / Video focus", "Full size / HOLD * / Video focus", "Full size / HOLD * / sibling focus"]
end function

function optionsProbeUsesVideoFocus(index as integer) as boolean
    return index = 0 or index = 7 or index = 8
end function

sub applyOptionsProbe(index as integer)
    m.optionsProbeRearm.control = "stop"
    cancelOptionsHoldProbe()
    if index < 0 then index = 0
    if index > 9 then index = 9
    m.optionsProbeMode = index
    m.playerOptions.holdOptionsTest = index >= 8
    m.optionsProbePresses = 0
    m.optionsProbeReleases = 0
    m.optionsHoldRepeats = 0
    m.optionsHoldElapsed = 0
    m.optionsHoldStatus = "WAITING"
    names = optionsProbeNames()
    m.optionsProbeName = names[index]
    m.videoViewport.translation = [0, 0]
    m.videoViewport.clippingRect = [0, 0, 1920, 1080]
    m.video.width = 1920
    m.video.height = 1080
    m.video.translation = [0, 0]
    m.video.scale = [1, 1]
    m.video.enableUI = index = 6 or index = 7
    m.video.showUI = false
    m.video.enableTrickPlay = false
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
    if optionsProbeUsesVideoFocus(index) then m.video.setFocus(true) else m.playerInput.setFocus(true)
    updateOptionsProbeHud()
    snapshot = {
        caseNumber: index + 1, name: m.optionsProbeName, state: m.video.state
        videoFocus: m.video.hasFocus(), visible: m.video.visible
        width: m.video.width, height: m.video.height, scale: m.video.scale
        optionsOverride: m.video.allowOptionsKeyOverride, enableUI: m.video.enableUI
        showUI: m.video.showUI, trickPlay: m.video.enableTrickPlay
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
    header = "OPTIONS KEY TEST " + (m.optionsProbeMode + 1).toStr() + "/10: " + m.optionsProbeName
    counts = "Delivered * down events: " + m.optionsProbePresses.toStr() + "   releases: " + m.optionsProbeReleases.toStr()
    hint = "Press * once. Back closes its menu. Fast Forward: next test. Rewind: previous. Back: exit test."
    if m.optionsProbeMode >= 8
        counts += "   repeats: " + m.optionsHoldRepeats.toStr() + "   " + m.optionsHoldStatus
        hint = "HOLD * continuously for 3 seconds, then release. App elapsed: " + m.optionsHoldElapsed.toStr() + " ms. Back closes menu / exits test."
    end if
    m.optionsProbeText.text = header + chr(10) + counts + chr(10) + hint
end sub

sub cancelOptionsHoldProbe()
    if m.optionsHoldTimer <> invalid then m.optionsHoldTimer.control = "stop"
    m.optionsHoldDown = false
    m.optionsHoldFired = false
    m.optionsHoldClock = invalid
end sub

function handleOptionsHoldProbe(press as boolean) as boolean
    if m.optionsProbeActive <> true then return false
    if m.optionsProbeMode < 8 then return false
    if press
        if not m.optionsHoldDown
            m.optionsHoldDown = true
            m.optionsHoldFired = false
            m.optionsHoldElapsed = 0
            m.optionsHoldStatus = "DOWN SEEN"
            m.optionsHoldClock = CreateObject("roTimespan")
            m.optionsHoldClock.mark()
            m.optionsHoldTimer.control = "stop"
            m.optionsHoldTimer.control = "start"
        else
            m.optionsHoldRepeats++
            m.optionsHoldElapsed = m.optionsHoldClock.totalMilliseconds()
        end if
    else
        if m.optionsHoldDown
            m.optionsHoldElapsed = m.optionsHoldClock.totalMilliseconds()
            if not m.optionsHoldFired then m.optionsHoldStatus = "RELEASED"
        else
            m.optionsHoldStatus = "RELEASE ONLY"
        end if
        m.optionsHoldDown = false
        m.optionsHoldTimer.control = "stop"
    end if
    updateOptionsProbeHud()
    snapshot = {press: press, repeats: m.optionsHoldRepeats, elapsedMs: m.optionsHoldElapsed, status: m.optionsHoldStatus}
    print "[options-hold] "; FormatJson(snapshot)
    ' Do not run the ordinary short-press action during this experiment.
    return true
end function

sub onOptionsHoldThreshold()
    if m.optionsProbeActive <> true then return
    if m.optionsProbeMode < 8 or not m.optionsHoldDown or m.optionsHoldFired then return
    if m.optionsHoldClock = invalid then return
    m.optionsHoldElapsed = m.optionsHoldClock.totalMilliseconds()
    if m.optionsHoldElapsed < 1000 then return
    m.optionsHoldFired = true
    m.optionsHoldStatus = "THRESHOLD REACHED"
    m.optionsHoldTimer.control = "stop"
    updateOptionsProbeHud()
    print "[options-hold] threshold reached after delivered down; elapsedMs="; m.optionsHoldElapsed
    openPlayerOptions()
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
    cancelOptionsHoldProbe()
    m.optionsProbeActive = false
    m.playerOptions.holdOptionsTest = false
    m.optionsProbeHeldKey = ""
    m.optionsProbeHud.visible = false
    m.optionsProbeRearm.control = "stop"
    m.video.allowOptionsKeyOverride = m.optionsProbeOriginalOverride
    m.video.enableUI = m.optionsProbeOriginalUI
    m.video.showUI = m.optionsProbeOriginalShowUI
    m.video.enableTrickPlay = m.optionsProbeOriginalTrickPlay
    applyVideoLayout()
    if m.page = "player" and m.playingChannel <> invalid then focusPlaybackInput()
    print "[options-probe] ended; normal layout restored"
end sub
