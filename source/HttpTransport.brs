' Task-thread transport. GET bodies stage in tmp and are size-checked before
' reading/ParseJSON. tmp is not a hard byte quota: also abort on memory pressure.
function httpTransferOnce(url as string, body as dynamic, bearer as string, timeoutMs as integer, maxBytes as integer, method = "GET" as string, checkedJson = invalid as dynamic) as object
    key = textValue(m.key)
    if bearer <> "" then key = ""
    permit = requestGateAcquire(url, key)
    if not permit.allowed then return {status: 0, headers: {}, body: "", bytes: -1, error: permit.reason}
    result = httpTransferPermitted(url, body, bearer, timeoutMs, maxBytes, method, checkedJson, permit)
    requestGateReport(permit, result)
    return result
end function

function httpTransferPermitted(url as string, body as dynamic, bearer as string, timeoutMs as integer, maxBytes as integer, method as string, checkedJson as dynamic, permit as object) as object
    result = {status: 0, headers: {}, body: "", bytes: -1, error: ""}
    method = ucase(method)
    if method <> "GET" and method <> "POST" and method <> "PUT" and method <> "PATCH" and method <> "DELETE"
        result.error = "invalid-request"
        return result
    end if
    payload = httpWriteBody(body, checkedJson)
    if not payload.ok or ((method = "PUT" or method = "PATCH") and not payload.hasBody)
        result.error = "invalid-request"
        return result
    end if
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(url)
    ' GET responses are downloaded to tmp even for failures. Keep Dispatcharr's
    ' specific rejection body until it has been bounded/read below, then delete.
    transfer.retainBodyOnError(true)
    transfer.addHeader("Accept", "application/json")
    mode = "x-api-key"
    agent = ""
    if m.global <> invalid
        mode = textValue(m.global.authHeaderMode)
        agent = textValue(m.global.httpUserAgent)
    end if
    if m.requestMode <> invalid then mode = textValue(m.requestMode)
    if m.requestUserAgent <> invalid then agent = textValue(m.requestUserAgent)
    headers = dispatcharrRequestHeaders(m.key, mode, agent)
    for each name in headers
        if name <> "X-API-Key" and name <> "Authorization" then transfer.addHeader(name, headers[name])
    end for
    transfer.enableEncodings(true)
    if bearer <> ""
        transfer.addHeader("Authorization", "Bearer " + bearer)
    else
        if headers["X-API-Key"] <> invalid then transfer.addHeader("X-API-Key", headers["X-API-Key"])
        if headers.Authorization <> invalid then transfer.addHeader("Authorization", headers.Authorization)
    end if
    file = ""
    fs = CreateObject("roFileSystem")
    monitor = CreateObject("roAppMemoryMonitor")
    if method = "DELETE"
        transfer.setRequest("DELETE")
        started = transfer.asyncGetToString()
    else if not payload.hasBody and method = "GET"
        file = "tmp:/aeriotv-http-" + CreateObject("roDeviceInfo").getRandomUUID() + ".json"
        started = transfer.asyncGetToFile(file)
    else
        transfer.addHeader("Content-Type", "application/json")
        bytes = CreateObject("roByteArray")
        bytes.fromAsciiString(payload.text)
        transfer.addHeader("Content-Length", bytes.count().toStr())
        if method = "PUT" or method = "PATCH" then transfer.setRequest(method)
        started = transfer.asyncPostFromString(payload.text)
    end if
    clock = CreateObject("roTimespan")
    clock.mark()
    if not started then result.error = "network"
    while started and clock.totalMilliseconds() < timeoutMs
        if not requestGatePermitActive(permit)
            result.error = "request-held"
            exit while
        end if
        if httpIsCancelled()
            result.error = "cancelled"
            exit while
        end if
        if monitor <> invalid
            available = monitor.getChannelAvailableMemory()
            if monitor.getMemoryLimitPercent() >= 75 or (available > 0 and available < 32768)
                result.error = "memory"
                exit while
            end if
        end if
        if file <> ""
            stat = fs.stat(file)
            if type(stat) = "roAssociativeArray" and stat.size <> invalid
                result.bytes = stat.size
                if stat.size > maxBytes
                    result.error = "too-large"
                    exit while
                end if
            end if
        end if
        event = wait(50, port)
        if type(event) = "roUrlEvent"
            if event.getInt() = 1
                result.status = event.getResponseCode()
                result.headers = event.getResponseHeaders()
                if result.status > 0
                    if file <> ""
                        stat = fs.stat(file)
                        if type(stat) <> "roAssociativeArray" or stat.size = invalid
                            ' Some firmware retains an error body on the event
                            ' rather than creating the requested download file.
                            ' Do not retry a refused credential to recover it.
                            if result.status >= 400
                                retained = event.getString()
                                bytes = CreateObject("roByteArray")
                                bytes.fromAsciiString(retained)
                                result.bytes = bytes.count()
                                if result.bytes > maxBytes
                                    result.error = "too-large"
                                else
                                    result.body = retained
                                end if
                            else
                                result.error = "invalid-response"
                            end if
                        else if stat.size > maxBytes
                            result.bytes = stat.size
                            result.error = "too-large"
                        else
                            result.body = ReadAsciiFile(file)
                            result.bytes = stat.size
                        end if
                    else
                        ' Native POST responses are buffered before this check.
                        result.body = event.getString()
                        bytes = CreateObject("roByteArray")
                        bytes.fromAsciiString(result.body)
                        result.bytes = bytes.count()
                        if result.bytes > maxBytes then result.error = "too-large"
                    end if
                end if
                exit while
            end if
        end if
    end while
    if result.status = 0 and result.error = "" then result.error = "timeout"
    transfer.asyncCancel()
    transfer = invalid
    if file <> "" then fs.delete(file)
    return result
end function

' checkedJson has already passed the caller's schema/type/UTF-8 budget checks.
' Keep the checked wire representation: serializing a string would quote it;
' serializing the object again could change literal types or byte length.
function httpWriteBody(body as dynamic, checkedJson = invalid as dynamic) as object
    if checkedJson <> invalid
        if GetInterface(checkedJson, "ifString") = invalid or body <> invalid then return {ok: false, hasBody: false, text: ""}
        return {ok: true, hasBody: true, text: checkedJson}
    end if
    if body = invalid then return {ok: true, hasBody: false, text: ""}
    return {ok: true, hasBody: true, text: FormatJson(body)}
end function

function httpGuideWindowUrl(base as string, startTime as string, endTime as string) as string
    encoder = CreateObject("roUrlTransfer")
    return base + "/api/epg/grid/?start=" + encoder.escape(startTime) + "&end=" + encoder.escape(endTime)
end function
