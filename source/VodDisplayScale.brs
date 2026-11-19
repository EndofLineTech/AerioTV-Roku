function vodDisplayScaleChoices() as object
    return [85, 100, 115, 125, 135, 150]
end function

function normalizeVodDisplayScale(value as dynamic) as integer
    kind = type(value)
    if kind <> "Integer" and kind <> "roInt" and kind <> "roInteger" and kind <> "LongInteger" and kind <> "roLongInteger" and kind <> "Float" and kind <> "roFloat" and kind <> "Double" and kind <> "roDouble" then return 100
    for each choice in vodDisplayScaleChoices()
        if value = choice then return choice
    end for
    return 100
end function
