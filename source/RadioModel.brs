function liveOpensRadio(declared as boolean, byDefault as boolean, intent as string) as boolean
    if intent = "video" then return false
    return declared or byDefault or intent = "radio"
end function

function radioPlaybackLabel(state as string, ready as boolean) as string
    if state = "paused" then return "Paused"
    if state = "playing" and ready then return "Playing"
    if state = "buffering" or ready then return "Buffering…"
    return "Starting stream…"
end function

function liveFailureTitle(channelName as string, radio as boolean) as string
    if radio then return "Channel unavailable: " + channelName
    return "Playback interrupted: " + channelName
end function
