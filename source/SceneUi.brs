function uiRect(parent as object, x as float, y as float, w as float, h as float, color as string) as object
    node = parent.createChild("Rectangle")
    node.translation = [x, y]
    node.width = w
    node.height = h
    uiSetColor(node, color)
    return node
end function

function uiPalette() as object
    return {background: "0x0A1628FF", card: "0x0D1E35FF", elevated: "0x263549FF", accent: "0x1AC4D8FF", text: "0xE8F3FAFF", secondary: "0x9EB5C9FF", disabled: "0x627384FF", clear: "0x00000000", white: "0xFFFFFFFF", ink: "0x0A1628FF", onAccent: "0x0A1629FF", focusWash: "0x365163FF", border: "0x17344AFF"}
end function

function uiAppearance() as object
    if m.global <> invalid
        if type(m.global.appearance) = "roAssociativeArray" then return m.global.appearance
    end if
    return {}
end function

function uiResolvedPalette(preferences as object) as object
    cacheKey = ""
    for each key in ["themePreset", "appearanceMode", "customAccent", "panelStyle", "contrastMode"]
        if GetInterface(preferences[key], "ifString") <> invalid then cacheKey += preferences[key]
        cacheKey += "|"
    end for
    if m.uiPaletteCacheKey = cacheKey and m.uiPaletteCache <> invalid then return m.uiPaletteCache
    result = uiPalette()
    presets = {
        aerio: ["0A1628", "0D1E35", "1AC4D8", "F2F7FA", "0E8FA0"]
        midnight: ["0A0F1A", "111827", "60A5FA", "F4F6FB", "2563EB"]
        sunset: ["0F0A07", "1A1108", "FB923C", "FCF7F2", "E8590C"]
        forest: ["080F0A", "0E1A10", "4ADE80", "F3F8F4", "16A34A"]
        lavender: ["0C0A12", "130F1E", "A78BFA", "F7F5FC", "7C3AED"]
        monochrome: ["0A0A0A", "111111", "E2E8F0", "F5F5F5", "475569"]
        light: ["0E1518", "17211F", "3E9EAC", "F6F8FA", "2B7A86"]
    }
    preset = "aerio"
    if GetInterface(preferences.themePreset, "ifString") <> invalid
        if presets.doesExist(preferences.themePreset) then preset = preferences.themePreset
    end if
    selected = presets[preset]
    result.background = "0x" + selected[0] + "FF"
    result.card = "0x" + selected[1] + "FF"
    result.accent = "0x" + selected[2] + "FF"
    result.lightMode = preferences.appearanceMode = "light"
    if result.lightMode
        result.background = "0x" + selected[3] + "FF"
        result.card = "0xFFFFFFFF"
        result.accent = "0x" + selected[4] + "FF"
        result.text = "0x0F1B24FF"
        result.secondary = "0x435366FF"
        result.disabled = "0x697687FF"
    end if
    if GetInterface(preferences.customAccent, "ifString") <> invalid
        if CreateObject("roRegex", "^[0-9A-Fa-f]{6}$", "").isMatch(preferences.customAccent) then result.accent = "0x" + ucase(preferences.customAccent) + "FF"
    end if
    result.elevated = uiMixColor(result.card, result.text, 0.12)
    result.focusWash = uiMixColor(result.card, result.accent, 0.24)
    result.border = uiMixColor(result.card, result.text, 0.22)
    result.focusBorder = "0xFFFFFFFF"
    if result.lightMode then result.focusBorder = result.accent
    result.onAccent = "0x000000FF"
    if uiContrastRatio(result.accent, "0xFFFFFFFF") > uiContrastRatio(result.accent, "0x000000FF") then result.onAccent = "0xFFFFFFFF"
    result.solid = preferences.panelStyle = "solid"
    if preferences.contrastMode = "high"
        result.secondary = result.text
        result.border = uiMixColor(result.card, result.text, 0.65)
        result.solid = true
    end if
    m.uiPaletteCacheKey = cacheKey
    m.uiPaletteCache = result
    return result
end function

function uiHexByte(color as string, position as integer) as integer
    digits = "0123456789ABCDEF"
    high = instr(1, digits, ucase(mid(color, position, 1))) - 1
    low = instr(1, digits, ucase(mid(color, position + 1, 1))) - 1
    return high * 16 + low
end function

function uiMixColor(base as string, tint as string, amount as float) as string
    digits = "0123456789ABCDEF"
    result = "0x"
    for each position in [3, 5, 7]
        value = int(uiHexByte(base, position) * (1 - amount) + uiHexByte(tint, position) * amount + 0.5)
        result += mid(digits, (value \ 16) + 1, 1) + mid(digits, (value mod 16) + 1, 1)
    end for
    return result + "FF"
end function

function uiLuminance(color as string) as float
    result = 0.0
    weights = [0.2126, 0.7152, 0.0722]
    for i = 0 to 2
        value = uiHexByte(color, 3 + i * 2) / 255.0
        if value <= 0.04045 then value /= 12.92 else value = ((value + 0.055) / 1.055) ^ 2.4
        result += value * weights[i]
    end for
    return result
end function

function uiContrastRatio(a as string, b as string) as float
    first = uiLuminance(a)
    second = uiLuminance(b)
    if first > second then return (first + 0.05) / (second + 0.05)
    return (second + 0.05) / (first + 0.05)
