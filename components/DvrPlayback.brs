' Playback is read-only: get the current server row before constructing a
' route from its numeric ID. Never use a path or URL returned by the server.
sub onDvrPlayRequested(event as object)
    if not m.dvr.isSameNode(event.getRoSGNode()) or m.page <> "dvr" then return
    request = event.getData()
    if type(request) <> "roAssociativeArray" or m.dvrPlayTask <> invalid then return
    if m.capabilities.dvr <> "view" and m.capabilities.dvr <> "manage" then return
    if request.scope <> m.accountIdentity or request.accountId <> m.serverAccountId then return
    if recordingPlaybackPlan(m.baseUrl, {id: request.recordingId, status: "completed", fileReady: true}) = invalid then return
    m.dvrPlaybackRequest = {id: request.recordingId, account: m.accountIdentity, fromBeginning: request.fromBeginning = true}
    m.dvrPlayTask = CreateObject("roSGNode", "DvrRecordingTask")
    m.dvrPlayTask.baseUrl = m.baseUrl
    m.dvrPlayTask.apiKey = m.apiKey
    m.dvrPlayTask.accountId = m.serverAccountId
    m.dvrPlayTask.action = "status"
    m.dvrPlayTask.recordingId = request.recordingId
    m.dvrPlayTask.observeField("result", "onDvrPlaybackReady")
    m.dvrPlayTask.control = "RUN"
    showNotice("Checking recording playback availability...")
end sub

sub cancelDvrPlayback()
    cancelDvrHandoff()
    if m.dvrPlayTask <> invalid
        m.dvrPlayTask.unobserveField("result")
        cancelNetworkTask(m.dvrPlayTask)
        m.dvrPlayTask = invalid
    end if
    m.dvrPlaybackRequest = invalid
    m.dvrPlayback = invalid
end sub

' Only a fresh status response for the same account and recording can switch
' from the old HLS reader to the completed-file reader. The status task reads
' metadata; it never stops or edits the server recording.
sub onDvrHandoffRequested(event as object)
    if not m.mediaPlayer.isSameNode(event.getRoSGNode()) or m.page <> "onDemand" or m.mediaReturn <> "dvr" then return
    if m.dvrHandoffTask <> invalid or m.dvrPlayback = invalid then return
    if m.capabilities.dvr <> "view" and m.capabilities.dvr <> "manage" then return
    request = event.getData()
    if type(request) <> "roAssociativeArray" then return
    current = m.mediaPlayer.request
    if type(current) <> "roAssociativeArray" or current.growing <> true then return
    if request.account <> m.accountIdentity or request.account <> m.dvrPlayback.account then return
    if request.identity <> m.mediaIdentity or request.identity <> current.identity then return
    if request.id <> m.dvrPlayback.id or request.id <> current.key then return
    if recordingPlaybackPlan(m.baseUrl, {id: request.id, status: "completed", fileReady: true}) = invalid then return
    position = 0
    if mediaNumber(request.position)
        if request.position >= 0 and request.position < 86400 then position = int(request.position)
    end if
    m.dvrHandoff = {account: request.account, identity: request.identity, id: request.id, position: position}
    m.dvrHandoffTask = CreateObject("roSGNode", "DvrRecordingTask")
    m.dvrHandoffTask.baseUrl = m.baseUrl
    m.dvrHandoffTask.apiKey = m.apiKey
    m.dvrHandoffTask.accountId = m.serverAccountId
    m.dvrHandoffTask.action = "status"
    m.dvrHandoffTask.recordingId = request.id
    m.dvrHandoffTask.observeField("result", "onDvrHandoffReady")
    m.dvrHandoffTask.control = "RUN"
end sub

sub cancelDvrHandoff()
    if m.dvrHandoffTask <> invalid
        m.dvrHandoffTask.unobserveField("result")
        cancelNetworkTask(m.dvrHandoffTask)
        m.dvrHandoffTask = invalid
    end if
    m.dvrHandoff = invalid
end sub

