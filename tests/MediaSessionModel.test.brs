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
    print "ALL TESTS PASSED"
end sub
