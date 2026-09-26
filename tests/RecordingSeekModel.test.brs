sub main()
    plan = recordingSeekTarget(60, 120, -1, 30, true)
    if plan = invalid or plan.position <> 30 or plan.last <> 114 or not plan.moved then stop
    plan = recordingSeekTarget(115, 120, 1, 30, true)
    if plan.position <> 114 or plan.moved then stop
    plan = recordingSeekTarget(120, 120, -1, 30, true)
    if plan.position <> 84 then stop
    plan = recordingSeekTarget(3, 120, -1, 30, true)
    if plan.position <> 0 then stop
    plan = recordingSeekTarget(0, 120, -1, 30, true)
    if plan.moved then stop
    if recordingSeekTarget(invalid, 120, 1, 30, true) <> invalid then stop
    if recordingSeekTarget(60, 0, -1, 30, true) <> invalid then stop
    if recordingSeekTarget(60, 120, 0, 30, true) <> invalid then stop
    if recordingSeekTarget(60, 120, -1, 100000, true) <> invalid then stop
    plan = recordingSeekTarget(115, 120, 1, 30, false)
    if plan.position <> 119 then stop
    print "ALL TESTS PASSED"
end sub
