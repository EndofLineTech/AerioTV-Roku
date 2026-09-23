function guideRemoteAction(slot as string) as string
    map = defaultRemoteMap()
    if type(m.top.remotePreferences) = "roAssociativeArray" then map = m.top.remotePreferences.remoteMap
    return resolveRemoteAction(map, "guide", slot)
end function

sub executeGuideRemoteAction(action as string)
    if action = "jumpToNow"
        jumpTo(uiNow())
    else if action = "jumpToTop"
        m.selected = 0
    else if action = "openGroups"
        if m.settings.groupLayout = "modal"
            items = []
            for i = 0 to m.groups.count() - 1
                items.push({title: m.groups[i].name, index: i})
            end for
            openPicker("Channel groups", items, "groups")
        else
            m.navigator.active = true
        end if
    else if action = "openOptions"
        openOptions()
    else if action = "pageUp" or action = "pageDown"
        delta = m.rowCount
        if action = "pageUp" then delta = -delta
        m.selected += delta
        if m.selected >= m.filtered.count() then m.selected = m.filtered.count() - 1
        if m.selected < 0 then m.selected = 0
    else if action = "resumePlayer" and m.top.miniActive
        m.top.playerRequest = "expandPlayer"
    else if action = "programDetails"
        showDetails()
    else if action = "activateSelection"
        activateGuideSelection()
    end if
end sub

' Called after GuideView handles fixed keys and overlay/focus ownership.
function handleGuideMappedKey(key as string) as boolean
    if key = "left"
        ' All short Left actions wait for release, independently of the hold map.
        beginGuideHold(key)
        return true
    end if
    slot = ""
    if key = "right" then slot = "rightShort"
    if key = "OK" then slot = "okShort"
    if key = "replay" or key = "rewind" or key = "fastforward" then slot = key
    if key = "play" then slot = "playPause"
    if slot = "" then return false
    action = guideRemoteAction(slot)
    if action = "navigate" then moveGuideTime(key) else executeGuideRemoteAction(action)
    finishGuideMappedAction()
    if key = "right" or key = "OK" then announceGuidePosition()
    return true
end function

sub finishGuideMappedAction()
    drawGuide()
    scheduleLoad()
    m.saveDelay.control = "stop"
    m.saveDelay.control = "start"
end sub

function handleGuideHeldKey(key as string, press as boolean) as boolean
    if press and key <> "left" then m.guideLeftReleasePending = false
    if m.guideLeftReleasePending = true and key = "left"
        if not press then m.guideLeftReleasePending = false
        return true
    end if
    if m.holdKey = "" then return false
    if key <> m.holdKey
        if press then cancelGuideHold()
        return false
    end if
    if not press
        shortLeft = key = "left"
        cancelGuideHold()
        if shortLeft
            action = guideRemoteAction("leftShort")
            if action = "navigate" then moveGuideTime("left") else executeGuideRemoteAction(action)
        end if
        finishGuideMappedAction()
        if shortLeft then announceGuidePosition()
    end if
    return true
end function

sub announceGuidePosition()
    if m.filtered.count() = 0 then return
    channel = m.filtered[m.selected]
    label = channel.name + ", " + textValue(channel.number)
    if m.ready = true
        cell = selectedCell()
        if cell <> invalid and cell.program <> invalid then label += ", " + cell.program.title
    end if
    uiAnnounce(label)
end sub

sub cancelGuideHold()
    m.holdKey = ""
    if m.holdTimer <> invalid then m.holdTimer.control = "stop"
end sub

sub beginGuideHold(key as string)
    m.holdKey = key
    m.holdClock = CreateObject("roTimespan")
    m.holdClock.mark()
    m.holdTimer.duration = 0.4
    m.holdTimer.control = "start"
end sub

sub repeatGuideHold()
    if not m.top.active or m.picker <> invalid or m.navigator.active or m.searchView.active or m.details.active
        cancelGuideHold()
        return
    end if
    if m.holdKey = "" then return
    if m.filtered.count() = 0
        cancelGuideHold()
        m.selected = 0
        return
    end if
    if m.holdClock.totalMilliseconds() > 10000
        m.holdTimer.control = "stop"
        return
    end if
    if m.holdKey = "left"
        cancelGuideHold()
        executeGuideRemoteAction(guideRemoteAction("leftLong"))
        m.guideLeftReleasePending = true
        return
    end if
    stepSize = guideHoldStep(m.holdClock.totalMilliseconds())
    if m.holdKey = "up" then stepSize = -stepSize
    m.selected += stepSize
    if m.selected < 0 then m.selected = 0
    if m.selected >= m.filtered.count() then m.selected = m.filtered.count() - 1
    if m.holdKey = "up" or m.holdKey = "down" then uiAnnounce(m.filtered[m.selected].name + ", " + textValue(m.filtered[m.selected].number))
    m.holdTimer.duration = 0.12
    drawGuide()
    ' Defer network requests until the gesture settles, not on every repeat.
    m.loadDelay.control = "stop"
    m.loadDelay.duration = 0.3
    m.loadDelay.control = "start"
    m.saveDelay.control = "stop"
    m.saveDelay.control = "start"
end sub

function guideRemoteHint() as string
    hint = "OK  " + remoteActionHint(guideRemoteAction("okShort")) + "    Hold Left  " + remoteActionHint(guideRemoteAction("leftLong")) + "    Replay  " + remoteActionHint(guideRemoteAction("replay"))
    if m.top.miniActive then hint += "    Play  " + remoteActionHint(guideRemoteAction("playPause"))
    hint += "    *  Options    Back  "
    if m.top.miniActive then return hint + "Fullscreen"
    return hint + "Connection"
end function
