function catchupEligible(program as dynamic, days as integer, now as integer) as boolean
    if type(program) <> "roAssociativeArray" or days <= 0 then return false
    if not mediaNumber(program.startsAt) or not mediaNumber(program.endsAt) then return false
    return program.startsAt >= now - days * 86400 and program.endsAt <= now and program.endsAt > program.startsAt and program.endsAt - program.startsAt <= 86400
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
