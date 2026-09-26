' Server-owned DVR library. Rendering and focus stay on the SceneGraph thread;
' DvrRecordingTask performs bounded network I/O on a Task thread.
sub init()
    m.top.focusable = true
    m.top.visible = false
    m.list = m.top.findNode("recordings")
    m.list.observeField("itemSelected", "onDvrSelected")
    m.list.observeField("itemFocused", "onDvrFocused")
    m.poster = m.top.findNode("artwork")
    m.poster.visible = false
    m.status = m.top.findNode("status")
    m.refreshTimer = m.top.findNode("refreshTimer")
    m.refreshTimer.observeField("fire", "refreshRecordings")
    m.hint = uiLabel(m.top, "OK  Facts / play    *  Search / sort    Replay  Refresh    Back  Guide", 96, 997, 1728, 36, 21, "0x9EB5C9FF")
    m.loaded = []
    m.loadedRules = []
    m.rows = []
    m.lastFocusedItem = -1
    m.channelsById = {}
    m.channelLogos = {}
    m.query = ""
    m.sortMode = "date"
    m.task = invalid
    m.refreshRequested = false
    m.mutationTask = invalid
    m.dialog = invalid
    m.pending = invalid
    m.actionFeedback = ""
    m.ruleError = ""
    m.comskipPendingIds = {}
    drawDvr()
end sub

sub onDvrConfig()
    cancelDvrLoad()
    m.refreshRequested = false
    cancelDvrMutation()
    dismissDvrDialog()
    m.loaded = []
    m.loadedRules = []
    m.rows = []
    m.lastFocusedItem = -1
    m.query = ""
    m.actionFeedback = ""
    m.ruleError = ""
    m.comskipPendingIds = {}
    m.channelsById = {}
    m.channelLogos = {}
    if m.poster <> invalid
        m.poster.visible = false
        m.poster.uri = ""
    end if
    config = m.top.config
    if m.poster <> invalid
        agent = CreateObject("roHttpAgent")
        agent.setCertificatesFile("common:/certs/ca-bundle.crt")
        if type(config) = "roAssociativeArray" then agent.setHeaders(dispatcharrRequestHeaders(config.apiKey, textValue(m.global.authHeaderMode), textValue(m.global.httpUserAgent)))
        m.poster.setHttpAgent(agent)
    end if
    if type(config) = "roAssociativeArray"
        if type(config.channels) = "roArray"
            for each channel in config.channels
                m.channelsById[textValue(channel.id)] = channelHeading(textValue(channel.number), textValue(channel.name))
                m.channelLogos[textValue(channel.id)] = textValue(channel.logoId)
            end for
        end if
    end if
    drawDvr()
    if m.top.active then refreshRecordings()
end sub

sub onDvrActive()
    m.top.visible = m.top.active
    if m.top.active
        m.list.setFocus(true)
        m.refreshTimer.control = "start"
        drawDvr()
        refreshRecordings()
    else
        m.refreshTimer.control = "stop"
        m.poster.visible = false
        m.poster.uri = ""
        cancelDvrLoad()
        cancelDvrMutation()
        dismissDvrDialog()
    end if
end sub

sub cancelDvrMutation()
    if m.mutationTask <> invalid
        m.mutationTask.unobserveField("result")
        cancelNetworkTask(m.mutationTask)
        m.mutationTask = invalid
    end if
    m.pending = invalid
end sub

sub cancelDvrLoad()
    if m.task <> invalid
        m.task.unobserveField("result")
        cancelNetworkTask(m.task)
        m.task = invalid
    end if
end sub

sub refreshRecordings()
    if not m.top.active or m.mutationTask <> invalid then return
    if m.task <> invalid
        m.refreshRequested = true
        return
    end if
    config = m.top.config
    if type(config) <> "roAssociativeArray" then return
    if config.permission <> "view" and config.permission <> "manage" then return
    m.task = CreateObject("roSGNode", "DvrRecordingTask")
    m.task.baseUrl = config.baseUrl
    m.task.apiKey = config.apiKey
    m.task.accountId = config.accountId
    m.task.action = "list"
    m.taskKind = "list"
    m.taskScope = config.scope
    m.task.observeField("result", "onDvrLoaded")
    m.status.text = "Refreshing server recordings..."
    m.task.control = "RUN"
end sub

