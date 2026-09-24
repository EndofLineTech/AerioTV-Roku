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
    m.tabs = ["Recording Now", "Scheduled", "Recent", "Series Rules"]
    m.shelves = ["now", "scheduled", "recent", "rules"]
    m.shelfIndex = 1
    m.tabLabels = []
    for i = 0 to 3
        label = uiLabel(m.top, m.tabs[i], 96 + i * 330, 254, 310, 54, 26)
        m.tabLabels.push(label)
    end for
    m.hint = uiLabel(m.top, "Left / Right  Shelf    OK  Facts    *  Search / sort    Replay  Refresh    Back  Guide", 96, 997, 1728, 36, 21, "0x9EB5C9FF")
    m.loaded = []
    m.loadedRules = []
    m.rows = []
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
    m.query = ""
    m.actionFeedback = ""
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
    if m.shelfIndex = 3 then m.task.action = "series-list"
    m.taskKind = m.task.action
    m.taskScope = config.scope
    m.task.observeField("result", "onDvrLoaded")
    m.status.text = "Refreshing server recordings..."
    m.task.control = "RUN"
end sub

sub onDvrLoaded(event as object)
    if not isCurrentTaskEvent(event, m.task) then return
    result = event.getData()
    m.task.unobserveField("result")
    m.task = invalid
    config = m.top.config
    if not m.top.active or type(config) <> "roAssociativeArray" then return
    if m.taskScope <> config.scope or result.accountId <> config.accountId then return
    if result.ok
        if type(result.rules) = "roArray" then m.loadedRules = result.rules else m.loaded = result.recordings
        if type(result.recordings) = "roArray"
            for each row in m.loaded
                if row.comskipStatus <> "" then m.comskipPendingIds.delete(row.id)
            end for
        end if
        drawDvr()
    else
        m.status.text = "Could not refresh recordings: " + textValue(result.message)
    end if
    if m.refreshRequested or (m.taskKind = "series-list" and m.shelfIndex <> 3) or (m.taskKind = "list" and m.shelfIndex = 3)
        m.refreshRequested = false
        refreshRecordings()
    end if
end sub

sub drawDvr()
    if m.tabLabels = invalid then return
    for i = 0 to 3
        color = "0x9EB5C9FF"
        if i = m.shelfIndex then color = "0x1AC4D8FF"
        uiSetColor(m.tabLabels[i], color)
    end for
    focusId = ""
    selected = m.list.itemFocused
    if selected >= 0 and selected < m.rows.count() then focusId = dvrRowIdentity(m.rows[selected])
    if m.shelfIndex = 3
        m.rows = seriesRuleRows(m.loadedRules, m.query)
    else
        m.rows = recordingShelfRows(m.loaded, m.shelves[m.shelfIndex], m.query, CreateObject("roDateTime").asSeconds(), m.channelsById, m.sortMode)
    end if
    content = CreateObject("roSGNode", "ContentNode")
    newIndex = 0
    for i = 0 to m.rows.count() - 1
        row = m.rows[i]
        if dvrRowIdentity(row) = focusId then newIndex = i
        if m.shelfIndex = 3
            title = ucase(row.mode) + "  |  " + row.title + "  |  " + row.tvgId + "  |  " + row.titleMode
        else
            channelName = "Channel " + row.channelId
            if m.channelsById.doesExist(row.channelId) then channelName = m.channelsById[row.channelId]
            title = ucase(row.displayStatus) + "  |  " + left(row.title, 20) + "  |  " + left(channelName, 12)
            start = guideEpoch(row.startTime)
            if start <> invalid then title += "  |  " + uiLocalDate(start)
        end if
        content.createChild("ContentNode").title = "   " + left(title, 240)
    end for
    m.list.content = content
    if m.rows.count() > 0 then m.list.jumpToItem = newIndex
    showDvrArtwork(newIndex)
    noun = " recordings"
    if m.shelfIndex = 3 then noun = " rules"
    m.status.text = m.tabs[m.shelfIndex] + "  |  " + m.rows.count().toStr() + noun
    if m.query <> "" then m.status.text += "  |  Search: " + m.query
    if m.sortMode = "title" and m.shelfIndex <> 3 then m.status.text += "  |  Sort: title"
    if m.rows.count() = 0 then m.status.text += "  |  No matching server items."
    if m.actionFeedback <> "" then m.status.text += "  |  " + m.actionFeedback
end sub

sub onDvrFocused(event as object)
    if not m.list.isSameNode(event.getRoSGNode()) then return
    showDvrArtwork(event.getData())
end sub

sub showDvrArtwork(index as integer)
    if m.poster = invalid then return
    if m.shelfIndex = 3 or index < 0 or index >= m.rows.count()
        m.poster.visible = false
        m.poster.uri = ""
        return
    end if
    row = m.rows[index]
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
    if m.shelfIndex = 3
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
        m.actionFeedback = "Rule removed. Server reported " + textValue(result.removed) + " future schedules removed. Refresh Scheduled to verify."
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
    if key = "left" and m.shelfIndex > 0 then m.shelfIndex--
    if key = "right" and m.shelfIndex < 3 then m.shelfIndex++
    if key = "left" or key = "right"
        drawDvr()
        refreshRecordings()
        return true
    end if
    if key = "options"
        dialog = CreateObject("roSGNode", "KeyboardDialog")
        dialog.title = "Search recordings (blank clears), or change sort"
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
