' Skip Back / Skip Forward choices shared by Settings and the player (e3e.30).
function skipSecondsChoices() as object
    return [10, 15, 30, 60, 120, 300]
end function

function normalizeSkipSeconds(value as dynamic, fallback as integer) as integer
    valueType = type(value)
    if valueType <> "Integer" and valueType <> "roInt" and valueType <> "roInteger" then return fallback
    for each seconds in skipSecondsChoices()
        if value = seconds then return seconds
    end for
    return fallback
end function

function skipChoiceText(seconds as integer) as string
    if seconds = 60 then return "1 minute"
    if seconds > 60 then return (seconds \ 60).toStr() + " minutes"
    return seconds.toStr() + " seconds"
end function

' The four skip preferences the player reads for archive and recordings.
function playerSkipIntervals(device as object) as object
    intervals = {}
    for each field in ["archiveSkipBackSeconds", "archiveSkipForwardSeconds", "recordingSkipBackSeconds", "recordingSkipForwardSeconds"]
        intervals[field] = device[field]
    end for
    return intervals
end function