sub refreshSeriesRules()
    config = m.top.config
    if not m.top.active or type(config) <> "roAssociativeArray" then return
    m.task = CreateObject("roSGNode", "DvrRecordingTask")
    m.task.baseUrl = config.baseUrl
    m.task.apiKey = config.apiKey
    m.task.accountId = config.accountId
    m.task.action = "series-list"
    m.taskKind = "series-list"
    m.taskScope = config.scope
    m.task.observeField("result", "onDvrLoaded")
    m.task.control = "RUN"
end sub

sub onDvrLoaded(event as object)
    if not isCurrentTaskEvent(event, m.task) then return
    result = event.getData()
    kind = m.taskKind
    m.task.unobserveField("result")
    m.task = invalid
    config = m.top.config
    if not m.top.active or type(config) <> "roAssociativeArray" then return
    if m.taskScope <> config.scope or result.accountId <> config.accountId then return
    if result.ok
        if kind = "list"
            m.loaded = result.recordings
            m.ruleError = ""
            for each row in m.loaded
                if row.comskipStatus <> "" then m.comskipPendingIds.delete(row.id)
            end for
            drawDvr()
            refreshSeriesRules()
            return
        end if
        m.loadedRules = result.rules
        m.ruleError = ""
    else
        if kind = "list"
            m.status.text = "Could not refresh recordings: " + textValue(result.message)
        else
            m.loadedRules = []
            m.ruleError = textValue(result.message)
        end if
    end if
    if kind = "series-list" then drawDvr()
    if m.refreshRequested
        m.refreshRequested = false
        refreshRecordings()
    end if
end sub

sub drawDvr()
    if m.list = invalid then return
    focusId = ""
    selected = m.list.itemFocused
    if selected >= 0 and selected < m.rows.count() then focusId = dvrRowIdentity(m.rows[selected])
    now = uiNow()
    m.rows = dvrLibraryRows(m.loaded, m.loadedRules, m.query, now, m.channelsById, m.sortMode)
    content = CreateObject("roSGNode", "ContentNode")
    newIndex = 0
    itemCount = 0
    for i = 0 to m.rows.count() - 1
        row = m.rows[i]
        if dvrRowIdentity(row) = focusId then newIndex = i
        if row.heading <> invalid
            title = row.heading + "  (" + row.itemCount.toStr() + ")"
        else if row.id = invalid
            itemCount++
            title = "SERIES RULE  |  " + row.title + "  |  " + ucase(row.mode) + "  |  " + row.tvgId
        else
            itemCount++
            channelName = "Channel " + row.channelId
            if m.channelsById.doesExist(row.channelId) then channelName = m.channelsById[row.channelId]
            statusLabel = ucase(row.displayStatus)
            if row.displayStatus = "recording" then statusLabel = "RECORDING NOW"
            title = statusLabel + "  |  " + left(row.title, 20) + "  |  " + left(channelName, 12)
            start = guideEpoch(row.startTime)
            if start <> invalid then title += "  |  " + uiLocalDate(start)
        end if
        item = content.createChild("ContentNode")
        item.title = left(title, 240)
        if row.heading <> invalid then item.shortDescriptionLine1 = "heading"
    end for
    m.updatingList = true
    m.list.drawFocusFeedback = itemCount > 0
    m.list.content = content
    if m.rows.count() > 0
        selectable = dvrSelectableIndex(m.rows, newIndex, 1)
        if selectable >= 0 then newIndex = selectable
        m.lastFocusedItem = newIndex
        m.list.jumpToItem = newIndex
    end if
    m.updatingList = false
    showDvrArtwork(newIndex)
    nowCount = 0
    scheduledCount = 0
    recentCount = 0
    for each recording in m.loaded
        state = recordingDisplayStatus(recording, now)
        if state = "recording" then nowCount++ else if state = "scheduled" then scheduledCount++ else recentCount++
    end for
    ruleCount = m.loadedRules.count().toStr()
    if m.ruleError <> "" then ruleCount = "unavailable"
    m.status.text = "Recording now: " + nowCount.toStr() + "  |  Scheduled: " + scheduledCount.toStr() + "  |  Recent: " + recentCount.toStr() + "  |  Series rules: " + ruleCount
    if m.query <> "" then m.status.text += "  |  " + itemCount.toStr() + " matches: " + m.query
    if m.sortMode = "title" then m.status.text += "  |  Sort: title within each status"
    if itemCount = 0
        if m.query = ""
            m.status.text += "  |  No server recordings. Replay refreshes."
        else
            m.status.text += "  |  No matching server items."
        end if
    end if
    if m.ruleError <> "" then m.status.text += "  |  Series rules unavailable: " + m.ruleError
    if m.actionFeedback <> "" then m.status.text += "  |  " + m.actionFeedback
