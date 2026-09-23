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
    print "ALL TESTS PASSED"
end sub
