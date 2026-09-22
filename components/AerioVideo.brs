sub init()
    m.top.allowOptionsKeyOverride = false
    m.top.enableUI = false
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if key = "home" then return false
    ' Fullscreen Options belongs to Roku. Only forward where explicitly enabled
    ' for the mini-guide; fullscreen app options use hold OK or transport.
    if key = "options"
        if not m.top.allowOptionsKeyOverride then return false
        m.top.optionsKeyPress = press
        return true
    end if
    m.top.playerKey = {key: key, press: press}
    return true
end function
