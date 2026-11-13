' brs does not implement Roku's default Label font. Supply an initialized
' stand-in to check the real helper preserves its face while applying sizing.
' This is a font-binding regression test, not an on-device rendering test.
sub main()
    secureBox = {secureMode: false, secureLastCharacter: false, hasField: function(field as string) as boolean
        return field = "secureLastCharacter"
    end function}
    uiSecureTextInput(secureBox)
    assertEqual(secureBox.secureMode, true, "password entry is masked")
    assertEqual(secureBox.secureLastCharacter, true, "last typed password character stays masked where supported")
    legacyBox = {secureMode: false, hasField: function(field as string) as boolean
        return false
    end function}
    uiSecureTextInput(legacyBox)
    assertEqual(legacyBox.secureMode, true, "secure mode retained without optional last-character field")
    assertEqual(legacyBox.doesExist("secureLastCharacter"), false, "unsupported optional field is not invented")
    assertEqual(uiControlInkOffset("Cancel", 24), 2.5, "native ascender-only control ink needs optical baseline correction")
    assertEqual(uiControlInkOffset("Record current program", 24), 0, "descenders already occupy the lower line box")
    assertEqual(uiControlInkOffset("OK", 19), 2, "hint correction scales with font")
    assertEqual(uiControlInkOffset("Cancel", 29), 3, "large control correction follows resolved font")
    parent = {
        createChild: function(kind as string) as object
            if kind = "AerioSurface" then return {kind: kind}
            if kind <> "Label" then stop
            return {kind: kind, font: {uri: "test:device-default-face", size: 24}}
        end function
    }
    for each size in [20, 25, 34, 64]
        label = uiLabel(parent, "Server URL", 186, 328, 380, 40, size)
        assertEqual(label.font.uri, "test:device-default-face", "retain a resolved font face")
        assertEqual(label.font.size, size, "apply requested text size")
        assertEqual(label.text, "Server URL", "retain label text")
    end for
    for each height in [40, 58, 64, 82, 90, 92]
        button = uiButton(parent, "Cancel", 160, 300, 460, height, 25, "0x263549FF")
        assertEqual(button.bg.radius, height / 2, "button has full pill end caps")
        assertEqual(button.label.horizAlign, "center", "button text horizontally centered")
        assertEqual(button.label.vertAlign, "center", "button text vertically centered")
        assertEqual(button.label.translation[1], 302.5, "full-height label has native optical ink correction")
        assertEqual(button.label.height, height, "label and button share vertical bounds")
        assertEqual(button.label.translation[0] + button.label.width / 2, 390, "symmetric horizontal label bounds")
    end for
    assertEqual(formatClock(0, 5, "12"), "12:05 AM", "midnight")
    assertEqual(formatClock(12, 0, "12"), "12:00 PM", "noon")
    assertEqual(formatClock(23, 59, "24"), "23:59", "24-hour")
    palette = uiPalette()
    palette.accent = "0xA78BFAFF"
    palette.background = "0x111111FF"
    assertEqual(uiColorForPalette("0x1AC4D840", palette, false), "0xA78BFA40", "theme recolors accent while retaining opacity")
    assertEqual(uiColorForPalette("0x0A1628FF", palette, false), "0x111111FF", "background uses theme")
    assertEqual(uiColorForPalette("0x0A1628FF", palette, true), palette.ink, "dark focus ink is not light-mode background")
    assertEqual(uiColorForPalette("0xFF4757FF", palette, false), "0xFF4757FF", "EPG semantic red is not recolored")
    for each preset in ["aerio", "midnight", "sunset", "forest", "lavender", "monochrome", "light"]
        for each mode in ["dark", "light"]
            themed = uiResolvedPalette({themePreset: preset, appearanceMode: mode})
            if uiContrastRatio(themed.text, themed.background) < 4.5 then stop
            if uiContrastRatio(themed.onAccent, themed.accent) < 4.5 then stop
        end for
    end for
    assertEqual(uiResolvedPalette({themePreset: "lavender"}).accent, "0xA78BFAFF", "upstream lavender accent")
    assertEqual(uiResolvedPalette({customAccent: "FF8800"}).accent, "0xFF8800FF", "custom accent override")
    assertEqual(uiResolvedPalette({customAccent: "not-hex"}).accent, "0x1AC4D8FF", "malformed accent fallback")
    prefs = normalizeDevicePreferences({themePreset: "unknown", appearanceMode: "system", customAccent: "invalid"})
    assertEqual(prefs.themePreset, "aerio", "safe migration preset")
    assertEqual(prefs.appearanceMode, "dark", "no invented system appearance")
    assertEqual(prefs.customAccent, "", "invalid accent cleared")
    assertEqual(uiScaledFontSize(24, 68, false, {textSize: 120, subtextSize: 100}), 29, "large primary text")
    assertEqual(uiScaledFontSize(24, 68, false, {textSize: 90, subtextSize: 100}), 22, "small primary text")
    assertEqual(uiScaledFontSize(20, 36, true, {textSize: 120, subtextSize: 110}), 26, "independent secondary scale")
    if uiScaledFontSize(24, 24, false, {textSize: 120}) > 21 then stop
    if normalizeDevicePreferences({textSize: 999, subtextSize: -1}).textSize <> 100 then stop
    high = uiResolvedPalette({contrastMode: "high", appearanceMode: "light"})
    light = uiResolvedPalette({appearanceMode: "light"})
    assertEqual(uiColorForPalette("0xB6DCE7FF", light, true), light.secondary, "guide subtitle follows secondary theme ink")
    if uiContrastRatio(light.secondary, light.background) < 4.5 then stop
    assertEqual(high.secondary, high.text, "high contrast raises secondary ink")
    assertEqual(uiControlStyle("primary", false, true).fill, "0xFFFFFFFF", "primary focus is white")
    assertEqual(uiControlStyle("primary", true, false).fill, "0x1AC4D8FF", "unfocused selection is accent")
    assertEqual(uiControlStyle("choice", true, true).ring, "0xFFFFFFFF", "selected pill focus ring")
    assertEqual(uiControlStyle("choice", false, true).ring, "0x1AC4D8FF", "unselected pill focus ring")
    assertEqual(uiControlStyle("primary", true, true, false).scale, 1.0, "disabled never grows")
    content = uiPillContent(200, 50, 80, 24)
    assertEqual(content.iconX, 12, "icon stays in leading gutter")
    assertEqual(content.iconY, 13, "icon is vertically centered")
    assertEqual(content.textX + content.textWidth / 2, 100, "text itself stays centered in the pill")
    content = uiPillContent(200, 50, 500, 24)
    assertEqual(content.iconX, 12, "long text retains left padding")
    assertEqual(content.textX + content.textWidth, 156, "symmetric icon gutters prevent label/icon collisions")
    assertEqual(uiCenteredStripX(5, 235, 10, 1920), 352.5, "five groups centered on screen")
    assertEqual(uiCenteredStripX(3, 200, 12, 1728) + 96, 648, "three primary tabs centered in safe area")
    assertEqual(uiCenteredStripX(2, 200, 12, 1728) + 96, 754, "two primary tabs centered")
    assertEqual(uiCenteredStripX(1, 235, 10, 1920), 842.5, "single group centered")
    for each flag in [{label: "LIVE", width: 56}, {label: "NEW", width: 46}, {label: "PREMIERE", width: 96}, {label: "FINALE", width: 76}]
        bounds = uiFlagLabelBounds(flag.label, flag.width)
        assertEqual(bounds.y + bounds.height / 2, 14, "uppercase optical center is two pixels below line-box center")
        if bounds.x < 0 or bounds.x + bounds.width > flag.width or bounds.y + bounds.height > 24 then stop
    end for
    for each dims in [[200, 50, 25], [60, 60, 30], [10, 4, 50], [200, 50, 0]]
        boxes = uiSurfaceBoxes(dims[0], dims[1], dims[2])
        assertEqual(boxes.count(), 7, "fixed bounded surface node count")
        for each bounds in boxes
            if bounds.w < 0 or bounds.h < 0 or bounds.x < 0 or bounds.y < 0 then stop
            if bounds.x + bounds.w > dims[0] or bounds.y + bounds.h > dims[1] then stop
        end for
    end for
    ' Pill cap masks must cover the center rectangle's sampled edge when
    ' focus-scaled; touching exactly leaves a dark vertical seam on Roku.
    boxes = uiSurfaceBoxes(235, 40, 20, 2)
    assertEqual(boxes[0].x + boxes[0].w, 215, "center fill reaches right cap")
    assertEqual(boxes[4].x, 213, "top-right cap overlaps center by two pixels")
    assertEqual(boxes[6].x, 213, "bottom-right cap overlaps center by two pixels")
    assertEqual(boxes[4].x + boxes[4].w, 235, "overlap preserves pill outer edge")
    assertEqual(boxes[3].w, 22, "top-left cap covers the left join")
    caps = uiPillSurfaceBoxes(280, 94)
    assertEqual(caps.count(), 4, "pill uses unsplit full-height caps and inset seam coverage")
    assertEqual(caps[1].w, 47, "cap preserves circular aspect, never widened for overlap")
    assertEqual(caps[1].h, 94, "no top/bottom quadrant join")
    assertEqual(caps[3].x, 46, "inset center overlaps cap without stretching it")
    assertEqual(caps[3].w, 188, "both straight cap joins are covered")
    assertEqual(caps[3].y, 1, "overlap does not protrude at top/bottom curve")
    scene = {backgroundColor: "0x0A1628FF", uiPaint: {backgroundColor: {color: "0x0A1628FF", isText: false}}, subtype: function() as string
        return "Scene"
    end function, hasField: function(field as string) as boolean
        return m.doesExist(field)
    end function, getChildren: function(count as integer, start as integer) as object
        return []
    end function}
    m.global = {appearance: {appearanceMode: "light"}}
    uiApplyAppearanceTree(scene)
    assertEqual(scene.backgroundColor, light.background, "tracked Scene background repaints in place to light")
    m.global.appearance = {appearanceMode: "dark"}
    uiApplyAppearanceTree(scene)
    assertEqual(scene.backgroundColor, "0x0A1628FF", "tracked Scene background restores dark")
    print "ALL TESTS PASSED"
end sub

sub assertEqual(actual as dynamic, expected as dynamic, label as string)
    if actual <> expected
        print "FAIL: "; label; " expected="; expected; " actual="; actual
        stop
    end if
end sub