end sub

sub onDvrFocused(event as object)
    if not m.list.isSameNode(event.getRoSGNode()) then return
    if m.updatingList then return
    index = event.getData()
    if index < 0 or index >= m.rows.count() then return
    direction = 1
    if m.lastFocusedItem >= 0 and index < m.lastFocusedItem then direction = -1
    target = dvrSelectableIndex(m.rows, index, direction)
    if target >= 0 and target <> index
        m.lastFocusedItem = target
        m.list.jumpToItem = target
        return
    end if
    m.lastFocusedItem = index
    showDvrArtwork(index)
end sub

sub showDvrArtwork(index as integer)
    if m.poster = invalid then return
    if index < 0 or index >= m.rows.count()
        m.poster.visible = false
        m.poster.uri = ""
        return
    end if
    row = m.rows[index]
    if row.heading <> invalid or row.id = invalid
        m.poster.visible = false
        m.poster.uri = ""
        return
    end if
    logoId = textValue(row.posterLogoId)
    if logoId = "" and m.channelLogos.doesExist(row.channelId) then logoId = m.channelLogos[row.channelId]
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(logoId)
        m.poster.visible = false
        m.poster.uri = ""
        return
    end if
    config = m.top.config
    if type(config) <> "roAssociativeArray" then return
    base = normalizeBaseUrl(config.baseUrl)
    if base = "" then return
    uri = base + "/api/channels/logos/" + logoId + "/cache/"
    m.poster.visible = true
    if uri <> m.poster.uri then m.poster.uri = uri
end sub

sub onDvrSelected(event as object)
    if not m.top.active or not m.list.isSameNode(event.getRoSGNode()) then return
    index = event.getData()
    if index < 0 or index >= m.rows.count() then return
    row = m.rows[index]
    if row.heading <> invalid then return
    if row.id = invalid
        openDvrRuleDetails(row)
        return
    end if
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = left(row.title, 120)
    channelName = "Channel " + row.channelId
    if m.channelsById.doesExist(row.channelId) then channelName = m.channelsById[row.channelId]
    dialog.message = "Server status: " + row.displayStatus + chr(10) + channelName + chr(10) + row.startTime + " - " + row.endTime + chr(10) + row.description
    if row.comskipStatus <> ""
        statusText = row.comskipStatus
        if row.comskipReason = "comskip_not_installed" then statusText = "unavailable (server lacks Comskip)"
        if row.comskipSkipped = true then statusText = "completed; no commercials detected"
        if row.comskipMode = "mark" then statusText = "completed; commercials marked on server"
        if row.comskipMode = "remove" then statusText = "completed; server removed commercial segments"
        dialog.message += chr(10) + "Commercial processing: " + statusText
    end if
    m.dialogActions = ["close"]
    labels = ["Close"]
    config = m.top.config
    if type(config) <> "roAssociativeArray" then return
    if config.permission = "view" or config.permission = "manage"
        if recordingPlaybackPlan(config.baseUrl, row) <> invalid
            labels.push("Play / resume on Roku")
            m.dialogActions.push("play")
            if row.displayStatus <> "recording"
                labels.push("Play from beginning")
                m.dialogActions.push("restart")
            end if
        end if
    end if
    if config.permission = "manage" and m.mutationTask = invalid
        if row.displayStatus = "scheduled" and guideEpoch(row.startTime) > CreateObject("roDateTime").asSeconds()
            labels.push("Cancel future schedule")
            m.dialogActions.push("cancel")
        else if row.displayStatus = "recording"
            labels.push("Stop and keep partial recording")
            m.dialogActions.push("stop")
        else if row.displayStatus = "completed" or row.displayStatus = "stopped"
            if row.comskipStatus = "" and not m.comskipPendingIds.doesExist(row.id)
                labels.push("Queue commercial processing")
                m.dialogActions.push("comskip")
            end if
            labels.push("Delete permanently")
            m.dialogActions.push("delete")
        else if row.displayStatus = "interrupted" or row.displayStatus = "failed"
            labels.push("Delete permanently")
            m.dialogActions.push("delete")
        end if
    end if
    m.targetRow = row
    dialog.buttons = labels
    dialog.observeField("buttonSelected", "onDvrDetailAction")
    dialog.observeField("wasClosed", "onDvrDialogClosed")
    m.dialog = dialog
    m.top.getScene().dialog = dialog
