function catchupEligible(program as dynamic, days as integer, now as integer) as boolean
    if type(program) <> "roAssociativeArray" or days <= 0 then return false
    if not mediaNumber(program.startsAt) or not mediaNumber(program.endsAt) then return false
    return program.startsAt >= now - days * 86400 and program.endsAt <= now and program.endsAt > program.startsAt and program.endsAt - program.startsAt <= 86400
end function

function catchupBookmarkExpiry(program as object, days as integer, shiftMinutes as integer, minuteStart as boolean) as integer
    start = program.startsAt + catchupOffsetMinutes(shiftMinutes) * 60
    if minuteStart then start -= start mod 60
    if start > program.startsAt then start = program.startsAt
    ' The last eligible second is inclusive in catchupRequestWindow.
    return (start + days * 86400 + 1) \ 1
end function

function catchupBookmarkMatches(row as object, channelUuid as string, program as object) as boolean
    return row.channelUuid = channelUuid and row.startsAt = program.startsAt and row.endsAt = program.endsAt
end function

function catchupBookmarks(raw as dynamic, now as integer) as object
    rows = []
    if type(raw) <> "roArray" then return rows
    for each row in raw
        if type(row) = "roAssociativeArray"
            uuid = textValue(row.channelUuid)
            if uuid <> "" and len(uuid) <= 128 and mediaNumber(row.position) and mediaNumber(row.expiresAt)
                if row.expiresAt > now and catchupEligible(row, 30, now)
                    if row.position >= 60 and row.position < row.endsAt - row.startsAt
                        rows.push({channelUuid: uuid, startsAt: row.startsAt, endsAt: row.endsAt, position: int(row.position), expiresAt: row.expiresAt})
                        if rows.count() >= 20 then exit for
                    end if
                end if
            end if
        end if
    end for
    return rows
end function

function catchupFindBookmark(raw as dynamic, channelUuid as string, program as object, now as integer) as dynamic
    for each row in catchupBookmarks(raw, now)
        if catchupBookmarkMatches(row, channelUuid, program) then return row
    end for
    return invalid
end function

function catchupBookmarkUpdate(raw as dynamic, channelUuid as string, program as object, position as integer, expiresAt as integer, now as integer) as object
    rows = [{channelUuid: channelUuid, startsAt: program.startsAt, endsAt: program.endsAt, position: position, expiresAt: expiresAt}]
    for each row in catchupBookmarks(raw, now)
        if not catchupBookmarkMatches(row, channelUuid, program) then rows.push(row)
    end for
    return catchupBookmarks(rows, now)
end function

function catchupBookmarkReconcile(raw as dynamic, channels as object, permission as string, facts as dynamic, factsAvailable as boolean, now as integer) as object
    rows = catchupBookmarks(raw, now)
    if rows.count() = 0 or permission = "denied" then return []
    ids = {}
    ids.setModeCaseSensitive()
    for each channel in channels
        ids[textValue(channel.uuid)] = textValue(channel.id)
    end for
    kept = []
    for each row in rows
        if ids.doesExist(row.channelUuid)
            retain = true
            if permission = "allowed" and factsAvailable
                days = catchupChannelDays(permission, facts, ids[row.channelUuid])
                retain = catchupEligible(row, days, now)
            end if
            if retain then kept.push(row)
        end if
    end for
    return kept
end function

function catchupBookmarkUnavailableStatus(status as dynamic) as boolean
    return status = 401 or status = 403 or status = 404 or status = 410
end function

function catchupBookmarkUnavailableMediaError(detail as string) as boolean
    return CreateObject("roRegex", "(http[^0-9]{0,24}|response code[^0-9]{0,16})(401|403|404|410)([^0-9]|$)", "i").isMatch(detail)
end function

function catchupBookmarkPlan(raw as dynamic, channelUuid as string, program as object, action as string, now as integer) as dynamic
    if action = "resume"
        row = catchupFindBookmark(raw, channelUuid, program, now)
        if row = invalid then return invalid
        return catchupSeekPlan(program, row.position, now)
    end if
    return {program: program, offset: 0}
end function

function catchupOffsetSupported(provider as string) as boolean
    return provider = "dispatcharr" or provider = "xtream"
end function

