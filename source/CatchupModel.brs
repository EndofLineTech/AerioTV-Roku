function catchupEligible(program as dynamic, days as integer, now as integer) as boolean
    if type(program) <> "roAssociativeArray" or days <= 0 then return false
    if not mediaNumber(program.startsAt) or not mediaNumber(program.endsAt) then return false
    return program.startsAt >= now - days * 86400 and program.endsAt <= now and program.endsAt > program.startsAt and program.endsAt - program.startsAt <= 86400
end function

' Archive re-open seeks use minute-sized provider windows, not native TS seek.
function catchupSeekPlan(program as dynamic, requested as dynamic) as dynamic
    if type(program) <> "roAssociativeArray" or not mediaNumber(requested) then return invalid
    if not mediaNumber(program.startsAt) or not mediaNumber(program.endsAt) then return invalid
    duration = program.endsAt - program.startsAt
    if duration <= 0 or duration > 86400 then return invalid
    target = int(requested / 60) * 60
    if target < 0 then target = 0
    maximum = int((duration - 1) / 60) * 60
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
