sub init()
    m.top.focusable = true
    m.input = m.top.findNode("input")
    m.top.textEditBox = m.input
    m.dots = []
    holder = m.top.findNode("dots")
    for i = 0 to 5
        outer = holder.createChild("AerioSurface")
        outer.setFields({width: 32, height: 32, radius: 16, color: "0xE8F3FAFF"})
        inner = holder.createChild("AerioSurface")
        inner.setFields({width: 24, height: 24, radius: 12, color: "0x172D43FF"})
        m.dots.push({outer: outer, inner: inner})
    end for
    m.input.observeField("text", "onDirectionText")
    m.input.observeField("maxTextLength", "onDirectionText")
    onDirectionText()
end sub

sub onDirectionTitle()
    m.top.findNode("titleLabel").text = m.top.title
end sub

sub onDirectionText()
    value = m.input.text
    count = m.input.maxTextLength
    start = 960 - ((count - 1) * 64 + 32) / 2
    for i = 0 to 5
        dot = m.dots[i]
        dot.outer.translation = [start + i * 64, 0]
        dot.inner.translation = [start + i * 64 + 4, 4]
        dot.outer.visible = i < count
        dot.inner.visible = i < count and i >= len(value)
    end for
end sub

sub onDirectionClose()
    if not m.top.close then return
    m.input.text = ""
    m.top.visible = false
    m.top.setFocus(false)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.top.close then return true
    directions = {up: "U", down: "D", left: "L", right: "R"}
    if directions.doesExist(key)
        if len(m.input.text) < m.input.maxTextLength then m.input.text += directions[key]
        return true
    end if
    if key = "OK"
        if len(m.input.text) >= 4 then m.top.buttonSelected = 0
        return true
    end if
    if key = "back"
        if m.input.text <> ""
            m.input.text = ""
        else
            m.top.wasClosed = true
        end if
        return true
    end if
    if key = "options" or key = "info" then m.top.wasClosed = true
    return true
end function
