sub main()
    fit = videoGeometry(1920, 1080, "fit", "4:3")
    assertNear(fit.width, 1920, "Fit delegates original viewport to native aspect handling")
    fill = videoGeometry(1920, 1080, "fill", "4:3")
    assertNear(fill.width * fill.scale[0], 1920, "4:3 fill covers width")
    assertNear(fill.height * fill.scale[1], 1440, "4:3 fill uniform aspect")
    assertNear(fill.translation[1], -180, "vertical crop centered")
    stretch = videoGeometry(1920, 1080, "stretch", "4:3")
    assertNear(stretch.width * stretch.scale[0], 1920, "stretch full width")
    assertNear(stretch.height * stretch.scale[1], 1080, "stretch full height")
    wide = videoGeometry(1920, 1080, "fill", "21:9")
    assertNear(wide.translation[0], -300, "cinema horizontal crop centered")
    mini = videoGeometry(464, 261, "fill", "4:3")
    assertNear(mini.width * mini.scale[0], 464, "mini fill shares geometry")
    assertNear(mini.translation[1], -43.5, "mini crop centered")
    unknown = videoGeometry(1920, 1080, "fill", "")
    assertNear(unknown.scale[0], 1, "unknown aspect falls back to Fit")
    print "ALL TESTS PASSED"
end sub

sub assertNear(actual as float, expected as float, label as string)
    if abs(actual - expected) > 0.01
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
