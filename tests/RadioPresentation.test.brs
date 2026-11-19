sub main()
    assertEqual(normalizeDevicePreferences(invalid).radioDefault, false, "opt-in starts off")
    assertEqual(normalizeDevicePreferences(ParseJson("{""radiodefault"":true}")).radioDefault, true, "local choice survives persisted key casing")
    assertEqual(normalizeDevicePreferences({radioDefault: "true"}).radioDefault, false, "malformed choice cannot opt in")
    assertEqual(settingsHubChangeAllowed({}, "device", "radioDefault", true), true, "Player settings allows device opt-in")
    assertEqual(settingsHubChangeAllowed({}, "account", "radioDefault", true), false, "no account preference")
    assertEqual(liveOpensRadio(false, false, "auto"), false, "ordinary tune remains video")
    assertEqual(liveOpensRadio(true, false, "auto"), true, "declared station opens radio")
    assertEqual(liveOpensRadio(false, true, "auto"), true, "opt-in applies to video channels")
    assertEqual(liveOpensRadio(true, true, "video"), false, "Watch Video bypasses presentation without changing the declaration")
    assertEqual(liveOpensRadio(false, false, "radio"), true, "manual Radio Mode applies to this tune")
    assertEqual(radioPlaybackLabel("stopped", false), "Starting stream…", "replacement stop is not failure")
    assertEqual(radioPlaybackLabel("playing", false), "Starting stream…", "previous reader state is not readiness")
    assertEqual(radioPlaybackLabel("error", true), "Buffering…", "recovery pending is not terminal")
    resetRadioFixture()
    applyLivePresentation()
    assertEqual(m.radioPanel.visible, false, "ordinary channel stays in its normal player")
    m.channelFacts = normalizeChannelCapabilities([{id: 4, uuid: "a", effective_is_radio: true}])
    applyLivePresentation()
    assertEqual(m.radioPanel.visible, true, "late Dispatcharr detail adopts same tune")
    assertEqual(m.video.content.programId, "a", "radio reuses content")
    assertEqual(m.video.control, "play", "radio does not issue another playback command")
    assertEqual(m.video.visible, false, "radio hides the native plane")
    assertEqual(m.playerInput.focused, true, "radio owns remote input instead of hidden Video")
    assertEqual(m.banner.channel.uuid, "a", "card uses current channel artwork identity")
    assertEqual(m.banner.info.channelUuid, "a", "card uses the current program snapshot")
    assertEqual(m.radioStatus.text, "Playing", "card shows renderer state")
    onKeyEvent("OK", false)
    assertEqual(m.radioPanel.visible, true, "unmatched initiating OK release cannot select Watch Video")
    m.video.state = "buffering"
    refreshRadioPresentation()
    assertEqual(m.radioStatus.text, "Buffering…", "card tracks rebuffer")
    m.video.state = "playing"
    assertEqual(onKeyEvent("play", true), true, "radio input owns Play/Pause")
    assertEqual(m.video.control, "pause", "pause uses the existing renderer")
    m.video.state = "paused"
    refreshRadioPresentation()
    assertEqual(m.radioStatus.text, "Paused", "card shows native pause")
    assertEqual(onKeyEvent("OK", true), true, "a press alone does not transfer control")
    assertEqual(m.radioPanel.visible, true, "Watch Video waits for release")
    assertEqual(onKeyEvent("OK", false), true, "Watch Video on release")
    assertEqual(m.radioPanel.visible, false, "explicit video removes radio card")
    assertEqual(m.video.visible, true, "Watch Video restores native plane")
    assertEqual(m.video.suppressCaptions, false, "Watch Video restores captions")
    assertEqual(m.video.alwaysShowVideoPlanes, true, "Watch Video restores renderer's previous plane policy")
    assertEqual(m.video.focused, true, "video owns remote input again")
    assertEqual(m.video.control, "pause", "Watch Video does not reopen a paused stream")
    assertEqual(m.sleepDeadline > uiNow(), true, "presentation changes preserve sleep timer")
    assertEqual(m.livePresentationIntent, "video", "same-channel recovery can preserve override")
    applyLivePresentation()
    assertEqual(m.radioPanel.visible, false, "late details cannot override Watch Video")

    for each mode in ["channels", "recent"]
        resetRadioFixture()
        m.devicePreferences.radioDefault = true
        applyLivePresentation()
        openChannelBrowser(mode)
        assertEqual(m.browser.model.mode, mode, "opens the requested browser")
        assertEqual(m.banner.visible, false, "browser covers station information")
        m.browser.active = false
        m.playerInput.focused = false
        onBrowserClosed()
        assertEqual(m.banner.visible, true, "closing " + mode + " restores the radio station and program")
        assertEqual(m.playerInput.focused, true, "closing browser restores radio input")
        assertEqual(m.video.control, "play", "browser close never retunes")
        m.browser.active = true
        m.banner.visible = false
        m.playerInput.focused = false
        onBrowserClosed()
        assertEqual(m.banner.visible, false, "stale close does not paint under a reopened browser")
        assertEqual(m.playerInput.focused, false, "stale close does not steal focus from the browser")
        m.browser.active = false
        onBrowserClosed()
        onKeyEvent("OK", true)
        onKeyEvent("OK", false)
        hideBanner()
        onBrowserClosed()
        assertEqual(m.banner.visible, false, "stale browser close cannot reopen a video banner")
    end for

    for each exitKind in ["back", "back-pending", "stop", "sleep"]
        resetRadioFixture()
        m.devicePreferences.radioDefault = true
        applyLivePresentation()
        assertEqual(m.radioPanel.visible, true, "opt-in opens a nonradio video feed")
        if exitKind = "stop"
            onKeyEvent("right", true)
            onKeyEvent("OK", true)
            assertEqual(m.video.control, "play", "focus handoff waits for OK release")
            onKeyEvent("OK", false)
        else if exitKind = "back" or exitKind = "back-pending"
            if exitKind = "back-pending"
                m.pendingAacTune = {channel: {uuid: "different-station"}, account: "account", mode: "aac", clock: {totalMilliseconds: function() as integer
                    return 0
                end function}}
                m.guide.pendingTune = true
                m.devicePreferences.audioMode = "aac"
                m.aacProfile = {id: "7"}
            end if
            onKeyEvent("back", true)
            onKeyEvent("back", true)
            if exitKind = "back-pending"
                assertEqual(m.guide.pendingTune, true, "Radio owns Back-down without invoking video-only cancellation")
                processAacWait()
            end if
            assertEqual(m.video.control, "play", "held Back cannot reach guide before release")
            onKeyEvent("back", false)
        else
            m.sleepDeadline = uiNow() - 1
            onPlayerClock()
        end if
        assertEqual(m.video.control, "stop", exitKind + " stops the reader")
        assertEqual(m.video.content, invalid, exitKind + " releases media")
        assertEqual(m.pendingAacTune, invalid, exitKind + " retires the deferred tune")
        assertEqual(m.radioPanel.visible, false, exitKind + " dismisses Radio Mode")
        assertEqual(m.guide.active, true, exitKind + " hands focus back to the guide")
        assertEqual(m.guide.selectedUuid, "a", exitKind + " keeps the tune-origin row")
        assertEqual(m.livePresentationIntent, "auto", exitKind + " clears per-tune override")
    end for
    resetRadioFixture()
    m.pendingAacTune = {channel: {uuid: "different-station"}}
    m.guide.pendingTune = true
    onKeyEvent("back", true)
    assertEqual(m.pendingAacTune, invalid, "ordinary video Back still cancels only the pending tune")
    assertEqual(m.video.control, "play", "ordinary video continues playing")
    checkRadioRefreshAndRetry()
    print "ALL TESTS PASSED"
