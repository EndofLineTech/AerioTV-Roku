' Preserve native list scrolling/selection/focus events; own the visual row.
sub init()
    m.top.itemComponentName = "AerioPillListItem"
    m.top.drawFocusFeedback = false
    m.top.vertFocusAnimationStyle = "floatingFocus"
    normal = CreateObject("roSGNode", "Label")
    focused = CreateObject("roSGNode", "Label")
    m.top.font = normal.font
    m.top.focusedFont = focused.font
    for each field in ["content", "itemSize", "focusedChild", "focusBitmapBlendColor"]
        m.top.observeField(field, "stylePillItems")
    end for
    m.top.observeField("itemFocused", "announcePillItem")
end sub

sub stylePillItems()
    if m.styling = true or m.top.content = invalid then return
    m.styling = true
    for each item in m.top.content.getChildren(-1, 0)
        if not item.hasField("pillStyle") then item.addField("pillStyle", "assocarray", true)
        item.pillStyle = {width: m.top.itemSize[0], height: m.top.itemSize[1], normalFont: m.top.font, focusedFont: m.top.focusedFont
            ink: m.top.color, focusedInk: m.top.focusedColor, fill: m.top.focusBitmapBlendColor, active: m.top.isInFocusChain()}
    end for
    m.styling = false
end sub

sub announcePillItem(event as object)
    index = event.getData()
    if m.top.content = invalid or not m.top.isInFocusChain() then return
    if index >= 0 and index < m.top.content.getChildCount() then uiAnnounce(m.top.content.getChild(index).title)
end sub
