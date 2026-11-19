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
    testLongXmltvReminderIdentity(now)
    print "ALL TESTS PASSED"
end sub

sub testLongXmltvReminderIdentity(now as integer)
    ' M3U proxy channel IDs can be 64 characters; XMLTV uses up to 128
    ' characters for its channel key, followed by "-" and the start epoch.
    channelUuid = String(64, "c")
    guideKey = String(128, "g")
    firstId = guideKey + "-" + (now + 300).toStr()
    secondId = guideKey + "-" + (now + 900).toStr()
    rows = [
        {id: channelUuid + "|" + firstId, channelUuid: channelUuid, title: "First", startsAt: now + 300, endsAt: now + 900}
        {id: channelUuid + "|" + secondId, channelUuid: channelUuid, title: "Second", startsAt: now + 900, endsAt: now + 1500}
    ]
    restored = normalizeReminders(ParseJson(FormatJson(normalizeReminders(rows))))
    assertEqual(restored.count(), 2, "programs sharing a long XMLTV prefix survive storage")
    assertEqual(hasReminder(restored, channelUuid, firstId), true, "first details/Guide lookup survives storage")
    assertEqual(hasReminder(restored, channelUuid, secondId), true, "second details/Guide lookup survives storage")
    fired = reminderTick(restored, now)
    assertEqual(fired.alerts.count(), 1, "only the reminder entering its foreground lead time fires")
    assertEqual(fired.alerts[0].id, channelUuid + "|" + firstId, "alert retains full program identity")
    later = reminderTick(normalizeReminders(ParseJson(FormatJson(fired.items))), now + 600)
    assertEqual(later.alerts.count(), 1, "first reminder does not repeat after reload")
    assertEqual(later.alerts[0].id, channelUuid + "|" + secondId, "second reminder remains independently alertable")

    ' The cap also accommodates the stored 128-character Roku channel UUID.
    widestChannel = String(128, "c")
    widest = {id: widestChannel + "|" + firstId, channelUuid: widestChannel, startsAt: now + 300, endsAt: now + 900}
    assertEqual(hasReminder(normalizeReminders([widest]), widestChannel, firstId), true, "widest supported XMLTV identity survives storage")
    oversized = {id: widest.id + String(20, "x"), channelUuid: widestChannel, startsAt: now + 300, endsAt: now + 900}
    assertEqual(normalizeReminders([oversized]).count(), 0, "out-of-bounds IDs are rejected rather than turned into a different identity")
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
