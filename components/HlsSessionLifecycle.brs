' Only Dispatcharr live HLS owns this per-client session. Direct feeds, DVR,
' catch-up and the TS transport do not use this control endpoint.
sub cancelHlsMint()
    m.hlsMintRetry = invalid
    if m.hlsMintTask = invalid then return
    m.hlsMintTask.cancelRequested = true
    m.hlsMintTask = invalid
    m.hlsMintClock = invalid
    m.hlsMintReplacesReader = false
end sub

sub closeOwnedHlsSession()
    session = m.hlsSession
    m.hlsSession = invalid
    if session = invalid then return
    queueHlsDisconnect(session)
end sub

sub queueHlsDisconnect(session as object)
    task = createHlsSessionTask()
    task.operation = "close"
    task.baseUrl = session.baseUrl
    task.apiKey = session.apiKey
    task.token = session.token
    task.observeField("result", "onHlsSessionClosed")
    m.hlsStopTasks.push(task)
    task.control = "RUN"
end sub

function createHlsSessionTask() as object
    if m.hlsSessionTaskFactory <> invalid then return m.hlsSessionTaskFactory()
    return CreateObject("roSGNode", "HlsSessionTask")
end function

sub onHlsSessionClosed(event as object)
    for i = 0 to m.hlsStopTasks.count() - 1
        task = m.hlsStopTasks[i]
        if task.isSameNode(event.getRoSGNode())
            task.unobserveField("result")
            print "[hls-session] disconnect status="; event.getData().status
            m.hlsStopTasks.delete(i)
            return
        end if
    end for
end sub

sub beginOwnedHlsPlayback(content as object, replacesReader = false as boolean)
    mintOwnedHlsPlayback(content, m.baseUrl, m.apiKey, false, true, replacesReader)
end sub

sub mintOwnedHlsPlayback(content as object, baseUrl as string, apiKey as string, recovering as boolean, waitForSources as boolean, replacesReader as boolean)
    task = createHlsSessionTask()
    tagTaskForCurrentUser(task)
    task.operation = "open"
    task.baseUrl = baseUrl
    task.apiKey = apiKey
    task.entryUrl = content.url
    task.observeField("result", "onHlsSessionOpened")
    m.hlsMintTask = task
    m.hlsMintReplacesReader = replacesReader
    m.hlsMintClock = CreateObject("roTimespan")
    m.hlsMintClock.mark()
    m.hlsPendingMints.push({task: task, baseUrl: baseUrl, apiKey: apiKey, content: content, entryUrl: content.url, recovering: recovering, waitForSources: waitForSources, replacesReader: replacesReader, busyRetries: 0})
    task.control = "RUN"
end sub

' Replace this playback attempt, not just the Video reader. A retry must get
' its own capability so that the previous attempt can be closed independently.
sub retryOwnedHlsPlayback(replacement as object, waitForSources as boolean)
    owner = m.hlsSession
    closeOwnedHlsSession()
    replacement.url = owner.entryUrl
    m.video.content = replacement
    mintOwnedHlsPlayback(replacement, owner.baseUrl, owner.apiKey, true, waitForSources, true)
end sub

sub onHlsSessionOpened(event as object)
    for i = 0 to m.hlsPendingMints.count() - 1
        pending = m.hlsPendingMints[i]
        if pending.task.isSameNode(event.getRoSGNode())
            pending.task.unobserveField("result")
            m.hlsPendingMints.delete(i)
            result = event.getData()
            current = m.hlsMintTask <> invalid and m.playingChannel <> invalid
            current = current and taskUserSessionCurrent(pending.task)
            if current and m.video.content <> invalid then current = m.hlsMintTask.isSameNode(pending.task) and m.video.content.isSameNode(pending.content) else current = false
            if not current or pending.task.cancelRequested
                if result.ok = true
                    queueHlsDisconnect({token: result.token, baseUrl: pending.baseUrl, apiKey: pending.apiKey})
                end if
                return
            end if
            m.hlsMintTask = invalid
            m.hlsMintClock = invalid
            m.hlsMintReplacesReader = false
            if result.ok <> true
                if scheduleBusyHlsMintRetry(pending, result) then return
                detail = "Dispatcharr HLS session could not be opened (HTTP " + result.status.toStr() + ")."
                if result.status >= 200 and result.status < 300 then detail = "Dispatcharr did not provide a valid HLS session."
                failLivePlayback(-1, detail)
                return
            end if
            m.hlsSession = {token: result.token, url: result.url, baseUrl: pending.baseUrl, apiKey: pending.apiKey, entryUrl: pending.entryUrl, userSession: currentUserSessionId()}
            pending.content.url = result.url
            if not requestGateTrackRenderer(m.video, result.url, pending.apiKey)
                stopPlayback()
                return
            end if
            beginStartupWatch(pending.content, pending.recovering = true, pending.waitForSources = true)
            m.startupWatch.guardOwnedHlsFinish = pending.replacesReader = true
            m.video.control = "play"
            print "[hls-session] owned session opened"
            return
        end if
    end for
end sub

' Honor only an explicit Retry-After on a busy (502/503) mint. Without one,
' the existing manual Retry stays authoritative: no delay is inferred. A 429
' is owned by the request gate, which parks the whole server instead.
function scheduleBusyHlsMintRetry(pending as object, result as object) as boolean
    status = result.status
    if status <> 502 and status <> 503 then return false
    if pending.busyRetries = invalid or pending.busyRetries >= 2 then return false
    delay = -1
    if type(result.retryAfter) = "roInt" or type(result.retryAfter) = "roInteger" or type(result.retryAfter) = "Integer" then delay = result.retryAfter
    if delay < 0 or delay > 15 then return false
    if delay = 0 then delay = 1
    clock = CreateObject("roTimespan")
    clock.mark()
    m.hlsMintRetry = {due: delay * 1000, clock: clock, pending: pending, attempt: pending.busyRetries + 1}
    unit = " seconds"
    if delay = 1 then unit = " second"
    showNotice("Dispatcharr is busy (HTTP " + status.toStr() + "). Retrying in " + delay.toStr() + unit + "...")
    print "[hls-session] busy mint retry "; m.hlsMintRetry.attempt; "/2 status="; status; " after="; delay
    return true
end function

sub checkBusyHlsMintRetry()
    retry = m.hlsMintRetry
    pending = retry.pending
    current = m.playingChannel <> invalid and m.video.content <> invalid and m.hlsMintTask = invalid
    if current then current = m.video.content.isSameNode(pending.content) and taskUserSessionCurrent(pending.task)
    if not current
        m.hlsMintRetry = invalid
        return
    end if
    if retry.clock.totalMilliseconds() < retry.due then return
    m.hlsMintRetry = invalid
    mintOwnedHlsPlayback(pending.content, pending.baseUrl, pending.apiKey, pending.recovering = true, pending.waitForSources = true, pending.replacesReader = true)
    m.hlsPendingMints[m.hlsPendingMints.count() - 1].busyRetries = retry.attempt
end sub

sub checkHlsMint()
    if m.hlsMintRetry <> invalid then checkBusyHlsMintRetry()
    if m.hlsMintTask = invalid or m.hlsMintClock = invalid then return
    if m.hlsMintClock.totalMilliseconds() < 30000 then return
    cancelHlsMint()
    failLivePlayback(-2, "Dispatcharr HLS session setup timed out.")
end sub
