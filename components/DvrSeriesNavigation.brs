sub showSeriesOptions()
    if m.seriesDraft = invalid or m.recordIntent = invalid then return
    draft = m.seriesDraft
    pinned = "Use this channel"
    if draft.channelId = "" then pinned = "Use server's lowest-numbered matching channel"
    description = draft.description
    if description = "" then description = "none"
    choices = [
        {title: "Cancel", action: "cancel"}
        {title: "Preview series matches", action: "seriesPreview"}
        {title: "Title: " + left(draft.title, 38) + " (edit)", action: "seriesTitle"}
        {title: "Title matching: " + draft.titleMode, action: "seriesTitleMode"}
        {title: "Description phrase: " + left(description, 32) + " (edit)", action: "seriesDescription"}
        {title: "Channel: " + pinned, action: "seriesPin"}
    ]
    if draft.mode = "new"
        label = "No"
        if draft.untaggedIsNew then label = "Yes"
        choices.push({title: "Treat untagged episodes as new: " + label, action: "seriesUntagged"})
    end if
    openRecordPicker("Series rule: " + draft.mode, "Exact EPG channel scope: " + left(draft.tvgId, 60) + ". Preview before saving.", choices)
end sub

sub openSeriesKeyboard(action as string)
    closeRecordDialog()
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.title = "Series title to match"
    dialog.text = m.seriesDraft.title
    if action = "seriesDescription"
        dialog.title = "Optional description phrase"
        dialog.text = m.seriesDraft.description
    end if
    dialog.buttons = ["Save", "Cancel"]
    m.seriesEditAction = action
    dialog.observeField("buttonSelected", "onSeriesKeyboard")
    dialog.observeField("wasClosed", "onRecordDialogClosed")
    m.recordDialog = dialog
    m.top.dialog = dialog
end sub

sub onSeriesKeyboard(event as object)
    if m.recordDialog = invalid or not m.recordDialog.isSameNode(event.getRoSGNode()) then return
    if event.getData() = 0
        value = left(m.recordDialog.text.trim(), 160)
        if m.seriesEditAction = "seriesTitle" and value <> "" then m.seriesDraft.title = value
        if m.seriesEditAction = "seriesDescription" then m.seriesDraft.description = value
    end if
    closeRecordDialog()
    showSeriesOptions()
end sub

sub runSeriesTask(action as string, callback as string)
    if m.recordIntent = invalid or m.seriesDraft = invalid or m.recordTask <> invalid then return
    m.recordTask = CreateObject("roSGNode", "DvrRecordingTask")
    m.recordTask.baseUrl = m.baseUrl
    m.recordTask.apiKey = m.apiKey
    m.recordTask.accountId = m.serverAccountId
    m.recordTask.action = action
    m.recordTask.seriesRule = m.seriesDraft
    m.recordScope = m.recordIntent.scope
    m.recordAccount = m.accountIdentity
    m.recordTask.observeField("result", callback)
    m.recordTask.control = "RUN"
end sub

function seriesResultIsCurrent(result as object) as boolean
    if m.recordAccount <> m.accountIdentity or (m.page <> "guide" and m.page <> "player") then return false
    if m.guide.config = invalid or m.recordIntent = invalid then return false
    return m.recordScope = textValue(m.guide.config.scope) and result.accountId = m.serverAccountId and m.capabilities.dvr = "manage"
end function

sub onSeriesPreview(event as object)
    if not isCurrentTaskEvent(event, m.recordTask) then return
    result = event.getData()
    m.recordTask.unobserveField("result")
    m.recordTask = invalid
    if not seriesResultIsCurrent(result) then return
    if not result.ok
        showNotice("Series preview failed: " + textValue(result.message))
        showSeriesOptions()
        return
    end if
    message = "Matched " + result.total.toStr() + " upcoming programs (7-day window)."
    if result.warn then message += " Many matches; verify the title and scope."
    count = 0
    for each match in result.matches
        if count >= 2 then exit for
        message += chr(10) + left(textValue(match.title), 45) + " " + left(textValue(match.start_time), 16)
        count++
    end for
    message += chr(10) + "Saving may schedule future recordings immediately."
    openRecordPicker("Confirm series rule", left(message, 340), [{title: "Cancel", action: "cancel"}, {title: "Create series rule: " + m.seriesDraft.mode, action: "seriesCreate"}])
end sub

sub onSeriesCreated(event as object)
    if not isCurrentTaskEvent(event, m.recordTask) then return
    result = event.getData()
    m.recordTask.unobserveField("result")
    m.recordTask = invalid
    if not seriesResultIsCurrent(result) then return
    m.recordIntent = invalid
    m.seriesDraft = invalid
    if result.ok
        showNotice("Series rule saved and evaluated. Open DVR > Series Rules and Scheduled to review it.")
    else
        showNotice("Series rule not confirmed: " + textValue(result.message) + " Review rules before retrying.")
    end if
end sub
