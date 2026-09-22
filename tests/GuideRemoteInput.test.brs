sub main()
    bindings = [{key: "OK", slot: "okShort"}, {key: "left", slot: "leftShort"}, {key: "right", slot: "rightShort"}, {key: "rewind", slot: "rewind"}, {key: "fastforward", slot: "fastForward"}, {key: "replay", slot: "replay"}, {key: "play", slot: "playPause"}]
    for each binding in bindings
        for each action in remoteActionChoices("guide", binding.slot)
            setupGuide()
            m.top.remotePreferences.remoteMap = setRemoteAction(defaultRemoteMap(), "guide", binding.slot, action)
            check(handleGuideMappedKey(binding.key), "mapped key consumed")
            if binding.key = "left"
                check(m.observed = "" and m.selected = 10, "custom Left waits for short/long decision")
                check(handleGuideHeldKey("left", false), "short Left release handled")
            end if
            if action = "pageUp"
                check(m.selected = 4, "page up")
            else if action = "pageDown"
                check(m.selected = 16, "page down")
            else if action = "jumpToTop"
                check(m.selected = 0, "jump to top")
            else if action = "openGroups"
                check(m.navigator.active, "open groups")
            else if action = "resumePlayer"
                check(m.top.playerRequest = "expandPlayer", "resume same mini-player")
            else if action = "none"
                check(m.observed = "" and m.selected = 10 and m.top.playerRequest = "", "none has no action")
            else
                check(m.observed = action, binding.key + " executes " + action)
            end if
            check(m.draws = 1 and m.loads = 1, "mapped action refreshes once")
        end for
    end for
    ' Every short mapping must leave BOTH hold choices reachable, with no short
    ' action leaking on native repeats or the eventual release.
    for each shortAction in remoteActionChoices("guide", "leftShort")
        for each longAction in remoteActionChoices("guide", "leftLong")
            setupGuide()
            map = setRemoteAction(defaultRemoteMap(), "guide", "leftShort", shortAction)
            m.top.remotePreferences.remoteMap = setRemoteAction(map, "guide", "leftLong", longAction)
            handleGuideMappedKey("left")
            repeatGuideHold()
            check(m.navigator.active = (longAction = "openGroups"), "long Left executes independently of short map")
            check(handleGuideHeldKey("left", true), "native repeat suppressed after hold")
            check(handleGuideHeldKey("left", false), "release suppressed after hold")
            check(m.observed = "" and m.selected = 10, "hold never fires short action")
            check(m.holdTimer.control = "stop", "hold timer stops")
        end for
    end for
    setupGuide()
    m.settings.groupLayout = "modal"
    executeGuideRemoteAction("openGroups")
    check(m.observed = "groupsPicker" and not m.navigator.active, "modal groups opens visible picker, not hidden navigator")
    setupGuide()
    m.settings.groupLayout = "pills"
    executeGuideRemoteAction("openGroups")
    check(m.navigator.active, "pills groups opens navigator")
    setupGuide()
    m.selected = 1
    handleGuideMappedKey("rewind")
    check(m.selected = 0, "page up clamps")
    m.selected = 19
    handleGuideMappedKey("fastforward")
    check(m.selected = 19, "page down clamps")
    m.top.miniActive = false
    handleGuideMappedKey("play")
    check(m.top.playerRequest = "", "no mini-player means no resume request")
    for each key in ["back", "home", "options", "up", "down"]
        check(not handleGuideMappedKey(key), "fixed navigation is not remapped")
    end for
    setupGuide()
    handleGuideMappedKey("left")
    m.picker = {}
    repeatGuideHold()
    check(m.holdKey = "" and not m.navigator.active, "picker cancels delayed guide action")
    setupGuide()
    map = setRemoteAction(defaultRemoteMap(), "guide", "okShort", "programDetails")
    map = setRemoteAction(map, "guide", "leftLong", "none")
    m.top.remotePreferences.remoteMap = setRemoteAction(map, "guide", "playPause", "none")
    hint = guideRemoteHint()
    check(instr(1, hint, "OK  Details") > 0 and instr(1, hint, "Hold Left  None") > 0, "custom guide hints")
    check(instr(1, hint, "Play  None") > 0 and instr(1, hint, "Back  Fullscreen") > 0, "mini hints distinguish fixed Back from mapped Play")
    print "ALL TESTS PASSED"
end sub

sub setupGuide()
    m.top = {active: true, miniActive: true, playerRequest: "", remotePreferences: {remoteMap: defaultRemoteMap()}}
    m.navigator = {active: false}
    m.settings = {groupLayout: "sidebar"}
    m.groups = [{name: "All channels"}]
    m.searchView = {active: false}
    m.details = {active: false}
    m.picker = invalid
    m.holdKey = ""
    m.guideLeftReleasePending = false
    m.holdTimer = {control: "stop"}
    m.saveDelay = {control: "stop"}
    m.loadDelay = {control: "stop"}
    m.filtered = []
    for i = 0 to 19
        m.filtered.push({uuid: i.toStr()})
    end for
    m.selected = 10
    m.rowCount = 6
    m.observed = ""
    m.draws = 0
    m.loads = 0
end sub

sub drawGuide()
    m.draws++
end sub

sub scheduleLoad()
    m.loads++
end sub

sub jumpTo(epoch as integer)
    m.observed = "jumpToNow"
end sub

sub moveGuideTime(key as string)
    m.observed = "navigate"
end sub

sub openOptions()
    m.observed = "openOptions"
end sub

sub openPicker(title as string, items as object, kind as string)
    check(title = "Channel groups" and items.count() = 1 and kind = "groups", "group picker contract")
    m.observed = "groupsPicker"
end sub

sub showDetails()
    m.observed = "programDetails"
end sub

sub activateGuideSelection()
    m.observed = "activateSelection"
end sub

sub check(value as boolean, label as string)
    if not value then print "FAIL: " + label : stop
end sub
