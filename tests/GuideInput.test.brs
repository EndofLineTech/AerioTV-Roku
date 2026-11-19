sub main()
    m.top = {active: true, miniActive: false, getScene: function() as object
        return m.scene
    end function, scene: {}, removeChild: sub(child as object)
    end sub, setFocus: sub(focused as boolean)
    end sub}
    m.ready = false
    m.picker = invalid
    m.pickerWakeKey = ""
    m.navigator = {active: false, callFunc: sub(name as string)
        if name <> "dismissGroups" then stop
        m.active = false
        m.closed = true
    end sub}
    m.searchView = {active: false}
    m.details = {active: false}
    m.holdTimer = {control: "stop"}
    m.saveDelay = {control: "stop"}
    m.loadDelay = {control: "stop"}
    m.holdKey = ""
    m.settings = normalizeGuideSettings({groupLayout: "sidebar"})
    m.rowCount = 6
    m.selected = 1
    m.filtered = []
    for i = 0 to 19
        m.filtered.push({uuid: i.toStr(), name: "Channel " + i.toStr(), number: i.toStr()})
    end for
    m.picker = {}
    m.pickerList = {isSameNode: function(node as object) as boolean
        return true
    end function}
    m.pickerItems = [{value: "pills"}]
    m.pickerKind = "settingValue"
    onPickerSelected({getData: function() as integer
        return 0
    end function, getRoSGNode: function() as object
        return {}
    end function})
    if m.picker <> invalid or m.selectedLayout <> "pills" then stop
    if not onKeyEvent("OK", true) then stop
    if m.top.watchChannel <> invalid then stop
    onKeyEvent("OK", false)
    if m.pickerWakeKey <> "" then stop
    onKeyEvent("down", true)
    if m.selected <> 2 then stop
    onKeyEvent("down", true)
    if m.selected <> 2 then stop
    m.holdClock = {totalMilliseconds: function() as integer
        return 1600
    end function}
    repeatGuideHold()
    if m.selected <> 5 then stop
    onKeyEvent("down", false)
    repeatGuideHold()
    if m.selected <> 5 or m.holdTimer.control <> "stop" then stop
    m.anchor = 123
    onKeyEvent("left", true)
    if m.anchor <> 123 then stop
    repeatGuideHold()
    if not m.navigator.active or m.anchor <> 123 then stop
    if m.holdKey <> "" then stop
    onKeyEvent("left", false)
    m.picker = invalid
    m.settings.groupLayout = "modal"
    m.navigator.active = false
    m.primaryNavigation = {active: false}
    m.selected = 0
    onKeyEvent("up", true)
    if m.primaryNavigation.active or m.selected <> m.filtered.count() - 1 then stop
    onKeyEvent("up", false)
    onKeyEvent("down", true)
    if m.selected <> 0 then stop
    onKeyEvent("down", false)
    m.primaryNavigation.active = false
    m.navigator.active = false
    m.settings.groupLayout = "pills"
    onKeyEvent("left", true)
    if m.anchor <> 123 then stop
    repeatGuideHold()
    if not m.navigator.active or m.anchor <> 123 then stop
    onKeyEvent("left", false)
    m.navigator.active = false
    onKeyEvent("down", true)
    m.picker = {}
    repeatGuideHold()
    if m.holdKey <> "" then stop
    m.picker = invalid
    m.primaryNavigation.active = false
    m.top.miniActive = false
    m.top.exitRequested = invalid
    m.top.playerRequest = invalid
    m.selected = 10
    if not onKeyEvent("back", true) or m.primaryNavigation.active then stop
    if not onKeyEvent("back", true) or m.primaryNavigation.active then stop
    if not onKeyEvent("back", false) or not m.primaryNavigation.active then stop
    if instr(1, guideRemoteHint(), "Back  Guide grid") = 0 then stop
    if m.top.exitRequested <> invalid or m.selected <> 10 then stop
    m.primaryNavigation.active = false
    m.top.miniActive = true
    tapBack()
    if m.top.playerRequest <> "stopPlayer" then stop
    if m.top.exitRequested <> invalid then stop
    m.top.playerRequest = invalid
    if not onKeyEvent("play", true) or m.top.playerRequest <> "expandPlayer" then stop
    m.top.playerRequest = invalid
    setGuideBackForTest("resumePlayer")
    m.picker = {}
    if not onKeyEvent("back", true) or m.picker = invalid then stop
    tapBack()
    if m.picker <> invalid or m.top.playerRequest <> invalid then stop
    if not onKeyEvent("back", false) or m.top.playerRequest <> invalid then stop
    for each overlay in ["details", "searchView", "navigator", "primaryNavigation"]
        m[overlay].active = true
        tapBack()
        if m.top.playerRequest <> invalid then stop
        if overlay = "details" and m.details.action <> "close" then stop
        if overlay = "searchView" and m.searchView.selection.action <> "close" then stop
        if overlay = "navigator" and m.navigator.closed <> true then stop
        if overlay = "primaryNavigation" and m.primaryNavigation.exitRequested <> "back" then stop
        m[overlay].active = false
    end for
    if not onKeyEvent("back", true) then stop
    m.details.active = true
    m.details.action = ""
    if not onKeyEvent("back", false) then stop
    if m.details.action <> "" or m.top.playerRequest <> invalid then stop
    m.details.active = false
    dialog = {wasClosed: false, observeFieldScoped: sub(field as string, callback as string)
        m.watcher = callback
    end sub, unobserveFieldScoped: sub(field as string)
        m.watcher = ""
    end sub, isSameNode: function(node as object) as boolean
        return m.id = node.id
    end function, id: "native"}
    m.top.scene.dialog = dialog
    trackGuideSceneDialog(dialog)
    if dialog.watcher <> "onGuideSceneDialogClosed" then stop
    ' The platform dialog receives the initial press, not GuideView.
    dialog.wasClosed = true
    onGuideSceneDialogClosed({getData: function() as boolean
        return true
    end function, getRoSGNode: function() as object
        return m.node
    end function, node: dialog})
    tapBack() ' repeat + release delivered to newly focused GuideView
    if m.top.playerRequest <> invalid then stop
    tapBack()
    if m.top.playerRequest <> "expandPlayer" then stop
    ' Some native dialogs leave the field without a usable wasClosed event.
    m.top.playerRequest = invalid
    dialog.wasClosed = false
    trackGuideSceneDialog(dialog)
    m.top.scene.dialog = invalid
    trackGuideSceneDialog(invalid)
    tapBack()
    if m.top.playerRequest <> invalid or dialog.watcher <> "" then stop
    m.top.playerRequest = invalid
    m.top.pendingTune = true
    if instr(1, guideRemoteHint(), "Back  Cancel tune") = 0 then stop
    if not onKeyEvent("back", true) then stop
    if m.top.playerRequest <> "cancelPendingTune" then stop
    m.top.pendingTune = false
    m.top.playerRequest = invalid
    tapBack() ' repeat + release after cancellation cleared the pending flag
    if m.top.playerRequest <> invalid then stop
    m.top.miniActive = false
    m.top.playerRequest = invalid
    tapBack()
    if m.top.playerRequest <> invalid or m.primaryNavigation.active then stop
    if instr(1, guideRemoteHint(), "Back  ") <> 0 then stop
    setGuideBackForTest("pageDown")
    m.selected = 1
    tapBack()
    if m.selected <> 7 or instr(1, guideRemoteHint(), "Back  Page down") = 0 then stop
    m.top.miniActive = true
    tapBack()
    if m.selected <> 13 or m.top.playerRequest <> invalid then stop
    m.top.miniActive = false
    m.selected = 7
    setGuideBackForTest("none")
    tapBack()
    if m.selected <> 7 or m.primaryNavigation.active then stop
    setGuideBackForTest("pageDown")
    suppressGuideBackForHandoff()
    tapBack()
    if m.selected <> 7 then stop
    tapBack()
    if m.selected <> 13 then stop
    suppressGuideBackForHandoff()
    m.guideBackHandoff = {elapsed: 900, marks: 0, totalMilliseconds: function() as integer
        return m.elapsed
    end function, mark: sub()
        m.elapsed = 0
        m.marks++
    end sub}
    if not onKeyEvent("back", true) or m.guideBackHandoff.marks <> 1 then stop
    m.guideBackHandoff.elapsed = 900
    if not onKeyEvent("back", true) or m.guideBackHandoff.marks <> 2 then stop
    m.guideBackHandoff.elapsed = 1001
    tapBack() ' a missing key-up cannot suppress later independent presses forever
    if m.selected <> 19 then stop
    if onKeyEvent("home", true) then stop
    m.top.beacons = []
    m.top.signalBeacon = sub(name as string)
        m.beacons.push(name)
    end sub
    m.ready = true
    m.top.active = false
    m.epgLaunchPending = false
    m.epgLaunchRecorded = false
    if not beginEpgLaunch() or beginEpgLaunch() then stop
    if m.top.beacons.count() <> 1 or m.top.beacons[0] <> "EPGLaunchInitiate" then stop
    completeEpgLaunch()
    if m.top.beacons.count() <> 1 then stop
    m.top.active = true
    completeEpgLaunch()
    completeEpgLaunch()
    if m.top.beacons.count() <> 2 or m.top.beacons[1] <> "EPGLaunchComplete" then stop
    m.top.active = false
    if beginEpgLaunch() then stop
    m.userSessionId = "view-session"
    m.channels = m.filtered
    m.savedFavoriteIds = []
    m.favorites = {}
    m.groups = [{id: "all"}]
    m.groupIndex = 0
    m.selected = 2
    watchLive(true)
    if m.top.watchChannel.uuid <> "2" or m.top.watchChannel.watchVideo <> true or userViewSession(m.top.watchChannel) <> "view-session" then stop
    if m.filtered[2].watchVideo <> invalid then stop
    watchLive()
    if m.top.watchChannel.watchVideo <> invalid then stop
    m.ready = false
    m.top.active = true
    m.top.miniActive = false
    m.top.remotePreferences = {}
    m.cache = guideNewCache()
    m.filtered[2].epgKey = ""
    m.anchor = uiNow()
    m.viewStart = m.anchor
    m.span = 8928
    m.filtered[2].id = "2"
    for each mode in ["default", "declared", "late", "video"]
        m.top.remotePreferences.radioDefault = mode = "default"
        rows = []
        if mode = "declared" then rows = [{id: 2, uuid: "2", effective_is_radio: true}]
        m.top.channelFacts = normalizeChannelCapabilities(rows)
        m.top.watchChannel = invalid
        if not onKeyEvent("OK", true) or m.top.watchChannel <> invalid
            print "FAIL: Guide must retain the initiating OK until release, including "; mode
            stop
        end if
        if mode = "late" then m.top.channelFacts = normalizeChannelCapabilities([{id: 2, uuid: "2", effective_is_radio: true}])
        if not onKeyEvent("OK", true) or m.top.watchChannel <> invalid then stop
        if not onKeyEvent("OK", false) or m.top.watchChannel.uuid <> "2" then stop
        m.top.watchChannel = invalid
        if onKeyEvent("OK", false) or m.top.watchChannel <> invalid then stop
    end for
    m.top.watchChannel = invalid
    m.filtered[3].epgKey = ""
    if not onKeyEvent("OK", true) or not onKeyEvent("down", true) or m.selected <> 3 then stop
    if not onKeyEvent("OK", true) or not onKeyEvent("OK", false) or m.top.watchChannel <> invalid
        print "FAIL: cancelled Guide OK re-armed a different row"
        stop
    end if
    onKeyEvent("down", false)
    if not onKeyEvent("OK", true) or m.top.watchChannel <> invalid then stop
    if not onKeyEvent("OK", false) or m.top.watchChannel.uuid <> "3" then stop
    print "ALL TESTS PASSED"
end sub

sub tapBack()
    if not onKeyEvent("back", true) then stop
    if not onKeyEvent("back", false) then stop
end sub

sub setGuideBackForTest(action as string)
    m.top.remotePreferences = {remoteMap: setRemoteAction(defaultRemoteMap(), "guide", "backShort", action)}
end sub

function handleGuideSetting(kind as string, item as object) as boolean
    m.selectedLayout = item.value
    return true
end function
