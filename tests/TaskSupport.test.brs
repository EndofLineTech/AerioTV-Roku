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
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
