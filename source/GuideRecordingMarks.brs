' e3e.29: scheduled and in-progress DVR recordings mark their Guide cells.
' Rows are DvrRecordingModel normalizeRecording results.
function guideActiveRecordings(recordings as dynamic, now as integer) as object
    result = []
    if type(recordings) <> "roArray" then return result
    for each row in recordings
        if result.count() >= 200 then exit for
        if type(row) = "roAssociativeArray"
            status = textValue(row.status)
            if status = "" then status = "scheduled"
            channelId = textValue(row.channelId)
            startsAt = guideEpoch(row.startTime)
            endsAt = guideEpoch(row.endTime)
            if (status = "scheduled" or status = "recording") and channelId <> "" and startsAt <> invalid and endsAt <> invalid
                if endsAt > startsAt and endsAt > now then result.push({channelId: channelId, startsAt: startsAt, endsAt: endsAt, status: status, programId: textValue(row.programId)})
            end if
        end if
    end for
    return result
end function

function guideRecordingMarks(active as dynamic) as object
    marks = {}
    if type(active) <> "roArray" then return marks
    for each mark in active
        if type(mark) = "roAssociativeArray"
            channelId = textValue(mark.channelId)
            if not marks.doesExist(channelId) then marks[channelId] = []
            marks[channelId].push(mark)
        end if
    end for
    return marks
end function

' A recording marks the program it was scheduled for, or the program whose
' midpoint its (possibly padded) window covers.
function guideRecordingMark(marks as dynamic, channelId as string, program as object) as string
    if type(marks) <> "roAssociativeArray" then return ""
    rows = marks[channelId]
    if rows = invalid then return ""
    middle = invalid
    if GetInterface(program.startsAt, "ifInt") <> invalid and GetInterface(program.endsAt, "ifInt") <> invalid then middle = program.startsAt + (program.endsAt - program.startsAt) \ 2
    programId = textValue(program.id)
    for each mark in rows
        matched = programId <> "" and mark.programId = programId
        if not matched and middle <> invalid then matched = mark.startsAt <= middle and middle < mark.endsAt
        if matched then return mark.status
    end for
    return ""
end function
