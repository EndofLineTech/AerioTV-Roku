sub main()
    now = guideEpoch("2026-09-18T12:00:00Z")
    rows = [{id: "a|1", channelUuid: "a", title: "One", startsAt: now + 301, endsAt: now + 601, notified: false}]
    assertEqual(reminderTick(rows, now).alerts.count(), 0, "not early")
    fired = reminderTick(rows, now + 1)
    assertEqual(fired.alerts.count(), 1, "five-minute foreground threshold")
    assertEqual(reminderTick(fired.items, now + 10).alerts.count(), 0, "no duplicate alert")
    assertEqual(reminderTick(fired.items, now + 601).items.count(), 0, "expiry cleanup")
    assertEqual(hasReminder(rows, "a", "1"), true, "guide/detail reminder state")
    assertEqual(hasReminder(rows, "b", "1"), false, "channel identity distinct")
    rows[0].unavailable = true
    assertEqual(reminderTick(rows, now + 1).alerts.count(), 0, "removed schedule does not issue misleading alert")
    assertEqual(normalizeReminders([invalid, {}, {id: "bad", startsAt: "bad"}]).count(), 0, "malformed storage ignored")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
