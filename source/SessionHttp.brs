' Session mutations are never automatically repeated. DELETE is owner-scoped.
function sessionMutation(url as string, method as string, body = invalid as dynamic) as object
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(url)
    transfer.setHeaders({"X-API-Key": m.key, "Authorization": "ApiKey " + m.key, "Content-Type": "application/json"})
    transfer.retainBodyOnError(true)
    transfer.setRequest(method)
    started = false
    if method = "DELETE" then started = transfer.asyncGetToString()
    if method = "POST" then started = transfer.asyncPostFromString(FormatJson(body))
    result = {status: 0, data: invalid}
    if started
        event = wait(15000, port)
        if type(event) = "roUrlEvent"
            result.status = event.getResponseCode()
            raw = event.getString()
            if raw <> "" and len(raw) <= 1048576 then result.data = ParseJson(raw)
        end if
    end if
    transfer.asyncCancel()
    return result
end function
