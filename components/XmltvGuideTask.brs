sub loadXmltvWindow()
    start = m.top.windowStart
    if m.top.providerType = "xtream"
        origin = urlOrigin(m.top.baseUrl)
        expected = origin + "/xmltv.php?username="
        if origin = "" or left(m.top.guideUrl, len(expected)) <> expected or instr(1, m.top.guideUrl, "&password=") = 0
            m.top.result = {ok: false, windowStart: start, message: "Invalid Xtream guide endpoint."}
            return
        end if
    else if normalizeBaseUrl(m.top.guideUrl) = ""
        m.top.result = {ok: false, windowStart: start, message: "Set an XMLTV guide URL for this M3U connection."}
        return
    end if
    path = "tmp:/aeriotv-xmltv-" + CreateObject("roDeviceInfo").getRandomUUID() + ".xml"
    download = xmltvDownloadToFile(m.top.guideUrl, path)
    if not download.ok
        if m.top.cancelRequested <> true then m.top.result = {ok: false, windowStart: start, message: download.message}
        return
    end if
    result = xmltvReadWindowFile(path, start, start + 10800, m.top.allowedKeys)
    CreateObject("roFileSystem").delete(path)
    if m.top.cancelRequested = true then return
    if not result.ok
        m.top.result = {ok: false, windowStart: start, message: result.message}
        return
    end if
    now = CreateObject("roDateTime").asSeconds()
    metadataCacheWrite(m.top.scope, "guide", start.toStr(), m.top.generation, now, metadataCacheGuidePayload(result.index))
    m.top.result = {ok: true, windowStart: start, index: result.index, fetched: now, source: "xmltv"}
end sub
