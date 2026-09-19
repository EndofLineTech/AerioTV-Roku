sub init()
    m.top.visible = false
    uiRect(m.top, 0, 0, 1920, 1080, "0x000000BB")
    uiRect(m.top, 460, 155, 1000, 755, "0x0D1E35FF")
    uiRect(m.top, 460, 155, 1000, 3, "0x1AC4D8FF")
    m.title = uiLabel(m.top, "Player options", 510, 197, 900, 60, 36)
    m.note = uiLabel(m.top, "", 510, 265, 900, 54, 22, "0x9EB5C9FF")
    m.note.wrap = true
    m.list = m.top.createChild("LabelList")
    m.list.translation = [510, 340]
    m.list.itemSize = [900, 64]
    m.list.numRows = 8
    m.list.color = "0xE8F3FAFF"
    m.list.focusedColor = "0x0A1628FF"
    m.list.focusBitmapBlendColor = "0x1AC4D8FF"
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
    if m.top.active then m.list.setFocus(true)
end sub

sub onActive()
    m.top.visible = m.top.active
    if m.top.active then m.list.setFocus(true)
end sub

sub onSelected(event as object)
    if not m.top.active then return
    if event.getData() < 0 or event.getData() >= m.top.menu.items.count() then return
    m.top.selection = m.top.menu.items[event.getData()]
end sub

sub onFocused(event as object)
    m.top.focusedIndex = event.getData()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.active then return false
    if key = "back"
        m.top.active = false
        m.top.backRequested = true
    else if key = "options"
        m.top.active = false
        m.top.closed = true
    end if
    ' Don't let menu arrows reach the channel-switch handler.
    return true
end function
