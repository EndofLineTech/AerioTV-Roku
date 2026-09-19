function isCurrentTaskEvent(event as dynamic, task as dynamic) as boolean
    if event = invalid or task = invalid then return false
    node = event.getRoSGNode()
    if node = invalid then return false
    return task.isSameNode(node)
end function

function connectionTimedOut(elapsedSeconds as integer) as boolean
    return elapsedSeconds >= 120
end function
