sub main()
    epoch = "1789946400".toInt()
    bounds = rewindBounds(epoch - 7200, epoch)
    if bounds.start <> epoch - 3600 or bounds.finish <> epoch - 60 then stop
    if rewindBounds(epoch - 900, epoch).start <> epoch - 900 then stop
    if rewindBounds(epoch + 10, epoch + 20) <> invalid then stop
    if rewindBounds(epoch + 10, epoch + 61).start <> epoch + 60 then stop
    if rewindBounds(epoch + 1, epoch) <> invalid then stop
    baseWindow = {id: "history", title: "Channel", startsAt: epoch - 3600, endsAt: epoch}
    oldest = rewindSeekPlan(baseWindow, epoch - 7200, -500, epoch)
    if oldest.offset <> 0 or oldest.program.startsAt <> epoch - 3600 or oldest.remaining <> 3600 then stop
    newest = rewindSeekPlan(baseWindow, epoch - 7200, 999999, epoch)
    if newest.program.startsAt <> epoch - 60 or newest.remaining <> 60 then stop
    moved = rewindSeekPlan(baseWindow, epoch - 7200, 0, epoch + 61)
    if moved.offset <> 120 then stop
    clock = rewindPlaybackClock(baseWindow, epoch - 7200, 0, 30, epoch + 61)
    if not clock.outside or clock.broadcast <> epoch - 3570 or clock.behindLive <> 3631 then stop
    if clock.fraction <> 0 then stop
    facts = {"42": {catchupDays: 3}, "43": {catchupDays: 0}, "44": {catchupDays: -1}}
    if catchupChannelDays("allowed", facts, "42") <> 3 then stop
    if catchupChannelDays("denied", facts, "42") <> 0 then stop
    if catchupChannelDays("unknown", facts, "42") <> 0 then stop
    if catchupChannelDays("allowed", facts, "43") <> 0 then stop
    if catchupChannelDays("allowed", facts, "44") <> 0 then stop
    if catchupChannelDays("allowed", facts, "missing") <> 0 then stop
    if catchupChannelDays("allowed", invalid, "42") <> 0 then stop
    if catchupRetentionLabel(1) <> "Catch-up: 1 day" then stop
    if catchupRetentionLabel(3) <> "Catch-up: 3 days" then stop
    if catchupRetentionLabel(0) <> "" then stop
    p = {startsAt: 1000, endsAt: 1300}
    restart = catchupRestartPlan(p, 3, 1125)
    if restart = invalid or restart.program.startsAt <> 1000 or restart.program.endsAt <> 1300 or restart.availableUntil <> 1125 then stop
    if catchupSeekPlan(p, 9999, 1125).offset <> 120 then stop
    if catchupSeekPlan(p, 9999, 1000) <> invalid then stop
    if p.endsAt <> 1300 then stop
    if catchupRestartPlan(p, 0, 1125) <> invalid then stop
    if catchupRestartPlan(p, 3, 999) <> invalid then stop
    if catchupRestartPlan(p, 3, 1300) <> invalid then stop
    if catchupRestartPlan(p, 3, 1000) <> invalid then stop
    clock = catchupPlaybackClock(p, 60, 15, 2000)
    if clock.position <> 75 or clock.broadcast <> 1075 or clock.behindLive <> 925 then stop
    if clock.duration <> 300 or clock.seekEnd <> 240 or clock.fraction <> 0.25 then stop
    pausedClock = catchupPlaybackClock(p, 60, 15, 2060)
    if pausedClock.broadcast <> clock.broadcast or pausedClock.behindLive <> 985 then stop
    pastEnd = catchupPlaybackClock(p, 240, 80, 2000)
    if pastEnd.position <> 320 or pastEnd.fraction <> 1 or not pastEnd.pastEnd then stop
    if catchupPlaybackClock(p, 0, invalid, 2000) <> invalid then stop
    if catchupPlaybackClock(p, 0, -1, 2000) <> invalid then stop
    if catchupPlaybackClock(p, -60, 10, 2000) <> invalid then stop
    if catchupPlaybackClock({startsAt: 1300, endsAt: 1000}, 0, 10, 2000) <> invalid then stop
    if catchupElapsedText(3661) <> "1:01:01" or catchupElapsedText(65) <> "1:05" then stop
    if not catchupEligible(p, 1, 2000) then stop
    if catchupEligible(p, 0, 2000) or catchupEligible(p, 1, 1200) then stop
    if catchupEligible(p, 1, 90000) then stop
    plan = catchupSeekPlan(p, 99)
    if plan.offset <> 60 or plan.program.startsAt <> 1060 or plan.remaining <> 240 then stop
    if catchupSeekPlan(p, -30).offset <> 0 then stop
    if catchupSeekPlan(p, 9999).offset <> 240 then stop
    context = {account: "account-a", channel: {uuid: "channel"}}
    if not catchupLiveReturnAllowed(context, "account-a", {uuid: "channel"}) then stop
    if catchupLiveReturnAllowed(context, "account-b", {uuid: "channel"}) then stop
    if catchupLiveReturnAllowed(context, "account-a", invalid) then stop
    if catchupLiveReturnAllowed(context, "account-a", {uuid: "other"}) then stop
    response = {session_id: "abcdefghijklmnop", channel_uuid: "channel", expires_at: 2060, playback_url: "/proxy/catchup/channel?session_id=abcdefghijklmnop"}
    if catchupSessionUrl("https://host.test", "channel", response, 2000) = "" then stop
    if catchupSessionUrl("https://host.test", "other", response, 2000) <> "" then stop
    if catchupSessionUrl("https://host.test", "channel", response, 2060) <> "" then stop
    response.playback_url = "https://other.test/media"
    if catchupSessionUrl("https://host.test", "channel", response, 2000) <> "" then stop
    print "ALL TESTS PASSED"
end sub
