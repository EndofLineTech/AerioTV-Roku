' Dispatcharr v0.31.0: /api/channels/recordings/ accepts channel (integer),
' start_time, end_time and custom_properties. There is no program-ID endpoint
' or per-recording pre/post-roll field. Send adjusted times without a nested
' custom_properties.program: that nested object also triggers global DVR offsets.
function recordingIdValid(value as string) as boolean
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(value) then return false
    return len(value) < 10 or value <= "2147483647"
end function

function recordingEpochValid(value as dynamic) as boolean
    return GetInterface(value, "ifInt") <> invalid
end function

function normalizeRecording(raw as dynamic) as dynamic
    if type(raw) <> "roAssociativeArray" then return invalid
    id = textValue(raw.id)
    if not recordingIdValid(id) then return invalid
    cp = raw.custom_properties
    if type(cp) <> "roAssociativeArray" then cp = {}
    program = cp.program
    if type(program) <> "roAssociativeArray" then program = {}
    programId = textValue(cp.roku_program_id)
    if programId = "" then programId = textValue(program.id)
    title = textValue(program.title)
    if title = "" then title = textValue(cp.roku_program_title)
    if title = "" then title = "Recording " + id
    filePath = lcase(textValue(cp.file_path))
    format = "mkv"
    if right(filePath, 4) = ".mp4" then format = "mp4"
    comskip = cp.comskip
    if type(comskip) <> "roAssociativeArray" then comskip = {}
    comskipStatus = textValue(comskip.status)
    if comskipStatus <> "completed" and comskipStatus <> "skipped" and comskipStatus <> "error" then comskipStatus = ""
    comskipReason = textValue(comskip.reason)
    if comskipReason <> "comskip_not_installed" and comskipReason <> "no_commercials_detected" then comskipReason = ""
    comskipMode = ""
    if comskipStatus = "completed" and comskip.mode = "mark" then comskipMode = "mark"
    if comskipStatus = "completed" and GetInterface(comskip.segments_kept, "ifInt") <> invalid then comskipMode = "remove"
    return {
        id: id, channelId: textValue(raw.channel)
        startTime: textValue(raw.start_time), endTime: textValue(raw.end_time)
        status: textValue(cp.status), programId: programId
        title: left(title, 256), description: left(textValue(program.description), 500)
        posterLogoId: textValue(cp.poster_logo_id)
        fileReady: filePath <> "", fileFormat: format, hlsReady: textValue(cp._hls_dir) <> ""
        comskipStatus: comskipStatus, comskipReason: comskipReason, comskipSkipped: comskip.skipped = true
        comskipMode: comskipMode
    }
end function

function recordingFailure() as object
    result = {ok: false, message: m.failure}
    if type(m.httpFailure) = "roAssociativeArray" then result.category = m.httpFailure.category
    return result
end function

function listRecordings(baseUrl as string, apiKey as string, status as string) as object
    m.base = baseUrl
    m.key = apiKey
    m.timeout = 30000
    m.maxResponseBytes = 2000000
    payload = requestPages("/api/channels/recordings/")
    if payload = invalid then return recordingFailure()
    if payload.count() > 500 then return {ok: false, message: "The recording library exceeds this Roku's 500-item browsing limit."}
    recordings = []
    for each row in payload
        recording = normalizeRecording(row)
        if recording <> invalid and (status = "" or recording.status = status) then recordings.push(recording)
    end for
    return {ok: true, recordings: recordings}
end function

function scheduleRecording(baseUrl as string, apiKey as string, channelId as string, program as dynamic, preRoll as integer, postRoll as integer) as object
    if not recordingIdValid(channelId) or type(program) <> "roAssociativeArray" then return {ok: false, message: "Select a valid channel and program."}
    programId = textValue(program.id)
    if programId = "" or not recordingEpochValid(program.startsAt) or not recordingEpochValid(program.endsAt) then return {ok: false, message: "Program times or ID are missing."}
    if program.endsAt <= program.startsAt then return {ok: false, message: "Invalid program time range."}
    if preRoll < 0 or preRoll > 120 or postRoll < 0 or postRoll > 120 then return {ok: false, message: "Recording padding must be between 0 and 120 minutes."}
    startAt = program.startsAt - preRoll * 60
    endAt = program.endsAt + postRoll * 60
    if endAt <= startAt or endAt <= CreateObject("roDateTime").asSeconds() then return {ok: false, message: "The selected program has ended."}
    m.base = baseUrl
    m.key = apiKey
    m.timeout = 30000
    ' Read before POST to avoid repeating an already scheduled program. This is
    ' not an atomic server-side idempotency guarantee; the UI must guard taps.
    existing = listRecordings(baseUrl, apiKey, "")
    if not existing.ok then return existing
    for each row in existing.recordings
        if row.channelId = channelId and (row.status = "" or row.status = "scheduled" or row.status = "recording")
            if (row.programId <> "" and row.programId = programId) or (guideEpoch(row.startTime) = startAt and guideEpoch(row.endTime) = endAt)
                return {ok: false, category: "duplicate", message: "This program is already scheduled to record."}
            end if
        end if
    end for
    body = {
        channel: channelId.toInt(), start_time: recordingTime(startAt), end_time: recordingTime(endAt)
        custom_properties: {roku_program_id: programId, roku_program_title: left(textValue(program.title), 256)}
    }
    result = requestJson(m.base + "/api/channels/recordings/", body)
    if result = invalid then return recordingFailure()
    recording = normalizeRecording(result)
    if recording = invalid then return {ok: false, message: "Unexpected recording response; check the server before retrying."}
    return {ok: true, recording: recording}
