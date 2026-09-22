sub main()
    ' Exercise production key-to-action routing, not just map normalization.
    bindings = [{key: "up", slot: "upShort"}, {key: "down", slot: "downShort"}, {key: "left", slot: "leftShort"}, {key: "right", slot: "rightShort"}, {key: "replay", slot: "replay"}, {key: "rewind", slot: "rewind"}, {key: "play", slot: "playPause"}]
    for each binding in bindings
        for each action in remoteActionChoices("player", binding.slot)
            m.devicePreferences = {remoteMap: setRemoteAction(defaultRemoteMap(), "player", binding.slot, action)}
            m.heldZap = ""
            m.heldZapTimer = {control: "stop"}
            m.observed = ""
            check(handlePlayerMappedKey(binding.key), binding.key + " consumed")
            expected = action
            if action = "none" then expected = ""
            check(m.observed = expected, binding.key + " executes " + action)
            if action = "channelUp" or action = "channelDown"
                check(m.heldZap = binding.key and m.heldZapTimer.control = "start", "channel hold works on every direction")
            else
                check(m.heldZap = "", "non-channel action cannot start channel repeat")
            end if
        end for
    end for
    for each key in ["back", "home", "options", "OK", "fastforward"]
        m.observed = ""
        check(not handlePlayerMappedKey(key), "fixed/other-owner key not claimed: " + key)
        check(m.observed = "", "fixed key has no mapped side effect")
    end for
    m.devicePreferences.remoteMap = setRemoteAction(defaultRemoteMap(), "player", "okShort", "none")
    m.devicePreferences.remoteMap = setRemoteAction(m.devicePreferences.remoteMap, "player", "okLong", "none")
    hint = playerRemoteHint(true)
    check(instr(1, hint, "OK  None") > 0 and instr(1, hint, "Hold OK  None") > 0, "info overlay hints reflect disabled OK gestures")
    check(instr(1, hint, "Up/Down  Controls") > 0, "overlay hints reflect fixed control ownership")
    m.devicePreferences.remoteMap = setRemoteAction(defaultRemoteMap(), "player", "upShort", "channelList")
    check(instr(1, playerRemoteHint(false), "Up  Channels") > 0, "custom direction hint")
    print "ALL TESTS PASSED"
end sub

sub queueChannelSwitch(direction as integer)
    if direction = 1 then m.observed = "channelUp" else m.observed = "channelDown"
end sub

sub togglePlayerInfo()
    m.observed = "toggleInfo"
end sub

sub openPlayerOptions()
    m.observed = "openOptions"
end sub

sub openChannelBrowser(mode = "channels" as string)
    if mode = "recent" then m.observed = "recentChannels" else m.observed = "channelList"
end sub

sub zapPreviousChannel()
    m.observed = "lastChannel"
end sub

sub openLiveRewind()
    m.observed = "rewindHistory"
end sub

sub minimizePlayback()
    m.observed = "minimizeToGuide"
end sub

sub togglePause()
    m.observed = "playPause"
end sub

sub check(value as boolean, label as string)
    if not value then print "FAIL: " + label : stop
end sub