end sub

sub openDvrRuleDetails(row as object)
    config = m.top.config
    if type(config) <> "roAssociativeArray" then return
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = left(row.title, 120)
    dialog.message = "Series mode: " + row.mode + chr(10) + "Title matching: " + row.titleMode + chr(10) + "EPG channel: " + row.tvgId + chr(10) + "Description: " + left(row.description, 180)
    m.dialogActions = ["close"]
    labels = ["Close"]
    if config.permission = "manage" and m.mutationTask = invalid
        labels.push("Remove rule and future schedules")
        m.dialogActions.push("deleteRule")
    end if
    m.targetRow = row
    dialog.buttons = labels
    dialog.observeField("buttonSelected", "onDvrDetailAction")
    dialog.observeField("wasClosed", "onDvrDialogClosed")
    m.dialog = dialog
    m.top.getScene().dialog = dialog
end sub

sub onDvrDetailAction(event as object)
    if m.dialog = invalid or not m.dialog.isSameNode(event.getRoSGNode()) then return
    index = event.getData()
    if index < 0 or index >= m.dialogActions.count() then return
    action = m.dialogActions[index]
    if action = "close"
        m.dialog.close = true
        return
    end if
    config = m.top.config
    if action = "play" or action = "restart"
        if type(config) <> "roAssociativeArray" then return
        if config.permission <> "view" and config.permission <> "manage" then return
        row = m.targetRow
        if recordingPlaybackPlan(config.baseUrl, row) = invalid then return
        dismissDvrDialog()
        m.top.playRequested = {scope: config.scope, accountId: config.accountId, recordingId: row.id, fromBeginning: action = "restart"}
        return
    end if
    if action = "deleteRule"
        if type(config) <> "roAssociativeArray" or config.permission <> "manage" or m.mutationTask <> invalid then return
        row = m.targetRow
        dismissDvrDialog()
        m.pending = {action: "series-delete", rule: row, title: row.title, scope: config.scope, accountId: config.accountId}
        dialog = CreateObject("roSGNode", "Dialog")
        dialog.title = "Remove series rule and future schedules?"
        dialog.message = left(row.title, 90) + chr(10) + "EPG channel: " + left(row.tvgId, 60) + chr(10) + "The server may remove future schedules made by this rule. Completed recordings stay intact."
        dialog.buttons = ["Keep series rule", "Remove rule and future schedules"]
        dialog.observeField("buttonSelected", "onDvrConfirmed")
        dialog.observeField("wasClosed", "onDvrDialogClosed")
        m.dialog = dialog
        m.top.getScene().dialog = dialog
        return
    end if
    if config = invalid or config.permission <> "manage" or m.mutationTask <> invalid then return
    row = m.targetRow
    dismissDvrDialog()
    m.pending = {action: action, recordingId: row.id, title: row.title, scope: config.scope, accountId: config.accountId}
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Confirm server recording action"
    effect = "Stop recording early and keep its partial content?"
    if action = "cancel" then effect = "Cancel this future schedule?"
    if action = "delete" then effect = "Permanently delete this finished recording and its server file?"
    if action = "comskip" then effect = "Ask the server to queue commercial processing for this finished recording?"
    channelName = "Channel " + row.channelId
    if m.channelsById.doesExist(row.channelId) then channelName = m.channelsById[row.channelId]
    when = row.startTime
    startAt = guideEpoch(row.startTime)
    if startAt <> invalid then when = uiLocalDate(startAt) + " " + uiTime(startAt)
    dialog.message = left(row.title, 90) + chr(10) + left(channelName, 64) + " | " + when + chr(10) + effect
    dialog.buttons = ["Keep recording", "Confirm " + action]
    dialog.observeField("buttonSelected", "onDvrConfirmed")
    dialog.observeField("wasClosed", "onDvrDialogClosed")
    m.dialog = dialog
    m.top.getScene().dialog = dialog