end sub

sub checkRadioRefreshAndRetry()
    resetRadioFixture()
    identity = m.playingChannel
    m.capabilityTask = fixtureCapabilityTask()
    facts = normalizeChannelCapabilities([{id: 4, uuid: "a", effective_is_radio: true}])
    onCapabilities(fixtureCapabilityEvent(m.capabilityTask, {ok: true, capabilities: {dvr: "manage"}, factsAvailable: true, channelFacts: facts}))
    assertEqual(m.radioPanel.visible, true, "matching Dispatcharr detail activates Radio Mode")
    assertEqual(identity.isRadio, invalid, "late detail must not mutate the lineup channel")
    m.capabilityTask = fixtureCapabilityTask()
    onCapabilities(fixtureCapabilityEvent(m.capabilityTask, {ok: true, capabilities: {dvr: "manage"}, factsAvailable: false, channelFacts: {}}))
    assertEqual(radioForCurrentTune(), true, "partial success does not erase a verified active radio station")
    m.capabilityTask = fixtureCapabilityTask()
    onCapabilities(fixtureCapabilityEvent(m.capabilityTask, {ok: false, message: "fixture capability failure"}))
    assertEqual(m.guide.channelFacts.count(), 0, "failed authority refresh does not preserve global channel facts")
    assertEqual(m.radioPanel.visible, true, "existing radio screen survives transient capability loss")
    assertEqual(radioForCurrentTune(), true, "verified radio identity survives loss for the active reader")
    context = livePlaybackFailureContext()
    assertEqual(context.radio, true, "interruption is a radio terminal failure")
    assertEqual(context.presentation, "radio", "explicit retry reopens the active presentation")
    assertEqual(channelDeclaredRadio(context.channel, {}), true, "retry keeps active station's verified radio signal")
    onKeyEvent("OK", true)
    onKeyEvent("OK", false)
    context = livePlaybackFailureContext()
    assertEqual(context.radio, false, "Watch Video uses normal failure presentation")
    assertEqual(context.presentation, "video", "retry preserves explicit Watch Video")
    assertEqual(channelDeclaredRadio(context.channel, {}), true, "Watch Video does not enable picture recovery for a declared station")

    m.capabilityTask = fixtureCapabilityTask()
    facts = normalizeChannelCapabilities([{id: 4, uuid: "a", effective_is_radio: false}])
    onCapabilities(fixtureCapabilityEvent(m.capabilityTask, {ok: true, capabilities: {dvr: "manage"}, factsAvailable: true, channelFacts: facts}))
    m.capabilityTask = fixtureCapabilityTask()
    onCapabilities(fixtureCapabilityEvent(m.capabilityTask, {ok: false}))
    context = livePlaybackFailureContext()
    assertEqual(channelDeclaredRadio(context.channel, {}), false, "an explicit verified false is not treated as missing facts")
