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
    m.top = {ids: ["1", "2"], subtype: function() as string
        return "LogoCacheTask"
    end function}
    runUiAuditFixtureTask()
    if m.top.result <> invalid then stop
    m.global.uiAuditLibraryCase = "live-browser-appearance"
    runUiAuditFixtureTask()
    if not m.top.result.ok or m.top.result.assets.count() <> 2 then stop
    for each asset in m.top.result.assets
        if asset.uri <> "pkg:/images/channel-icon-hd.png" or asset.bytes <> 0 then stop
    end for
    print "ALL TESTS PASSED"
end sub
