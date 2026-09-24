sub init()
    m.top.functionName = "loadM3u"
end sub

sub loadM3u()
    url = normalizeBaseUrl(m.top.url)
    if url = "" or m.top.connectionId = ""
        m.top.result = {ok: false, message: "Enter a valid M3U URL."}
        return
    end if
    m.top.progress = "Loading M3U channels"
    path = "tmp:/aeriotv-m3u-" + CreateObject("roDeviceInfo").getRandomUUID() + ".txt"
    fs = CreateObject("roFileSystem")
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.setUrl(url)
    transfer.addHeader("User-Agent", dispatcharrUserAgent(textValue(m.global.httpUserAgent)))
    if textValue(m.global.httpReferer) <> "" then transfer.addHeader("Referer", m.global.httpReferer)
    if not transfer.asyncGetToFile(path)
        m.top.result = {ok: false, message: "Could not start M3U download."}
        return
    end if
    clock = CreateObject("roTimespan")
    clock.mark()
    status = 0
    failure = "Playlist download timed out."
    while clock.totalMilliseconds() < 30000
        if m.top.cancelRequested = true then exit while
        stat = fs.stat(path)
        if type(stat) = "roAssociativeArray"
            if GetInterface(stat.size, "ifInt") <> invalid
                if stat.size > 2097152
                    failure = "Playlist exceeds the 2-MiB limit."
                    exit while
                end if
            end if
        end if
        event = wait(50, port)
        if type(event) = "roUrlEvent"
            if event.getInt() = 1
                status = event.getResponseCode()
                exit while
            end if
        end if
    end while
    transfer.asyncCancel()
    transfer = invalid
    if m.top.cancelRequested = true
        fs.delete(path)
        return
    end if
    if status <> 200
        fs.delete(path)
        m.top.result = {ok: false, message: failure}
        return
    end if
    stat = fs.stat(path)
    if type(stat) <> "roAssociativeArray"
        fs.delete(path)
        m.top.result = {ok: false, message: "Playlist file unavailable."}
        return
    end if
    if GetInterface(stat.size, "ifInt") = invalid or stat.size > 2097152
        fs.delete(path)
        m.top.result = {ok: false, message: "Playlist exceeds the 2-MiB limit."}
        return
    end if
    body = ReadAsciiFile(path)
    fs.delete(path)
    parsed = m3uParsePlaylist(body)
    if not parsed.ok
        m.top.result = parsed
        return
    end if
    scope = metadataCacheDigest("m3u|" + url + "|" + m.top.connectionId)
    generation = metadataCacheDigest(body)
    body = invalid
    if m.top.cancelRequested = true then return
    m.top.result = {ok: true, channels: parsed.channels, groups: parsed.groups, scope: scope, generation: generation, accountId: "feed", apiKey: "", warning: ""}
end sub
