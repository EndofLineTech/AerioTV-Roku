sub init()
    m.top.functionName = "runProbe"
end sub

sub runProbe()
    start = guideEpoch("2026-09-23T18:00:00Z")
    allowed = guideDictionary()
    allowed["station.alpha"] = true
    fields = xmltvNativeFields("<programme channel=""station.alpha""><title>News &amp; Weather</title><desc>Café updates</desc><new/></programme>")
    if fields = invalid
        m.top.result = {ok: false}
        return
    end if
    if fields.title <> "News & Weather" or fields.description <> "Café updates" or fields.is_new <> true
        m.top.result = {ok: false}
        return
    end if
    result = xmltvReadWindowFile("pkg:/data/xmltv-probe.txt", start, start + 10800, allowed, invalid, 4096, 37)
    compressed = xmltvReadWindowFile("pkg:/data/xmltv-probe.gz", start, start + 10800, allowed, invalid, 4096, 37)
    if result.ok and result.count = 1 and result.index["station.alpha"][0].title = "News & Weather" and not compressed.ok and instr(1, compressed.message, ".xml.gz") > 0
        if m.top.feedUrl <> ""
            m.top.result = probeLargeFeed()
        else
            m.top.result = {ok: true}
        end if
    else
        m.top.result = {ok: false, reason: "fixture"}
    end if
end sub

function probeLargeFeed() as object
    path = "tmp:/xmltv-probe-feed.xml"
    fs = CreateObject("roFileSystem")
    download = xmltvDownloadToFile(m.top.feedUrl, path)
    if not download.ok then return {ok: false, reason: "download"}
    stat = fs.stat(path)
    if type(stat) <> "roAssociativeArray" then return {ok: false, reason: "file-stat"}
    if stat.size < 1000000 or stat.size > 75497472
        fs.delete(path)
        return {ok: false, reason: "file-size"}
    end if
    sample = CreateObject("roByteArray")
    if not sample.readFile(path, 0, 2097152)
        fs.delete(path)
        return {ok: false, reason: "sample-read"}
    end if
    valid = xmltvUtf8PrefixLength(sample)
    if valid < 1
        fs.delete(path)
        return {ok: false, reason: "sample-utf8"}
    end if
    while sample.count() > valid
        sample.pop()
    end while
    text = sample.toAsciiString()
    sample = invalid
    beginning = instr(1, text, "<programme")
    if beginning = 0
        fs.delete(path)
        return {ok: false, reason: "program-start"}
    end if
    header = mid(text, beginning, 256)
    text = invalid
    quote = chr(34)
    channelParts = CreateObject("roRegex", "channel=" + quote + "([^" + quote + "]{1,128})" + quote, "").match(header)
    timeParts = CreateObject("roRegex", "start=" + quote + "([^" + quote + "]{1,40})" + quote, "").match(header)
    if channelParts.count() <> 2 or timeParts.count() <> 2
        fs.delete(path)
        return {ok: false, reason: "program-header"}
    end if
    start = xmltvEpoch(timeParts[1])
    if start = invalid
        fs.delete(path)
        return {ok: false, reason: "program-time"}
    end if
    marker = "/output/epg/"
    position = instr(1, m.top.feedUrl, marker)
    if position < 1
        fs.delete(path)
        return {ok: false, reason: "m3u-location"}
    end if
    playlistUrl = left(m.top.feedUrl, position - 1) + "/output/m3u/" + mid(m.top.feedUrl, position + len(marker))
    m3uFile = "tmp:/xmltv-probe-playlist.m3u"
    xfer = CreateObject("roUrlTransfer")
    xfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.setUrl(playlistUrl)
    if xfer.getToFile(m3uFile) <> 200
        fs.delete(path)
        fs.delete(m3uFile)
        return {ok: false, reason: "m3u-download"}
    end if
    statPlaylist = fs.stat(m3uFile)
    if type(statPlaylist) <> "roAssociativeArray"
        fs.delete(path)
        fs.delete(m3uFile)
        return {ok: false, reason: "m3u-stat"}
    end if
    if GetInterface(statPlaylist.size, "ifInt") = invalid or statPlaylist.size > 2097152
        fs.delete(path)
        fs.delete(m3uFile)
        return {ok: false, reason: "m3u-size"}
    end if
    playlist = m3uParsePlaylist(ReadAsciiFile(m3uFile))
    fs.delete(m3uFile)
    if not playlist.ok
        fs.delete(path)
        return {ok: false, reason: "m3u-parse"}
    end if
    allowed = guideDictionary()
    for each channel in playlist.channels
        if channel.epgKey <> "" then allowed[channel.epgKey] = true
    end for
    channelCount = playlist.channels.count()
    playlist = invalid
    ' Measure the live guide window, not only the feed's earliest programme.
    start = (CreateObject("roDateTime").asSeconds() \ 10800) * 10800
    scan = CreateObject("roTimespan")
    scan.mark()
    result = xmltvReadWindowFile(path, start, start + 10800, allowed)
    fs.delete(path)
    if not result.ok then return {ok: false, reason: "window-scan"}
    if result.count < 1 then return {ok: false, reason: "no-programs"}
    return {ok: true, large: true, count: result.count, channels: channelCount, elapsed: scan.totalSeconds()}
end function
