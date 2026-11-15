' Four-column remote grid. Delay short OK until release; a held OK is consumed
' even when the parent refuses reorder. Returning from a dialog cannot switch.
function userProfilePickerInput(previous as object, key as string, press as boolean) as object
    state = {focus: previous.focus, count: previous.count, armed: previous.armed, held: previous.held, action: ""}
    if key = "OK"
        if press
            if not state.armed
                state.armed = true
                state.held = false
            end if
        else
            if state.armed and not state.held then state.action = "choose"
            state.armed = false
        end if
        return state
    end if
    if not press then return state
    if key = "hold"
        if state.armed and not state.held
            state.held = true
            state.action = "reorder"
        end if
        return state
    end if
    state.armed = false
    if key = "back"
        state.action = "back"
    else if key = "left"
        if state.focus mod 4 > 0 then state.focus--
    else if key = "right"
        if state.focus mod 4 < 3 and state.focus + 1 < state.count then state.focus++
    else if key = "up"
        if state.focus >= 4 then state.focus -= 4
    else if key = "down"
        if state.focus + 4 < state.count
            state.focus += 4
        else if state.count > 4 and state.focus < 4
            state.focus = state.count - 1
        end if
    end if
    return state
end function

function userProfilePickerChoice(plan as object, index as dynamic) as string
    kind = type(index)
    if kind <> "Integer" and kind <> "roInt" and kind <> "roInteger" and kind <> "LongInteger" and kind <> "roLongInteger" then return ""
    if not plan.ok or not plan.show then return ""
    if index < 0 or index >= plan.tiles.count() then return ""
    tile = plan.tiles[index]
    if tile.kind = "add" or tile.kind = "manage" then return tile.kind
    if tile.kind <> "profile" then return ""
    if plan.purpose = "switcher"
        if tile.current then return "close"
        return "switch"
    end if
    if plan.purpose <> "launch" then return ""
    if tile.locked then return "pin"
    return "select"
end function