end function

function uiColorForPalette(color as string, palette as object, isText as boolean) as string
    if len(color) <> 10 or lcase(left(color, 2)) <> "0x" then return color
    rgb = ucase(mid(color, 3, 6))
    role = ""
    if rgb = "0A1628" or rgb = "081525" then role = "background"
    if rgb = "0D1E35" or rgb = "172D43" then role = "card"
    if rgb = "263549" or rgb = "294357" then role = "elevated"
    if rgb = "1AC4D8" then role = "accent"
    if rgb = "E8F3FA" then role = "text"
    if rgb = "9EB5C9" or rgb = "BDD0E0" then role = "secondary"
    if rgb = "627384" then role = "disabled"
    if rgb = "365163" or rgb = "10344A" then role = "focusWash"
    if rgb = "17344A" then role = "border"
    if rgb = "0A1629" then role = "onAccent"
    if rgb = "FFFFFE" then role = "focusBorder"
    if isText and (rgb = "0A1628" or rgb = "081525") then role = "ink"
    if role = "" then return color
    alpha = right(color, 2)
    if palette.solid = true and (role = "background" or role = "card" or role = "elevated") and alpha <> "00" then alpha = "FF"
    return left(palette[role], 8) + alpha
end function

sub uiSetColor(node as object, color as string, field = "color" as string)
    isText = field = "focusedColor" or field = "blendColor"
    if type(node) = "roAssociativeArray"
        isText = isText or node.font <> invalid
    else
        isText = isText or node.subtype() = "Label" or node.subtype() = "LabelList"
        if not node.hasField("uiPaint") then node.addField("uiPaint", "assocarray", false)
        paint = node.uiPaint
        if type(paint) <> "roAssociativeArray" then paint = {}
        paint[field] = {color: color, isText: isText}
        node.uiPaint = paint
    end if
    node[field] = uiColorForPalette(color, uiResolvedPalette(uiAppearance()), isText)
end sub

' Repaint tracked nodes in place; never recreate Video or reassign its content.
sub uiApplyAppearanceTree(node as object)
    if node = invalid then return
    kind = node.subtype()
    if kind = "TopNavigation" then node.callFunc("configureNavigation")
    if kind = "GroupNavigator" and node.model <> invalid then node.callFunc("applyPresentation", node.model)
    if kind = "RemoteHints" then node.callFunc("renderHints")
    if kind = "VodView" then node.callFunc("refreshAppearance")
    if node.hasField("uiPaint")
        palette = uiResolvedPalette(uiAppearance())
        for each field in node.uiPaint
            paint = node.uiPaint[field]
            node[field] = uiColorForPalette(paint.color, palette, paint.isText)
        end for
    end if
    if node.hasField("uiTypography")
        for each field in node.uiTypography
            entry = node.uiTypography[field]
            uiSetFont(node, entry.size, field, entry.secondary, entry.height)
        end for
    end if
    for each child in node.getChildren(-1, 0)
        uiApplyAppearanceTree(child)
    end for
end sub

function uiScaledFontSize(base as integer, height as float, secondary as boolean, preferences as object) as integer
    scale = 100
    for each allowed in [90, 100, 110, 120]
        if preferences.textSize = allowed then scale = allowed
    end for
    subscale = 100
    if secondary
        for each allowed in [90, 100, 110, 120]
            if preferences.subtextSize = allowed then subscale = allowed
        end for
    end if
    if scale = 100 and subscale = 100 then return base
    size = int(base * scale * subscale / 10000.0 + 0.5)
    if height > 0 and size * 1.12 > height then size = int(height / 1.12)
    if size < 10 then size = 10
    return size
end function

sub uiSetFont(node as object, size as integer, field = "font" as string, secondary = false as boolean, height = 0 as float)
    if type(node) <> "roAssociativeArray"
        if not node.hasField("uiTypography") then node.addField("uiTypography", "assocarray", false)
        info = node.uiTypography
        if type(info) <> "roAssociativeArray" then info = {}
        info[field] = {size: size, secondary: secondary, height: height}
        node.uiTypography = info
        if height = 0 and node.hasField("height") then height = node.height
    else if height = 0 and node.height <> invalid
        height = node.height
    end if
    font = node[field]
    font.size = uiScaledFontSize(size, height, secondary, uiAppearance())
    node[field] = font
end sub

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
        result.ink = p.onAccent
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
            if uiAppearance().appearanceMode = "light" then result.ring = p.accent
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
    uiSetColor(node, color)
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

' The 16px system font's uppercase ink sits above its line-box center on Roku.
' Keep the text box inside the 24px pill, with the native-measured optical inset.
function uiFlagLabelBounds(label as string, width as float) as object
    x = 4
    if label = "LIVE" then x = 5 ' compensate the LIVE run's unequal side bearings
    return {x: x, y: 4, width: width - 8, height: 20}
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
    uiSetColor(node, color)
    ' Label provides a resolved system font. A new Font with no uri has no
    ' font face and renders no text on Roku, even when size is specified.
    secondary = color = "0x9EB5C9FF" or color = "0xBDD0E0FF"
    uiSetFont(node, size, "font", secondary)
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
