' Loopback-only synthetic images and header assertions. No account or registry.
sub init()
    m.top.functionName = "serveLogoFixture"
end sub

sub serveLogoFixture()
    m.port = CreateObject("roMessagePort")
    listener = CreateObject("roStreamSocket")
    listener.setMessagePort(m.port)
    address = CreateObject("roSocketAddress")
    if not address.setAddress("127.0.0.1:0") then stop
    if not listener.setAddress(address) or not listener.listen(8) then stop
    listener.notifyReadable(true)
    m.base = "http://127.0.0.1:" + listener.getAddress().getPort().toStr()
    m.counts = {remote: 0, proxy: 0, authLeaks: 0, exactQuery: 0, redirects: 0, authHeaders: 0, referers: 0, privateAgents: 0}
    m.top.baseUrl = m.base
    while not m.top.cancelRequested
        if listener.isReadable()
            client = listener.accept()
            if client <> invalid
                client.setMessagePort(m.port)
                client.notifyReadable(true)
                client.notifyWritable(true)
                serveLogoClient(client)
                client.close()
            end if
        end if
        event = wait(10, m.port)
    end while
    listener.close()
end sub

sub serveLogoClient(client as object)
    clock = CreateObject("roTimespan")
    clock.mark()
    crlf = chr(13) + chr(10)
    head = ""
    while instr(1, head, crlf + crlf) = 0
        if len(head) > 16384 or clock.totalMilliseconds() > 5000 then return
        if client.isReadable()
            chunk = CreateObject("roByteArray")
            chunk[4095] = 0
            count = client.receive(chunk, 0, 4096)
            if count = 0 then return
            if count > 0 then head += chunk.slice(0, count).toAsciiString()
        end if
        event = wait(10, m.port)
    end while
    lines = head.split(crlf)
    parts = lines[0].split(" ")
    if parts.count() <> 3 or parts[0] <> "GET" then stop
    path = parts[1]
    headers = {}
    for each line in lines
        colon = instr(1, line, ":")
        if colon > 1 then headers[lcase(left(line, colon - 1))] = mid(line, colon + 1).trim()
    end for
    proxy = path = "/api/channels/logos/12/cache/"
    if proxy
        m.counts.proxy++
        if headers["x-api-key"] <> "private-fixture-key" or headers.authorization <> "ApiKey private-fixture-key" then stop
    else if path <> "/guide.xml"
        m.counts.remote++
        if headers.doesExist("x-api-key") or headers.doesExist("authorization") then m.counts.authHeaders++
        if headers.doesExist("referer") and headers["referer"] <> "" then m.counts.referers++
        if headers["user-agent"] = "PrivateProviderAgent" then m.counts.privateAgents++
        if headers.doesExist("x-api-key") or headers.doesExist("authorization") or (headers.doesExist("referer") and headers["referer"] <> "") or headers["user-agent"] = "PrivateProviderAgent" then m.counts.authLeaks++
        if path = "/logo.png?token=fixture%2Bvalue&size=100" then m.counts.exactQuery++
    end if
    body = CreateObject("roByteArray")
    body.fromBase64String(ReadAsciiFile("pkg:/logo-fixture.base64"))
    status = "200 OK"
    extra = ""
    contentType = "image/png"
    if path = "/redirect"
        status = "302 Found"
        extra = "Location: " + m.base + "/logo.png?token=fixture%2Bvalue&size=100" + crlf
        body.clear()
        m.counts.redirects++
    else if path = "/bad.png"
        body.fromAsciiString("not an image")
    else if path = "/large.png"
        body[2097152] = 0
    else if path = "/missing.png"
        status = "404 Not Found"
        body.fromAsciiString("missing")
    else if path = "/guide.xml"
        contentType = "application/xml"
        body.fromAsciiString("<tv></tv>")
    else if path <> "/logo.png?token=fixture%2Bvalue&size=100" and not proxy
        stop
    end if
    m.top.counts = m.counts
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString("HTTP/1.1 " + status + crlf + "Content-Type: " + contentType + crlf + extra + "Content-Length: " + body.count().toStr() + crlf + "Connection: close" + crlf + crlf)
    bytes.append(body)
    sent = 0
    clock.mark()
    while sent < bytes.count() and clock.totalMilliseconds() < 5000
        if client.isWritable()
            count = client.send(bytes, sent, bytes.count() - sent)
            if count > 0 then sent += count
            if count <= 0 and not client.eOK() then return
        end if
        if sent < bytes.count() then event = wait(10, m.port)
    end while
end sub
