' brs does not implement Roku's default Label font. Supply an initialized
' stand-in to check the real helper preserves its face while applying sizing.
' This is a font-binding regression test, not an on-device rendering test.
sub main()
    parent = {
        createChild: function(kind as string) as object
            if kind <> "Label" then stop
            return {font: {uri: "test:device-default-face", size: 24}}
        end function
    }
    for each size in [20, 25, 34, 64]
        label = uiLabel(parent, "Server URL", 186, 328, 380, 40, size)
        assertEqual(label.font.uri, "test:device-default-face", "retain a resolved font face")
        assertEqual(label.font.size, size, "apply requested text size")
        assertEqual(label.text, "Server URL", "retain label text")
    end for
    assertEqual(formatClock(0, 5, "12"), "12:05 AM", "midnight")
    assertEqual(formatClock(12, 0, "12"), "12:00 PM", "noon")
    assertEqual(formatClock(23, 59, "24"), "23:59", "24-hour")
    assertEqual(uiControlStyle("primary", false, true).fill, "0xFFFFFFFF", "primary focus is white")
    assertEqual(uiControlStyle("primary", true, false).fill, "0x1AC4D8FF", "unfocused selection is accent")
    assertEqual(uiControlStyle("choice", true, true).ring, "0xFFFFFFFF", "selected pill focus ring")
    assertEqual(uiControlStyle("choice", false, true).ring, "0x1AC4D8FF", "unselected pill focus ring")
    assertEqual(uiControlStyle("primary", true, true, false).scale, 1.0, "disabled never grows")
    content = uiPillContent(200, 50, 80, 24)
    assertEqual(content.iconX, 44, "combined icon/text run is centered")
    assertEqual(content.iconY, 13, "icon is vertically centered")
    assertEqual(content.textX + content.textWidth, 156, "matching left/right margins")
    content = uiPillContent(200, 50, 500, 24)
    assertEqual(content.iconX, 12, "long text retains left padding")
    assertEqual(content.textX + content.textWidth, 188, "long text retains right padding")
    assertEqual(uiCenteredStripX(5, 235, 10, 1920), 352.5, "five groups centered on screen")
    assertEqual(uiCenteredStripX(3, 200, 12, 1728) + 96, 648, "three primary tabs centered in safe area")
    assertEqual(uiCenteredStripX(2, 200, 12, 1728) + 96, 754, "two primary tabs centered")
    assertEqual(uiCenteredStripX(1, 235, 10, 1920), 842.5, "single group centered")
    for each dims in [[200, 50, 25], [60, 60, 30], [10, 4, 50], [200, 50, 0]]
        boxes = uiSurfaceBoxes(dims[0], dims[1], dims[2])
        assertEqual(boxes.count(), 7, "fixed bounded surface node count")
        for each bounds in boxes
            if bounds.w < 0 or bounds.h < 0 or bounds.x < 0 or bounds.y < 0 then stop
            if bounds.x + bounds.w > dims[0] or bounds.y + bounds.h > dims[1] then stop
        end for
    end for
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
