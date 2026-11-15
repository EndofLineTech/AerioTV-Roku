sub init()
    m.tiles = m.top.findNode("tiles")
    m.holdTimer = m.top.findNode("holdTimer")
    m.holdTimer.observeField("fire", "onPickerHold")
    m.input = {focus: 0, count: 0, armed: false, held: false}
end sub

sub onPickerModel()
    model = m.top.model
    m.holdTimer.control = "stop"
    m.input = {focus: 0, count: 0, armed: false, held: false}
    if type(model) = "roAssociativeArray"
        if model.ok = true and model.show = true
            m.input.count = model.tiles.count()
            m.input.focus = model.focus
        end if
    end if
    drawPickerTiles()
end sub

sub onPickerMessage()
    m.top.findNode("messageLabel").text = m.top.message
end sub

sub drawPickerTiles()
    m.tiles.removeChildrenIndex(m.tiles.getChildCount(), 0)
    m.top.focusIndex = m.input.focus
    if m.input.count = 0 then return
    model = m.top.model
    for i = 0 to m.input.count - 1
        tile = model.tiles[i]
        x = (i mod 4) * 400
        y = int(i / 4) * 310
        group = m.tiles.createChild("Group")
        group.translation = [x, y]
        color = "0x172D43FF"
        if i = m.input.focus then color = "0x356480FF"
        uiSurface(group, 0, 0, 370, 280, 24, color)
        mark = "+"
        ink = "0xFFFFFFFF"
        if tile.kind = "manage" then mark = "*"
        if tile.kind = "profile"
            mark = userProfileAvatarInitial(tile.name, tile.username)
            colorName = ""
            if type(tile.avatar.color) = "String" or type(tile.avatar.color) = "roString" then colorName = tile.avatar.color
            if colorName = "" then colorName = userProfileAvatarColor(tile.username)
            avatarHex = userProfileAvatarHex(colorName)
            if avatarHex = ""
                colorName = userProfileAvatarColor(tile.username)
                avatarHex = userProfileAvatarHex(colorName)
            end if
            avatarColor = "0x" + avatarHex + "FF"
            uiSurface(group, 137, 25, 96, 96, 48, avatarColor)
            ink = "0x" + userProfileAvatarInk(colorName) + "FF"
            if tile.locked
                ' Native shapes, not a font glyph that may be absent on Roku.
                uiSurface(group, 319, 28, 20, 24, 10, "0xE8F3FAFF")
                uiSurface(group, 324, 33, 10, 17, 5, color)
                uiSurface(group, 313, 45, 32, 25, 4, "0xE8F3FAFF")
            end if
        end if
        label = uiLabel(group, mark, 137, 25, 96, 96, 48, ink)
        label.horizAlign = "center"
        label.vertAlign = "center"
        label = uiLabel(group, tile.name, 20, 140, 330, 75, 30, "0xFFFFFFFF")
        label.horizAlign = "center"
        label.wrap = true
        caption = ""
        if tile.kind = "profile"
            if tile.current and model.purpose = "switcher" then caption = "Current"
            if tile.locked
                if caption <> "" then caption += "  |  "
                caption += "PIN required"
            end if
        end if
        label = uiLabel(group, caption, 20, 225, 330, 38, 22, "0xBDD0E0FF")
        label.horizAlign = "center"
    end for
end sub

sub onPickerHold()
    if m.top.busy or not m.top.isInFocusChain() then return
    m.input = userProfilePickerInput(m.input, "hold", true)
    emitPickerIntent()
end sub

sub emitPickerIntent()
    if m.input.action = "" then return
    model = m.top.model
    action = m.input.action
    if action = "choose" then action = userProfilePickerChoice(model, m.input.focus)
    if action = "reorder"
        if model.tiles[m.input.focus].kind <> "profile" then return
    end if
    ' Parent must bind node/nonce/current roots and authorize every intent.
    m.top.intent = {action: action, index: m.input.focus}
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if key <> "OK" and key <> "back" and key <> "left" and key <> "right" and key <> "up" and key <> "down" then return false
    if m.top.busy or m.input.count = 0 then return true
    wasArmed = m.input.armed
    m.input = userProfilePickerInput(m.input, key, press)
    if key = "OK" and press and not wasArmed then m.holdTimer.control = "start"
    if key <> "OK" or not press then m.holdTimer.control = "stop"
    drawPickerTiles()
    emitPickerIntent()
    return true
end function
