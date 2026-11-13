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

function userProfileGateClosed() as boolean
    if m.global = invalid then return false
    if type(m.global) = "roSGNode"
        if not m.global.hasField("profilegateclosed") then return false
    end if
    return m.global.profilegateclosed = true
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
    if userProfileGateClosed() then return false
    if type(task) = "roAssociativeArray"
        if not task.doesExist("aeriosession") then return true
    else
        if not task.hasField("aeriosession") then return true
    end if
    session = task.aeriosession
    if type(session) <> "String" and type(session) <> "roString" then return false
    return session <> "" and session = currentUserSessionId()
end function

' Capture the view's configured session, never the current global session at
' emission time: a delayed old view must not label its old data as incoming.
function userViewEvent(value as object, session = invalid as dynamic) as object
    result = userEventData(value)
    if type(session) = "String" or type(session) = "roString"
        if session <> "" then result["aeriosession"] = session
    end if
    return result
end function

function userViewSession(value as dynamic) as string
    if type(value) <> "roAssociativeArray" then return ""
    captured = value["aeriosession"]
    if type(captured) <> "String" and type(captured) <> "roString" then return ""
    return captured
end function

function userProfileUiClosed() as boolean
    if userProfileGateClosed() then return true
    if m.global <> invalid
        for each pendingField in ["profileswitchpending", "profileownsigninpending"]
            if type(m.global) = "roSGNode"
                if m.global.hasField(pendingField)
                    if m.global[pendingField] = true then return true
                end if
            else
                if m.global[pendingField] = true then return true
            end if
        end for
    end if
    return false
end function

function userEventCurrent(value as dynamic) as boolean
    if userProfileUiClosed() then return false
    if type(value) <> "roAssociativeArray" then return false
    count = 0
    captured = invalid
    for each key in value
        if lcase(key) = "aeriosession"
            count++
            captured = value[key]
        end if
    end for
    current = currentUserSessionId()
    if count = 0 then return current = ""
    if count <> 1 then return false
    if type(captured) <> "String" and type(captured) <> "roString" then return false
    return captured = current
end function

function userEventData(value as object) as object
    ' Local SceneGraph event/model schema fields use ordinary case-insensitive
    ' AA lookup. Do not turn literal apiKey/accountId fields into a parsed,
    ' case-sensitive JSON map while copying their envelope.
    result = {}
    for each key in value
        if lcase(key) <> "aeriosession" then result[key] = value[key]
    end for
    return result
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
