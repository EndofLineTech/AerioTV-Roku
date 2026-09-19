function uiRect(parent as object, x as float, y as float, w as float, h as float, color as string) as object
    node = parent.createChild("Rectangle")
    node.translation = [x, y]
    node.width = w
    node.height = h
    node.color = color
    return node
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
