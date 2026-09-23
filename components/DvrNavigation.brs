' Record-once flow: validate permission and guide identity at the Scene boundary.
' A mutation is sent once on a Task; ambiguous failures require server refresh.
sub onRecordRequested(event as object)
    if not m.guide.isSameNode(event.getRoSGNode()) or m.page <> "guide" then return
    if m.capabilities.dvr <> "manage" or m.recordTask <> invalid or m.recordDialog <> invalid then return
    if m.guide.config = invalid then return
    request = event.getData()
    if type(request) <> "roAssociativeArray" then return
    if textValue(request.scope) <> textValue(m.guide.config.scope) then return
    if type(request.channel) <> "roAssociativeArray" then return
    channel = m.guide.callFunc("channelByUuid", textValue(request.channel.uuid))
    if channel = invalid then return
    if channel.id <> request.channel.id then return
    if not recordingScheduleEligible(m.capabilities.dvr, channel, request.program, uiNow()) then return
    openRecordFlow(channel, request.program, request.scope)
end sub

sub requestPlayerRecording()
    if m.page <> "player" or m.playingChannel = invalid or m.capabilities.dvr <> "manage" then return
    if m.recordTask <> invalid or m.recordDialog <> invalid or m.guide.config = invalid then return
    channel = m.guide.callFunc("channelByUuid", m.playingChannel.uuid)
    if channel = invalid then return
    info = m.guide.callFunc("cachedPlaybackInfo", channel, uiNow())
    if type(info) <> "roAssociativeArray" or type(info.programs) <> "roArray" then return
    program = selectNowNext(info.programs, uiNow()).current
    if not recordingScheduleEligible(m.capabilities.dvr, channel, program, uiNow())
        showNotice("Current program information is unavailable. Open Guide details to record a future program.")
        return
    end if
    openRecordFlow(channel, program, m.guide.config.scope)
end sub

sub openRecordFlow(channel as object, program as object, scope as string)
    m.recordIntent = {account: m.accountIdentity, scope: scope, channelId: channel.id, channelName: channel.name, tvgId: textValue(channel.epgKey), program: program}
    m.recordPadding = {pre: m.accountPreferences.dvrPreRollMinutes, post: m.accountPreferences.dvrPostRollMinutes}
    backLabel = "Back to guide"
    if m.page = "player" then backLabel = "Back to player"
    options = [{title: backLabel, action: "cancel"}, {title: "Use saved padding (" + m.recordPadding.pre.toStr() + " / " + m.recordPadding.post.toStr() + " minutes)", action: "defaults"}, {title: "Customize padding for this recording", action: "custom"}]
    if m.recordIntent.tvgId <> ""
        options.push({title: "Record every episode (series rule)", action: "seriesMode", value: "all"})
        options.push({title: "Record new episodes (series rule)", action: "seriesMode", value: "new"})
    end if
    openRecordPicker("Record once on Dispatcharr", "The server owns this recording after the Roku exits.", options)
end sub

sub openRecordPicker(title as string, message as string, choices as object)
    closeRecordDialog()
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = title
    dialog.message = message
    labels = []
    for each choice in choices
        labels.push(choice.title)
    end for
    dialog.buttons = labels
    dialog.observeField("buttonSelected", "onRecordChoice")
    dialog.observeField("wasClosed", "onRecordDialogClosed")
    m.recordDialog = dialog
    m.recordChoices = choices
    m.top.dialog = dialog
end sub

sub closeRecordDialog()
    if m.recordDialog = invalid then return
    m.recordDialog.unobserveField("buttonSelected")
    m.recordDialog.unobserveField("wasClosed")
    m.recordDialog.close = true
    m.recordDialog = invalid
end sub

sub onRecordDialogClosed(event as object)
    if m.recordDialog = invalid or not m.recordDialog.isSameNode(event.getRoSGNode()) then return
    closeRecordDialog()
    m.recordIntent = invalid
    m.seriesDraft = invalid
    focusAfterRecordDialog()
end sub

sub focusAfterRecordDialog()
    if m.page = "guide" then m.guide.setFocus(true)
    if m.page = "player" then focusPlaybackInput()
end sub

