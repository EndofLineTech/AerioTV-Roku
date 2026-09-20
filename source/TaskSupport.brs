function isCurrentTaskEvent(event as dynamic, task as dynamic) as boolean
    if event = invalid or task = invalid then return false
    node = event.getRoSGNode()
    if node = invalid then return false
    return task.isSameNode(node)
end function

function connectionTimedOut(elapsedSeconds as integer) as boolean
    return elapsedSeconds >= 120
end function

sub cancelNetworkTask(task as dynamic)
    if task = invalid then return
    if type(task) = "roAssociativeArray"
        task.cancelRequested = true
    else if task.hasField("cancelRequested")
        ' Allow the transport's bounded poll loop to cancel and delete staging.
        task.cancelRequested = true
    else
        task.control = "STOP"
    end if
end sub
