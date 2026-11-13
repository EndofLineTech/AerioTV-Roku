' Pure memory-only safety policy. Inputs contain credential digests, never raw
' credentials. The runtime broker must serialize permits/reports across Tasks.
function requestGateDefault() as object
    return {keys: {}, servers: {}, overflow: false}
end function

function requestGateProbeIdentityMatches(user as dynamic, expected as string, expectedUsername = "" as string) as boolean
    if type(user) <> "roAssociativeArray" then return false
    if not CreateObject("roRegex", "^[1-9][0-9]{0,15}$", "").isMatch(expected) then return false
    kind = type(user.id)
    if kind <> "Integer" and kind <> "roInt" and kind <> "roInteger" and kind <> "LongInteger" and kind <> "roLongInteger" then return false
    if user.id <= 0 or user.id > 9007199254740991& then return false
    if expectedUsername <> ""
        if type(user.username) <> "String" and type(user.username) <> "roString" then return false
        if lcase(user.username) <> lcase(expectedUsername) then return false
    end if
    return user.id = ParseJson(expected)
end function

function requestGateCopy(value as dynamic) as dynamic
    return ParseJson(FormatJson(value))
end function

function requestGateTicketUrl(url as string, probe as boolean) as string
    if requestGateServer(url) = "" then return ""
    origin = urlOrigin(url)
    if probe and CreateObject("roRegex", "/api/accounts/users/me/([?#].*)?$", "").isMatch(url)
        return origin + "/api/accounts/users/me/"
    end if
    return origin + "/"
end function

function requestGateServer(url as string) as string
    parts = CreateObject("roRegex", "^(https?)://(\[[^\]]+\]|[^:/?#@\s]+)(:([0-9]{1,5}))?([/?#].*)?$", "i").match(url)
    if parts.count() < 3 then return ""
    port = 80
    if lcase(parts[1]) = "https" then port = 443
    if parts.count() > 4
        if parts[4] <> "" then port = parts[4].toInt()
    end if
    if port < 1 or port > 65535 then return ""
    return lcase(parts[2]) + ":" + port.toStr()
end function

function requestGateKeyRejected(status as integer, body as string) as boolean
    return httpDispatcharrKeyRejected(status, body)
end function

function requestGateDigestValid(hash as string) as boolean
    return CreateObject("roRegex", "^[0-9a-fA-F]{64}$", "").isMatch(hash)
end function

function requestGateObserve(state as object, server as string, hash as string, status as integer, headers as dynamic, body as string, now as integer, verifiedProbe = false as boolean) as object
    result = requestGateCopy(state)
    hash = lcase(hash)
    for each name in result.servers.keys()
        if result.servers[name] <= now then result.servers.delete(name)
    end for
    if status = 429
        delay = httpRetryAfter(headers, now)
        if delay < 0 then delay = 60
        if delay > 120 then delay = 120
        until = now + delay
        if result.servers.doesExist(server)
            if result.servers[server] > until then until = result.servers[server]
        else if result.servers.count() >= 32
            ' Do not evict an active park to admit more requests. A bounded
            ' failure state is safer than unbounded storage or forgotten holds.
            result.overflow = true
            return result
        end if
        result.servers[server] = until
    end if
    if hash = "" or not requestGateDigestValid(hash) then return result
    if requestGateKeyRejected(status, body)
        if not result.keys.doesExist(hash)
            if result.keys.count() >= 64
                result.overflow = true
                return result
            end if
            result.keys[hash] = {rejectedat: now, nextprobe: now + 60, lastprobe: 0, probeindex: 0, prompted: false}
        end if
    else if verifiedProbe and status >= 200 and status < 300
        ' A normal in-flight 200 must never re-lift a later rejection. Only a
        ' broker-authorized /me probe can clear this memory-only key hold.
        result.keys.delete(hash)
    end if
    return result
end function

function requestGatePermit(state as object, server as string, hash as string, now as integer, probe as boolean) as object
    denied = {allowed: false, probe: false, reason: "", until: 0, state: state}
    if state.overflow = true
        denied.reason = "capacity"
        return denied
    end if
    if server = "" or (hash <> "" and not requestGateDigestValid(hash))
        denied.reason = "invalid-context"
        return denied
    end if
    if state.servers.doesExist(server)
        if state.servers[server] > now
            denied.reason = "parked"
            denied.until = state.servers[server]
            return denied
        end if
    end if
    hash = lcase(hash)
    if hash <> "" and state.keys.doesExist(hash)
        entry = state.keys[hash]
        denied.reason = "rejected-key"
        denied.until = entry.nextprobe
        if not probe or now < entry.nextprobe or now < entry.lastprobe + 60 then return denied
        nextState = requestGateCopy(state)
        entry = nextState.keys[hash]
        entry.lastprobe = now
        entry.probeindex++
        if now < entry.rejectedat + 300
            entry.nextprobe = entry.rejectedat + 300
        else if now < entry.rejectedat + 900
            entry.nextprobe = entry.rejectedat + 900
        else
            entry.nextprobe = now + 1800
        end if
        if entry.nextprobe < now + 60 then entry.nextprobe = now + 60
        return {allowed: true, probe: true, reason: "", until: 0, state: nextState}
    end if
    return {allowed: true, probe: false, reason: "", until: 0, state: state}
end function

function requestGatePrompt(state as object, hash as string) as object
    result = {show: false, state: state}
    hash = lcase(hash)
    if not state.keys.doesExist(hash) then return result
    if state.keys[hash].prompted then return result
    result.state = requestGateCopy(state)
    result.state.keys[hash].prompted = true
    result.show = true
    return result
end function
