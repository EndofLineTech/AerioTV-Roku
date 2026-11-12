sub init()
    m.fill = m.top.findNode("fill")
    m.label = m.top.findNode("label")
    m.content = invalid
end sub

sub setPillContent()
    if m.content <> invalid then m.content.unobserveField("pillStyle")
    m.content = m.top.itemContent
    if m.content <> invalid
        if not m.content.hasField("pillStyle") then m.content.addField("pillStyle", "assocarray", true)
        m.content.observeField("pillStyle", "drawPillItem")
        drawPillItem()
    end if
end sub

sub drawPillItem()
    if m.fill = invalid or m.content = invalid then return
    style = m.content.pillStyle
    if type(style) <> "roAssociativeArray" then return
    width = style.width
    height = style.height
    action = true
    if m.content.hasField("pillAction") then action = m.content.pillAction
    if not action then uiReleaseCenteredLabel(m.label)
    m.fill.width = width
    m.fill.height = height
    m.fill.radius = height / 2
    m.fill.cornerOverlap = 2
    m.fill.visible = action
    m.label.translation = [24, 0]
    m.label.width = width - 48
    m.label.height = height
    m.label.vertAlign = "center"
    m.label.text = m.content.title
    m.label.horizAlign = "center"
    if not action then m.label.horizAlign = "left"
    m.label.font = style.normalFont
    uiSetColor(m.fill, "0x263549FF")
    m.label.color = style.ink ' List color fields are already resolved native colors.
    if m.top.focusPercent > 0.5 and style.active
        if action
            m.label.font = style.focusedFont
            m.fill.color = style.fill
            m.label.color = style.focusedInk
        else
            uiSetColor(m.label, "0x1AC4D8FF")
        end if
    end if
    if action then uiCenterLabel(m.label, 24, 0, width - 48, height)
end sub
