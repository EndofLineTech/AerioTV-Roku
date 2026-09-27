function diagnosticText(value as string, apiKey as string) as string
    value = sanitizePlaybackDiagnostic(value, apiKey)
    value = CreateObject("roRegex", "(session_id|token|password|api_key)\s*[:=]\s*[^\s,;&]+", "i").replaceAll(value, "[credential]")
    value = CreateObject("roRegex", "bearer\s+[A-Za-z0-9._~-]+", "i").replaceAll(value, "[credential]")
    return left(value, 240)
end function

function guideMetadataDiagnosticText(value as dynamic) as string
    message = textValue(value.stage) + " " + textValue(value.source)
    category = textValue(value.category)
    if category = "response-too-large" or category = "memory-pressure" then message += " " + category
    bucket = textValue(value.sizeBucket)
    if bucket = "at-least-16-mb" then message += " " + bucket
    if bucket = "at-least-1-mib" or bucket = "at-least-2-mib" or bucket = "at-least-4-mib" or bucket = "at-least-8-mib" or bucket = "at-least-16-mib" or bucket = "at-least-32-mib" then message += " " + bucket
    return message.trim() + " " + textValue(value.message)
end function

function diagnosticEvents(raw as dynamic, now as integer, apiKey as string, scope = "" as string) as object
    result = []
    if type(raw) <> "roArray" then return result
    for each row in raw
        if type(row) = "roAssociativeArray"
            if textValue(row.scope) = scope and mediaNumber(row.time)
                if row.time >= now - 3600 and row.time <= now
                    stage = "app"
                    for each allowed in ["connect", "guide", "playback", "archive", "vod", "capabilities"]
                        if row.stage = allowed then stage = allowed
                    end for
                    code = 0
                    if mediaNumber(row.code) then code = int(row.code)
                    elapsed = 0
                    if mediaNumber(row.elapsedMs) then elapsed = int(row.elapsedMs)
                    result.push({time: int(row.time), stage: stage, code: code, elapsedMs: elapsed, message: diagnosticText(textValue(row.message), apiKey), scope: scope})
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

' The developer-console route keeps sanitized text but never prints account
' identity; the user-visible support code below exports no message text at all.
function diagnosticConsoleEvents(events as object) as object
    result = []
    for each row in events
        result.push({time: row.time, stage: row.stage, code: row.code, elapsedMs: row.elapsedMs, message: row.message})
    end for
    return result
end function

function diagnosticBase36(value as integer, width as integer) as string
    digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    result = ""
    for i = 1 to width
        result = mid(digits, (value mod 36) + 1, 1) + result
        value = value \ 36
    end for
    return result
end function

' D1 + event count + up to eight fixed-width, non-identifying facts + a
' three-character transcription checksum. No message, account or URL enters
' the encoded payload. Age/elapsed buckets deliberately lose precision.
function diagnosticSupportCode(raw as dynamic, now as integer, apiKey as string, scope as string) as string
    events = diagnosticEvents(raw, now, apiKey, scope)
    if events.count() = 0 then return ""
    first = events.count() - 8
    if first < 0 then first = 0
    count = events.count() - first
    payload = "D1" + count.toStr()
    stages = ["app", "connect", "guide", "playback", "archive", "vod", "capabilities"]
    for i = first to events.count() - 1
        row = events[i]
        stage = 0
        for j = 0 to stages.count() - 1
            if row.stage = stages[j] then stage = j
        end for
        code = row.code
        if code < -4095 then code = -4095
        if code > 4095 then code = 4095
        elapsed = row.elapsedMs \ 250
        if elapsed < 0 then elapsed = 0
        if elapsed > 35 then elapsed = 35
        age = (now - row.time) \ 60
        if age < 0 then age = 0
        if age > 60 then age = 60
        payload += diagnosticBase36(stage, 1) + diagnosticBase36(code + 4095, 3) + diagnosticBase36(elapsed, 1) + diagnosticBase36(age, 2)
    end for
    alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    checksum = 0
    for i = 1 to len(payload)
        checksum = (checksum * 31 + instr(1, alphabet, mid(payload, i, 1)) - 1) mod 46656
    end for
    payload += diagnosticBase36(checksum, 3)
    display = ""
    for i = 1 to len(payload) step 4
        if display <> "" then display += "-"
        display += mid(payload, i, 4)
    end for
    return display
end function
