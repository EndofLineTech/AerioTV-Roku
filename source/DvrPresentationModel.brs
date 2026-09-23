' Pure, bounded server-recording presentation helpers. Backend status wins;
' only an unstarted row with a future start can be inferred as scheduled.
function recordingScheduleEligible(permission as string, channel as dynamic, program as dynamic, now as integer) as boolean
    if permission <> "manage" or type(channel) <> "roAssociativeArray" or type(program) <> "roAssociativeArray" then return false
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(textValue(channel.id)) then return false
    if textValue(program.id) = "" then return false
    if GetInterface(program.startsAt, "ifInt") = invalid or GetInterface(program.endsAt, "ifInt") = invalid then return false
    return program.startsAt < program.endsAt and program.endsAt > now
end function

function recordingConfirmationText(intent as object, padding as object) as string
    startAt = intent.program.startsAt - padding.pre * 60
    endAt = intent.program.endsAt + padding.post * 60
    return left(textValue(intent.program.title), 72) + chr(10) + left(textValue(intent.channelName), 72) + chr(10) + "Time: " + uiLocalDate(startAt) + " " + uiTime(startAt) + " - " + uiLocalDate(endAt) + " " + uiTime(endAt) + chr(10) + "Start early " + padding.pre.toStr() + " min; end late " + padding.post.toStr() + " min"
end function

' Use only the server-owned recording routes, never a path/URL embedded in
' custom_properties. Completed files are finite; a growing HLS window is not.
function recordingPlaybackPlan(baseUrl as string, row as dynamic) as dynamic
    if type(row) <> "roAssociativeArray" then return invalid
    id = textValue(row.id)
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(id) then return invalid
    if len(id) = 10 and id > "2147483647" then return invalid
    base = normalizeBaseUrl(baseUrl)
    if base = "" then return invalid
    path = base + "/api/channels/recordings/" + id + "/"
    state = lcase(textValue(row.status))
    if state = "recording" and row.hlsReady = true
        return {url: path + "hls/index.m3u8", streamFormat: "hls", growing: true}
    end if
    if (state = "completed" or state = "stopped") and row.fileReady = true
        format = "mkv"
        if row.fileFormat = "mp4" then format = "mp4"
        return {url: path + "file/", streamFormat: format, growing: false}
    end if
    return invalid
end function

function recordingDisplayStatus(recording as object, now as integer) as string
    state = lcase(textValue(recording.status))
    if state <> "" then return state
    start = guideEpoch(recording.startTime)
    if start <> invalid and start > now then return "scheduled"
    return "unknown"
end function

function recordingShelfRows(rows as object, shelf as string, query as string, now as integer, channelNames = invalid as dynamic, sortMode = "date" as string) as object
    result = []
    query = lcase(query.trim())
    for each row in rows
        if type(row) = "roAssociativeArray"
            state = recordingDisplayStatus(row, now)
            include = false
            if shelf = "now" then include = state = "recording"
            if shelf = "scheduled" then include = state = "scheduled"
            if shelf = "recent" then include = state <> "recording" and state <> "scheduled"
            channelName = ""
            if type(channelNames) = "roAssociativeArray"
                if channelNames.doesExist(row.channelId) then channelName = textValue(channelNames[row.channelId])
            end if
            if include and (query = "" or instr(1, lcase(row.title), query) > 0 or instr(1, lcase(row.channelId), query) > 0 or instr(1, lcase(channelName), query) > 0)
                item = {}
                item.append(row)
                item.startEpoch = guideEpoch(row.startTime)
                if item.startEpoch = invalid then item.startEpoch = 0
                item.displayStatus = state
                result.push(item)
            end if
        end if
        if result.count() > 500 then exit for
    end for
    result.sortBy("startEpoch")
    if shelf = "recent" then result.reverse()
    if sortMode = "title" then result.sortBy("title")
    return result
end function

function dvrRowIdentity(row as object) as string
    if row.id <> invalid then return textValue(row.id)
    return "rule:" + textValue(row.tvgId) + ":" + textValue(row.title) + ":" + textValue(row.epgSourceId)
end function

function seriesRuleRows(rows as object, query as string) as object
    result = []
    term = lcase(query.trim())
    for each row in rows
        if type(row) = "roAssociativeArray"
            if term = "" or instr(1, lcase(textValue(row.title) + " " + textValue(row.tvgId) + " " + textValue(row.description)), term) > 0 then result.push(row)
        end if
    end for
    result.sortBy("title")
    return result
end function
