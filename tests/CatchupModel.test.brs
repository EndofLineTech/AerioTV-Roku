sub main()
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
