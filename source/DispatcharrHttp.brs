' Task-thread-only helpers. Never include this script in a rendering component.
function requestPages(path as string) as dynamic
    url = m.base + path
    rows = []
    visited = {}
    while url <> ""
        if m.progressLabel <> invalid
            m.top.progress = m.progressLabel + " - page " + (visited.count() + 1).toStr()
        end if
        if visited.doesExist(url) or visited.count() >= 100
            m.failure = "Pagination repeated or exceeded 100 pages."
            return invalid
        end if
        visited[url] = true
        payload = requestJson(url)
        page = apiRows(payload)
        if page = invalid
            if m.failure = "" then m.failure = "The server did not return a JSON list."
            return invalid
        end if
        rows.append(page)
        url = ""
        if type(payload) = "roAssociativeArray"
            nextPage = textValue(payload.next)
            if nextPage <> ""
                url = trustedPageUrl(m.base, nextPage)
                if url = ""
                    m.failure = "The server returned an unexpected pagination URL."
                    return invalid
                end if
            end if
        end if
    end while
    return rows
end function

function requestJson(url as string, body = invalid as dynamic, bearer = "" as string) as dynamic
    m.failure = ""
    timeout = 20000
    if m.timeout <> invalid then timeout = m.timeout
    if m.deadlineMs <> invalid
        remaining = m.deadlineMs - m.clock.totalMilliseconds()
        if remaining <= 0
            m.failure = "Connection time budget exhausted. Retry the connection."
            return invalid
        end if
        if remaining < timeout then timeout = remaining
    end if
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(url)
    transfer.addHeader("Accept", "application/json")
    transfer.addHeader("User-Agent", "AerioTV-Roku/0.3")
    transfer.enableEncodings(true)
    if bearer <> ""
        transfer.addHeader("Authorization", "Bearer " + bearer)
    else if m.key <> ""
        transfer.addHeader("X-API-Key", m.key)
        transfer.addHeader("Authorization", "ApiKey " + m.key)
    end if
    if body = invalid
        started = transfer.asyncGetToString()
    else
        transfer.addHeader("Content-Type", "application/json")
        started = transfer.asyncPostFromString(FormatJson(body))
    end if
    if not started
        m.failure = "Could not start the request."
        return invalid
    end if
    event = wait(timeout, port)
    if event = invalid
        transfer.asyncCancel()
        m.failure = "Request timed out. Check the server address and network."
        return invalid
    end if
    if type(event) <> "roUrlEvent"
        transfer.asyncCancel()
        m.failure = "Unexpected network event."
        return invalid
    end if
    status = event.getResponseCode()
    if status < 200 or status >= 300
        m.failure = "HTTP " + status.toStr() + "."
        if status < 0 then m.failure = "Could not reach the server. Check its address, TLS certificate and network."
        if status = 401 or status = 403 then m.failure = "Credentials rejected or account lacks permission."
        if status = 429 then m.failure = "Too many requests. Wait a minute before retrying."
        if status >= 300 and status < 400 then m.failure = "The API returned a redirect. Use the final server URL."
        return invalid
    end if
    json = event.getString()
    ' Bound parsing/normalization, not transfer memory: the native transfer has
    ' already buffered this response. Measure peak memory on the target device.
    if len(json) > 16000000
        m.failure = "The server response exceeds this build's 16 MB parsing limit."
        return invalid
    end if
    value = ParseJson(json)
    if value = invalid then m.failure = "The server response was not valid JSON."
    return value
end function
