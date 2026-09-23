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
