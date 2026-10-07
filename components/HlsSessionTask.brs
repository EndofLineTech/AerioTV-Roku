' Dispatcharr's HLS entry mints a client and redirects to an opaque playlist.
' Roku returns the 302 headers in GetResponseHeadersArray even after following
' the redirect (verified on 3820RW2 / OS 15.3.4). Never log the token or URL.
sub init()
    m.top.functionName = "runHlsSession"
end sub

function stopOwnedHlsSession(base as string, token as string, key as string) as integer
    if not CreateObject("roRegex", "^[A-Za-z0-9_-]{16,128}$", "").isMatch(token) then return 0
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(base + "/api/proxy/hls/sessions/" + token + "/")
    transfer.addHeader("X-API-Key", key)
    transfer.setRequest("DELETE")
    status = 0
    if transfer.asyncGetToString()
        event = wait(8000, port)
        if type(event) = "roUrlEvent" then status = event.getResponseCode()
    end if
    transfer.asyncCancel()
    return status
end function

function mintOwnedHlsSession(base as string, url as string, key as string) as object
    result = {session: invalid, status: 0}
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(url)
    transfer.addHeader("X-API-Key", key)
    path = "tmp:/aeriotv-hls-" + CreateObject("roDeviceInfo").getRandomUUID() + ".m3u8"
    fs = CreateObject("roFileSystem")
    started = transfer.asyncGetToFile(path)
    clock = CreateObject("roTimespan")
    clock.mark()
    while started and clock.totalMilliseconds() < 20000
        event = wait(50, port)
        if type(event) = "roUrlEvent" and event.getInt() = 1
            result.status = event.getResponseCode()
            result.session = hlsSessionFromHeaders(base, event.getResponseHeadersArray())
            exit while
        end if
        stat = fs.stat(path)
        if type(stat) = "roAssociativeArray"
            if stat.size <> invalid and stat.size > 262144 then exit while
        end if
    end while
    transfer.asyncCancel()
    fs.delete(path)
    return result
end function

sub runHlsSession()
    base = normalizeBaseUrl(m.top.baseUrl)
    key = m.top.apiKey
    result = {ok: false, status: 0}
    if base <> "" and key <> ""
        if m.top.operation = "close"
            result.status = stopOwnedHlsSession(base, m.top.token, key)
            result.ok = result.status = 204 or result.status = 404
        else if m.top.operation = "open"
            mint = mintOwnedHlsSession(base, m.top.entryUrl, key)
            result.status = mint.status
            if mint.session <> invalid
                if m.top.cancelRequested or mint.status < 200 or mint.status >= 400
                    stopOwnedHlsSession(base, mint.session.token, key)
                else
                    result.ok = true
                    result.url = mint.session.url
                    result.token = mint.session.token
                end if
            end if
        end if
    end if
    m.top.apiKey = ""
    m.top.entryUrl = ""
    m.top.token = ""
    key = ""
    m.top.result = result
end sub
