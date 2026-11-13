function httpRetryAfter(headers as dynamic, now as integer) as integer
    if type(headers) <> "roAssociativeArray" then return -1
    value = ""
    for each name in headers
        if lcase(name) = "retry-after" then value = textValue(headers[name]).trim()
    end for
    if CreateObject("roRegex", "^[0-9]+$", "").isMatch(value)
        value = CreateObject("roRegex", "^0+", "").replace(value, "")
        if value = "" then return 0
        if len(value) > 8 then return 99999999
        return value.toInt()
    end if
    parts = CreateObject("roRegex", "^[A-Za-z]{3}, ([0-9]{2}) ([A-Za-z]{3}) ([0-9]{4}) ([0-9]{2}:[0-9]{2}:[0-9]{2}) GMT$", "").match(value)
    if parts.count() <> 5 then return -1
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    month = 0
    for i = 0 to 11
        if months[i] = parts[2] then month = i + 1
    end for
    if month = 0 then return -1
    iso = parts[3] + "-" + right("0" + month.toStr(), 2) + "-" + parts[1] + "T" + parts[4] + "Z"
    date = CreateObject("roDateTime")
    date.fromISO8601String(iso)
    if left(date.toISOString(), 19) <> left(iso, 19) then return -1
    delay = date.asSeconds() - now
    if delay < 0 then delay = 0
    return delay
end function

function httpFailure(status as integer, headers as dynamic, now as integer, error = "" as string, responseBytes = invalid as dynamic, maxBytes = invalid as dynamic) as object
    result = {status: status, category: "server", retryable: false, retryAfter: httpRetryAfter(headers, now), sizeBucket: "", message: "Server returned HTTP " + status.toStr() + "."}
    if error = "rejected-key" or error = "parked" or error = "request-held" or error = "gate-unavailable" or error = "gate-busy" or error = "capacity" or error = "invalid-context" or error = "stale-session"
        result.category = "request-held"
        result.message = "Requests are paused for this account or server. Wait before trying again."
    else if error = "cancelled"
        result.category = "cancelled"
        result.message = "Request cancelled."
    else if error = "timeout"
        result.category = "timeout"
        result.message = "Request timed out. Try again when the server is reachable."
    else if error = "too-large"
        result.category = "response-too-large"
        result.sizeBucket = httpResponseSizeBucket(responseBytes, maxBytes)
        result.message = "Metadata response exceeds this device's safe loading budget."
    else if error = "memory"
        result.category = "memory-pressure"
        result.message = "Device memory pressure stopped the metadata download."
    else if error = "invalid-response"
        result.category = "invalid-response"
        result.message = "The server did not return valid JSON."
    else if status < 0 or error = "network"
        result.category = "network"
        result.message = "Could not reach the server. Check its address, TLS certificate and network."
    else if status = 401
        result.category = "authentication"
        result.message = "Credentials rejected. Sign in again."
    else if status = 403
        result.category = "permission"
        result.message = "This account does not have permission for that operation."
    else if status = 409
        result.category = "conflict"
        result.message = "The server refused the request because of a conflict or resource limit."
    else if status = 404
        result.category = "not-found"
        result.message = "The requested item was not found or is no longer available."
    else if status = 410
        result.category = "expired"
        result.message = "The requested item or playback session has expired."
    else if status = 429
        result.category = "rate-limit"
        result.retryable = true
        if result.retryAfter < 0 then result.retryAfter = 60
        if result.retryAfter > 120 then result.retryAfter = 120
        result.message = "The server is limiting requests. Wait before trying again."
    else if status = 502 or status = 503 or status = 504 or status = 408
        result.category = "temporary-server"
        result.retryable = true
        result.message = "The server is temporarily unavailable."
    else if status >= 300 and status < 400
        result.category = "redirect"
        result.message = "The API returned a redirect. Use the final server URL."
    end if
    if result.retryAfter > 0 then result.message += " Retry after " + result.retryAfter.toStr() + " seconds."
    return result
end function

function httpAccountRejected(failure as dynamic) as boolean
    if type(failure) <> "roAssociativeArray" then return false
    return failure.status = 401 and failure.keyRejected = true
end function

function httpDispatcharrKeyRejected(status as integer, body as string) as boolean
    if status <> 401 or len(body) > 4096 then return false
    if not CreateObject("roRegex", "^\s*\{", "").isMatch(body) then return false
    parsed = ParseJson(body)
    if type(parsed) <> "roAssociativeArray" then return false
    if type(parsed.detail) <> "String" and type(parsed.detail) <> "roString" then return false
    detail = lcase(parsed.detail.trim())
    return detail = "invalid api key" or detail = "user inactive"
end function

function httpResponseSizeBucket(responseBytes as dynamic, maxBytes as dynamic) as string
    if type(responseBytes) <> "Integer" and type(responseBytes) <> "roInt" then return ""
    if type(maxBytes) <> "Integer" and type(maxBytes) <> "roInt" then return ""
    if responseBytes <= maxBytes or maxBytes < 1048576 then return ""
    if maxBytes = 16000000 then return "at-least-16-mb"
    return "at-least-" + int(maxBytes / 1048576).toStr() + "-mib"
end function
function taskRequestIdentity(override as dynamic, globalFields as dynamic) as object
    agent = ""
    referer = ""
    if type(override) = "roAssociativeArray"
        agent = textValue(override.userAgent)
        referer = textValue(override.referer)
    else if type(globalFields) = "roAssociativeArray" or type(globalFields) = "roSGNode"
        agent = textValue(globalFields.httpUserAgent)
        referer = textValue(globalFields.httpReferer)
    end if
    return {userAgent: dispatcharrUserAgent(agent), referer: referer}
end function
