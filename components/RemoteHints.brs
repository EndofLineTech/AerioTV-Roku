sub renderHints()
    m.top.removeChildrenIndex(m.top.getChildCount(), 0)
    x = 0
    size = m.top.fontSize
    pieces = CreateObject("roRegex", " {3,}", "").split(m.top.text)
    keys = ["Hold Left", "Hold OK", "Up/Down", "Left/Right", "Back or Play", "Play/Pause", "Replay", "Back", "Right", "Left", "Down", "Play", "Up", "OK", "*"]
    for each piece in pieces
        text = piece.trim()
        button = ""
        for each key in keys
            if left(text, len(key) + 1) = key + " "
                button = key
                text = mid(text, len(key) + 1).trim()
                exit for
            end if
        end for
        if button <> ""
            keyWidth = len(button) * size * 0.63 + 18
            if x + keyWidth >= m.top.width then exit for
            uiRect(m.top, x, 0, keyWidth, m.top.height, "0x294357FF")
            label = uiLabel(m.top, button, x + 7, 2, keyWidth - 14, m.top.height - 2, size, "0xFFFFFFFF")
            label.font = "font:SmallBoldSystemFont"
            font = label.font
            font.size = size
            label.font = font
            label.horizAlign = "center"
            x += keyWidth + 9
        end if
        width = len(text) * size * 0.58 + 8
        if x + width > m.top.width then width = m.top.width - x
        if width <= 0 then exit for
        uiLabel(m.top, text, x, 2, width, m.top.height - 2, size, "0xBDD0E0FF")
        x += width + 24
    end for
end sub
