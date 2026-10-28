sub main()
    m.ready = true
    m.top = {active: false, recentIds: ["a", "c"]}
    m.channels = [{id: "1", uuid: "a", name: "A", groupId: "1"}, {id: "2", uuid: "b", name: "B", groupId: "1"}, {id: "3", uuid: "c", name: "C", groupId: "1"}]
    m.filtered = m.channels
    m.groups = [{id: "recent", name: "Recently Watched"}]
    m.groupIndex = 0
    m.selected = 1
    m.favorites = {}
    m.collections = []
    m.settings = normalizeGuideSettings(invalid)
    m.query = ""
    updateHistory()
    check(m.filtered.count() = 2 and m.selected = 1, "removed middle row selects adjacent row")
    check(m.filtered[m.selected].uuid = "c", "adjacent channel selected")
    m.top.recentIds = ["c", "a"]
    updateHistory()
    check(m.selected = 0 and m.filtered[0].uuid = "c", "existing selected channel retained on reorder")
    m.top.recentIds = []
    updateHistory()
    check(m.selected = 0 and m.filtered.count() = 0 and m.rowStart = 0, "clear leaves valid empty focus state")
    print "ALL TESTS PASSED"
end sub

sub check(condition as boolean, label as string)
    if not condition
        print "FAIL: "; label
        stop
    end if
end sub
