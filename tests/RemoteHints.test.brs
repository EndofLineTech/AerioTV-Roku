sub main()
    m.top = hintNode("root")
    m.top.width = 1728
    m.top.height = 36
    m.top.fontSize = 22
    m.top.text = "OK  Select     Hold Left  Groups     Back  Return"
    renderHints()
    if m.top.children.count() <> 3 then stop
    keys = ["OK", "Hold Left", "Back"]
    help = ["Select", "Groups", "Return"]
    for i = 0 to 2
        children = m.top.children[i].children
        if children.count() <> 3 then stop
        pill = children[0]
        keyLabel = children[1]
        helpLabel = children[2]
        if pill.kind <> "AerioSurface" or keyLabel.text <> keys[i] or helpLabel.text <> help[i] then stop
        if helpLabel.translation[0] <= pill.width then stop ' help is OUTSIDE the pill
        if keyLabel.horizAlign <> "center" or keyLabel.vertAlign <> "center" or helpLabel.vertAlign <> "center" then stop
        if keyLabel.translation[0] * 2 + keyLabel.width <> pill.width then stop
    end for
    m.top.text = "Loading guide..."
    renderHints()
    if m.top.children[0].children.count() <> 1 then stop ' status is not a key pill
    m.top.width = 50
    m.top.text = "Hold Left  Groups"
    renderHints()
    if m.top.children.count() <> 0 then stop ' do not draw a clipped key
    print "ALL TESTS PASSED"
end sub

function hintNode(kind as string) as object
    return {kind: kind, children: [], font: {size: 22}, createChild: function(kind as string) as object
        child = hintNode(kind)
        m.children.push(child)
        return child
    end function, getChildCount: function() as integer
        return m.children.count()
    end function, removeChildrenIndex: sub(count as integer, index as integer)
        m.children = []
    end sub, removeChild: sub(child as object)
        m.children.pop()
    end sub, localBoundingRect: function() as object
        return {width: len(m.text) * 10}
    end function}
end function
