sub main()
    m.shape = {scale: [1.0, 1.0]}
    m.top = {
        focusScale: 1.04, pressedScale: 0.95, pressed: false
        nodes: {focusAnimation: {control: ""}, pressAnimation: {control: ""}, focusScaleInterpolator: {}, pressScaleInterpolator: {}}
        findNode: function(id as string) as object
            return m.nodes[id]
        end function
    }
    animateSurface()
    if m.top.nodes.focusAnimation.control <> "start" then stop
    if m.top.nodes.focusScaleInterpolator.keyValue[0][0] <> 1.0 then stop
    if m.top.nodes.focusScaleInterpolator.keyValue[1][0] <> 1.04 then stop
    m.top.pressed = true
    animateSurface()
    if m.top.nodes.pressAnimation.control <> "start" then stop
    if m.top.nodes.pressScaleInterpolator.keyValue[1][0] <> 0.95 then stop
    m.top.pressed = false
    animateSurface()
    if m.top.nodes.focusAnimation.control <> "start" then stop
    m.parts = [{}, {}, {}, {}, {}, {}, {}]
    m.caps = [{}, {}]
    m.pill = {}
    m.top.width = 280
    m.top.height = 94
    m.top.radius = 47
    m.top.cornerOverlap = 2
    m.top.color = "0xFFFFFFFF"
    layoutSurface()
    if not m.pill.visible or m.pill.uri <> "pkg:/images/ui-pill-h94.9.png" then stop
    if m.pill.width <> 280 or m.pill.height <> 94 then stop
    m.top.radius = 12
    layoutSurface()
    if m.pill.visible or not m.parts[3].visible then stop
    m.top.radius = 47
    m.top.height = 131
    m.top.radius = 65.5
    layoutSurface()
    if m.pill.visible then stop ' unsupported bitmap height uses geometry fallback
    if not m.caps[0].visible or m.caps[0].width <> 65.5 or m.caps[0].height <> 131 then stop
    if m.parts[3].visible or m.parts[6].visible then stop
    if m.parts[0].width <> 149 or m.caps[1].translation[0] <> 214.5 then stop
    if m.parts[1].translation[1] <> 1 or m.parts[1].height <> 129 then stop
    m.top.radius = 12
    layoutSurface()
    if m.caps[0].visible or not m.parts[3].visible then stop
    print "ALL TESTS PASSED"
end sub
