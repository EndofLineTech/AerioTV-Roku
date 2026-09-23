' Isolated, single-use disposable recording probe. The normal package excludes
' this file. It schedules ONE short recording and never mutates another ID.
sub installDvrLifecycleProbe()
    m.lifecycleStage = "wait"
    m.lifecycleTicks = 0
    m.lifecycleTask = invalid
    m.lifecycleTimer = m.top.createChild("Timer")
    m.lifecycleTimer.duration = 1
    m.lifecycleTimer.repeat = true
    m.lifecycleTimer.observeField("fire", "lifecycleTick")
    m.lifecycleTimer.control = "start"
end sub

sub lifecycleTick()
    m.lifecycleTicks++
    if m.lifecycleTicks > 90
        print "[dvr-lifecycle] timed out; inspect Scheduled before any retry"
        m.lifecycleTimer.control = "stop"
        return
    end if
    if m.lifecycleStage <> "wait" or m.page <> "guide" or m.capabilities.dvr <> "manage" then return
    if m.guide.config = invalid or m.guide.config.channels.count() = 0 then return
    channel = m.guide.config.channels[0]
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(textValue(channel.id)) then return
    now = uiNow()
    m.lifecycleChannel = textValue(channel.id)
    m.lifecycleProgram = {id: "aerio-disposable-" + now.toStr(), title: "AerioTV disposable lifecycle test", startsAt: now + 60, endsAt: now + 480}
    m.lifecycleStage = "schedule"
    lifecycleRun("schedule", "")
end sub

sub lifecycleRun(action as string, id as string)
    task = CreateObject("roSGNode", "DvrRecordingTask")
    task.baseUrl = m.baseUrl
    task.apiKey = m.apiKey
    task.accountId = m.serverAccountId
    task.action = action
    task.channelId = m.lifecycleChannel
    task.program = m.lifecycleProgram
    task.recordingId = id
    task.observeField("result", "onLifecycleResult")
    m.lifecycleTask = task
    task.control = "RUN"
end sub

sub onLifecycleResult(event as object)
    if not isCurrentTaskEvent(event, m.lifecycleTask) then return
    result = event.getData()
    m.lifecycleTask.unobserveField("result")
    m.lifecycleTask = invalid
    if m.lifecycleStage = "schedule"
        if not result.ok
            print "[dvr-lifecycle] schedule unconfirmed; category="; textValue(result.category); "; inspect server before any retry"
            m.lifecycleTimer.control = "stop"
            return
        end if
        m.lifecycleId = result.recording.id
        m.lifecycleStage = "status"
        lifecycleRun("status", m.lifecycleId)
    else if m.lifecycleStage = "status"
        matched = result.ok and result.recording.id = m.lifecycleId and result.recording.channelId = m.lifecycleChannel and result.recording.programId = m.lifecycleProgram.id
        print "[dvr-lifecycle] created id="; m.lifecycleId; " identity-match="; matched
        m.lifecycleStage = "complete"
        m.lifecycleTimer.control = "stop"
    end if
end sub
