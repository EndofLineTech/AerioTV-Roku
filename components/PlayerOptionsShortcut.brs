sub cancelPlayerOkHold()
    m.playerOkDown = false
    m.playerOkClock = invalid
    if m.playerOkTimer <> invalid then m.playerOkTimer.control = "stop"
end sub

function canHoldPlayerOk() as boolean
    if m.page <> "player" or m.playingChannel = invalid or m.mini then return false
    if m.pictureCover.visible or m.playerOptions.active or m.browser.active or m.transport.active then return false
    if m.top.dialog <> invalid
        if not m.top.dialog.wasClosed then return false
    end if
    return true
end function

function handlePlayerOkKey(key as string, press as boolean) as boolean
    if key <> "OK"
        if press then cancelPlayerOkHold()
        return false
    end if
    if not press
        consumed = m.playerOkDown = true
        ' Some focus transitions may deliver release to the original Video.
        ' Unlock the menu in that route too, without selecting anything.
        if m.playerOptions.active and m.playerOptions.consumeSelectRelease
            m.playerOptions.callFunc("releaseSelectGuard")
            consumed = true
        end if
        cancelPlayerOkHold()
        return consumed
    end if
    if m.playerOkDown = true then return true
    if not canHoldPlayerOk() then return false
    m.playerOkDown = true
    m.playerOkClock = CreateObject("roTimespan")
    m.playerOkClock.mark()
    ' Preserve immediate tap-OK information feedback. A sustained press upgrades
    ' this gesture to Options; repeats must not toggle the information repeatedly.
    togglePlayerInfo()
    m.playerOkTimer.control = "start"
    return true
end function

sub onPlayerOkHold()
    if m.playerOkDown <> true then return
    if not canHoldPlayerOk()
        cancelPlayerOkHold()
        return
    end if
    if m.playerOkClock = invalid then return
    if m.playerOkClock.totalMilliseconds() < 1000 then return
    cancelPlayerOkHold()
    ' Keep focus on the menu's parent until OK is released, so the initiating
    ' gesture cannot select the first/current LabelList item (including Stop).
    m.playerOptions.consumeSelectRelease = true
    openPlayerOptions()
end sub
