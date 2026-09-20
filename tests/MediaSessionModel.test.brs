sub main()
    live = mediaSession("a", "1", "live", "channel", 1000)
    if live.seek <> "unknown" or live.position <> invalid then stop
    mediaObserve(live, "paused", 30, 0, invalid)
    if live.mode <> "live" or live.seek <> "unknown" then stop
    mediaObserve(live, "playing", 40, 0, {start: 10, finish: 50})
    if mediaSeekTarget(live, -100) <> 10 or mediaSeekTarget(live, 100) <> 50 then stop
    archive = mediaSession("a", "2", "catchup", "program", 1000)
    archive.programStart = 1000
    mediaObserve(archive, "paused", 50, 120, invalid)
    if archive.programStart + archive.position <> 1050 then stop
    if archive.seek <> "unknown" then stop
    if mediaSessionMatches(archive, "b", "2") then stop
    mediaEnd(archive)
    if archive.state <> "stopped" or archive.position <> invalid then stop
    headers = mediaPlaybackHeaders("fixture-key")
    if headers.count() <> 1 or headers[0] <> "X-API-Key: fixture-key" then stop
    clockSession = mediaSession("a", "clock", "live", "channel", 1000)
    first = mediaLiveClock(clockSession, "playing", 0, {epoch: 0}, 1, 1000, false)
    if not first.known or first.epoch <> 1000 or first.delayed then stop
    mediaLiveClock(clockSession, "paused", 20, {epoch: 0}, 1, 1020, false)
    paused = mediaLiveClock(clockSession, "paused", 20, {epoch: 0}, 1, 1100, false)
    if paused.epoch <> 1020 or paused.delay <> 80 or not paused.delayed then stop
    programs = [{id: "old", title: "Old", startsAt: 1000, endsAt: 1050}, {id: "new", title: "New", startsAt: 1050, endsAt: 1200}]
    if selectNowNext(programs, paused.epoch).current.id <> "old" then stop
    if selectNowNext(programs, 1100).current.id <> "new" then stop
    resumed = mediaLiveClock(clockSession, "playing", 30, {epoch: 0}, 1, 1110, false)
    if resumed.epoch <> 1030 or resumed.delay <> 80 then stop
    jumped = mediaLiveClock(clockSession, "playing", 400, {epoch: 0}, 1, 1111, false)
    if jumped.known then stop
    reset = mediaLiveClock(clockSession, "playing", 0, {epoch: 0}, 2, 1200, false)
    if not reset.known or reset.epoch <> 1200 then stop
    if mediaLiveClock(clockSession, "paused", 0, {epoch: 0}, 2, 1205, true).known then stop
    mediaEnd(clockSession)
    if mediaLiveClock(clockSession, "playing", 1, {epoch: 0}, 2, 1206, false).known then stop
    modernEpoch = "1789946455".toInt()
    modern = mediaSession("a", "modern", "live", "channel", modernEpoch)
    mediaLiveClock(modern, "playing", 3.912, {epoch: 0}, 9, modernEpoch, false)
    modernPause = mediaLiveClock(modern, "paused", 3.912, {epoch: 0}, 9, modernEpoch + 10, false)
    if modernPause.epoch <> modernEpoch or modernPause.delay <> 10 then stop
    early = mediaSession("a", "early", "live", "channel", 1000)
    mediaLiveClock(early, "playing", 0, {epoch: 0}, 1, 1000, false)
    mediaLiveClock(early, "paused", 3.9, {epoch: 0}, 1, 1000, false)
    settled = mediaLiveClock(early, "paused", 3.9, {epoch: 0}, 1, 1010, false)
    if settled.epoch <> 1000 or settled.delay <> 10 then stop
    print "ALL TESTS PASSED"
end sub
