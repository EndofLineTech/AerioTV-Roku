sub init()
    m.top.allowOptionsKeyOverride = true
    m.top.enableUI = false
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    ' Handle at the native Video owner as well as at the Scene: some firmware
    ' sends Options directly to the media node instead of bubbling normally.
    if key = "options"
        m.top.optionsKeyPress = press
        return true
    end if
    m.top.playerKey = {key: key, press: press}
    return true
end function
