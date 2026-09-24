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
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
