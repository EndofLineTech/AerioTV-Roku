' e3e.29: scheduled and in-progress server recordings mark their Guide cells.
sub main()
    now = 1000000
    rows = [
        {id: "1", channelId: "7", startTime: "1970-01-12T13:50:00Z", endTime: "1970-01-12T14:20:00Z", status: "scheduled", programId: "p-1"}
        {id: "2", channelId: "7", startTime: "1970-01-12T13:00:00Z", endTime: "1970-01-12T13:30:00Z", status: "completed", programId: "p-0"}
        {id: "3", channelId: "8", startTime: "1970-01-12T13:40:00Z", endTime: "1970-01-12T13:55:00Z", status: "recording", programId: ""}
        {id: "4", channelId: "8", startTime: "1970-01-12T12:00:00Z", endTime: "1970-01-12T12:30:00Z", status: "scheduled", programId: ""}
        {id: "5", channelId: "", startTime: "1970-01-12T13:50:00Z", endTime: "1970-01-12T14:20:00Z", status: "scheduled"}
        {id: "6", channelId: "9", startTime: "bad", endTime: "1970-01-12T14:20:00Z", status: "scheduled"}
        {id: "7", channelId: "9", startTime: "1970-01-12T13:50:00Z", endTime: "1970-01-12T14:20:00Z", status: ""}
        "not-a-row"
    ]
    active = guideActiveRecordings(rows, now)
    check(active.count() = 3, "only future scheduled/in-progress rows with valid times and channels are kept")
    check(active[0].channelId = "7" and active[0].status = "scheduled" and active[0].programId = "p-1", "scheduled row kept")
    check(active[1].status = "recording", "in-progress row kept")
    check(active[2].channelId = "9" and active[2].status = "scheduled", "a new row without status counts as scheduled")
    check(guideActiveRecordings(invalid, now).count() = 0, "missing list is empty")
    many = []
    for i = 1 to 400
        many.push({id: i.toStr(), channelId: "7", startTime: "1970-01-12T13:50:00Z", endTime: "1970-01-12T14:20:00Z", status: "scheduled"})
    end for
    check(guideActiveRecordings(many, now).count() = 200, "markers are bounded")

    marks = guideRecordingMarks(active)
    startsAt = guideEpoch("1970-01-12T13:50:00Z")
    program = {id: "p-1", startsAt: startsAt, endsAt: startsAt + 1800}
    check(guideRecordingMark(marks, "7", program) = "scheduled", "program ID match marks a scheduled cell")
    check(guideRecordingMark(marks, "7", {id: "other", startsAt: startsAt + 300, endsAt: startsAt + 900}) = "scheduled", "a padded window covering the program midpoint marks it")
    check(guideRecordingMark(marks, "7", {id: "next", startsAt: startsAt + 1800, endsAt: startsAt + 3600}) = "", "the following program is not marked")
    check(guideRecordingMark(marks, "8", {id: "x", startsAt: guideEpoch("1970-01-12T13:30:00Z"), endsAt: guideEpoch("1970-01-12T14:00:00Z")}) = "recording", "in-progress window marks its program")
    check(guideRecordingMark(marks, "10", program) = "", "other channels are not marked")
    check(guideRecordingMark(guideRecordingMarks(invalid), "7", program) = "", "no recordings, no markers")

    flags = programFlagPills({is_live: true}, {badges: {live: true, new: true, premiere: true, finale: true}}, 400, 1.0, "recording")
    check(flags[0].key = "rec" and flags[0].label = "REC" and flags[1].key = "live" and flags[1].x > 0, "REC leads the flags")
    flags = programFlagPills({}, {badges: {live: false, new: false, premiere: false, finale: false}}, 400, 1.0, "scheduled")
    check(flags.count() = 1 and flags[0].label = "REC", "REC is shown even when EPG badges are off")
    check(programFlagPills({}, {badges: {live: true, new: true, premiere: true, finale: true}}, 400).count() = 0, "no marker by default")
    print "ALL TESTS PASSED"
end sub

sub check(condition as boolean, label as string)
    if not condition
        print "FAIL: "; label
        stop
    end if
end sub
