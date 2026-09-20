sub main()
    resetLive()
    original = m.video.content
    if not retryInterruptedLive("finished", 0, "") then stop
    if m.liveRetryCount <> 1 or m.startupRetryCount <> 1 then stop
    if m.video.content.serial = original.serial or m.video.content.url <> original.url then stop
    if m.video.control <> "play" or m.streamReady then stop
    if m.activeAudioProfile <> "7" or not m.mini then stop
    m.streamReady = true
    if retryInterruptedLive("finished", 0, "") then stop

    for each refusal in ["HTTP 403", "HTTP 429", "connection limit reached"]
        resetLive()
        if retryInterruptedLive("error", -5, "buffering is stalled " + refusal) then stop
    end for
    resetLive()
    if retryInterruptedLive("error", -5, "unsupported codec") then stop
    m.video.state = "paused"
    if retryInterruptedLive("finished", 0, "") then stop
    resetLive()
    m.streamReady = false
    if retryInterruptedLive("finished", 0, "") then stop
    resetLive()
    m.pendingChannel = {uuid: "new"}
    if retryInterruptedLive("finished", 0, "") then stop
    resetLive()
    m.recoveryTask = {}
    if retryInterruptedLive("finished", 0, "") then stop

    resetLive()
    m.video.state = "buffering"
    checkLivePlayback()
    m.liveBufferWatch.clock = elapsedClock(19999)
    checkLivePlayback()
    if m.liveRetryCount <> 0 then stop
    m.liveBufferWatch.clock = elapsedClock(20000)
    checkLivePlayback()
    if m.liveRetryCount <> 1 then stop

    resetLive()
    m.video.state = "buffering"
    checkLivePlayback()
    m.video.state = "paused"
    checkLivePlayback()
    if m.liveBufferWatch <> invalid or m.liveRetryCount <> 0 then stop
    resetLive()
    m.video.state = "buffering"
    checkLivePlayback()
    m.video.content = testContent(9)
    m.liveBufferWatch.clock = elapsedClock(99999)
    checkLivePlayback()
    if m.liveRetryCount <> 0 then stop
    print "ALL TESTS PASSED"
end sub

sub resetLive()
    m.liveRetryCount = 0
    m.liveBufferWatch = invalid
    m.playingChannel = {uuid: "live"}
    m.video = {state: "finished", content: testContent(1), control: "play"}
    m.streamReady = true
    m.pendingChannel = invalid
    m.heldZap = ""
    m.recoveryTask = invalid
    m.sourceTask = invalid
    m.sourceWatchState = invalid
    m.page = "guide"
    m.mini = true
    m.audioCheck = {control: "stop"}
    m.banner = {playbackState: "finished"}
    m.activeAudioProfile = "7"
end sub

function testContent(serial)
    return {serial: serial, url: "https://example.test/live?output_profile=7", isSameNode: function(other)
        return m.serial = other.serial
    end function, clone: function(deep)
        return testContent(m.serial + 1)
    end function}
end function

function elapsedClock(milliseconds)
    return {milliseconds: milliseconds, totalMilliseconds: function()
        return m.milliseconds
    end function}
end function

sub beginStartupWatch(content, recovering)
    m.watched = content
end sub

sub showNotice(message)
    m.notice = message
end sub

sub failLivePlayback(code, detail)
    m.failed = true
end sub
