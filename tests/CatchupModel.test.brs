sub main()
    p = {startsAt: 1000, endsAt: 1300}
    if not catchupEligible(p, 1, 2000) then stop
    if catchupEligible(p, 0, 2000) or catchupEligible(p, 1, 1200) then stop
    if catchupEligible(p, 1, 90000) then stop
    plan = catchupSeekPlan(p, 99)
    if plan.offset <> 60 or plan.program.startsAt <> 1060 or plan.remaining <> 240 then stop
    if catchupSeekPlan(p, -30).offset <> 0 then stop
    if catchupSeekPlan(p, 9999).offset <> 240 then stop
    response = {session_id: "abcdefghijklmnop", channel_uuid: "channel", expires_at: 2060, playback_url: "/proxy/catchup/channel?session_id=abcdefghijklmnop"}
    if catchupSessionUrl("https://host.test", "channel", response, 2000) = "" then stop
    if catchupSessionUrl("https://host.test", "other", response, 2000) <> "" then stop
    if catchupSessionUrl("https://host.test", "channel", response, 2060) <> "" then stop
    response.playback_url = "https://other.test/media"
    if catchupSessionUrl("https://host.test", "channel", response, 2000) <> "" then stop
    print "ALL TESTS PASSED"
end sub
