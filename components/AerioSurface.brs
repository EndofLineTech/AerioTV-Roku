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
    layoutSurface()
end sub

sub layoutSurface()
    if m.parts = invalid then return
    boxes = uiSurfaceBoxes(m.top.width, m.top.height, m.top.radius)
    m.shape.scaleRotateCenter = [m.top.width / 2, m.top.height / 2]
    for i = 0 to m.parts.count() - 1
        part = m.parts[i]
        bounds = boxes[i]
        part.translation = [bounds.x, bounds.y]
        part.width = bounds.w
        part.height = bounds.h
        part.visible = bounds.w > 0 and bounds.h > 0
        if i < 3 then part.color = m.top.color else part.blendColor = m.top.color
    end for
end sub

sub animateSurface()
    if m.shape = invalid then return
    focusAnim = m.top.findNode("focusAnimation")
    pressAnim = m.top.findNode("pressAnimation")
    if m.top.focusScale <> m.shape.scale then
        focusAnim.control = "stop"
        m.top.findNode("focusScaleInterpolator").keyValue = [m.shape.scale, [m.top.focusScale, m.top.focusScale]]
        focusAnim.control = "start"
    end if
    if m.top.pressedScale <> m.shape.scale then
        pressAnim.control = "stop"
        m.top.findNode("pressScaleInterpolator").keyValue = [m.shape.scale, [m.top.pressedScale, m.top.pressedScale]]
        pressAnim.control = "start"
    end if
    if m.top.pressed then
        if m.top.pressedScale = 0.95 then
            pressAnim.control = "stop"
            m.top.findNode("pressScaleInterpolator").keyValue = [m.shape.scale, [0.95, 0.95]]
            pressAnim.control = "start"
        end if
    end if
end sub
