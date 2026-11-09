sub init()
    m.top.focusable = true
    m.content = m.top.findNode("content")
    m.watch = m.top.findNode("watch")
    m.watch.observeField("fire", "watchSetupTask")
    m.task = invalid
    m.info = {kind: "preparing"}
    m.index = 0
end sub

sub stopSetupTask()
    m.watch.control = "stop"
    if m.task <> invalid
        m.task.cancelRequested = true
        m.task.unobserveField("info")
        m.task.unobserveField("result")
        m.task.info = invalid
        m.task.result = invalid
        ' Do not force STOP: cooperative cancellation closes sockets/keys first.
        m.task = invalid
    end if
end sub

sub onSetupActive()
    stopSetupTask()
    m.top.payload = invalid
    m.top.phase = ""
    if not m.top.active
        m.content.removeChildrenIndex(m.content.getChildCount(), 0)
        return
    end if
    m.info = {kind: "preparing"}
    m.index = 0
    drawPhoneSetup()
    m.task = CreateObject("roSGNode", "PhoneSetupTask")
    m.task.observeField("info", "onSetupInfo")
    m.task.observeField("result", "onSetupPayload")
    m.task.control = "RUN"
    m.watch.control = "start"
    m.top.setFocus(true)
end sub

sub onSetupInfo(event as object)
    if m.task = invalid then return
    if not event.getRoSGNode().isSameNode(m.task) then return
    if type(event.getData()) <> "roAssociativeArray" then return
    m.info = event.getData()
    m.top.sessionInfo = m.info
    if m.info.kind = "accepted" then m.top.phase = "Connecting to your server"
    drawPhoneSetup()
end sub

sub onSetupPayload(event as object)
    if m.task = invalid then return
    if not event.getRoSGNode().isSameNode(m.task) or not m.top.active then return
    payload = event.getData()
    if type(payload) <> "roAssociativeArray" then return
    m.task.result = invalid
    m.watch.control = "stop"
    m.top.phase = "Connecting to your server"
    m.top.payload = payload
end sub

sub watchSetupTask()
    if m.task = invalid or m.top.phase <> "" then return
    if m.task.state = "done" or m.task.state = "stop"
        if m.info.kind = "ready" or m.info.kind = "preparing" or m.info.kind = "rotating"
            m.info = {kind: "error", message: "The setup task stopped. Get a new code to try again."}
            drawPhoneSetup()
        end if
    end if
end sub

sub drawPhoneSetup()
    if m.content = invalid or not m.top.active then return
    m.content.removeChildrenIndex(m.content.getChildCount(), 0)
    uiLabel(m.content, "Set up from another device", 130, 70, 1660, 90, 55)
    kind = m.info.kind
    m.actions = ["New Code", "Cancel"]
    if m.top.phase <> ""
        uiLabel(m.content, m.top.phase, 160, 350, 1580, 100, 40, "0x1AC4D8FF")
        m.actions = ["Cancel"]
    else if kind = "ready"
        uiLabel(m.content, m.info.name, 160, 245, 930, 70, 34, "0x9EB5C9FF")
        uiLabel(m.content, m.info.code, 150, 337, 970, 155, 112)
        uiLabel(m.content, "Key " + m.info.fingerprint, 160, 500, 950, 68, 40, "0x1AC4D8FF")
        copy = uiLabel(m.content, "Open AerioTV on your other device, then Settings > Playlists > open your playlist > Set up another device, or scan this code.", 160, 600, 930, 235, 30)
        copy.wrap = true
        phoneSetupDrawQr(m.info.rows)
    else if kind = "expired"
        uiLabel(m.content, "The setup code expired", 160, 330, 1500, 80, 42)
        uiLabel(m.content, "Codes last 10 minutes. Get a new code to try again.", 160, 450, 1500, 110, 30, "0x9EB5C9FF")
    else if kind = "offline"
        uiLabel(m.content, "This device is not on a network", 160, 330, 1500, 80, 42)
        copy = uiLabel(m.content, "Connect this device to the same network as your other device, then try again.", 160, 450, 1500, 140, 30)
        copy.wrap = true
        m.actions = ["Try Again", "Cancel"]
    else if kind = "preparing" or kind = "rotating"
        uiLabel(m.content, "Preparing a secure setup code", 160, 350, 1500, 100, 40, "0x1AC4D8FF")
        m.actions = ["Cancel"]
    else
        uiLabel(m.content, "Setup is not available", 160, 330, 1500, 80, 42)
        message = "Get a new code to try again, or use manual setup."
        if m.info.message <> invalid then message = m.info.message
        copy = uiLabel(m.content, message, 160, 450, 1500, 160, 30)
        copy.wrap = true
        m.actions = ["Try Again", "Cancel"]
    end if
    if m.index >= m.actions.count() then m.index = 0
    for i = 0 to m.actions.count() - 1
        color = "0x17344AFF"
        textColor = "0xE8F3FAFF"
        if i = m.index
            color = "0x1AC4D8FF"
            textColor = "0x0A1629FF"
        end if
        uiRect(m.content, 160 + i * 500, 870, 460, 82, color)
        label = uiLabel(m.content, m.actions[i], 180 + i * 500, 890, 420, 45, 29, textColor)
        label.horizAlign = "center"
    end for
    if m.top.warning <> "" then uiLabel(m.content, m.top.warning, 160, 985, 1610, 58, 22, "0xFFB080FF")
end sub

sub phoneSetupDrawQr(rows as dynamic)
    if type(rows) <> "roArray" then return
    ' Integer modules, four-module quiet zone, no smoothing or mark overlay.
    scale = 6
    uiRect(m.content, 1150, 220, 630, 630, "0xFFFFFFFF")
    for y = 0 to rows.count() - 1
        x = 0
        while x < 97
            start = x
            if mid(rows[y], x + 1, 1) = "1"
                while x < 97 and mid(rows[y], x + 1, 1) = "1"
                    x++
                end while
                uiRect(m.content, 1150 + (start + 4) * scale, 220 + (y + 4) * scale, (x - start) * scale, scale, "0x000000FF")
            else
                x++
            end if
        end while
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.active then return false
    if key = "back"
        m.top.active = false
        m.top.closed = true
        return true
    end if
    if key = "left" or key = "right"
        if key = "left" then m.index-- else m.index++
        if m.index < 0 then m.index = m.actions.count() - 1
        if m.index >= m.actions.count() then m.index = 0
        drawPhoneSetup()
        return true
    end if
    if key = "OK"
        if m.actions[m.index] = "Cancel"
            m.top.active = false
            m.top.closed = true
        else
            onSetupActive()
        end if
        return true
    end if
    return true
end function
