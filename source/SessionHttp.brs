' Session mutations are never automatically repeated. DELETE is owner-scoped.
function sessionMutation(url as string, method as string, body = invalid as dynamic) as object
    permit = requestGateAcquire(url, m.key)
    if not permit.allowed then return {status: 0, data: invalid}
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(url)
    mode = "x-api-key"
    agent = ""
    if m.global <> invalid
        mode = textValue(m.global.authHeaderMode)
        agent = textValue(m.global.httpUserAgent)
    end if
    headers = dispatcharrRequestHeaders(m.key, mode, agent)
    headers["Content-Type"] = "application/json"
    transfer.setHeaders(headers)
    transfer.retainBodyOnError(true)
    transfer.setRequest(method)
    started = false
    if method = "DELETE" then started = transfer.asyncGetToString()
    if method = "POST" then started = transfer.asyncPostFromString(FormatJson(body))
    result = {status: 0, data: invalid}
    if started
        clock = CreateObject("roTimespan")
        clock.mark()
        while clock.totalMilliseconds() < 15000 and requestGatePermitActive(permit)
            if httpIsCancelled() then exit while
            event = wait(50, port)
            if type(event) = "roUrlEvent"
                if event.getInt() = 1
                    result.status = event.getResponseCode()
                    raw = event.getString()
                    requestGateReportEvent(permit, event, raw)
                    if raw <> "" and len(raw) <= 1048576 then result.data = ParseJson(raw)
                    exit while
                end if
            end if
        end while
    end if
    transfer.asyncCancel()
    requestGateRelease(permit)
    return result
end function
