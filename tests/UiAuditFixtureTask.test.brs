sub main()
    m.global = {uiAuditLibraryCase: "dvr-completed"}
    for each action in ["delete", "stop", "cancel", "comskip", "schedule", "series-delete", "series-create"]
        m.top = {action: action, subtype: function() as string
            return "DvrRecordingTask"
        end function}
        runUiAuditFixtureTask()
        if m.top.result.ok <> false then stop
        if m.top.result.message <> "Gallery blocks all mutations." then stop
    end for
    m.top = {action: "list", subtype: function() as string
        return "DvrRecordingTask"
    end function}
    runUiAuditFixtureTask()
    if m.top.result.ok <> true or m.top.result.recordings.count() <> 12 then stop
    print "ALL TESTS PASSED"
end sub