end sub

function fixtureCapabilityTask() as object
    return {id: "capabilities", isSameNode: function(node as object) as boolean
        return node.id = m.id
    end function, unobserveField: sub(field as string)
    end sub}
end function

function fixtureCapabilityEvent(task as object, result as object) as object
    return {task: task, result: result, getRoSGNode: function() as object
        return m.task
    end function, getData: function() as object
        return m.result
    end function}
end function

sub resetRadioFixture()
    focus = function(value as boolean) as boolean
        m.focused = value
        return true
    end function
    m.top = {dialog: invalid}
    m.radioPanel = {visible: false}
    m.radioStatus = {}
    m.radioHelp = {}
    m.radioChoices = [{background: {}, label: {text: "Watch Video"}}, {background: {}, label: {text: "Stop"}}, {background: {}, label: {text: "Player options"}}]
    m.channelFacts = {}
    m.pendingAacTune = invalid
    m.accountIdentity = "account"
    m.page = "player"
    m.playingChannel = {id: "4", uuid: "a", name: "Station"}
    m.video = {state: "playing", control: "play", content: {programId: "a"}, visible: true, alwaysShowVideoPlanes: true, suppressCaptions: false, setFocus: focus}
    m.playerInput = {setFocus: focus}
    m.pictureCover = {visible: false}
    m.guide = {active: false, selectedUuid: "a"}
    m.guide.callFunc = function(name as string, channel = invalid as dynamic, now = 0 as integer) as object
        if name = "playerBrowserData" then return {channels: []}
        return {channelUuid: channel.uuid, status: "ready", programs: []}
    end function
    m.accountPreferences = {recent: []}
    m.vod = {}
    m.pendingChannel = invalid
    m.browser = {active: false}
    m.playerOptions = {active: false}
    m.transport = {active: false}
    m.banner = {visible: false}
    m.userInfoOpen = false
    m.mini = false
    m.miniFrame = {visible: false}
    m.heldZap = ""
    m.livePresentationIntent = "auto"
    m.streamReady = true
    m.devicePreferences = {radioDefault: false}
    m.sleepDeadline = uiNow() + 120
    m.noticeText = {text: ""}
    m.notice = {visible: false}
    for each field in ["heldZapTimer", "pictureHintTimer", "bannerTimer", "audioCheck", "sourceWatch", "playerClock", "channelTuneTimer", "noticeTimer"]
        m[field] = {control: "stop"}
    end for
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
