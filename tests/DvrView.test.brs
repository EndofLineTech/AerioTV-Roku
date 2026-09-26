sub main()
    m.top = {config: {permission: "view", scope: "scope-two", accountId: "account-two", channels: []}, active: false}
    m.list = invalid
    m.loaded = []
    m.rows = []
    m.task = invalid
    m.mutationTask = invalid
    m.pending = {action: "delete", scope: "scope-one", accountId: "account-one"}
    m.dialog = {close: false, unobserveField: sub(field as string)
        m.unobserved = true
    end sub}
    previous = m.dialog
    onDvrConfig()
    assertEqual(m.dialog, invalid, "account or permission change dismisses old recording action")
    assertEqual(previous.close, true, "old recording dialog is closed")
    assertEqual(previous.unobserved, true, "stale confirmation callback detached")
    assertEqual(m.pending, invalid, "old recording identity dropped")

    m.pending = {action: "delete", recordingId: "8", scope: "scope-one", accountId: "account-one"}
    m.dialog = {id: "confirm", close: false, isSameNode: function(node as object) as boolean
        return node.id = "confirm"
    end function}
    onDvrConfirmed({getRoSGNode: function() as object
        return {id: "confirm"}
    end function, getData: function() as integer
        return 1
    end function})
    assertEqual(m.mutationTask, invalid, "old-account confirmation cannot mutate server")
    assertEqual(m.pending, invalid, "old-account confirmation cannot be replayed")

    m.top.active = true
    m.list = {jumpToItem: -1, isSameNode: function(node as object) as boolean
        return node.id = "list"
    end function}
    m.rows = [{section: "now", heading: "Recording Now"}, {id: "4", title: "Live"}, {section: "scheduled", heading: "Scheduled"}, {id: "5", title: "Tomorrow"}]
    m.lastFocusedItem = 1
    onDvrFocused(dvrListEvent(2))
    assertEqual(m.list.jumpToItem, 3, "down skips header and focuses next recording")
    m.lastFocusedItem = 3
    onDvrFocused(dvrListEvent(2))
    assertEqual(m.list.jumpToItem, 1, "up skips header and focuses previous recording")
    m.dialog = invalid
    onDvrSelected(dvrListEvent(2))
    assertEqual(m.dialog, invalid, "header cannot open a recording action")
    print "ALL TESTS PASSED"
end sub

function dvrListEvent(index as integer) as object
    return {index: index, getRoSGNode: function() as object
        return {id: "list"}
    end function, getData: function() as integer
        return m.index
    end function}
end function

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
