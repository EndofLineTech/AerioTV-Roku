sub main()
    channels = [{id: "xc-19", streamId: "19", archiveDays: 3}, {id: "xc-20", streamId: "20", archiveDays: 0}]
    assertEqual(xtreamArchiveFacts(channels, "UTC")["xc-19"].catchupDays, 3, "advertised retention only")
    assertEqual(xtreamArchiveFacts(channels, "UTC")["xc-20"], invalid, "non-archive channel excluded")
    assertEqual(xtreamArchiveFacts(channels, "America/Chicago").count(), 0, "unknown timestamp conversion fails closed")
    program = {id: "test", title: "Test", startsAt: "1700000000".toInt(), endsAt: "1700003600".toInt()}
    channel = channels[0]
    url = xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channel, program, "1700007200".toInt())
    assertEqual(url, "https://example.test/timeshift/viewer/test-only/60/2023-11-14:22-13/19.ts", "whole-minute UTC path")
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channels[1], program, "1700007200".toInt()), "", "no advertised archive")
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channel, program, "1700264000".toInt()), "", "expired retention")
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channel, program, "1700002000".toInt()), "", "in-progress show not assumed archived")
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", {id: "xc-19", streamId: "19/evil", archiveDays: 3}, program, "1700007200".toInt()), "", "unsafe channel ID refused")
    shifted = catchupSeekPlan(program, 125, "1700007200".toInt())
    assertEqual(shifted.offset, 120, "seek rounds to provider minute")
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channel, shifted.program, "1700007200".toInt()), "https://example.test/timeshift/viewer/test-only/58/2023-11-14:22-15/19.ts", "seek reopens remaining archive")
    for each shift in [-30, 0, 30]
        request = xtreamArchiveRequest("https://example.test", "viewer", "test-only", "UTC", channel, shifted.program, "1700007200".toInt(), shift)
        assertEqual(request.guideStart, guideEpoch("2023-11-14T22:15:00Z"), "bookmark origin removes only the configured correction, not UTC minute rounding")
    end for
    program = {id: "midnight", startsAt: guideEpoch("2026-11-01T00:20:00Z"), endsAt: guideEpoch("2026-11-01T01:20:00Z")}
    now = guideEpoch("2026-11-01T05:00:00Z")
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channel, program, now, -30), "https://example.test/timeshift/viewer/test-only/60/2026-10-31:23-50/19.ts", "negative shift crosses UTC midnight")
    seek = catchupSeekPlan(program, 99999, now)
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channel, seek.program, now, 30), "https://example.test/timeshift/viewer/test-only/1/2026-11-01:01-49/19.ts", "positive shift on final seek minute, unchanged remaining duration")
    assertEqual(program.startsAt, guideEpoch("2026-11-01T00:20:00Z"), "EPG start remains the UTC identity")
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "America/New_York", channel, program, now, 30), "", "no non-UTC timezone support on the DST transition date")
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channel, program, program.endsAt, 30), "", "shifted end beyond live edge is not requested")
    now = guideEpoch("2026-11-01T03:00:15Z")
    program = {startsAt: guideEpoch("2026-11-01T01:57:05Z"), endsAt: guideEpoch("2026-11-01T02:00:10Z")}
    for each elapsed in [0, 120]
        plan = catchupSeekPlan(program, elapsed, now)
        assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channel, plan.program, now, 60), "", "rounded Xtream duration crosses live edge")
    end for
    program = {startsAt: guideEpoch("2026-11-01T01:57:50Z"), endsAt: guideEpoch("2026-11-01T01:59:55Z")}
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channel, program, now, 60), "https://example.test/timeshift/viewer/test-only/3/2026-11-01:02-57/19.ts", "validate the floored UTC start actually serialized")
    now = guideEpoch("2026-11-04T02:57:30Z")
    program = {startsAt: guideEpoch("2026-11-01T03:57:50Z"), endsAt: guideEpoch("2026-11-01T04:00:00Z")}
    assertEqual(xtreamArchiveUrl("https://example.test", "viewer", "test-only", "UTC", channel, program, now, -60), "", "floored UTC start falls outside retention")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
