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
    m.global.profileswitchpending = true
    assertEqual(userEventCurrent(userViewEvent({action: "connection"}, "session-a-3")), false, "switch scrim refuses UI events even with the staging Task session tag")
    assertEqual(requestGateTaskSessionCurrent(), true, "switch scrim permits only the properly tagged incoming Task, unlike a PIN cover")
    m.global.profileswitchpending = false
    m.global.profileownsigninpending = true
    assertEqual(userEventCurrent(userViewEvent({action: "connection"}, "session-a-3")), false, "credential form fences outgoing UI events without relabeling its user's Task session")
    assertEqual(requestGateTaskSessionCurrent(), true, "credential verification Task remains admitted while ordinary UI actions are fenced")
    m.global.profileownsigninpending = false
    m.global.profilegateclosed = true
    m.global.activeusersession = "00000000-0000-4000-8000-000000000090"
    m.global.profilesyncflush = "00000000-0000-4000-8000-000000000093"
    m.top = {aeriosession: m.global.activeusersession, flushNonce: m.global.profilesyncflush, userScope: {sessionId: m.global.activeusersession}, baseUrl: "https://example.test", kind: "DispatcharrSyncWriteTask"
        subtype: function() as string
            return m.kind
        end function
    }
    assertEqual(requestGateTaskSessionCurrent(), true, "only explicitly registered writer keeps the actual outgoing adopted nonce behind the PIN fence")
    m.writerOwnKey = "alice.aeriotv"
    assertEqual(requestGateAcquire("https://example.test/api/channels/channels/", "synthetic-own").allowed, false, "outgoing flush exception cannot fetch content")
    assertEqual(requestGateAcquire("https://example.test/api/accounts/users/me/app-data/other.aeriotv/", "synthetic-own").allowed, false, "flush exception cannot address another key")
    m.top.kind = "DispatcharrTask"
    assertEqual(requestGateTaskSessionCurrent(), false, "ordinary Tasks cannot claim the outgoing-flush exception")
    m.top.kind = "DispatcharrSyncWriteTask"
    m.global.profileswitchpending = true
    assertEqual(requestGateTaskSessionCurrent(), false, "incoming staging retires the outgoing write exception")
    m.global.profileswitchpending = false
    m.global.profilesyncflush = ""
    assertEqual(requestGateTaskSessionCurrent(), false, "cleared flush nonce fences a late outgoing request")
    m.top = {aeriosession: m.global.activeusersession}
    assertEqual(requestGateTaskSessionCurrent(), false, "ordinary old user Tasks remain blocked throughout outgoing flush")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
