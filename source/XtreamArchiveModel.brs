' XC archive requests use completed, provider-advertised history only.
' Dispatcharr 0.31 advertises UTC EPG timestamps and accepts UTC whole-minute
' programme starts in /timeshift; fail closed for other server timezones.
function xtreamArchiveFacts(channels as dynamic, timezone as string) as object
    result = {}
    if timezone <> "UTC" or type(channels) <> "roArray" then return result
    for each channel in channels
        if type(channel) = "roAssociativeArray"
            days = channel.archiveDays
            if mediaNumber(days)
                if days >= 1 and days <= 30 and textValue(channel.id) <> "" then result[channel.id] = {catchupDays: int(days)}
            end if
        end if
    end for
    return result
end function

function xtreamArchiveUrl(base as string, username as string, password as string, timezone as string, channel as dynamic, program as dynamic, now as integer) as string
    base = normalizeBaseUrl(base)
    if base = "" or timezone <> "UTC" or not xtreamCredentialsValid(username, password) then return ""
    if type(channel) <> "roAssociativeArray" then return ""
    id = textValue(channel.streamId)
    if not CreateObject("roRegex", "^[1-9][0-9]{0,9}$", "").isMatch(id) then return ""
    days = channel.archiveDays
    if not mediaNumber(days) or days < 1 or days > 30 then return ""
    if not catchupEligible(program, int(days), now) then return ""
    duration = program.endsAt - program.startsAt
    minutes = int((duration + 59) / 60)
    if minutes < 1 or minutes > 1440 then return ""
    stamp = CreateObject("roDateTime")
    stamp.fromSeconds(program.startsAt)
    utc = stamp.toISOString()
    if len(utc) < 16 then return ""
    start = left(utc, 10) + ":" + mid(utc, 12, 2) + "-" + mid(utc, 15, 2)
    return base + "/timeshift/" + xtreamEscape(username) + "/" + xtreamEscape(password) + "/" + minutes.toStr() + "/" + start + "/" + id + ".ts"
end function