' Pinned AerioTV CatchupSupport clamps the stored playlist value at use time.
function catchupOffsetMinutes(value as dynamic) as integer
    if GetInterface(value, "ifInt") = invalid then return 0
    if value < -180 then return -180
    if value > 180 then return 180
    return value
end function

function catchupOffsetInput(value as string) as dynamic
    value = value.trim()
    if not CreateObject("roRegex", "^[+-]?[0-9]{1,3}$", "").isMatch(value) then return invalid
    minutes = value.toInt()
    if minutes <> catchupOffsetMinutes(minutes) then return invalid
    return minutes
end function

' Input is always a guide-time window (possibly shortened for a seek).
' Recheck the translated completed window and exact wire interval against
' Roku's archive bounds. Xtream serializes a whole UTC minute; Dispatcharr
' sessions serialize seconds. Both send duration rounded up to minutes.
' Never clamp the translated start: that could select a different programme.
function catchupRequestWindow(program as dynamic, days as integer, now as integer, shiftMinutes as dynamic, minuteStart = false as boolean) as dynamic
    if not catchupEligible(program, days, now) then return invalid
    shift = catchupOffsetMinutes(shiftMinutes) * 60
    start = program.startsAt + shift
    if start < 0 or program.endsAt + shift > now then return invalid
    if minuteStart then start -= start mod 60
    duration = int((program.endsAt - program.startsAt + 59) / 60)
    if start < now - days * 86400 or start + duration * 60 > now then return invalid
    return {start: start, duration: duration}
end function

function catchupRestartPlan(program as dynamic, days as integer, now as integer) as dynamic
    if type(program) <> "roAssociativeArray" or days <= 0 then return invalid
    if not mediaNumber(program.startsAt) or not mediaNumber(program.endsAt) then return invalid
    if program.startsAt >= now or program.endsAt <= now then return invalid
    if program.endsAt - program.startsAt > 86400 then return invalid
    window = {id: textValue(program.id), title: textValue(program.title), startsAt: program.startsAt, endsAt: now}
    if not catchupEligible(window, days, now) then return invalid
    requested = {id: window.id, title: window.title, startsAt: program.startsAt, endsAt: program.endsAt}
    return {program: requested, availableUntil: now}
end function

function catchupChannelDays(permission as string, facts as dynamic, channelId as string) as integer
    if permission <> "allowed" or type(facts) <> "roAssociativeArray" then return 0
    if not facts.doesExist(channelId) then return 0
    fact = facts[channelId]
    if type(fact) <> "roAssociativeArray" then return 0
    if not mediaNumber(fact.catchupDays) then return 0
    if fact.catchupDays < 1 then return 0
    return int(fact.catchupDays)
end function

function catchupRetentionLabel(days as integer) as string
    if days <= 0 then return ""
    if days = 1 then return "Catch-up: 1 day"
    return "Catch-up: " + days.toStr() + " days"
end function

function catchupLiveReturnAllowed(context as dynamic, account as string, channel as dynamic) as boolean
    if type(context) <> "roAssociativeArray" or type(channel) <> "roAssociativeArray" then return false
    if type(context.channel) <> "roAssociativeArray" then return false
    return context.account = account and textValue(context.channel.uuid) <> "" and context.channel.uuid = channel.uuid
end function

' Broadcast time is an estimate from the requested provider start + native media
' progress. Guide length/seek window are not native duration or retained bytes.
function catchupPlaybackClock(program as dynamic, offset as dynamic, position as dynamic, now as integer) as dynamic
    if not mediaNumber(offset) or not mediaNumber(position) then return invalid
    if offset < 0 or position < 0 then return invalid
    plan = catchupSeekPlan(program, 86400, now)
    if plan = invalid then return invalid
    duration = program.endsAt - program.startsAt
    if offset >= duration then return invalid
    elapsed = int(offset + position)
    broadcast = program.startsAt + elapsed
    behind = now - broadcast
    if behind < 0 then behind = 0
    fraction = elapsed / duration
    if fraction > 1 then fraction = 1
    return {position: elapsed, duration: duration, broadcast: broadcast, behindLive: behind, fraction: fraction, seekEnd: plan.offset, pastEnd: elapsed > duration}
end function

