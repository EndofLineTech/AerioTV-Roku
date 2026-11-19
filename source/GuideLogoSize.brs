' Upstream wire units are tenths of a percent; 100 is stock display size.
function channelLogoSizeChoices() as object
    return [25, 50, 100, 150, 200, 250]
end function

function normalizeChannelLogoSize(value as dynamic) as integer
    kind = type(value)
    if kind <> "Integer" and kind <> "roInt" and kind <> "roInteger" and kind <> "LongInteger" and kind <> "roLongInteger" then return 100
    if value < 25 or value > 250 then return 100
    nearest = 100
    for each stopSize in channelLogoSizeChoices()
        if abs(value - stopSize) < abs(value - nearest) then nearest = stopSize
    end for
    return nearest
end function
