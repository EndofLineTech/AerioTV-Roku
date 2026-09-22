sub renderHints()
    m.top.removeChildrenIndex(m.top.getChildCount(), 0)
    x = 0
    size = m.top.fontSize
    pieces = CreateObject("roRegex", " {3,}", "").split(m.top.text)
    keys = ["Up from first row", "Hold Left", "Hold OK", "Up / Down", "OK / Right", "Left / Back", "FF / Rew", "Up/Down", "Left/Right", "Back or Play", "Play/Pause", "Replay", "Back", "Right", "Left", "Down", "Play", "Up", "OK", "FF", "Rew", "*"]
    for each piece in pieces
        text = piece.trim()
        if text <> ""
            button = ""
            for each key in keys
                if left(text, len(key) + 1) = key + " "
                    button = key
                    text = mid(text, len(key) + 1).trim()
                    exit for
                end if
            end for
            remaining = m.top.width - x
            if remaining < 48 then exit for
            group = m.top.createChild("Group")
            group.translation = [x, 0]
            helpX = 0
            if button <> ""
                surface = uiSurface(group, 0, 0, 0, m.top.height, m.top.height / 2, "0x294357FF")
                keyLabel = uiLabel(group, button, 14, 0, 0, m.top.height, size, "0xE8F3FAFF")
                keyWidth = keyLabel.localBoundingRect().width
                if keyWidth + 28 >= remaining
                    m.top.removeChild(group)
                    exit for
                end if
                surface.width = keyWidth + 28
                keyLabel.width = keyWidth
                keyLabel.horizAlign = "center"
                keyLabel.vertAlign = "center"
                helpX = keyWidth + 38
            end if
            label = uiLabel(group, text, helpX, 0, 0, m.top.height, size, "0xBDD0E0FF")
            width = label.localBoundingRect().width
            if width > remaining - helpX then width = remaining - helpX
            if width <= 0
                m.top.removeChild(group)
                exit for
            end if
            label.width = width
            label.vertAlign = "center"
            x += helpX + width + 24
        end if
    end for
end sub
