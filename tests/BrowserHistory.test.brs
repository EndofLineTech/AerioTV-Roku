sub main()
    m.ready = true
    m.top = {active: false, recentIds: ["a", "c"]}
    m.channels = [{id: "1", uuid: "a", name: "A", groupId: "1"}, {id: "2", uuid: "b", name: "B", groupId: "1"}, {id: "3", uuid: "c", name: "C", groupId: "1"}]
    m.filtered = m.channels
    m.groups = [{id: "all", name: "All Channels"}]
    m.groupIndex = 0
    m.selected = 1
    m.mode = "recent"
    m.focus = "channels"
    m.historyAccount = "account-a"
    m.userSessionId = "session-a"
    m.favorites = {}
    m.collections = []
    m.settings = normalizeGuideSettings(invalid)
    updateRecentHistory()
    check(m.filtered.count() = 2 and m.selected = 1, "removed middle row selects adjacent row")
    m.ready = false ' Exercise the input controller without Roku render nodes.
    m.top.active = true
    check(not onKeyEvent("options", true) and m.top.active, "fullscreen Star remains Roku-owned")
    check(m.top.historyRequest = invalid, "Star does not request app management")
    check(onKeyEvent("up", true) and m.selected = 0, "Up still browses channels")
    check(onKeyEvent("OK", true) and m.top.channelSelected = invalid and m.top.active, "Recently Watched keeps focus on OK-down")
    check(onKeyEvent("OK", true) and m.top.channelSelected = invalid, "held repeat cannot tune")
    check(onKeyEvent("OK", false) and m.top.channelSelected.uuid = "a" and userViewSession(m.top.channelSelected) = "session-a", "release tunes the selected recent channel")
    check(onKeyEvent("down", true) and m.selected = 1, "Down still browses channels")
    m.top.channelSelected = invalid
    check(onKeyEvent("right", true) and m.focus = "history" and m.selected = 1, "Right focuses the history button without moving the channel cursor")
    check(onKeyEvent("left", true) and m.focus = "channels" and m.selected = 1, "Left returns to the same channel")
    check(onKeyEvent("right", true) and onKeyEvent("up", true) and m.focus = "channels" and m.selected = 0, "Up from management resumes browsing")
    onKeyEvent("down", true)
    onKeyEvent("right", true)
    check(onKeyEvent("OK", true), "OK opens focused management button")
    check(m.top.historyRequest.account = "account-a" and m.top.historyRequest.uuid = "c" and userViewSession(m.top.historyRequest) = "session-a", "request captures account, session and selected channel")
    check(m.top.channelSelected = invalid, "management does not emit a tune")
    m.top.historyRequest = invalid
    check(not onKeyEvent("OK", false), "release does not emit another request")
    check(m.top.historyRequest = invalid, "no duplicate request")
    m.ready = true
    m.top.active = false
    m.top.recentIds = ["c", "a"]
    updateRecentHistory()
    check(m.selected = 0 and m.filtered[0].uuid = "c" and m.focus = "channels", "history edit restores channel focus and retains selected channel if present")
    m.top.recentIds = []
    updateRecentHistory()
    check(m.selected = 0 and m.filtered.count() = 0 and m.focus = "history", "clear leaves the button focused in a valid empty list")
    m.ready = false
    m.top.active = true
    onKeyEvent("left", true)
    check(m.focus = "history", "Left cannot focus a nonexistent channel")
    onKeyEvent("OK", true)
    check(m.top.historyRequest.uuid = "", "empty list management is safe")
    onKeyEvent("back", true)
    check(not m.top.active and m.top.closed, "Back closes empty browser")
    m.top.active = true
    m.mode = "channels"
    m.focus = "channels"
    m.top.historyRequest = invalid
    check(onKeyEvent("left", true) and m.focus = "groups" and m.groupsOpen, "regular browser still opens groups")
    check(onKeyEvent("right", true) and m.focus = "channels", "regular browser Right still returns to channels")
    check(m.top.historyRequest = invalid, "regular browser cannot request history")
    m.filtered = m.channels
    m.selected = 0
    m.top.channelSelected = invalid
    check(onKeyEvent("OK", true) and m.top.channelSelected = invalid and m.top.active, "Channels keeps focus on OK-down")
    check(onKeyEvent("OK", true) and m.top.channelSelected = invalid, "held Channels OK does not move focus to the player")
    check(onKeyEvent("OK", false) and m.top.channelSelected.uuid = "a", "Channels emits once on release")
    m.top.channelSelected = invalid
    check(not onKeyEvent("OK", false) and m.top.channelSelected = invalid, "stray release is harmless")
    onKeyEvent("OK", true)
    onKeyEvent("down", true)
    check(not onKeyEvent("OK", false) and m.top.channelSelected = invalid, "moving focus cancels the uncommitted selection")
    print "ALL TESTS PASSED"
end sub

sub check(condition as boolean, label as string)
    if not condition
        print "FAIL: "; label
        stop
    end if
end sub
