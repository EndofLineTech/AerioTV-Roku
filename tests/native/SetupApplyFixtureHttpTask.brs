' Isolated synthetic HTTP dependency. Bind LOOPBACK ONLY; no app registry,
' real credentials, external requests, or shipping setup entropy bypass.
sub init()
    m.top.functionName = "serveFixture"
end sub

sub serveFixture()
    m.port = CreateObject("roMessagePort")
    listener = CreateObject("roStreamSocket")
    listener.setMessagePort(m.port)
    address = CreateObject("roSocketAddress")
    if not address.setAddress("127.0.0.1:0") then stop
    if not listener.setAddress(address) or not listener.listen(4) then stop
    listener.notifyReadable(true)
    m.base = "http://127.0.0.1:" + listener.getAddress().getPort().toStr()
    m.responses = parseJson(ReadAsciiFile("pkg:/SetupApplyFixtureHttpResponses.json"))
    m.top.baseUrl = m.base
    while not m.top.cancelRequested
        if listener.isReadable()
            client = listener.accept()
            if client <> invalid
                client.setMessagePort(m.port)
                client.notifyReadable(true)
                client.notifyWritable(true)
                serveFixtureClient(client)
                client.close()
            end if
        end if
        event = wait(10, m.port)
    end while
    listener.close()
end sub

sub serveFixtureClient(client as object)
    head = ""
    clock = CreateObject("roTimespan")
    clock.mark()
    while instr(1, head, chr(13) + chr(10) + chr(13) + chr(10)) = 0
        if len(head) > 16384 or clock.totalMilliseconds() > 10000 or m.top.cancelRequested then return
        if client.isReadable()
            bytes = CreateObject("roByteArray")
            bytes[4095] = 0
            count = client.receive(bytes, 0, 4096)
            if count = 0 then return
            if count > 0 then head += bytes.slice(0, count).toAsciiString()
        end if
        event = wait(10, m.port)
    end while
    lines = head.split(chr(13) + chr(10))
    request = lines[0].split(" ")
    if request.count() <> 3 or (request[0] <> "GET" and request[0] <> "POST") then stop
    path = request[1]
    headers = {}
    for i = 1 to lines.count() - 1
        colon = instr(1, lines[i], ":")
        if colon > 1 then headers[lcase(left(lines[i], colon - 1))] = mid(lines[i], colon + 1).trim()
    end for
    if headers["user-agent"] <> "Fixture-Agent" then stop
    if headers.doesExist("referer") then stop
    bodyStart = instr(1, head, chr(13) + chr(10) + chr(13) + chr(10)) + 4
    requestBody = mid(head, bodyStart)
    if request[0] = "POST"
        if not headers.doesExist("content-length") then stop
        wanted = headers["content-length"].toInt()
        if wanted < 1 or wanted > 4096 then stop
        while len(requestBody) < wanted
            if clock.totalMilliseconds() > 10000 then return
            if client.isReadable()
                bytes = CreateObject("roByteArray")
                bytes[4095] = 0
                count = client.receive(bytes, 0, 4096)
                if count = 0 then return
                if count > 0 then requestBody += bytes.slice(0, count).toAsciiString()
            end if
            event = wait(10, m.port)
        end while
    end if
    family = "dispatcharr"
    body = "[]"
    contentType = "application/json"
    status = "200 OK"
    if instr(1, path, "/api/") > 0
        login = path = "/api/accounts/token/"
        bearer = headers["authorization"] = "Bearer fixture-session-token" and path = "/api/accounts/users/me/"
        if login or bearer
            if headers.doesExist("x-api-key") then stop
        else
            if headers["x-api-key"] <> "fixture-api-key" or headers.doesExist("authorization") then stop
        end if
        if login
            if request[0] <> "POST" or headers.doesExist("authorization") then stop
            credentials = parseJson(requestBody)
            if credentials.username <> "Viewer" or credentials.password <> "fixture-password" then stop
            body = "{""access"":""fixture-session-token""}"
            family = "dispatcharr-login"
        else if instr(1, path, "/reject/") > 0
            status = "401 Unauthorized"
            body = "{}"
        else if instr(1, path, "/users/me/") > 0
            body = formatJson(m.responses.user)
        else if instr(1, path, "/channels/summary/") > 0
            body = formatJson(m.responses.channels)
        else if instr(1, path, "/channels/profiles/") > 0
            body = formatJson(m.responses.profiles)
            family = "dispatcharr-profiles"
        else if instr(1, path, "/channels/groups/") > 0
            body = "[]"
        else if instr(1, path, "/epg/grid/") > 0
            body = formatJson(m.responses.programs)
            family = "guide-json"
        else
            stop
        end if
    else
        if headers.doesExist("x-api-key") or headers.doesExist("authorization") then stop
        family = "xtream"
        if instr(1, path, "/slow/") > 0 then sleep(5000)
        if instr(1, path, "/player_api.php?") > 0
            if instr(1, path, "username=Viewer") = 0 or instr(1, path, "password=fixture-password") = 0 then stop
            if instr(1, path, "action=get_live_categories") > 0
                body = formatJson(m.responses.xc_categories)
            else if instr(1, path, "action=get_live_streams") > 0
                body = formatJson(m.responses.xc_channels)
            else if instr(1, path, "action=get_vod_categories") > 0 or instr(1, path, "action=get_series_categories") > 0
                body = "[]"
            else
                body = formatJson(m.responses.xc_account)
            end if
        else if left(path, 6) = "/feed?"
            if path <> "/feed?token=session-token" then stop
            family = "m3u"
            contentType = "application/x-mpegurl"
            body = "#EXTM3U" + chr(10) + "#EXTINF:-1 tvg-id=""fixture.station"",Synthetic" + chr(10) + m.base + "/stream.ts" + chr(10)
        else if path = "/guide.xml" or left(path, 11) = "/xmltv.php?"
            family = "guide-xmltv"
            contentType = "application/xml"
            body = ReadAsciiFile("pkg:/SetupApplyFixtureGuide.xml")
        else
            stop
        end if
    end if
    crlf = chr(13) + chr(10)
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString("HTTP/1.1 " + status + crlf + "Content-Type: " + contentType + crlf + "Content-Length: " + len(body).toStr() + crlf + "Connection: close" + crlf + crlf + body)
    sent = 0
    clock.mark()
    while sent < bytes.count() and clock.totalMilliseconds() < 3000
        if client.isWritable()
            count = client.send(bytes, sent, bytes.count() - sent)
            if count > 0 then sent += count
            if count <= 0 and not client.eOK() then return ' Expected on cancellation.
        end if
        if sent < bytes.count() then event = wait(10, m.port)
    end while
    print "[setup-apply] "; formatJson({kind: "http_request", family: family})
end sub
