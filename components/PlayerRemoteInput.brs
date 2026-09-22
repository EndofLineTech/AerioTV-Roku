' Called only after the Scene's dialog, overlay, and fixed-key guards.
function playerRemoteAction(slot as string) as string
    map = defaultRemoteMap()
    if type(m.devicePreferences) = "roAssociativeArray" then map = m.devicePreferences.remoteMap
    return resolveRemoteAction(map, "player", slot)
end function

function handlePlayerMappedKey(key as string) as boolean
    slot = ""
    if key = "up" or key = "down" or key = "left" or key = "right" then slot = key + "Short"
    if key = "replay" or key = "rewind" then slot = key
    if key = "play" then slot = "playPause"
    if slot = "" then return false
    action = playerRemoteAction(slot)
    if beginMappedChannelSwitch(action, key) then return true
    return executePlayerRemoteAction(action)
end function

function executePlayerRemoteAction(action as string) as boolean
    if action = "none" then return true
    if action = "toggleInfo"
        togglePlayerInfo()
    else if action = "openOptions"
        openPlayerOptions()
    else if action = "recentChannels"
        openChannelBrowser("recent")
    else if action = "channelList"
        openChannelBrowser()
    else if action = "lastChannel"
        zapPreviousChannel()
    else if action = "rewindHistory"
        openLiveRewind()
    else if action = "minimizeToGuide"
        minimizePlayback()
    else if action = "playPause"
        togglePause()
    else
        return false
    end if
    return true
end function

function beginMappedChannelSwitch(action as string, key as string) as boolean
    direction = 0
    if action = "channelUp" then direction = 1
    if action = "channelDown" then direction = -1
    if direction = 0 then return false
    m.heldZap = key
    m.heldZapDirection = direction
    m.heldZapClock = CreateObject("roTimespan")
    m.heldZapClock.mark()
    m.heldZapTimer.duration = 0.4
    m.heldZapTimer.control = "start"
    queueChannelSwitch(direction)
    return true
end function

function playerRemoteHint(infoOpen as boolean) as string
    shortHint = remoteActionHint(playerRemoteAction("okShort"))
    if infoOpen and playerRemoteAction("okShort") = "toggleInfo" then shortHint = "Hide info"
    hint = "OK  " + shortHint + "    Hold OK  " + remoteActionHint(playerRemoteAction("okLong"))
    if infoOpen then return hint + "    Up/Down  Controls    Back  Hide info"
    return hint + "    Up  " + remoteActionHint(playerRemoteAction("upShort")) + "    Down  " + remoteActionHint(playerRemoteAction("downShort")) + "    Back  Guide"
end function
