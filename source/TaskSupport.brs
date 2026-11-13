function isCurrentTaskEvent(event as dynamic, task as dynamic) as boolean
    if event = invalid or task = invalid then return false
    node = event.getRoSGNode()
    if node = invalid then return false
    return task.isSameNode(node) and taskUserSessionCurrent(task)
end function

function currentUserSessionId() as string
    if m.global = invalid then return ""
    if type(m.global) = "roSGNode"
        if not m.global.hasField("activeusersession") then return ""
    end if
    value = m.global.activeusersession
    if type(value) <> "String" and type(value) <> "roString" then return ""
    return value
end function

sub tagTaskForCurrentUser(task as object)
    session = currentUserSessionId()
    if session = "" then return
    if type(task) = "roAssociativeArray"
        task["aeriosession"] = session
    else
        if not task.hasField("aeriosession") then task.addFields({aeriosession: ""})
        task.aeriosession = session
    end if
end sub

function taskUserSessionCurrent(task as object) as boolean
    if type(task) = "roAssociativeArray"
        if not task.doesExist("aeriosession") then return true
    else
        if not task.hasField("aeriosession") then return true
    end if
    session = task.aeriosession
    if type(session) <> "String" and type(session) <> "roString" then return false
    return session <> "" and session = currentUserSessionId()
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
