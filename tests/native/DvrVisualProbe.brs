' No server operations: the four DVR sections are UI-only sample metadata.
sub seedVisualProbe()
    cancelDvrLoad()
    m.refreshTimer.control = "stop"
    m.loaded = [
        {id: "9001", channelId: "1", title: "Sample recording now", status: "recording", startTime: "2026-10-02T12:00:00Z", endTime: "2026-10-02T13:00:00Z", posterLogoId: ""}
        {id: "9002", channelId: "1", title: "Sample scheduled", status: "scheduled", startTime: "2026-10-03T12:00:00Z", endTime: "2026-10-03T13:00:00Z", posterLogoId: ""}
        {id: "9003", channelId: "1", title: "Sample completed", status: "completed", startTime: "2026-10-01T12:00:00Z", endTime: "2026-10-01T13:00:00Z", posterLogoId: ""}
    ]
    m.loadedRules = [{title: "Sample series rule", mode: "all", titleMode: "exact", tvgId: "fixture", epgSourceId: "fixture", description: "Visual-only fixture"}]
    drawDvr()
end sub
