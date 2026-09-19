sub init()
    m.ready = false
    m.base = ""
    m.logo = m.top.findNode("logo")
    canvas = m.top.findNode("canvas")
    uiRect(canvas, 96, 684, 1728, 328, "0x0A1628EF")
    uiRect(canvas, 96, 684, 1728, 3, "0x1AC4D8FF")
    m.channelName = uiLabel(canvas, "", 246, 705, 1150, 38, 26, "0x1AC4D8FF")
    m.state = uiLabel(canvas, "", 1410, 705, 240, 36, 23, "0x1AC4D8FF")
    m.state.horizAlign = "right"
    m.clock = uiLabel(canvas, "", 1666, 704, 124, 38, 26)
    m.clock.horizAlign = "right"
    m.title = uiLabel(canvas, "", 246, 750, 970, 48, 34)
    m.times = uiLabel(canvas, "", 246, 800, 970, 34, 23, "0x9EB5C9FF")
    m.description = uiLabel(canvas, "", 128, 846, 1070, 68, 23)
    m.description.wrap = true
    m.description.maxLines = 2
    m.progressTrack = uiRect(canvas, 128, 933, 1070, 5, "0x294357FF")
    m.progressFill = uiRect(canvas, 128, 933, 0, 5, "0x1AC4D8FF")
    m.progressText = uiLabel(canvas, "", 128, 946, 1070, 31, 20, "0x9EB5C9FF")
    uiRect(canvas, 1234, 752, 1, 221, "0x294357FF")
    uiLabel(canvas, "UP NEXT", 1272, 754, 516, 34, 22, "0x1AC4D8FF")
    m.nextTitle = uiLabel(canvas, "", 1272, 799, 516, 74, 26)
    m.nextTitle.wrap = true
    m.nextTitle.maxLines = 2
    m.nextTimes = uiLabel(canvas, "", 1272, 885, 516, 34, 22, "0x9EB5C9FF")
    m.dataStatus = uiLabel(canvas, "", 1272, 936, 516, 34, 20, "0x9EB5C9FF")
    m.hint = uiLabel(canvas, "", 128, 981, 1664, 28, 19, "0x1AC4D8FF")
    m.ready = true
end sub

sub configureSession()
    m.base = ""
    m.logo.uri = ""
    agent = CreateObject("roHttpAgent")
    agent.setCertificatesFile("common:/certs/ca-bundle.crt")
    session = m.top.session
    if type(session) = "roAssociativeArray"
        m.base = session.baseUrl
        agent.setHeaders({"X-API-Key": session.apiKey, "Authorization": "ApiKey " + session.apiKey})
    end if
    m.top.setHttpAgent(agent)
    renderInfo()
end sub

sub renderInfo()
    if not m.ready or not m.top.visible then return
    channel = m.top.channel
    if channel = invalid then return
    now = m.top.now
    m.channelName.text = channel.number + "  " + channel.name
    uri = ""
    if channel.logoId <> "" and m.base <> "" then uri = m.base + "/api/channels/logos/" + channel.logoId + "/cache/"
    if m.logo.uri <> uri then m.logo.uri = uri
    m.clock.text = uiTime(now)
    m.state.text = "LIVE"
    if m.top.playbackState = "buffering" then m.state.text = "BUFFERING"
    if m.top.playbackState = "paused" then m.state.text = "PAUSED"
    if m.top.playbackState = "preview" then m.state.text = "CHANNEL PREVIEW"
    m.hint.text = m.top.hint
    programs = []
    status = "loading"
    info = m.top.info
    if type(info) = "roAssociativeArray"
        if info.channelUuid = channel.uuid
            programs = info.programs
            status = info.status
        end if
    end if
    schedule = selectNowNext(programs, now)
    m.title.text = "No program information"
    m.description.text = "No guide information is available for this time."
    m.times.text = "ON AIR NOW"
    m.progressTrack.visible = schedule.current <> invalid
    m.progressFill.visible = schedule.current <> invalid
    m.progressText.text = ""
    m.progressFill.width = 0
    if status = "loading"
        m.title.text = "Loading program information..."
        m.description.text = "Playback continues while the guide loads."
    else if status = "unavailable"
        m.title.text = "Program information unavailable"
        m.description.text = "The guide could not be refreshed. Playback is unaffected."
    end if
    if schedule.current <> invalid
        current = schedule.current
        m.title.text = current.title
        m.times.text = uiTime(current.startsAt) + " - " + uiTime(current.endsAt) + "  |  ON AIR NOW"
        m.description.text = current.description
        if current.subtitle <> ""
            m.description.text = current.subtitle
            if current.description <> "" then m.description.text += " - " + current.description
        end if
        m.progressFill.width = 1070 * scheduleProgress(current, now)
        minutes = (current.endsAt - now + 59) \ 60
        m.progressText.text = "Schedule progress  |  " + minutes.toStr() + " min remaining in the broadcast"
    end if
    m.nextTitle.text = "No upcoming program information"
    m.nextTimes.text = ""
    if schedule.next <> invalid
        m.nextTitle.text = schedule.next.title
        prefix = ""
        if uiLocalDate(schedule.nextStartsAt) <> uiLocalDate(now) then prefix = uiLocalDate(schedule.nextStartsAt) + "  "
        m.nextTimes.text = prefix + uiTime(schedule.nextStartsAt) + " - " + uiTime(schedule.next.endsAt)
    else if status = "loading"
        m.nextTitle.text = "Loading upcoming programs..."
    end if
    m.dataStatus.text = ""
    if status = "loading" then m.dataStatus.text = "Updating guide..."
    if status = "stale" then m.dataStatus.text = "Refreshing cached guide..."
    if status = "unavailable" then m.dataStatus.text = "Guide refresh unavailable"
end sub
