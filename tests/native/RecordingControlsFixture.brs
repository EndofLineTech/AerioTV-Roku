' Native-only, one-shot server fixture. Owner approved a short disposable
' recording. No write occurs until the connected account has DVR manage access.
sub installRecordingControlsFixture()
    m.controlsFixtureStage = "wait"
    m.controlsFixtureTicks = 0
    m.controlsFixtureTask = invalid
    m.controlsFixtureTimer = m.top.createChild("Timer")
    m.controlsFixtureTimer.duration = 1
    m.controlsFixtureTimer.repeat = true
    m.controlsFixtureTimer.observeField("fire", "recordingControlsFixtureTick")
    m.controlsFixtureTimer.control = "start"
end sub

sub recordingControlsFixtureTick()
    m.controlsFixtureTicks++
    if m.controlsFixtureTicks > 90
        m.controlsFixtureTimer.control = "stop"
        print "[controls-fixture] timeout; inspect DVR before retrying"
        return
    end if
    if m.controlsFixtureStage <> "wait" or m.page <> "guide" or m.capabilities.dvr <> "manage" then return
    if m.guide.config = invalid or m.guide.config.channels.count() = 0 then return
    channel = m.guide.config.channels[0]
    m.controlsFixtureChannel = textValue(channel.id)
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(m.controlsFixtureChannel) then return
    now = uiNow()
    m.controlsFixtureProgram = {id: "aerio-controls-" + now.toStr(), title: "AerioTV disposable controls check", startsAt: now + 30, endsAt: now + 330}
    m.controlsFixtureStage = "schedule"
    recordingControlsFixtureTask("schedule", "")
end sub

sub recordingControlsFixtureTask(action as string, id as string)
    task = CreateObject("roSGNode", "DvrRecordingTask")
    task.baseUrl = m.baseUrl
    task.apiKey = m.apiKey
    task.accountId = m.serverAccountId
    task.action = action
    task.channelId = m.controlsFixtureChannel
    task.program = m.controlsFixtureProgram
    task.recordingId = id
    task.preRoll = 0
    task.postRoll = 0
    task.observeField("result", "onRecordingControlsFixtureResult")
    m.controlsFixtureTask = task
    task.control = "RUN"
end sub

sub onRecordingControlsFixtureResult(event as object)
    if not isCurrentTaskEvent(event, m.controlsFixtureTask) then return
    result = event.getData()
    m.controlsFixtureTask.unobserveField("result")
    m.controlsFixtureTask = invalid
    if m.controlsFixtureStage = "schedule"
        if not result.ok
            print "[controls-fixture] schedule unconfirmed; inspect DVR before retrying"
            m.controlsFixtureTimer.control = "stop"
            return
        end if
        m.controlsFixtureId = result.recording.id
        m.controlsFixtureStage = "verify"
        recordingControlsFixtureTask("status", m.controlsFixtureId)
    else if m.controlsFixtureStage = "verify"
        matched = result.ok and result.recording.id = m.controlsFixtureId and result.recording.channelId = m.controlsFixtureChannel and result.recording.programId = m.controlsFixtureProgram.id
        print "[controls-fixture] created id="; m.controlsFixtureId; " identity-match="; matched
        m.controlsFixtureStage = "complete"
        m.controlsFixtureTimer.control = "stop"
    end if
end sub
