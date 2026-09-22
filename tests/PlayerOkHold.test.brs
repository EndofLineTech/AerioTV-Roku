sub main()
    m.top = {dialog: invalid}
    m.page = "player"
    m.playingChannel = {uuid: "a"}
    m.mini = false
    m.pictureCover = {visible: false}
    m.playerOptions = {active: false, consumeSelectRelease: false, callFunc: sub(name as string)
        if name = "releaseSelectGuard" then m.consumeSelectRelease = false
    end sub}
    m.browser = {active: false}
    m.transport = {active: false}
    m.playerOkTimer = {control: "stop"}
    m.toggles = 0
    m.opens = 0
    if not handlePlayerOkKey("OK", true) then stop
    if m.toggles <> 1 then stop
    handlePlayerOkKey("OK", true)
    if m.toggles <> 1 then stop
    handlePlayerOkKey("OK", false)
    onPlayerOkHold()
    if m.opens <> 0 then stop
    handlePlayerOkKey("OK", true)
    m.playerOkClock = {totalMilliseconds: function() as integer
        return 1000
    end function}
    onPlayerOkHold()
    onPlayerOkHold()
    if m.opens <> 1 or not m.playerOptions.consumeSelectRelease then stop
    if m.playerOkDown or m.playerOkTimer.control <> "stop" then stop
    if not handlePlayerOkKey("OK", false) then stop
    if m.playerOptions.consumeSelectRelease then stop
    m.playerOptions.active = false
    handlePlayerOkKey("OK", true)
    handlePlayerOkKey("up", true)
    onPlayerOkHold()
    if m.opens <> 1 then stop
    m.pictureCover.visible = true
    if handlePlayerOkKey("OK", true) then stop
    m.pictureCover.visible = false
    m.transport.active = true
    if handlePlayerOkKey("OK", true) then stop
    m.transport.active = false
    handlePlayerOkKey("OK", true)
    m.browser.active = true
    onPlayerOkHold()
    if m.opens <> 1 or m.playerOkDown then stop
    for each shortAction in remoteActionChoices("player", "okShort")
        for each longAction in remoteActionChoices("player", "okLong")
            m.browser.active = false
            m.playerOptions.active = false
            m.playerOptions.consumeSelectRelease = false
            cancelPlayerOkHold()
            map = setRemoteAction(defaultRemoteMap(), "player", "okShort", shortAction)
            m.devicePreferences = {remoteMap: setRemoteAction(map, "player", "okLong", longAction)}
            m.toggles = 0
            m.opens = 0
            if not handlePlayerOkKey("OK", true) then stop
            handlePlayerOkKey("OK", true)
            if shortAction = "toggleInfo" and m.toggles <> 1 then stop
            if shortAction = "none" and (m.toggles <> 0 or m.opens <> 0) then stop
            if shortAction = "openOptions" and (m.opens <> 1 or not m.playerOptions.consumeSelectRelease) then stop
            m.playerOkClock = {totalMilliseconds: function() as integer
                return 1000
            end function}
            onPlayerOkHold()
            onPlayerOkHold()
            if shortAction <> "openOptions"
                if longAction = "openOptions" and m.opens <> 1 then stop
                if longAction = "none"
                    if m.opens <> 0 or not m.playerOkDown then stop
                    handlePlayerOkKey("OK", true)
                    if shortAction = "toggleInfo" and m.toggles <> 1 then stop
                end if
            end if
            handlePlayerOkKey("OK", false)
            if m.playerOkDown or m.playerOptions.consumeSelectRelease then stop
        end for
    end for
    print "ALL TESTS PASSED"
end sub

sub togglePlayerInfo()
    m.toggles++
end sub

sub openPlayerOptions()
    m.opens++
    m.playerOptions.active = true
end sub
