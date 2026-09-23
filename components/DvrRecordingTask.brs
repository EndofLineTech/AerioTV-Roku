sub init()
    m.top.functionName = "executeRecordingAction"
end sub

sub executeRecordingAction()
    m.base = m.top.baseUrl
    m.key = m.top.apiKey
    account = m.top.accountId
    m.timeout = 30000
    m.failure = ""
    result = {ok: false, message: "Unknown recording action."}

    if m.top.action = "schedule"
        result = scheduleRecording(m.base, m.key, m.top.channelId, m.top.program, m.top.preRoll, m.top.postRoll)

    else if m.top.action = "cancel"
        result = cancelRecording(m.base, m.key, m.top.recordingId)

    else if m.top.action = "stop"
        result = stopRecording(m.base, m.key, m.top.recordingId)

    else if m.top.action = "delete"
        result = deleteFinishedRecording(m.base, m.key, m.top.recordingId)

    else if m.top.action = "comskip"
        result = queueRecordingComskip(m.base, m.key, m.top.recordingId)

    else if m.top.action = "list"
        status = m.top.statusFilter
        if status = invalid then status = ""
        result = listRecordings(m.base, m.key, status)

    else if m.top.action = "status"
        result = getRecordingStatus(m.base, m.key, m.top.recordingId)

    else if m.top.action = "series-list"
        result = listSeriesRules(m.base, m.key)

    else if m.top.action = "series-preview"
        result = previewSeriesRule(m.base, m.key, m.top.seriesRule)

    else if m.top.action = "series-create"
        result = createSeriesRule(m.base, m.key, m.top.seriesRule)

    else if m.top.action = "series-delete"
        result = deleteSeriesRule(m.base, m.key, m.top.seriesRule)

    else
        result = {ok: false, message: "Unknown action: " + m.top.action}
    end if
    m.key = ""
    m.top.apiKey = ""
    if m.top.cancelRequested = true or m.top.accountId <> account then return
    result.accountId = account
    m.top.result = result
end sub
