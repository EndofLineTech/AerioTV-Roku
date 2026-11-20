sub main(httpM3u as string, plainM3u as string, httpXml as string, plainXml as string)
    check(m3uStagedPlaylistIssue("m3u-raw", 64) = "Raw gzip M3U is unsupported. Use a plain M3U playlist URL.", "raw M3U is rejected before converting to text")
    check(m3uStagedPlaylistIssue("m3u-missing", 64) = "Could not read playlist file.", "failed prefix read is not treated as text")
    check(m3uStagedPlaylistIssue("m3u-http", len(httpM3u)) = "", "already HTTP-decoded M3U is text")
    check(m3uStagedPlaylistIssue("plain.m3u.gz", len(plainM3u)) = "", "M3U .gz suffix is not a format signal")
    for each text in [httpM3u, plainM3u]
        parsed = m3uParsePlaylist(text)
        check(parsed.ok and parsed.channels.count() = 1 and parsed.channels[0].epgKey = "station.alpha", "plain M3U fixture parses")
    end for

    check(xmltvFileEncoding("xml-raw", 64) = "gzip", "raw XMLTV magic is checked without a suffix")
    check(xmltvFileEncoding("xml-http", len(httpXml)) = "xml", "already HTTP-decoded XMLTV is XML")
    check(xmltvFileEncoding("plain.xml.gz", len(plainXml)) = "xml", "XMLTV .gz suffix is not a format signal")
    start = guideEpoch("2026-09-23T18:00:00Z")
    allowed = guideDictionary()
    allowed["station.alpha"] = true
    for each text in [httpXml, plainXml]
        state = xmltvWindowState(start, start + 10800, allowed)
        xmltvConsumeChunk(state, left(text, 151))
        xmltvConsumeChunk(state, mid(text, 152))
        check(state.error = "" and state.count = 1 and state.index["station.alpha"][0].title = "Fixture News", "plain XMLTV fixture indexes one programme")
    end for
    print "ALL TESTS PASSED"
end sub

sub check(passed as boolean, label as string)
    if not passed
        print "FAIL: "; label
        stop
    end if
end sub