end sub

sub onDvrConfirmed(event as object)
    if m.dialog = invalid or not m.dialog.isSameNode(event.getRoSGNode()) then return
    choice = event.getData()
    request = m.pending
    m.pending = invalid
    m.dialog.close = true
    if choice <> 1 or request = invalid or m.mutationTask <> invalid then return
    config = m.top.config
    if config = invalid or config.permission <> "manage" or config.scope <> request.scope or config.accountId <> request.accountId then return
    cancelDvrLoad()
    action = request.action
    m.mutationScope = request.scope
    m.mutationAction = action
    m.mutationId = request.recordingId
    m.mutationTask = CreateObject("roSGNode", "DvrRecordingTask")
    m.mutationTask.baseUrl = config.baseUrl
    m.mutationTask.apiKey = config.apiKey
    m.mutationTask.accountId = config.accountId
    m.mutationTask.action = action
    if action = "series-delete" then m.mutationTask.seriesRule = request.rule else m.mutationTask.recordingId = request.recordingId
    m.mutationTask.observeField("result", "onDvrMutation")
    m.actionFeedback = "Checking server status before " + action + "..."
    m.pending = invalid
    drawDvr()
    m.mutationTask.control = "RUN"
end sub

sub onDvrMutation(event as object)
    if not isCurrentTaskEvent(event, m.mutationTask) then return
    result = event.getData()
    m.mutationTask.unobserveField("result")
    m.mutationTask = invalid
    config = m.top.config
    if not m.top.active or type(config) <> "roAssociativeArray" then return
    if m.mutationScope <> config.scope or result.accountId <> config.accountId then return
    m.actionFeedback = textValue(result.message)
    if result.ok then m.actionFeedback = "Server confirmed the operation."
    if result.ok and m.mutationAction = "series-delete"
        m.loaded = []
        m.loadedRules = []
        m.actionFeedback = "Rule removed. Server reported " + textValue(result.removed) + " future schedules removed. Refresh DVR to verify."
    end if
    if result.ok and m.mutationAction = "comskip"
        m.comskipPendingIds[m.mutationId] = true
        m.actionFeedback = "Server queued commercial processing. Refresh for the actual result."
    end if
    if result.ok and m.mutationAction = "delete"
        m.comskipPendingIds.delete(m.mutationId)
        m.top.deleted = {scope: config.scope, accountId: config.accountId, recordingId: m.mutationId}
    end if
    drawDvr()
    refreshRecordings()
end sub

sub onDvrDialogClosed(event as object)
    if m.dialog = invalid or not m.dialog.isSameNode(event.getRoSGNode()) then return
    dismissDvrDialog()
    if m.top.active then m.list.setFocus(true)
end sub

sub dismissDvrDialog()
    if m.dialog = invalid then return
    m.dialog.unobserveField("buttonSelected")
    m.dialog.unobserveField("wasClosed")
    m.dialog.close = true
    m.dialog = invalid
    m.pending = invalid
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.active then return false
    if m.dialog <> invalid then return false
    if key = "back"
        m.top.closed = true
        return true
    end if
    if key = "options"
        dialog = CreateObject("roSGNode", "KeyboardDialog")
        dialog.title = "Search recordings and rules (blank clears), or change sort"
        dialog.text = m.query
        sortLabel = "Sort by title"
        if m.sortMode = "title" then sortLabel = "Sort by date"
        dialog.buttons = ["Search", sortLabel, "Cancel"]
        dialog.observeField("buttonSelected", "onDvrSearch")
        dialog.observeField("wasClosed", "onDvrDialogClosed")
        m.dialog = dialog
        m.top.getScene().dialog = dialog
        return true
    end if
    if key = "replay"
        refreshRecordings()
        return true
    end if
    return false
end function

sub onDvrSearch(event as object)
    if m.dialog = invalid or not m.dialog.isSameNode(event.getRoSGNode()) then return
    if event.getData() = 0
        m.query = left(m.dialog.text.trim(), 80)
        drawDvr()
    else if event.getData() = 1
        if m.sortMode = "date" then m.sortMode = "title" else m.sortMode = "date"
        drawDvr()
    end if
    m.dialog.close = true
end sub
