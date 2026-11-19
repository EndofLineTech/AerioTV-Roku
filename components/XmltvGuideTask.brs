sub loadXmltvWindow()
    start = m.top.windowStart
    url = m.top.guideUrl
    if normalizeBaseUrl(url) = ""
        if m.top.providerType <> "xtream"
            publishXmltvResult({ok: false, windowStart: start, message: "Set an XMLTV guide URL for this connection."})
            return
        end if
        base = normalizeBaseUrl(m.top.baseUrl)
        expected = base + "/xmltv.php?"
        query = mid(url, len(expected) + 1)
        escapedValue = "([A-Za-z0-9_.~-]|%[0-9A-F]{2}){1,64}"
        accountQuery = CreateObject("roRegex", "^username=" + escapedValue + "&password=" + escapedValue + "$", "")
        if base = "" or left(url, len(expected)) <> expected or not accountQuery.isMatch(query)
            publishXmltvResult({ok: false, windowStart: start, message: "Invalid Xtream guide endpoint."})
            return
        end if
    end if
    path = "tmp:/aeriotv-xmltv-" + CreateObject("roDeviceInfo").getRandomUUID() + ".xml"
    download = xmltvDownloadToFile(url, path, m.top.providerType <> "xtream")
    if not download.ok
        publishXmltvResult({ok: false, windowStart: start, message: download.message})
        return
    end if
    result = xmltvReadWindowFile(path, start, start + 10800, m.top.allowedKeys)
    CreateObject("roFileSystem").delete(path)
    if m.top.cancelRequested = true
        publishXmltvResult({ok: false, windowStart: start, message: "XMLTV load cancelled."})
        return
    end if
    if not result.ok
        publishXmltvResult({ok: false, windowStart: start, message: result.message})
        return
    end if
    now = CreateObject("roDateTime").asSeconds()
    metadataCacheWrite(m.top.scope, "guide", start.toStr(), m.top.generation, now, metadataCacheGuidePayload(result.index))
    publishXmltvResult({ok: true, windowStart: start, index: result.index, fetched: now, source: "xmltv"})
end sub

sub publishXmltvResult(result as object)
    m.key = ""
    m.top.apiKey = ""
    m.top.guideUrl = ""
    if m.top.cancelRequested <> true then m.top.result = result
end sub
