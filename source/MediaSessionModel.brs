' Schedule UTC and native media seconds are separate clocks. Duration alone is
' not evidence of seek support, especially for finite MPEG-TS archives.
function mediaSession(account as string, identity as string, mode as string, item as string, now as integer) as object
    known = mode = "live" or mode = "delayed" or mode = "catchup" or mode = "vod"
    if not known then mode = "unknown"
    return {account: account, identity: identity, mode: mode, item: item, state: "opening", openedAt: now, programStart: invalid, position: invalid, duration: invalid, bounds: invalid, seek: "unknown", liveEdge: "unknown"}
end function

function mediaPlaybackHeaders(apiKey as string) as object
    ' The VOD proxy forwards Authorization to its upstream. Authenticate using
    ' the Dispatcharr-specific header only; never send that extra credential.
    return ["X-API-Key: " + apiKey]
end function

function mediaNumber(value as dynamic) as boolean
    return GetInterface(value, "ifInt") <> invalid or GetInterface(value, "ifFloat") <> invalid or GetInterface(value, "ifDouble") <> invalid
end function

sub mediaObserve(session as object, state as string, position as dynamic, duration as dynamic, bounds as dynamic)
    if session.state = "stopped" then return
    session.state = state
    if mediaNumber(position)
        if position >= 0 then session.position = position
    end if
    if mediaNumber(duration)
        if duration > 0 then session.duration = duration
    end if
    session.bounds = invalid
    session.seek = "unknown"
    session.liveEdge = "unknown"
    if type(bounds) <> "roAssociativeArray" then return
    if not mediaNumber(bounds.start) or not mediaNumber(bounds.finish) then return
    if bounds.start < 0 or bounds.finish <= bounds.start then return
    session.bounds = {start: bounds.start, finish: bounds.finish}
    session.seek = "supported"
    if session.mode = "live" or session.mode = "delayed"
        if mediaNumber(session.position)
            session.liveEdge = "behind"
            if session.position >= bounds.finish - 2 then session.liveEdge = "at-edge"
        end if
    end if
end sub

function mediaSeekTarget(session as object, requested as dynamic) as dynamic
    if session.seek <> "supported" or session.state = "stopped" or not mediaNumber(requested) then return invalid
    if requested < session.bounds.start then return session.bounds.start
    if requested > session.bounds.finish then return session.bounds.finish
    return requested
end function

function mediaSessionMatches(session as dynamic, account as string, identity as string) as boolean
    if type(session) <> "roAssociativeArray" then return false
    return session.account = account and session.identity = identity and session.state <> "stopped"
end function

sub mediaEnd(session as object)
    session.state = "stopped"
    session.position = invalid
    session.bounds = invalid
    session.seek = "unavailable"
    session.liveEdge = "unknown"
end sub

' Relative TS clocks have no broadcast UTC. Anchor once at playback start and
' label the result estimated; abandon it on overflow/discontinuity, never guess.
function mediaLiveClock(session as dynamic, state as string, position as dynamic, info as dynamic, clip as dynamic, now as integer, overflow as boolean) as object
    unknown = {known: false}
    if type(session) <> "roAssociativeArray" then return unknown
    if session.state = "stopped" then return unknown
    if state <> "playing" and state <> "paused" then return unknown
    if not mediaNumber(position) then return unknown
    if position < 0 then return unknown
    if session.clockClip <> clip or session.clockAnchor = invalid
        session.clockClip = clip
        session.clockAnchor = now
        session.clockAnchorPosition = position
        session.clockUncertain = false
        session.clockLastPosition = position
        session.clockObservedAt = now
    end if
    if overflow then session.clockUncertain = true
    delta = position - session.clockLastPosition
    if delta < -2 or delta > now - session.clockObservedAt + 15 then session.clockUncertain = true
    session.clockLastPosition = position
    session.clockObservedAt = now
    if session.clockUncertain then return unknown
    ' Int() accepts a single-precision float on hardware: converting an absolute
    ' epoch through it loses seconds. Convert only the small elapsed delta.
    epoch = session.clockAnchor + int(position - session.clockAnchorPosition)
    estimated = true
    if type(info) = "roAssociativeArray"
        if info.epoch = 1
            epoch = position
            estimated = false
        end if
    end if
    if epoch > now + 5 then return unknown
    if estimated and epoch > now
        ' Some readers report zero at playing, then their first real timestamp.
        ' Calibrate that small startup lead rather than dating paused media ahead.
        session.clockAnchor -= epoch - now
        epoch = now
    end if
    delay = int(now - epoch)
    if delay < 0 then delay = 0
    delayed = delay > 3
    if delayed then session.mode = "delayed" else session.mode = "live"
    return {known: true, epoch: epoch, delay: delay, delayed: delayed, estimated: estimated}
end function