sub onDvrHandoffReady(event as object)
    if not isCurrentTaskEvent(event, m.dvrHandoffTask) then return
    result = event.getData()
    m.dvrHandoffTask.unobserveField("result")
    m.dvrHandoffTask = invalid
    handoff = m.dvrHandoff
    m.dvrHandoff = invalid
    if handoff = invalid or m.page <> "onDemand" or m.mediaReturn <> "dvr" then return
    if m.dvrPlayback = invalid or m.dvrPlayback.growing <> true then return
    if m.capabilities.dvr <> "view" and m.capabilities.dvr <> "manage" then return
    if handoff.account <> m.accountIdentity or handoff.account <> m.dvrPlayback.account then return
    if handoff.identity <> m.mediaIdentity or handoff.id <> m.dvrPlayback.id then return
    previous = m.mediaPlayer.request
    if type(previous) <> "roAssociativeArray" or previous.growing <> true then return
    if previous.identity <> handoff.identity or previous.key <> handoff.id then return
    if type(result) <> "roAssociativeArray" or result.ok <> true then return
    if result.accountId <> m.serverAccountId or type(result.recording) <> "roAssociativeArray" then return
    if result.recording.id <> handoff.id then return
    plan = recordingPlaybackPlan(m.baseUrl, result.recording)
    if plan = invalid or plan.growing <> false then return
    completed = {}
    completed.append(previous)
    completed.url = plan.url
    completed.streamFormat = plan.streamFormat
    completed.growing = false
    completed.resume = handoff.position
    m.dvrPlayback.growing = false
    print "[dvr-handoff] confirmed completed file; resuming second="; handoff.position
    m.mediaPlayer.request = completed
end sub

sub onDvrPlaybackReady(event as object)
    if not isCurrentTaskEvent(event, m.dvrPlayTask) then return
    result = event.getData()
    m.dvrPlayTask.unobserveField("result")
    m.dvrPlayTask = invalid
    request = m.dvrPlaybackRequest
    m.dvrPlaybackRequest = invalid
    if request = invalid or m.page <> "dvr" or request.account <> m.accountIdentity then return
    if m.capabilities.dvr <> "view" and m.capabilities.dvr <> "manage" then return
    if result.accountId <> m.serverAccountId then return
    if not result.ok
        showNotice("Recording unavailable: " + textValue(result.message))
        return
    end if
    if result.recording.id <> request.id then return
    plan = recordingPlaybackPlan(m.baseUrl, result.recording)
    if plan = invalid
        showNotice("Recording media is not ready on the server. Refresh DVR to check its status.")
        return
    end if
    m.dvrPlayback = {account: m.accountIdentity, id: request.id, growing: plan.growing}
    resume = 0
    if not plan.growing and not request.fromBeginning then resume = m.accountPreferences.dvrPositions[request.id]
    if resume = invalid then resume = 0
    m.mediaIdentity = CreateObject("roDeviceInfo").getRandomUUID()
    m.lastDvrWrite = 0
    m.mediaReturn = "dvr"
    m.dvr.active = false
    m.page = "onDemand"
    m.mediaPlayer.request = {account: m.accountIdentity, identity: m.mediaIdentity, key: request.id, mode: "recording", title: result.recording.title, url: plan.url, apiKey: m.apiKey, streamFormat: plan.streamFormat, growing: plan.growing, resume: resume}
end sub

sub onDvrProgress(progress as object)
    context = m.dvrPlayback
    if context = invalid or context.account <> m.accountIdentity or progress.identity <> m.mediaIdentity or progress.key <> context.id then return
    if context.growing or not mediaNumber(progress.position) or not mediaNumber(progress.duration) then return
    if progress.duration <= 0 then return
    finished = progress.finished = true or progress.position >= progress.duration * 0.95
    if not finished and progress.closing <> true and m.lastDvrWrite > uiNow() - 15 then return
    position = int(progress.position)
    if finished then position = 0
    if position < 0 or position >= 86400 then return
    m.lastDvrWrite = uiNow()
    before = m.accountPreferences.dvrPositions
    positions = {}
    positions.append(before)
    if position = 0 then positions.delete(context.id) else positions[context.id] = position
    m.accountPreferences.dvrPositions = normalizeDvrPositions(positions)
    if not persistAccountPreferences() then m.accountPreferences.dvrPositions = before
end sub

sub onDvrDeleted(event as object)
    if not m.dvr.isSameNode(event.getRoSGNode()) then return
    value = event.getData()
    if type(value) <> "roAssociativeArray" then return
    if value.scope <> m.accountIdentity or value.accountId <> m.serverAccountId then return
    id = textValue(value.recordingId)
    if not m.accountPreferences.dvrPositions.doesExist(id) then return
    before = m.accountPreferences.dvrPositions
    positions = {}
    positions.append(before)
    positions.delete(id)
    m.accountPreferences.dvrPositions = positions
    if not persistAccountPreferences() then m.accountPreferences.dvrPositions = before
end sub
