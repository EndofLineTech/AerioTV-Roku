sub main()
    ' Two wrappers can represent one underlying node. Identity is determined
    ' by the node API, not the BrightScript wrapper object.
    task = {
        nodeId: "active"
        wrapper: "owner"
        isSameNode: function(other as object) as boolean
            return m.nodeId = other.nodeId
        end function
    }
    event = {
        node: {nodeId: "active", wrapper: "event"}
        getRoSGNode: function() as object
            return m.node
        end function
    }
    assertEqual(isCurrentTaskEvent(event, task), true, "accept completion from another wrapper of active node")
    event.node.nodeId = "cancelled"
    assertEqual(isCurrentTaskEvent(event, task), false, "ignore cancelled attempt after retry")
    assertEqual(isCurrentTaskEvent(event, invalid), false, "ignore completion after cancellation")
    event.node = invalid
    assertEqual(isCurrentTaskEvent(event, task), false, "reject missing source")
    assertEqual(connectionTimedOut(119), false, "deadline not reached")
    assertEqual(connectionTimedOut(120), true, "deadline reached")
    assertEqual(connectionTimedOut(121), true, "late timer still expires")
    event.node = {nodeId: "active"}
    m.global = {activeusersession: "session-a-1"}
    tagTaskForCurrentUser(task)
    assertEqual(isCurrentTaskEvent(event, task), true, "tagged current session callback accepted")
    m.global.activeusersession = ""
    assertEqual(isCurrentTaskEvent(event, task), false, "retirement rejects old callbacks before another account is active")
    m.global.activeusersession = "session-b-1"
    assertEqual(isCurrentTaskEvent(event, task), false, "A callback cannot mutate B")
    m.global.activeusersession = "session-a-2"
    assertEqual(isCurrentTaskEvent(event, task), false, "returning to A cannot revive old A callback")
    tagTaskForCurrentUser(task)
    assertEqual(isCurrentTaskEvent(event, task), true, "freshly captured incoming session accepted")
    payload = userViewEvent({favoriteIds: ["own"]}, "session-a-2")
    assertEqual(userEventCurrent(payload), true, "current view envelope accepted")
    m.global.activeusersession = "session-b-2"
    assertEqual(userEventCurrent(payload), false, "queued view data cannot cross into B")
    m.global.activeusersession = "session-a-3"
    assertEqual(userEventCurrent(payload), false, "queued view data cannot revive after A/B/A")
    assertEqual(userEventCurrent({favoriteIds: ["wrong"]}), false, "scoped app refuses untagged view data")
    assertEqual(userViewSession(payload), "session-a-2", "view captures explicit configured identity, not incoming global")
    assertEqual(userEventCurrent({aeriosession: 7}), false, "typed malformed context fails closed")
    aliases = ParseJson("{" + chr(34) + "aeriosession" + chr(34) + ":" + chr(34) + "session-a-3" + chr(34) + "," + chr(34) + "AerioSession" + chr(34) + ":" + chr(34) + "session-a-3" + chr(34) + "}")
    if aliases.count() = 2 then assertEqual(userEventCurrent(aliases), false, "ambiguous native envelope aliases fail closed")
    assertEqual(instr(1, FormatJson(userEventData(payload)), "session-a-2"), 0, "transient envelope context never enters persisted account data")
    m.global.activeusersession = ""
    assertEqual(userEventCurrent({favoriteIds: ["legacy"]}), true, "unscoped direct-provider fixtures retain their legacy contract")
    m.global.profilegateclosed = true
    assertEqual(userEventCurrent({favoriteIds: ["legacy"]}), false, "launch protection rejects even unscoped direct handler events")
    m.global.activeusersession = "session-a-3"
    tagTaskForCurrentUser(task)
    assertEqual(isCurrentTaskEvent(event, task), false, "protected screen refuses current user background completion")
    m.top = task
    assertEqual(requestGateTaskSessionCurrent(), false, "protected screen refuses tagged Task network admission")
    m.global.profilegateclosed = false
    assertEqual(isCurrentTaskEvent(event, task), true, "verified closure restores own-session completion admission")
    assertEqual(requestGateTaskSessionCurrent(), true, "verified closure restores tagged network admission")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
