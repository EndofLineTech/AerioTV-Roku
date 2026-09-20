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
