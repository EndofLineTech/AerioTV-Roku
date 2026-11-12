sub init()
    m.shape = m.top.findNode("shape")
    m.parts = []
    for i = 0 to 2
        m.parts.push(m.shape.createChild("Rectangle"))
    end for
    for each corner in ["tl", "tr", "bl", "br"]
        poster = m.shape.createChild("Poster")
        poster.uri = "pkg:/images/ui-corner-" + corner + ".png"
        poster.loadDisplayMode = "scaleToFill"
        m.parts.push(poster)
    end for
    m.caps = []
    for each side in ["left", "right"]
        cap = m.shape.createChild("Poster")
        cap.uri = "pkg:/images/ui-cap-" + side + ".png"
        cap.loadDisplayMode = "scaleToFill"
        m.caps.push(cap)
    end for
    m.pill = m.shape.createChild("Poster")
    m.pill.loadDisplayMode = "noScale"
    layoutSurface()
end sub

sub layoutSurface()
    if m.parts = invalid then return
    boxes = uiSurfaceBoxes(m.top.width, m.top.height, m.top.radius, m.top.cornerOverlap)
    pill = m.top.width >= m.top.height and m.top.radius >= m.top.height / 2 and m.top.height > 0
    bitmap = pill and m.top.width >= m.top.height + 2 and m.top.height >= 20 and m.top.height <= 128 and int(m.top.height) = m.top.height and int(m.top.height) mod 2 = 0
    m.pill.visible = bitmap
    if bitmap
        m.pill.width = m.top.width
        m.pill.height = m.top.height
        m.pill.blendColor = m.top.color
        m.pill.uri = "pkg:/images/ui-pill-h" + int(m.top.height).toStr() + ".9.png"
    end if
    if pill then boxes = uiPillSurfaceBoxes(m.top.width, m.top.height)
    m.shape.scaleRotateCenter = [m.top.width / 2, m.top.height / 2]
    for i = 0 to m.parts.count() - 1
        part = m.parts[i]
        part.visible = false
        if not bitmap and (not pill or i < 2)
            bounds = boxes[i]
            if pill and i = 1 then bounds = boxes[3]
            part.translation = [bounds.x, bounds.y]
            part.width = bounds.w
            part.height = bounds.h
            part.visible = bounds.w > 0 and bounds.h > 0
            if i < 3 then part.color = m.top.color else part.blendColor = m.top.color
        end if
    end for
    for i = 0 to m.caps.count() - 1
        cap = m.caps[i]
        cap.visible = pill and not bitmap
        if pill and not bitmap
            bounds = boxes[i + 1]
            cap.translation = [bounds.x, bounds.y]
            cap.width = bounds.w
            cap.height = bounds.h
            cap.blendColor = m.top.color
        end if
    end for
end sub

sub animateSurface()
    if m.shape = invalid then return
    focusAnim = m.top.findNode("focusAnimation")
    pressAnim = m.top.findNode("pressAnimation")
    focusAnim.control = "stop"
    pressAnim.control = "stop"
    target = m.top.focusScale
    interpolator = m.top.findNode("focusScaleInterpolator")
    animation = focusAnim
    if m.top.pressed then
        target = m.top.pressedScale
        interpolator = m.top.findNode("pressScaleInterpolator")
        animation = pressAnim
    end if
    interpolator.keyValue = [m.shape.scale, [target, target]]
    animation.control = "start"
end sub
