sub main()
    m.fill = {}
    m.label = {}
    m.top = {focusPercent: 0}
    m.content = {title: "A long but ordinary action title", pillAction: true, hasField: function(name as string) as boolean
        return name = "pillAction"
    end function, pillStyle: {width: 952, height: 64, normalFont: {size: 24}, focusedFont: {size: 28}, ink: "0xE8F3FAFF", focusedInk: "0x0A1629FF", fill: "0x1AC4D8FF", active: true}}
    drawPillItem()
    check(m.fill.radius = 32 and m.fill.visible, "unfocused action remains pill shaped")
    check(m.label.horizAlign = "center" and m.label.vertAlign = "center" and m.label.height = 64, "centered full-height text box")
    check(m.label.translation[0] + m.label.width / 2 = 476 and m.label.translation[1] = 0, "symmetric horizontal/vertical label geometry")
    m.top.focusPercent = 1
    drawPillItem()
    check(m.label.font.size = 28 and m.label.color = "0x0A1629FF", "focused font and ink preserved")
    check(m.fill.color = "0x1AC4D8FF", "focused fill preserved")
    m.content.pillStyle.active = false
    drawPillItem()
    check(m.label.font.size = 24 and m.label.color = "0xE8F3FAFF", "list outside focus chain has no stale focus styling")
    m.content.pillAction = false
    drawPillItem()
    check(not m.fill.visible and m.label.horizAlign = "left", "informational/license text is not presented as a button")
    print "ALL TESTS PASSED"
end sub

sub check(ok as boolean, message as string)
    if not ok
        print "FAIL: "; message
        stop
    end if
end sub
