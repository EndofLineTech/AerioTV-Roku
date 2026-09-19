sub main()
    resetStartupTest()
    beginStartupWatch(m.video.content)
    before = m.video.content
    if not handleStartupFailure(-5, "buffering is stalled") then stop
    if m.startupRetryCount <> 1 or m.video.content.serial = before.serial then stop
    if m.video.content.url <> before.url or m.video.content.httpHeaders[0] <> before.httpHeaders[0] then stop
    if m.video.control <> "play" or not m.mini or not m.playerOptions.active then stop
    if m.sleepDeadline <> 123 or m.activeAudioProfile <> "7" then stop
    if handleStartupFailure(-5, "buffering is stalled") then stop
    if m.startupRetryCount <> 1 then stop

    resetStartupTest()
    beginStartupWatch(m.video.content)
    if handleStartupFailure(-5, "unsupported codec") then stop
    if handleStartupFailure(-1, "HTTP 403") then stop
    if m.startupRetryCount <> 0 then stop
    m.startupWatch.clock = elapsedClock(24999)
    checkStartupPlayback()
    if m.startupRetryCount <> 0 then stop
    m.startupWatch.clock = elapsedClock(25000)
    checkStartupPlayback()
    if m.startupRetryCount <> 1 then stop
    m.startupWatch.clock = elapsedClock(25000)
    checkStartupPlayback()
    if m.stops <> 1 or m.startupWatch <> invalid then stop
    if instr(1, m.failure, "retry") = 0 then stop
    checkStartupPlayback()
    if m.stops <> 1 then stop

    resetStartupTest()
    beginStartupWatch(m.video.content)
    m.video.state = "playing"
    checkStartupPlayback()
    if m.startupWatch <> invalid then stop
    m.video.state = "buffering"
    if handleStartupFailure(-5, "buffering is stalled") then stop
    if m.startupRetryCount <> 0 then stop ' no midstream retry from startup policy

    resetStartupTest()
    beginStartupWatch(m.video.content)
    m.video.content = testStartupContent(50)
    m.startupWatch.clock = elapsedClock(99999)
    checkStartupPlayback()
    if m.startupRetryCount <> 0 or m.startupWatch <> invalid then stop

    resetStartupTest()
    beginStartupWatch(m.video.content)
    cancelStartupWatch()
    if handleStartupFailure(-5, "buffering is stalled") then stop
    checkStartupPlayback()
    if m.startupRetryCount <> 0 then stop

    resetStartupTest()
    beginStartupWatch(m.video.content)
    m.startupWatch.clock = elapsedClock(99999)
    m.pendingChannel = {uuid: "next"}
    checkStartupPlayback()
    if m.startupRetryCount <> 0 then stop
    m.pendingChannel = invalid
    m.video.state = "paused"
    checkStartupPlayback()
    if m.startupWatch <> invalid then stop
    print "ALL TESTS PASSED"
end sub

sub resetStartupTest()
    m.playingChannel = {uuid: "test"}
    m.video = {state: "buffering", content: testStartupContent(1), control: "play"}
    m.startupRetryCount = 0
    m.startupWatch = invalid
    m.pendingChannel = invalid
    m.heldZap = ""
    m.page = "guide"
    m.mini = true
    m.playerOptions = {active: true}
    m.audioCheck = {control: "stop"}
    m.banner = {playbackState: "buffering"}
    m.sleepDeadline = 123
    m.activeAudioProfile = "7"
    m.stops = 0
    m.failure = ""
end sub

function elapsedClock(milliseconds as integer) as object
    return {milliseconds: milliseconds, totalMilliseconds: function() as integer
        return m.milliseconds
    end function}
end function

function testStartupContent(serial as integer) as object
    return {serial: serial, url: "https://example.test/proxy/ts/stream/test?output_format=mpegts&output_profile=7", httpHeaders: ["X-API-Key: test-only"], isSameNode: function(other as object) as boolean
        return other.serial = m.serial
    end function, clone: function(deep as boolean) as object
        result = testStartupContent(m.serial + 1)
        result.url = m.url
        result.httpHeaders = m.httpHeaders
        return result
    end function}
end function

sub showNotice(message as string)
    m.notice = message
end sub

sub stopPlayback()
    m.stops++
    cancelStartupWatch()
    m.playingChannel = invalid
    m.video.control = "stop"
end sub

sub showPlaybackFailure(code as integer, detail as string)
    m.failure = detail
end sub
