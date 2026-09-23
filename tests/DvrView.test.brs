sub main()
    m.top = {config: {permission: "view", scope: "scope-two", accountId: "account-two", channels: []}, active: false}
    m.tabLabels = invalid
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
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
