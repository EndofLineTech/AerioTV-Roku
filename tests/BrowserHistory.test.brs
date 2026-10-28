sub main()
    m.ready = true
    m.top = {active: false, recentIds: ["a", "c"]}
    m.channels = [{id: "1", uuid: "a", name: "A", groupId: "1"}, {id: "2", uuid: "b", name: "B", groupId: "1"}, {id: "3", uuid: "c", name: "C", groupId: "1"}]
    m.filtered = m.channels
    m.groups = [{id: "all", name: "All Channels"}]
    m.groupIndex = 0
    m.selected = 1
    m.mode = "recent"
    m.historyAccount = "account-a"
    m.favorites = {}
    m.collections = []
    m.settings = normalizeGuideSettings(invalid)
    updateRecentHistory()
    check(m.filtered.count() = 2 and m.selected = 1, "removed middle row selects adjacent row")
    m.top.active = true
    check(onKeyEvent("options", true), "star consumed for recent browser")
    check(m.top.historyRequest.account = "account-a" and m.top.historyRequest.uuid = "c", "request captures account and selected channel")
    m.top.historyRequest = invalid
    check(not onKeyEvent("options", false), "release does not emit another request")
    check(m.top.historyRequest = invalid, "no duplicate request")
    m.top.active = false
    m.top.recentIds = ["c", "a"]
    updateRecentHistory()
    check(m.selected = 0 and m.filtered[0].uuid = "c", "existing selected channel retained")
    m.top.recentIds = []
    updateRecentHistory()
    check(m.selected = 0 and m.filtered.count() = 0, "clear leaves valid empty list")
    m.top.active = true
    onKeyEvent("options", true)
    check(m.top.historyRequest.uuid = "", "empty list management is safe")
    onKeyEvent("back", true)
    check(not m.top.active and m.top.closed, "Back closes empty browser")
    print "ALL TESTS PASSED"
end sub

sub check(condition as boolean, label as string)
    if not condition
        print "FAIL: "; label
        stop
    end if
end sub