sub onRecordChoice(event as object)
    if m.recordDialog = invalid or not m.recordDialog.isSameNode(event.getRoSGNode()) then return
    index = event.getData()
    if index < 0 or index >= m.recordChoices.count() then return
    choice = m.recordChoices[index]
    if choice.action = "cancel"
        closeRecordDialog()
        m.recordIntent = invalid
        m.seriesDraft = invalid
        focusAfterRecordDialog()
        return
    end if
    if m.recordIntent = invalid or m.recordIntent.account <> m.accountIdentity or m.capabilities.dvr <> "manage" then return
    if choice.action = "seriesMode"
        m.seriesDraft = {title: m.recordIntent.program.title, tvgId: m.recordIntent.tvgId, channelId: m.recordIntent.channelId, mode: choice.value, titleMode: "exact", description: "", descriptionMode: "contains", untaggedIsNew: false}
        showSeriesOptions()
    else if choice.action = "seriesTitleMode"
        modes = ["exact", "contains", "search"]
        nextIndex = 0
        for i = 0 to 2
            if m.seriesDraft.titleMode = modes[i] then nextIndex = (i + 1) mod 3
        end for
        m.seriesDraft.titleMode = modes[nextIndex]
        showSeriesOptions()
    else if choice.action = "seriesPin"
        if m.seriesDraft.channelId = "" then m.seriesDraft.channelId = m.recordIntent.channelId else m.seriesDraft.channelId = ""
        showSeriesOptions()
    else if choice.action = "seriesUntagged"
        m.seriesDraft.untaggedIsNew = not m.seriesDraft.untaggedIsNew
        showSeriesOptions()
    else if choice.action = "seriesTitle" or choice.action = "seriesDescription"
        openSeriesKeyboard(choice.action)
    else if choice.action = "seriesPreview"
        closeRecordDialog()
        runSeriesTask("series-preview", "onSeriesPreview")
        showNotice("Previewing server series matches without changing the schedule...")
    else if choice.action = "seriesCreate"
        closeRecordDialog()
        runSeriesTask("series-create", "onSeriesCreated")
        showNotice("Saving one series rule and checking its server results...")
    else if choice.action = "defaults" or choice.action = "post"
        if choice.action = "post" then m.recordPadding.post = choice.value
        openRecordPicker("Confirm server recording", recordingConfirmationText(m.recordIntent, m.recordPadding), [{title: "Cancel", action: "cancel"}, {title: "Record once on server", action: "confirm"}])
    else if choice.action = "custom" or choice.action = "pre"
        if choice.action = "pre" then m.recordPadding.pre = choice.value
        title = "Start early (minutes)"
        action = "pre"
        if choice.action = "pre"
            title = "End late (minutes)"
            action = "post"
        end if
        options = [{title: "Cancel", action: "cancel"}]
        for each value in [0, 5, 10, 15, 30]
            options.push({title: value.toStr() + " minutes", action: action, value: value})
        end for
        openRecordPicker(title, "Applies only to this recording.", options)
    else if choice.action = "confirm"
        closeRecordDialog()
        if m.recordTask <> invalid then return
        m.recordTask = CreateObject("roSGNode", "DvrRecordingTask")
        m.recordTask.baseUrl = m.baseUrl
        m.recordTask.apiKey = m.apiKey
        m.recordTask.accountId = m.serverAccountId
        m.recordTask.action = "schedule"
        m.recordTask.channelId = m.recordIntent.channelId
        m.recordTask.program = m.recordIntent.program
        m.recordTask.preRoll = m.recordPadding.pre
        m.recordTask.postRoll = m.recordPadding.post
        m.recordScope = m.recordIntent.scope
        m.recordAccount = m.accountIdentity
        m.recordIntent = invalid
        m.recordTask.observeField("result", "onRecordScheduled")
        m.recordTask.control = "RUN"
        showNotice("Checking server schedule and submitting once...")
    end if
end sub

sub onRecordScheduled(event as object)
    if not isCurrentTaskEvent(event, m.recordTask) then return
    result = event.getData()
    m.recordTask.unobserveField("result")
    m.recordTask = invalid
    if m.recordAccount <> m.accountIdentity or (m.page <> "guide" and m.page <> "player") then return
    if m.guide.config = invalid then return
    if result.accountId <> m.serverAccountId then return
    if m.recordScope <> textValue(m.guide.config.scope)
        showNotice("The lineup changed while scheduling. Check DVR before retrying this program.")
        return
    end if
    if result.ok
        showNotice("Server recording scheduled. Open DVR to confirm its status.")
    else if result.category = "duplicate"
        showNotice("This program is already scheduled. Open DVR to review.")
    else
        showNotice("Recording was not confirmed: " + textValue(result.message) + " Check DVR before retrying.")
    end if
end sub

sub cancelRecordFlow()
    closeRecordDialog()
    m.recordIntent = invalid
    m.seriesDraft = invalid
    if m.recordTask <> invalid
        m.recordTask.unobserveField("result")
        cancelNetworkTask(m.recordTask)
        m.recordTask = invalid
    end if
end sub
