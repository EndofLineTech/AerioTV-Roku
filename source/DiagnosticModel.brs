function diagnosticText(value as string, apiKey as string) as string
    value = sanitizePlaybackDiagnostic(value, apiKey)
    value = CreateObject("roRegex", "(session_id|token|password|api_key)\s*[:=]\s*[^\s,;&]+", "i").replaceAll(value, "[credential]")
    value = CreateObject("roRegex", "bearer\s+[A-Za-z0-9._~-]+", "i").replaceAll(value, "[credential]")
    return left(value, 240)
end function

function diagnosticEvents(raw as dynamic, now as integer, apiKey as string) as object
    result = []
    if type(raw) <> "roArray" then return result
    for each row in raw
        if type(row) = "roAssociativeArray"
            if mediaNumber(row.time)
                if row.time >= now - 3600 and row.time <= now
                    stage = "app"
                    for each allowed in ["connect", "guide", "playback", "archive", "vod", "capabilities"]
                        if row.stage = allowed then stage = allowed
                    end for
                    code = 0
                    if mediaNumber(row.code) then code = int(row.code)
                    elapsed = 0
                    if mediaNumber(row.elapsedMs) then elapsed = int(row.elapsedMs)
                    result.push({time: int(row.time), stage: stage, code: code, elapsedMs: elapsed, message: diagnosticText(textValue(row.message), apiKey)})
                end if
            end if
        end if
    end for
    while result.count() > 80
        result.shift()
    end while
    while preferenceByteBudget(FormatJson(result)) > 32768
        result.shift()
    end while
    return result
end function
