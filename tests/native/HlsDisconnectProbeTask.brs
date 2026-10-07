' Disposable, one-session native probe. Do not print headers, URLs or tokens.
sub init()
    m.top.functionName = "probeHlsDisconnect"
end sub

function probeHeader(headers as dynamic, wanted as string) as string
    if type(headers) <> "roArray" then return ""
    for each row in headers
        if type(row) = "roAssociativeArray"
            for each name in row
                if lcase(name) = lcase(wanted) then return row[name]
            end for
        end if
    end for
    return ""
end function

function probeRequest(url as string, key as string, method as string, timeoutMs as integer) as object
    result = {status: 0, headers: []}
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(url)
    transfer.addHeader("X-API-Key", key)
    if method = "DELETE" then transfer.setRequest("DELETE")
    started = transfer.asyncGetToString()
    clock = CreateObject("roTimespan")
    clock.mark()
    while started and clock.totalMilliseconds() < timeoutMs
        event = wait(50, port)
        if type(event) = "roUrlEvent" and event.getInt() = 1
            result.status = event.getResponseCode()
            result.headers = event.getResponseHeadersArray()
            exit while
        end if
    end while
    transfer.asyncCancel()
    return result
end function

sub probeHlsDisconnect()
    base = m.top.baseUrl
    key = m.top.apiKey
    uuid = m.top.channelUuid
    m.top.apiKey = ""
    if not CreateObject("roRegex", "^[A-Za-z0-9-]+$", "").isMatch(uuid) then return
    response = probeRequest(base + "/proxy/ts/stream/" + uuid + "?output_format=hls", key, "GET", 20000)
    token = probeHeader(response.headers, "X-Dispatcharr-Session-Token")
    location = probeHeader(response.headers, "Location")
    ' Only accept a token bound to the expected Dispatcharr capability path.
    if not CreateObject("roRegex", "^[A-Za-z0-9_-]{16,128}$", "").isMatch(token) then token = ""
    if token <> "" and location <> ""
        if instr(1, location, "/proxy/hls/" + token + "/index.m3u8") = 0 then token = ""
    end if
    print "[hls-disconnect-probe] mint-status="; response.status; " token-visible="; token <> ""; " location-visible="; location <> ""
    if token <> ""
        stopped = probeRequest(base + "/api/proxy/hls/sessions/" + token + "/", key, "DELETE", 8000)
        print "[hls-disconnect-probe] delete-status="; stopped.status
    end if
    token = ""
    key = ""
    m.top.result = "complete"
end sub
