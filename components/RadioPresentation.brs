sub initRadioPresentation()
    m.radioPanel = m.top.findNode("radioPanel")
    m.radioStatus = m.top.findNode("radioStatus")
    m.radioHelp = m.top.findNode("radioHelp")
    m.radioChoices = []
    i = 0
    for each literal in ["Watch Video", "Stop and return to guide", "Player options"]
        x = 160 + i * 546
        background = uiSurface(m.radioPanel, x, 416, 496, 82, 22, "0x172D43FF")
        label = uiLabel(m.radioPanel, literal, x + 16, 433, 464, 50, 30)
        label.horizAlign = "center"
        m.radioChoices.push({background: background, label: label})
        i++
    end for
end sub

function radioPresentationActive() as boolean
    return m.radioPanel <> invalid and m.radioPanel.visible
end function

function radioForCurrentTune() as boolean
    if m.playingChannel = invalid or m.devicePreferences = invalid then return false
    declared = channelDeclaredRadio(m.playingChannel, m.channelFacts)
    return liveOpensRadio(declared, m.devicePreferences.radioDefault = true, textValue(m.livePresentationIntent))
end function

' Remember only an explicit, UUID-matched classification on the active
' reader's channel snapshot. A partial refresh still clears global authority.
sub captureLiveRadioDetail()
    declared = channelRadioDetail(m.playingChannel, m.channelFacts)
    if declared = invalid then return
    if m.playingChannel.isRadio = declared then return
    channel = {}
    channel.append(m.playingChannel)
    channel.isRadio = declared
    m.playingChannel = channel
end sub

sub applyLivePresentation()
    if m.radioPanel = invalid or m.page <> "player" or m.mini or not radioForCurrentTune() then return
    if m.pictureCover.visible then return
    if m.playerOptions.active or m.browser.active or m.transport.active or m.userInfoOpen then return
    if m.pendingChannel <> invalid or m.heldZap <> "" or m.pendingAacTune <> invalid then return
    if m.top.dialog <> invalid
        if m.top.dialog.wasClosed <> true then return
    end if
    if not radioPresentationActive()
        cancelPlayerOkHold()
        m.hiddenRadioCaptionMode = m.video.suppressCaptions
        m.radioPreviousVideoPlanes = m.video.alwaysShowVideoPlanes
        m.video.suppressCaptions = true
        m.video.alwaysShowVideoPlanes = false
        m.video.visible = false
        m.radioIndex = 0
        m.radioSelectDown = false
        m.radioBackDown = false
        m.radioPanel.visible = true
        paintRadioFocus()
        m.banner.visible = false
        m.banner.radioPresentation = true
        m.banner.playbackState = ""
        m.banner.hint = ""
        m.banner.channel = m.playingChannel
        m.banner.info = m.guide.callFunc("cachedPlaybackInfo", m.playingChannel, uiNow())
        m.banner.playhead = invalid
        m.banner.now = uiNow()
        focusPlaybackInput()
        uiAnnounce("Radio Mode, " + m.playingChannel.name + ", Watch Video")
    end if
    m.startMiniAfterPlayback = false
    m.bannerTimer.control = "stop"
    m.banner.visible = true
    refreshRadioPresentation()
    updateBufferingIndicator()
end sub

sub refreshRadioPresentation()
    if not radioPresentationActive() then return
    m.radioStatus.text = radioPlaybackLabel(m.video.state, m.streamReady = true)
    reminder = "Left/Right chooses a control  •  Play/Pause  •  Back stops"
    if channelDeclaredRadio(m.playingChannel, m.channelFacts)
        m.radioHelp.text = "Foreground listening  •  A radio feed may have no picture." + chr(10) + reminder
    else
        m.radioHelp.text = "Foreground listening  •  Video is hidden, not removed from the stream." + chr(10) + reminder
    end if
end sub

sub paintRadioFocus()
    for i = 0 to m.radioChoices.count() - 1
        color = "0x172D43FF"
        textColor = "0xE8F3FAFF"
        if i = m.radioIndex
            color = "0x1AC4D8FF"
            textColor = "0x0A1628FF"
        end if
        uiSetColor(m.radioChoices[i].background, color)
        uiSetColor(m.radioChoices[i].label, textColor)
    end for
end sub

sub clearRadioPresentation(restoreVideo = false as boolean)
    if not radioPresentationActive() then return
    m.radioPanel.visible = false
    m.radioSelectDown = false
    m.radioBackDown = false
    m.banner.radioPresentation = false
    m.banner.visible = false
    m.video.suppressCaptions = m.hiddenRadioCaptionMode
    m.video.alwaysShowVideoPlanes = m.radioPreviousVideoPlanes
    if restoreVideo then m.video.visible = true
end sub

function handleRadioKey(key as string, press as boolean) as boolean
    if m.page <> "player" or not radioPresentationActive() then return false
    if m.playerOptions.active or m.browser.active then return false
    if key = "OK"
        if press
            m.radioSelectDown = true
        else if m.radioSelectDown
            m.radioSelectDown = false
            if m.radioIndex = 0
                m.livePresentationIntent = "video"
                clearRadioPresentation(true)
                focusPlaybackInput()
                showChannelBanner(m.playingChannel, playerInfoHint())
            else if m.radioIndex = 1
                stopPlayback()
            else
                openPlayerOptions()
            end if
        end if
        return true
    end if
    if key = "back"
        if press
            m.radioBackDown = true
            m.radioSelectDown = false
        else if m.radioBackDown
            stopPlayback()
        end if
        return true
    end if
    if not press then return true
    m.radioSelectDown = false
    m.radioBackDown = false
    if key = "left" or key = "right"
        if key = "left" and m.radioIndex > 0 then m.radioIndex--
        if key = "right" and m.radioIndex < m.radioChoices.count() - 1 then m.radioIndex++
        paintRadioFocus()
        uiAnnounce(m.radioChoices[m.radioIndex].label.text)
    else if key = "play"
        togglePause()
    else if key = "playonly"
        if m.video.state = "paused" then m.video.control = "resume"
    else if key = "options"
        openPlayerOptions()
    end if
    return true
end function
