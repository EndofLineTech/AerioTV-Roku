' Native Dialog/ButtonGroup owns keyboard handling, indices and dismissal.
' Paint centered pills inside the documented Button children; retain their
' original text for native accessibility and selection, but hide native paint.
sub init()
    m.group = m.top.buttonGroup
    m.pills = []
    m.overlays = []
    m.delay = m.top.findNode("pillDelay")
    m.delay.observeField("fire", "buildDialogPills")
    m.top.observeField("buttons", "scheduleDialogPills")
    m.top.observeField("buttonFocused", "drawDialogPills")
    m.group.observeField("focusedChild", "drawDialogPills")
    m.top.width = 1120
    m.group.minWidth = 900
    m.group.maxWidth = 900
    m.group.buttonHeight = 64
    m.group.itemSpacings = [8]
    m.group.focusBitmapUri = "pkg:/images/ui-list-inset.png"
    m.group.focusFootprintBitmapUri = "pkg:/images/ui-list-inset.png"
    m.group.iconUri = ""
    m.group.focusedIconUri = ""
    m.group.textColor = "0x00000000"
    m.group.focusedTextColor = "0x00000000"
    ' Legacy Dialog owns its dark panel bitmap; keep readable panel ink even
    ' when the surrounding application uses the light palette.
    m.top.titleColor = "0xE8F3FAFF"
    m.top.messageColor = "0x9EB5C9FF"
end sub

sub scheduleDialogPills()
    m.delay.control = "stop"
    m.delay.control = "start"
end sub

sub buildDialogPills()
    for each previous in m.overlays
        previous.button.removeChild(previous.root)
    end for
    m.overlays = []
    m.pills = []
    for each button in m.group.getChildren(-1, 0)
        if button.isSubtype("Button")
            overlay = button.createChild("Group")
            pill = uiButton(overlay, button.text, 0, 0, 900, 64, 24, "0x263549FF")
            m.pills.push(pill)
            m.overlays.push({button: button, root: overlay})
        end if
    end for
    drawDialogPills()
end sub

sub drawDialogPills()
    if m.pills = invalid then return
    for i = 0 to m.pills.count() - 1
        style = uiControlStyle("action", false, i = m.top.buttonFocused and m.group.isInFocusChain())
        uiSetColor(m.pills[i].bg, style.fill)
        uiSetColor(m.pills[i].label, style.ink)
    end for
end sub
