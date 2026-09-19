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
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