end function

function recordingTime(seconds as integer) as string
    time = CreateObject("roDateTime")
    time.fromSeconds(seconds)
    return time.toISOString()
end function

function cancelRecording(baseUrl as string, apiKey as string, recordingId as string) as object
    if not recordingIdValid(recordingId) then return {ok: false, message: "Invalid recording ID."}
    m.base = baseUrl
    m.key = apiKey
    m.timeout = 30000
    current = getRecordingStatus(baseUrl, apiKey, recordingId)
    if not current.ok then return current
    startsAt = guideEpoch(current.recording.startTime)
    if startsAt = invalid or startsAt <= CreateObject("roDateTime").asSeconds() or (current.recording.status <> "scheduled" and current.recording.status <> "")
        return {ok: false, category: "state", message: "Only future scheduled recordings can be cancelled. Refresh the recording status."}
    end if
    ' The server DELETE endpoint also removes completed recordings. Keep this
    ' task action limited to future schedules; never retry an ambiguous DELETE.
    result = requestJson(m.base + "/api/channels/recordings/" + recordingId + "/", invalid, "", "DELETE")
    if result = invalid then return recordingFailure()
    return {ok: true}
end function

function stopRecording(baseUrl as string, apiKey as string, recordingId as string) as object
    if not recordingIdValid(recordingId) then return {ok: false, message: "Invalid recording ID."}
    current = getRecordingStatus(baseUrl, apiKey, recordingId)
    if not current.ok then return current
    if current.recording.status <> "recording" then return {ok: false, category: "state", message: "Only an active recording can be stopped. Refresh its status."}
    response = requestJson(m.base + "/api/channels/recordings/" + recordingId + "/stop/", {}, "", "POST")
    if response = invalid then return recordingFailure()
    if type(response) <> "roAssociativeArray" or response.success <> true then return {ok: false, message: "The server did not confirm the recording was stopped."}
    return {ok: true}
end function

function deleteFinishedRecording(baseUrl as string, apiKey as string, recordingId as string) as object
    if not recordingIdValid(recordingId) then return {ok: false, message: "Invalid recording ID."}
    current = getRecordingStatus(baseUrl, apiKey, recordingId)
    if not current.ok then return current
    state = current.recording.status
    if state <> "completed" and state <> "stopped" and state <> "interrupted" and state <> "failed"
        return {ok: false, category: "state", message: "Only a finished recording can be deleted. Refresh its status."}
    end if
    response = requestJson(m.base + "/api/channels/recordings/" + recordingId + "/", invalid, "", "DELETE")
    if response = invalid then return recordingFailure()
    return {ok: true}
end function

function queueRecordingComskip(baseUrl as string, apiKey as string, recordingId as string) as object
    if not recordingIdValid(recordingId) then return {ok: false, message: "Invalid recording ID."}
    current = getRecordingStatus(baseUrl, apiKey, recordingId)
    if not current.ok then return current
    if current.recording.status <> "completed" and current.recording.status <> "stopped" then return {ok: false, category: "state", message: "Commercial processing requires a finished recording."}
    response = requestJson(m.base + "/api/channels/recordings/" + recordingId + "/comskip/", {}, "", "POST")
    if response = invalid then return recordingFailure()
    if type(response) <> "roAssociativeArray" or response.success <> true or response.queued <> true then return {ok: false, message: "The server did not confirm commercial processing was queued."}
    return {ok: true}
end function

function getRecordingStatus(baseUrl as string, apiKey as string, recordingId as string) as object
    if not recordingIdValid(recordingId) then return {ok: false, message: "Invalid recording ID."}
    m.base = baseUrl
    m.key = apiKey
    m.timeout = 30000
    result = requestJson(m.base + "/api/channels/recordings/" + recordingId + "/")
    if result = invalid then return recordingFailure()
    recording = normalizeRecording(result)
    if recording = invalid then return {ok: false, message: "Invalid recording data."}
    return {ok: true, recording: recording}
end function
