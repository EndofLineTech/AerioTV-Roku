sub init()
    m.top.focusable = true
    m.top.visible = false
    uiRect(m.top, 0, 0, 1920, 1080, "0x000000BB")
    uiSurface(m.top, 460, 155, 1000, 755, 24, "0x0D1E35F0")
    m.title = uiLabel(m.top, "Player options", 510, 197, 900, 60, 36)
    m.note = uiLabel(m.top, "", 510, 265, 900, 54, 22, "0x9EB5C9FF")
    m.note.wrap = true
    m.list = m.top.createChild("LabelList")
    m.list.translation = [510, 340]
    m.list.itemSize = [900, 64]
    m.list.itemSpacing = [0, 0]
    m.list.numRows = 8
    uiSetColor(m.list, "0xE8F3FAFF")
    uiSetColor(m.list, "0x0A1629FF", "focusedColor")
    uiSetColor(m.list, "0x1AC4D8FF", "focusBitmapBlendColor")
    m.list.focusBitmapUri = "pkg:/images/ui-focus-pill.png"
    m.list.observeField("itemSelected", "onSelected")
    m.list.observeField("itemFocused", "onFocused")
end sub

sub setMenu()
    menu = m.top.menu
    if menu = invalid then return
    m.title.text = menu.title
    m.note.text = menu.note
    content = CreateObject("roSGNode", "ContentNode")
    for each item in menu.items
        content.createChild("ContentNode").title = item.title
    end for
    m.list.content = content
    m.list.jumpToItem = 0
    if menu.focusIndex <> invalid then m.list.jumpToItem = menu.focusIndex
    if m.top.active then focusMenuInput()
end sub

sub onActive()
    m.top.visible = m.top.active
    if m.top.active
        focusMenuInput()
    else
        m.top.consumeSelectRelease = false
    end if
end sub

sub focusMenuInput()
    if m.top.consumeSelectRelease then m.top.setFocus(true) else m.list.setFocus(true)
end sub

sub releaseSelectGuard()
    if not m.top.active or not m.top.consumeSelectRelease then return
    m.top.consumeSelectRelease = false
    m.list.setFocus(true)
end sub

sub onSelected(event as object)
    if not m.top.active then return
    if m.top.consumeSelectRelease then return
    if event.getData() < 0 or event.getData() >= m.top.menu.items.count() then return
    m.top.selection = m.top.menu.items[event.getData()]
end sub

sub onFocused(event as object)
    m.top.focusedIndex = event.getData()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not m.top.active then return false
    if m.top.consumeSelectRelease
        if key = "OK"
            if not press
                releaseSelectGuard()
            end if
            return true
        end if
        if press and key <> "options"
            m.top.consumeSelectRelease = false
            m.list.setFocus(true)
            if key = "up" or key = "down"
                target = m.list.itemFocused
                if key = "up" then target-- else target++
                if target < 0 then target = 0
                if target >= m.top.menu.items.count() then target = m.top.menu.items.count() - 1
                m.list.jumpToItem = target
                return true
            end if
        end if
    end if
    if not press or key = "options" then return false
    if key = "back"
        m.top.active = false
        m.top.backRequested = true
    end if
    ' Don't let menu arrows reach the channel-switch handler.
    return true
end function