function catchupElapsedText(seconds as integer) as string
    if seconds < 0 then seconds = 0
    minutes = seconds \ 60
    tail = (seconds mod 60).toStr()
    if len(tail) < 2 then tail = "0" + tail
    if minutes < 60 then return minutes.toStr() + ":" + tail
    hours = minutes \ 60
    middle = (minutes mod 60).toStr()
    if len(middle) < 2 then middle = "0" + middle
    return hours.toStr() + ":" + middle + ":" + tail
end function

' Archive re-open seeks use minute-sized provider windows, not native TS seek.
function catchupSeekPlan(program as dynamic, requested as dynamic, availableUntil = 0 as integer) as dynamic
    if type(program) <> "roAssociativeArray" or not mediaNumber(requested) then return invalid
    if not mediaNumber(program.startsAt) or not mediaNumber(program.endsAt) then return invalid
    duration = program.endsAt - program.startsAt
    if duration <= 0 or duration > 86400 then return invalid
    target = int(requested / 60) * 60
    if target < 0 then target = 0
    available = duration
    if availableUntil > 0 and availableUntil < program.endsAt then available = availableUntil - program.startsAt
    if available <= 0 then return invalid
    maximum = int((available - 1) / 60) * 60
    if target > maximum then target = maximum
    shifted = {id: textValue(program.id), title: textValue(program.title), startsAt: program.startsAt + target, endsAt: program.endsAt}
    return {offset: target, program: shifted, remaining: duration - target}
end function

function catchupSessionUrl(base as string, uuid as string, response as dynamic, now as integer) as string
    base = normalizeBaseUrl(base)
    if base = "" then return ""
    if type(response) <> "roAssociativeArray" then return ""
    id = textValue(response.session_id)
    if not CreateObject("roRegex", "^[A-Za-z0-9_-]{16,128}$", "").isMatch(id) then return ""
    if textValue(response.channel_uuid) <> uuid then return ""
    if not mediaNumber(response.expires_at) then return ""
    if response.expires_at <= now then return ""
    expected = "/proxy/catchup/" + uuid + "?session_id=" + id
    if textValue(response.playback_url) <> expected then return ""
    return base + expected
end function

' Requestable provider history, never a claim of locally buffered media.
' Integer modulo preserves epoch precision; providers use whole UTC minutes.
function rewindBounds(tunedAt as dynamic, now as integer) as dynamic
    if not mediaNumber(tunedAt) then return invalid
    if tunedAt <= 0 or tunedAt >= now then return invalid
    first = now - 3600
    if tunedAt > first then first = tunedAt
    remainder = first mod 60
    if remainder <> 0 then first += 60 - remainder
    last = now - 1
    last -= last mod 60
    if first > last then return invalid
    return {start: first, finish: last}
end function

function rewindSeekPlan(origin as dynamic, tunedAt as dynamic, requested as dynamic, now as integer) as dynamic
    if type(origin) <> "roAssociativeArray" or not mediaNumber(requested) then return invalid
    if not mediaNumber(origin.startsAt) then return invalid
    bounds = rewindBounds(tunedAt, now)
    if bounds = invalid then return invalid
    target = origin.startsAt + int(requested)
    target -= target mod 60
    if target < bounds.start then target = bounds.start
    if target > bounds.finish then target = bounds.finish
    window = {id: textValue(origin.id), title: textValue(origin.title), startsAt: target, endsAt: now}
    return {offset: target - origin.startsAt, program: window, remaining: now - target}
end function

function rewindPlaybackClock(origin as dynamic, tunedAt as dynamic, offset as dynamic, position as dynamic, now as integer) as dynamic
    if type(origin) <> "roAssociativeArray" or not mediaNumber(position) or not mediaNumber(offset) then return invalid
    if not mediaNumber(origin.startsAt) then return invalid
    if position < 0 or offset < 0 then return invalid
    bounds = rewindBounds(tunedAt, now)
    if bounds = invalid then return invalid
    broadcast = origin.startsAt + int(offset + position)
    behind = now - broadcast
    if behind < 0 then behind = 0
    fraction = (broadcast - bounds.start) / (now - bounds.start)
    if fraction < 0 then fraction = 0
    if fraction > 1 then fraction = 1
    return {broadcast: broadcast, behindLive: behind, start: bounds.start, finish: bounds.finish, fraction: fraction, outside: broadcast < bounds.start}
end function
