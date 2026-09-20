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
    print "ALL TESTS PASSED"
end sub

sub togglePlayerInfo()
    m.toggles++
end sub

sub openPlayerOptions()
    m.opens++
    m.playerOptions.active = true
end sub
