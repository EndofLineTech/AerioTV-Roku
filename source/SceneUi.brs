function uiRect(parent as object, x as float, y as float, w as float, h as float, color as string) as object
    node = parent.createChild("Rectangle")
    node.translation = [x, y]
    node.width = w
    node.height = h
    node.color = color
    return node
end function

function uiPalette() as object
    return {background: "0x0A1628FF", card: "0x0D1E35FF", elevated: "0x263549FF", accent: "0x1AC4D8FF", text: "0xE8F3FAFF", secondary: "0x9EB5C9FF", disabled: "0x627384FF", clear: "0x00000000", white: "0xFFFFFFFF", ink: "0x0A1628FF", focusWash: "0x365163FF"}
end function

function uiTypeSize(role as string) as integer
    sizes = {heading: 36, section: 28, body: 24, secondary: 20, button: 24, caption: 18}
    if sizes.doesExist(role) then return sizes[role]
    return 24
end function

function uiControlStyle(kind as string, selected as boolean, focused as boolean, enabled = true as boolean) as object
    p = uiPalette()
    result = {fill: p.elevated, ink: p.secondary, ring: p.clear, scale: 1.0}
    if kind = "primary" then result.fill = p.clear
    if selected
        result.fill = p.accent
        result.ink = p.ink
    end if
    if focused
        result.scale = 1.04
        result.ink = p.white
        result.ring = p.accent
        if selected then result.ring = p.white
        if kind = "primary" or kind = "action"
            result.fill = p.white
            result.ink = p.ink
            result.ring = p.clear
        end if
    end if
    if kind = "row"
        result.fill = p.clear
        result.ink = p.text
        result.ring = p.clear
        if selected then result.fill = p.card
        if focused
            result.fill = p.focusWash
            result.ring = p.accent
            result.scale = 1.02
        end if
    end if
    if not enabled
        result.ink = p.disabled
        result.fill = p.clear
        result.ring = p.clear
        result.scale = 1.0
    end if
    return result
end function

function uiSurface(parent as object, x as float, y as float, w as float, h as float, radius as float, color as string) as object
    node = parent.createChild("AerioSurface")
    node.translation = [x, y]
    node.width = w
    node.height = h
    node.radius = radius
    node.color = color
    return node
end function

' Center the entire icon + measured label run, not the label's leftover column.
function uiPillContent(w as float, h as float, textWidth as float, iconWidth = 0 as float) as object
    gap = 0
    if iconWidth > 0 then gap = 8
    maxText = w - 24 - iconWidth - gap
    if maxText < 0 then maxText = 0
    if textWidth > maxText then textWidth = maxText
    if textWidth < 0 then textWidth = 0
    start = (w - iconWidth - gap - textWidth) / 2
    return {iconX: start, iconY: (h - iconWidth) / 2, textX: start + iconWidth + gap, textWidth: textWidth}
end function

function uiCenteredStripX(count as integer, itemWidth as float, gap as float, availableWidth as float) as float
    if count <= 0 then return availableWidth / 2
    width = count * itemWidth + (count - 1) * gap
    start = (availableWidth - width) / 2
    if start < 0 then start = 0
    return start
end function

' Non-overlapping rectangles and quarter-circle masks avoid alpha seams.
function uiSurfaceBoxes(w as float, h as float, radius as float) as object
    if w < 0 then w = 0
    if h < 0 then h = 0
    r = radius
    if r < 0 then r = 0
    if r > w / 2 then r = w / 2
    if r > h / 2 then r = h / 2
    return [{x: r, y: 0, w: w - 2 * r, h: h}, {x: 0, y: r, w: r, h: h - 2 * r}, {x: w - r, y: r, w: r, h: h - 2 * r}, {x: 0, y: 0, w: r, h: r}, {x: w - r, y: 0, w: r, h: r}, {x: 0, y: h - r, w: r, h: r}, {x: w - r, y: h - r, w: r, h: r}]
end function

function uiLabel(parent as object, text as string, x as float, y as float, w as float, h as float, size as integer, color = "0xE8F3FAFF" as string) as object
    node = parent.createChild("Label")
    node.translation = [x, y]
    node.width = w
    node.height = h
    node.text = text
    node.color = color
    ' Label provides a resolved system font. A new Font with no uri has no
    ' font face and renders no text on Roku, even when size is specified.
    font = node.font
    font.size = size
    node.font = font
    return node
end function

function uiNow() as integer
    return CreateObject("roDateTime").asSeconds()
end function

function uiPad(value as integer) as string
    if value < 10 then return "0" + value.toStr()
    return value.toStr()
end function

function uiLocalDate(epoch as integer) as string
    date = CreateObject("roDateTime")
    date.fromSeconds(epoch)
    date.toLocalTime()
    return date.getYear().toStr() + "-" + uiPad(date.getMonth()) + "-" + uiPad(date.getDayOfMonth())
end function

function uiTime(epoch as integer, localTime = true as boolean) as string
    date = CreateObject("roDateTime")
    date.fromSeconds(epoch)
    if localTime then date.toLocalTime()
    mode = "24"
    if localTime and m.global <> invalid
        if m.global.clockFormat <> invalid then mode = m.global.clockFormat
    end if
    return formatClock(date.getHours(), date.getMinutes(), mode)
end function

function formatClock(hour as integer, minute as integer, mode as string) as string
    if mode <> "12" then return uiPad(hour) + ":" + uiPad(minute)
    suffix = " AM"
    if hour >= 12 then suffix = " PM"
    hour = hour mod 12
    if hour = 0 then hour = 12
    return hour.toStr() + ":" + uiPad(minute) + suffix
end function
function uiRemoteHints(parent as object, x as float, y as float, width as float, height as float, size as integer) as object
    hints = parent.createChild("RemoteHints")
    hints.translation = [x, y]
    hints.width = width
    hints.height = height
    hints.fontSize = size
    return hints
end function
